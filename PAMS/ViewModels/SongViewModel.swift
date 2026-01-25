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
                let trackAlbumIDs = spotifyTracks.map { $0.album.id }
                let directAlbumIDs = spotifyAlbums.map { $0.id }
                let allAlbumIDs = Set(trackAlbumIDs + directAlbumIDs)
                
                var enrichedAlbumMap: [String: SpotifyAlbum] = [:]
                
                if !allAlbumIDs.isEmpty {
                    let chunks = stride(from: 0, to: allAlbumIDs.count, by: 20).map {
                        Array(Array(allAlbumIDs)[$0..<min($0 + 20, allAlbumIDs.count)])
                    }
                    
                    for chunk in chunks {
                        if let fetchedAlbums = try? await apiService.getSpotifyAlbums(ids: chunk) {
                            for album in fetchedAlbums {
                                enrichedAlbumMap[album.id] = album
                            }
                        }
                    }
                                        
                    spotifyAlbums = spotifyAlbums.map { enrichedAlbumMap[$0.id] ?? $0 }
                    
                    spotifyTracks = spotifyTracks.map { track in
                        if let fullAlbum = enrichedAlbumMap[track.album.id] {
                            return SpotifyTrack(
                                id: track.id,
                                name: track.name,
                                artists: track.artists,
                                album: fullAlbum, 
                                externalIds: track.externalIds,
                                externalUrls: track.externalUrls,
                                durationMs: track.durationMs,
                                popularity: track.popularity
                            )
                        } else {
                            return track
                        }
                    }
                }
                
                let artistIDs = Set(spotifyTracks.compactMap { $0.artists.first?.id })
                var enrichedArtistMap: [String: SpotifyArtist] = [:]
                
                if !artistIDs.isEmpty {
                    let chunks = stride(from: 0, to: artistIDs.count, by: 50).map {
                        Array(Array(artistIDs)[$0..<min($0 + 50, artistIDs.count)])
                    }
                    
                    for chunk in chunks {
                        if let fetchedArtists = try? await apiService.getSpotifyArtists(ids: chunk) {
                            for artist in fetchedArtists {
                                enrichedArtistMap[artist.id] = artist
                            }
                        }
                    }
                    
                    spotifyTracks = spotifyTracks.map { track in
                        if let firstArtist = track.artists.first, let fullArtist = enrichedArtistMap[firstArtist.id] {
                            var newArtists = track.artists
                            newArtists[0] = fullArtist
                            return SpotifyTrack(
                                id: track.id,
                                name: track.name,
                                artists: newArtists,
                                album: track.album,
                                externalIds: track.externalIds,
                                externalUrls: track.externalUrls,
                                durationMs: track.durationMs,
                                popularity: track.popularity
                            )
                        }
                        return track
                    }
                    
                    spotifyAlbums = spotifyAlbums.map { album in
                        if let firstArtist = album.artists.first, let fullArtist = enrichedArtistMap[firstArtist.id] {
                           var newArtists = album.artists
                           newArtists[0] = fullArtist
                           return SpotifyAlbum(
                               id: album.id,
                               name: album.name,
                               images: album.images,
                               releaseDate: album.releaseDate,
                               copyrights: album.copyrights,
                               label: album.label,
                               artists: newArtists,
                               externalUrls: album.externalUrls,
                               totalTracks: album.totalTracks,
                               genres: album.genres
                           )
                        }
                        return album
                    }
                }
                
                let rankedResult = searchRanker.sortAndFilter(tracks: spotifyTracks, albums: spotifyAlbums, term: trimmed)
                let rankedItems = rankedResult.items

                guard !Task.isCancelled else { return }

                if rankedItems.isEmpty {
                    self.status = .noResults(query: trimmed)
                } else if !rankedResult.hasRelevantResults {
                    self.status = .lowRelevance(query: trimmed)
                }

                if let firstRanked = rankedItems.first {
                    let firstResult: SearchResultItem
                    switch firstRanked {
                    case .track(let t, _): 
                        let p = await self.augmentSpotifyTrack(t)
                        firstResult = .track(p)
                    case .album(let a, _): 
                        let p = await self.augmentSpotifyAlbum(a)
                        firstResult = .album(p)
                    }
                    
                    guard !Task.isCancelled else { return }
                    
                    var initialResults = [firstResult]
                    let remainingRanked = Array(rankedItems.dropFirst())
                    
                    initialResults.append(contentsOf: remainingRanked.map { item in
                        switch item {
                        case .track(let t, _): return .track(self.createPlaceholder(from: t))
                        case .album(let a, _): return .album(self.createPlaceholder(from: a))
                        }
                    })
                    
                    self.results = initialResults
                    self.isLoading = false
                    
                    await withTaskGroup(of: SearchResultItem.self, returning: Void.self) { group in
                        for item in remainingRanked {
                            group.addTask {
                                switch item {
                                case .track(let t, _): 
                                    return .track(await self.augmentSpotifyTrack(t))
                                case .album(let a, _): 
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
