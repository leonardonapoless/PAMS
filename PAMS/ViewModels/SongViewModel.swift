import Foundation
import Combine

enum SearchStatus: Equatable {
    case idle
    case noResults(query: String)
    case lowRelevance(query: String)
    case networkError
    case rateLimited
    case sessionExpired
    case genericError
    
    var message: String {
        switch self {
        case .idle: ""
        case .noResults(let query): "No results found for \"\(query)\""
        case .lowRelevance: "Not what you're looking for? Try refining your search"
        case .networkError: "No internet connection"
        case .rateLimited: "Too many requests. Try again shortly"
        case .sessionExpired: "Session expired. Retrying..."
        case .genericError: "Something went wrong"
        }
    }
    
    var icon: String {
        switch self {
        case .idle: ""
        case .noResults: "magnifyingglass"
        case .lowRelevance: "questionmark.circle"
        case .networkError: "wifi.slash"
        case .rateLimited: "clock.badge.exclamationmark"
        case .sessionExpired: "arrow.clockwise"
        case .genericError: "exclamationmark.triangle"
        }
    }
}

@MainActor
final class SongViewModel: ObservableObject {

    @Published private(set) var results: [SearchResultItem] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var status: SearchStatus = .idle 

    private let apiService = MusicAPIService.shared
    private let batchLoader = MusicBatchLoader()
    private let searchRanker = MusicSearchRanker()
    private var searchTask: Task<Void, Never>?

    func search(term: String) {
        searchTask?.cancel() 

        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        
        results = []
        status = .idle

        guard !trimmed.isEmpty else {
            isLoading = false
            return
        }

        isLoading = true
        
        searchTask = Task {
            do {
                var (spotifyTracks, spotifyAlbums) = try await apiService.searchSpotify(term: trimmed)
                
                guard !Task.isCancelled else { return }
                
                (spotifyTracks, spotifyAlbums) = await batchLoader.enrich(tracks: spotifyTracks, albums: spotifyAlbums)
                
                guard !Task.isCancelled else { return }

                let rankedResult = await searchRanker.sortAndFilter(tracks: spotifyTracks, albums: spotifyAlbums, term: trimmed)
                let rankedItems = rankedResult.items

                guard !Task.isCancelled else { return }

                if rankedItems.isEmpty {
                    self.status = .noResults(query: trimmed)
                } else if !rankedResult.hasRelevantResults {
                    self.status = .lowRelevance(query: trimmed)
                }

                if let firstRanked = rankedItems.first {
                    let firstResult: SearchResultItem
                    switch firstRanked.item {
                    case .track(let t): 
                        let p = await self.augmentSpotifyTrack(t)
                        firstResult = .track(p)
                    case .album(let a): 
                        let p = await self.augmentSpotifyAlbum(a)
                        firstResult = .album(p)
                    }
                    
                    guard !Task.isCancelled else { return }
                    
                    var initialResults = [firstResult]
                    let remainingRanked = Array(rankedItems.dropFirst())
                    
                    initialResults.append(contentsOf: remainingRanked.map { item in
                        switch item.item {
                        case .track(let t): return .track(self.createPlaceholder(from: t))
                        case .album(let a): return .album(self.createPlaceholder(from: a))
                        }
                    })
                    
                    self.results = initialResults
                    self.isLoading = false
                    
                    await withTaskGroup(of: SearchResultItem.self, returning: Void.self) { group in
                        for item in remainingRanked {
                            group.addTask {
                                switch item.item {
                                case .track(let t): 
                                    return .track(await self.augmentSpotifyTrack(t))
                                case .album(let a): 
                                    return .album(await self.augmentSpotifyAlbum(a))
                                }
                            }
                        }
                        
                        for await result in group {
                            if !Task.isCancelled {
                                if let index = self.results.firstIndex(where: { $0.id == result.id }) {
                                    self.results[index] = result
                                }
                            }
                        }
                    }
                }
                
                guard !Task.isCancelled else { return }

            } catch is CancellationError {
            } catch let error as URLError where error.code == .cancelled {
            } catch let error as MusicAPIError {
                switch error {
                case .unauthorized: self.status = .sessionExpired
                case .rateLimited: self.status = .rateLimited
                case .network: self.status = .networkError
                case .decoding, .invalidResponse: self.status = .genericError
                }
                self.results = []
            } catch {
                print("search failed with error: \(error)")
                self.status = .genericError
                self.results = []
            }
            
            if !Task.isCancelled {
                isLoading = false
            }
        }
    }

    private func augmentSpotifyTrack(_ track: SpotifyTrack) async -> TrackPresentation {
        async let linksTask = apiService.getSonglink(for: track.externalUrls.spotify)
        async let creditsTask = apiService.getMusicBrainzCredits(isrc: track.externalIds?.isrc)
        
        let platformLinks = await linksTask
        let credits = await creditsTask
        
        let releaseDate = credits.releaseDate ?? track.album.releaseDate
        let albumName = credits.album ?? track.album.name
        
        var genre: String = "n/a"
        if let g = credits.genre {
            genre = g.capitalized
        } else if let spotifyGenres = track.artists.first?.genres, !spotifyGenres.isEmpty {
            genre = (spotifyGenres.first ?? "n/a").capitalized
        } else if let albumGenre = track.album.genres?.first {
            genre = albumGenre.capitalized
        }

        var duration: String = "n/a"
        if let d = credits.duration {
            duration = d
        } else if let durationMs = track.durationMs {
            duration = "\(durationMs / 1000 / 60):\(String(format: "%02d", (durationMs / 1000) % 60))"
        }

        let recordLabel = credits.recordLabel ?? track.album.label ?? "n/a"
        let copyright = (credits.copyright ?? track.album.copyrights?.first?.text ?? "n/a").cleanedCopyright

        return TrackPresentation(
            id: track.id,
            title: track.name,
            artist: track.artistName,
            releaseDate: releaseDate,
            album: albumName,
            genre: genre,
            duration: duration,
            recordLabel: recordLabel,
            copyright: copyright,
            artworkURL: track.album.artworkURL,
            isrc: track.externalIds?.isrc,
            links: platformLinks ?? PlatformLinks()
        )
    }
    
    private func augmentSpotifyAlbum(_ album: SpotifyAlbum) async -> AlbumPresentation {
        var platformLinks = PlatformLinks()
        if let url = album.externalUrls?.spotify {
             if let links = await apiService.getSonglink(for: url) {
                 platformLinks = links
             }
        }

        let mainArtistGenre = album.artists.first?.genres?.first?.capitalized
        let albumGenre = album.genres?.first?.capitalized
        let genre = albumGenre ?? mainArtistGenre ?? "n/a"
        
        let tracksCount = album.totalTracks.map { "\($0) Songs" } ?? "n/a"

        return AlbumPresentation(
            id: album.id,
            title: album.name,
            artist: album.artistName,
            releaseDate: album.releaseDate,
            genre: genre,
            totalTracks: tracksCount,
            recordLabel: album.label ?? "n/a",
            copyright: (album.copyrights?.first?.text ?? "n/a").cleanedCopyright,
            artworkURL: album.artworkURL,
            links: platformLinks
        )
    }
    
    private func createPlaceholder(from track: SpotifyTrack) -> TrackPresentation {
        var duration = "n/a"
        if let durationMs = track.durationMs {
            duration = "\(durationMs / 1000 / 60):\(String(format: "%02d", (durationMs / 1000) % 60))"
        }
        
        return TrackPresentation(
            id: track.id,
            title: track.name,
            artist: track.artistName,
            releaseDate: track.album.releaseDate,
            album: track.album.name,
            genre: track.artists.first?.genres?.first?.capitalized ?? "n/a",
            duration: duration,
            recordLabel: track.album.label ?? "n/a",
            copyright: (track.album.copyrights?.first?.text ?? "n/a").cleanedCopyright,
            artworkURL: track.album.artworkURL,
            isrc: track.externalIds?.isrc,
            links: PlatformLinks(),
            isLoading: true
        )
    }

    private func createPlaceholder(from album: SpotifyAlbum) -> AlbumPresentation {
        return AlbumPresentation(
            id: album.id,
            title: album.name,
            artist: album.artistName,
            releaseDate: album.releaseDate,
            genre: album.genres?.first?.capitalized ?? "n/a",
            totalTracks: "n/a",
            recordLabel: album.label ?? "n/a",
            copyright: (album.copyrights?.first?.text ?? "n/a").cleanedCopyright,
            artworkURL: album.artworkURL,
            links: PlatformLinks(),
            isLoading: true
        )
    }
}
