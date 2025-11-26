import Foundation
import Combine

@MainActor
public final class SongViewModel: ObservableObject {

    // MARK: - ui properties
    @Published public private(set) var results: [SearchResult] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String? 

    // MARK: - services
    private let apiService = MusicAPIService.shared
    private let searchRanker = MusicSearchRanker()
    private var searchTask: Task<Void, Never>?

    // MARK: - main search function
    public func search(term: String) {
        searchTask?.cancel() 

        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        
        results = []
        errorMessage = nil

        guard !trimmed.isEmpty else {
            isLoading = false
            return
        }

        isLoading = true
        
        searchTask = Task {
            do {
                var spotifyTracks = try await apiService.searchSpotify(term: trimmed)
  
                spotifyTracks = searchRanker.sortAndFilterTracks(tracks: spotifyTracks, term: trimmed)

                guard !Task.isCancelled else {
                    return
                }

                if spotifyTracks.isEmpty {
                    self.errorMessage = "No results found for \"\(trimmed)\""
                }

                var resultsMap = [String: SearchResult]()

                await withTaskGroup(
                    of: SearchResult.self,
                    returning: Void.self
                ) { group in

                    for track in spotifyTracks {
                        
                        group.addTask {
                            
                            return await self.augmentSpotifyTrack(track)
                        }
                    }
                    
                    for await result in group {
                        if !Task.isCancelled {
                            resultsMap[result.id] = result
                        }
                    }
                }
                
                guard !Task.isCancelled else {
                    return
                }

                let searchResults = spotifyTracks.compactMap { resultsMap[$0.id] }
                
                self.results = searchResults

            } catch {
                
                print("search failed with error: \(error)")
                self.errorMessage = "search failed. check your connection."
                self.results = []
            }
            
            if !Task.isCancelled {
                isLoading = false
            }
        }
    }

    private func augmentSpotifyTrack(_ track: SpotifyTrack) async -> SearchResult {

        async let linksTask = apiService.getSonglink(for: track.externalUrls.spotify)
        async let creditsTask = apiService.getMusicBrainzCredits(isrc: track.externalIds?.isrc)
        async let spotifyTrackTask = try? await apiService.getSpotifyTrack(id: track.id)

        let platformLinks = await linksTask
        let credits = await creditsTask
        let fullSpotifyTrack = await spotifyTrackTask

        let releaseDate = credits.releaseDate ?? track.album.releaseDate
        let album = credits.album ?? track.album.name
        
        var genre: String = "n/a"
        if let g = credits.genre {
            genre = g
        } else if let spotifyGenres = fullSpotifyTrack?.artists.first?.genres {
            genre = spotifyGenres.first ?? "n/a"
        }

        var duration: String = "n/a"
        if let d = credits.duration {
            duration = d
        } else if let durationMs = fullSpotifyTrack?.durationMs {
            
            duration = "\(durationMs / 1000 / 60):\(String(format: "%02d", (durationMs / 1000) % 60))"
        }

        var recordLabel: String = "n/a"
        if let rl = credits.recordLabel {
            recordLabel = rl
        } else if let l = fullSpotifyTrack?.album.label {
            recordLabel = l
        }
        
        var copyright: String = "n/a"
        if let c = credits.copyright {
            copyright = c
        } else if let c = fullSpotifyTrack?.album.copyrights?.first?.text {
            copyright = c
        }

        return SearchResult(
            id: track.id,
            title: track.name,
            artist: track.artistName,
            releaseDate: releaseDate,
            songwriter: credits.songwriter ?? "n/a",
            producer: credits.producer ?? "n/a",
            album: album,
            genre: genre,
            duration: duration,
            recordLabel: recordLabel,
            copyright: copyright,
            artworkURL: track.album.artworkURL,
            isrc: track.externalIds?.isrc,
            links: platformLinks ?? PlatformLinks() 
        )
    }

}

