import Foundation
import Combine

@MainActor
final class SongViewModel: ObservableObject {

    @Published private(set) var results: [SearchResult] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String? 

    private let apiService = MusicAPIService.shared
    private let searchRanker = MusicSearchRanker()
    private var searchTask: Task<Void, Never>?

    func search(term: String) {
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
                
                // enrich tracks with full artist and album details
                let artistIDs = Set(spotifyTracks.compactMap { $0.artists.first?.id })
                let albumIDs = Set(spotifyTracks.map { $0.album.id })
                
                var fullArtists: [String: SpotifyArtist] = [:]
                var fullAlbums: [String: SpotifyAlbum] = [:]

                if !artistIDs.isEmpty {
                    let chunks = stride(from: 0, to: Array(artistIDs).count, by: 50).map {
                        Array(Array(artistIDs)[$0..<min($0 + 50, Array(artistIDs).count)])
                    }
                    for chunk in chunks {
                        if let artists = try? await apiService.getSpotifyArtists(ids: chunk) {
                            for artist in artists {
                                fullArtists[artist.id] = artist
                            }
                        }
                    }
                }
                
                if !albumIDs.isEmpty {
                    let chunks = stride(from: 0, to: Array(albumIDs).count, by: 20).map {
                        Array(Array(albumIDs)[$0..<min($0 + 20, Array(albumIDs).count)])
                    }
                    for chunk in chunks {
                        if let albums = try? await apiService.getSpotifyAlbums(ids: chunk) {
                            for album in albums {
                                fullAlbums[album.id] = album
                            }
                        }
                    }
                }
                
                spotifyTracks = spotifyTracks.map { track in
                    let firstArtistID = track.artists.first?.id
                    let fullArtist = firstArtistID != nil ? fullArtists[firstArtistID!] : nil
                    let fullAlbum = fullAlbums[track.album.id]
                    
                    // create a new track with the enriched artist and album
                    return SpotifyTrack(
                        id: track.id,
                        name: track.name,
                        artists: fullArtist != nil ? [fullArtist!] + track.artists.dropFirst() : track.artists,
                        album: fullAlbum ?? track.album,
                        externalIds: track.externalIds,
                        externalUrls: track.externalUrls,
                        durationMs: track.durationMs,
                        popularity: track.popularity
                    )
                }
  
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
        
        let platformLinks = await linksTask
        let credits = await creditsTask
        let fullSpotifyAlbum = track.album
        let fullSpotifyArtist = track.artists.first

        let releaseDate = credits.releaseDate ?? track.album.releaseDate
        let album = credits.album ?? track.album.name
        
        var genre: String = "n/a"
        if let g = credits.genre {
            genre = g.capitalized
        } else if let spotifyGenres = fullSpotifyArtist?.genres, !spotifyGenres.isEmpty {
            genre = (spotifyGenres.first ?? "n/a").capitalized
        }

        var duration: String = "n/a"
        if let d = credits.duration {
            duration = d
        } else if let durationMs = track.durationMs {
            
            duration = "\(durationMs / 1000 / 60):\(String(format: "%02d", (durationMs / 1000) % 60))"
        }

        var recordLabel: String = "n/a"
        if let rl = credits.recordLabel {
            recordLabel = rl
        } else if let l = fullSpotifyAlbum.label {
            recordLabel = l
        }
        
        var copyright: String = "n/a"
        if let c = credits.copyright {
            copyright = c
        } else if let c = fullSpotifyAlbum.copyrights?.first?.text {
            copyright = c
        }

        return SearchResult(
            id: track.id,
            title: track.name,
            artist: track.artistName,
            releaseDate: releaseDate,
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

