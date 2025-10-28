//
//  SpotifyAPI.swift
//  PAMS
//
//  Created by Leonardo Nápoles on 10/27/25.
//

import Foundation

// MARK: - Spotify API Models

public struct SpotifyTokenResponse: Sendable, Codable {
    public let accessToken: String
    public let expiresIn: Int

    public enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

public struct SpotifySearchResponse: Sendable, Codable {
    public let tracks: SpotifyTrackList?
}

public struct SpotifyTrackList: Sendable, Codable {
    public let items: [SpotifyTrack]
}

public struct SpotifyTrack: Sendable, Codable, Identifiable {
    public let id: String
    public let name: String // song title
    public let artists: [SpotifyArtist]
    public let album: SpotifyAlbum
    public let externalIds: SpotifyExternalIDs?
    public let externalUrls: SpotifyExternalURLs
    public let durationMs: Int?
    public let popularity: Int?

    public var artistName: String { artists.first?.name ?? "Unknown Artist" }

    public enum CodingKeys: String, CodingKey {
        case id, name, artists, album, popularity
        case externalIds = "external_ids"
        case externalUrls = "external_urls"
        case durationMs = "duration_ms"
    }
}

public struct SpotifyArtist: Sendable, Codable {
    public let name: String
    public let genres: [String]?
    public let popularity: Int?
}

public struct SpotifyAlbum: Sendable, Codable {
    public let name: String
    public let images: [SpotifyImage]
    public let releaseDate: String
    public let copyrights: [SpotifyCopyright]?
    public let label: String?

    public var artworkURL: URL? { URL(string: images.first?.url ?? "") }

    public enum CodingKeys: String, CodingKey {
        case name, images, copyrights, label
        case releaseDate = "release_date"
    }
}

public struct SpotifyImage: Sendable, Codable {
    public let url: String
}

public struct SpotifyExternalIDs: Sendable, Codable {
    public let isrc: String?
}

public struct SpotifyExternalURLs: Sendable, Codable {
    public let spotify: String // the URL for this track
}

public struct SpotifyCopyright: Sendable, Codable {
    public let text: String
    public let type: String
}

