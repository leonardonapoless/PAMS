import Foundation

// MARK: - Spotify API Models
struct SpotifyTokenResponse: Sendable, Codable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

struct SpotifySearchResponse: Sendable, Codable {
    let tracks: SpotifyTrackList?
}

struct SpotifyTrackList: Sendable, Codable {
    let items: [SpotifyTrack]
}

struct SpotifyTrack: Sendable, Codable, Identifiable {
    let id: String
    let name: String 
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
    let externalIds: SpotifyExternalIDs?
    let externalUrls: SpotifyExternalURLs
    let durationMs: Int?
    let popularity: Int?

    var artistName: String { artists.first?.name ?? "Unknown Artist" }

    enum CodingKeys: String, CodingKey {
        case id, name, artists, album, popularity
        case externalIds = "external_ids"
        case externalUrls = "external_urls"
        case durationMs = "duration_ms"
    }
}

struct SpotifyArtist: Sendable, Codable {
    let id: String
    let name: String
    let genres: [String]?
    let popularity: Int?
}

struct SpotifyArtistsResponse: Codable {
    let artists: [SpotifyArtist]
}

struct SpotifyAlbumsResponse: Codable {
    let albums: [SpotifyAlbum]
}

struct SpotifyAlbum: Sendable, Codable {
    let id: String
    let name: String
    let images: [SpotifyImage]
    let releaseDate: String
    let copyrights: [SpotifyCopyright]?
    let label: String?

    var artworkURL: URL? { URL(string: images.first?.url ?? "") }

    enum CodingKeys: String, CodingKey {
        case id, name, images, copyrights, label
        case releaseDate = "release_date"
    }
}

struct SpotifyImage: Sendable, Codable {
    let url: String
}

struct SpotifyExternalIDs: Sendable, Codable {
    let isrc: String?
}

struct SpotifyExternalURLs: Sendable, Codable {
    let spotify: String 
}

struct SpotifyCopyright: Sendable, Codable {
    let text: String
    let type: String
}

