import Foundation
import Algorithms

actor MusicBatchLoader {
    func enrich(tracks: [SpotifyTrack], albums: [SpotifyAlbum]) async -> (tracks: [SpotifyTrack], albums: [SpotifyAlbum]) {
        async let enrichedAlbums = fetchMissingAlbums(for: tracks, existingAlbums: albums)
        async let enrichedArtists = fetchMissingArtists(for: tracks, albums: albums)
        
        let (albumMap, artistMap) = await (enrichedAlbums, enrichedArtists)
        
        let finalTracks = tracks.map { track in
            var updatedTrack = track
            
            if let fullAlbum = albumMap[track.album.id] {
                updatedTrack = SpotifyTrack(
                    id: track.id,
                    name: track.name,
                    artists: track.artists,
                    album: fullAlbum,
                    externalIds: track.externalIds,
                    externalUrls: track.externalUrls,
                    durationMs: track.durationMs,
                    popularity: track.popularity
                )
            }
            
            if let firstArtist = track.artists.first, let fullArtist = artistMap[firstArtist.id] {
                var newArtists = updatedTrack.artists
                newArtists[0] = fullArtist
                updatedTrack = SpotifyTrack(
                    id: updatedTrack.id,
                    name: updatedTrack.name,
                    artists: newArtists,
                    album: updatedTrack.album,
                    externalIds: updatedTrack.externalIds,
                    externalUrls: updatedTrack.externalUrls,
                    durationMs: updatedTrack.durationMs,
                    popularity: updatedTrack.popularity
                )
            }
            
            return updatedTrack
        }
        
        let finalAlbums = albums.map { album in
            var updatedAlbum = albumMap[album.id] ?? album
            
            if let firstArtist = album.artists.first, let fullArtist = artistMap[firstArtist.id] {
                var newArtists = updatedAlbum.artists
                newArtists[0] = fullArtist
                updatedAlbum = SpotifyAlbum(
                    id: updatedAlbum.id,
                    name: updatedAlbum.name,
                    images: updatedAlbum.images,
                    releaseDate: updatedAlbum.releaseDate,
                    copyrights: updatedAlbum.copyrights,
                    label: updatedAlbum.label,
                    artists: newArtists,
                    externalUrls: updatedAlbum.externalUrls,
                    totalTracks: updatedAlbum.totalTracks,
                    genres: updatedAlbum.genres
                )
            }
            
            return updatedAlbum
        }
        
        return (finalTracks, finalAlbums)
    }
    
    private func fetchMissingAlbums(for tracks: [SpotifyTrack], existingAlbums: [SpotifyAlbum]) async -> [String: SpotifyAlbum] {
        let trackAlbumIDs = tracks.map { $0.album.id }
        let directAlbumIDs = existingAlbums.map { $0.id }
        let allIDs = Array((trackAlbumIDs + directAlbumIDs).uniqued())
        
        guard !allIDs.isEmpty else { return [:] }
        
        let chunks = allIDs.chunks(ofCount: 20)
        
        return await withTaskGroup(of: [SpotifyAlbum].self) { group in
            for chunk in chunks {
                let ids = Array(chunk)
                group.addTask {
                    let albums = try? await MusicAPIService.shared.getSpotifyAlbums(ids: ids)
                    return albums ?? []
                }
            }
            
            var results: [String: SpotifyAlbum] = [:]
            for await albums in group {
                for album in albums {
                    results[album.id] = album
                }
            }
            return results
        }
    }
    
    private func fetchMissingArtists(for tracks: [SpotifyTrack], albums: [SpotifyAlbum]) async -> [String: SpotifyArtist] {
        let trackArtistIDs = tracks.compactMap { $0.artists.first?.id }
        let albumArtistIDs = albums.compactMap { $0.artists.first?.id }
        let allIDs = Array((trackArtistIDs + albumArtistIDs).uniqued())
        
        guard !allIDs.isEmpty else { return [:] }
        
        let chunks = allIDs.chunks(ofCount: 50)
        
        return await withTaskGroup(of: [SpotifyArtist].self) { group in
            for chunk in chunks {
                let ids = Array(chunk)
                group.addTask {
                    let artists = try? await MusicAPIService.shared.getSpotifyArtists(ids: ids)
                    return artists ?? []
                }
            }
            
            var results: [String: SpotifyArtist] = [:]
            for await artists in group {
                for artist in artists {
                    results[artist.id] = artist
                }
            }
            return results
        }
    }
}
