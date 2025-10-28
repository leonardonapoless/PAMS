import Foundation
import Combine

// this is the "brain" for the search view
// @MainActor means UI updates are safe

@MainActor
public final class SongViewModel: ObservableObject {

    // MARK: - ui properties
    @Published public private(set) var results: [SearchResult] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String? // for showing errors

    // MARK: - services
    private let apiService = MusicAPIService.shared
    
    // custom search sorter
    private let searchRanker = MusicSearchRanker()

    // holds the current search task so we can cancel it
    private var searchTask: Task<Void, Never>?

    // MARK: - main search function

    public func search(term: String) {
        searchTask?.cancel() // cancel the last search

        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)

        // reset ui
        results = []
        errorMessage = nil

        // don't search for nothing
        guard !trimmed.isEmpty else {
            isLoading = false
            return
        }

        isLoading = true

        // start the new search
        searchTask = Task {
            do {
                // get results from spotify
                // this is the simple, 1-argument call
                var spotifyTracks = try await apiService.searchSpotify(term: trimmed)

                // sort the results using the ranker
                // this is the critical step
                spotifyTracks = searchRanker.sortAndFilterTracks(tracks: spotifyTracks, term: trimmed)

                // check if user typed again
                guard !Task.isCancelled else {
                    isLoading = false
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
                        // add a sub-task for each track
                        group.addTask {
                            // this helper does the fetching for one song
                            return await self.augmentSpotifyTrack(track)
                        }
                    }

                    // collect results as they finish and put them in the dictionary
                    for await result in group {
                        if !Task.isCancelled {
                            resultsMap[result.id] = result
                        }
                    }
                }

                // check again if user typed while it were fetching details
                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }

                let searchResults = spotifyTracks.compactMap { resultsMap[$0.id] }

                // update the ui
                self.results = searchResults

            } catch {
                // handle network errors
                print("search failed with error: \(error)")
                self.errorMessage = "search failed. check your connection."
                self.results = []
            }

            // final ui state update
            if !Task.isCancelled {
                isLoading = false
            }
        }
    }


    // fetches all the extra data for a single song
    private func augmentSpotifyTrack(_ track: SpotifyTrack) async -> SearchResult {

        // start all 3 network calls at the same time
        async let linksTask = apiService.getSonglink(for: track.externalUrls.spotify)
        async let creditsTask = apiService.getMusicBrainzCredits(isrc: track.externalIds?.isrc)
        async let spotifyTrackTask = try? await apiService.getSpotifyTrack(id: track.id)

        // wait for them all to come back
        let platformLinks = await linksTask
        let credits = await creditsTask
        let fullSpotifyTrack = await spotifyTrackTask

        // combine data
        // use musicbrainz data first, fall back to spotify data if missing.

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
            // format milliseconds to "m:ss"
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

        // build the final searchresult object for the ui
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
            links: platformLinks ?? PlatformLinks() // platformlinks() is just an empty struct
        )
    }

}

