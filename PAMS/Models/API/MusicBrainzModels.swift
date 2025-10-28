//
//  MusicBrainzModels.swift
//  PAMS
//
//  Created by Leonardo Nápoles on 10/27/25.
//

import Foundation

// MARK: - MusicBrainz Credits Struct (Our Tidy Model)

/// a simple, clean struct to hold the credits fetched from MusicBrainz
/// this is much tidier than using a complex tuple
public struct MusicBrainzCredits: Sendable {
    public let songwriter: String?
    public let producer: String?
    public let album: String?
    public let releaseDate: String?
    public let genre: String?
    public let duration: String?
    public let recordLabel: String?
    public let copyright: String?

    // an empty state for when a search fails
    public static var empty: MusicBrainzCredits {
        MusicBrainzCredits(songwriter: nil, producer: nil, album: nil, releaseDate: nil, genre: nil, duration: nil, recordLabel: nil, copyright: nil)
    }
}


// MARK: - MusicBrainz API Decoding Models (The "Blueprints")

public struct MusicBrainzISRCResponse: Sendable, Codable {
    public let recordings: [MusicBrainzRecording]
}

public struct MusicBrainzRecording: Sendable, Codable {
    public let relations: [MusicBrainzRelation]?
    public let releaseList: MusicBrainzReleaseList?
    public let genres: [MusicBrainzGenre]?
    public let length: Int?

    public enum CodingKeys: String, CodingKey {
        case relations
        case releaseList = "release-list"
        case genres
        case length
    }
}

public struct MusicBrainzReleaseList: Sendable, Codable {
    public let releases: [MusicBrainzRelease]?
}

public struct MusicBrainzRelease: Sendable, Codable {
    public let title: String? // album title
    public let date: String?  // release date
    public let labelInfo: [MusicBrainzLabelInfo]?
    public let artistCredits: [MusicBrainzArtistCredit]?

    public enum CodingKeys: String, CodingKey {
        case title
        case date
        case labelInfo = "label-info"
        case artistCredits = "artist-credit"
    }
}

public struct MusicBrainzRelation: Sendable, Codable {
    public let type: String // e.g. "producer", "songwriter"
    public let artist: MusicBrainzArtistCredit
}

public struct MusicBrainzArtistCredit: Sendable, Codable {
    public let name: String
    public let joinphrase: String?
}

public struct MusicBrainzGenre: Sendable, Codable {
    public let name: String
}

public struct MusicBrainzLabelInfo: Sendable, Codable {
    public let label: MusicBrainzLabel?
}

public struct MusicBrainzLabel: Sendable, Codable {
    public let name: String
}

