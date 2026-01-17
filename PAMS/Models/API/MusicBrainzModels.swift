import Foundation

struct MusicBrainzCredits: Sendable {
    let album: String?
    let releaseDate: String?
    let genre: String?
    let duration: String?
    let recordLabel: String?
    let copyright: String?
    static var empty: MusicBrainzCredits {
        MusicBrainzCredits(album: nil, releaseDate: nil, genre: nil, duration: nil, recordLabel: nil, copyright: nil)
    }
}

// MARK: - MusicBrainz API Decoding Models 
struct MusicBrainzISRCResponse: Sendable, Codable {
    let recordings: [MusicBrainzRecording]
}

struct MusicBrainzRecording: Sendable, Codable {
    let relations: [MusicBrainzRelation]?
    let releaseList: MusicBrainzReleaseList?
    let genres: [MusicBrainzGenre]?
    let length: Int?

    enum CodingKeys: String, CodingKey {
        case relations
        case releaseList = "release-list"
        case genres
        case length
    }
}

struct MusicBrainzReleaseList: Sendable, Codable {
    let releases: [MusicBrainzRelease]?
}

struct MusicBrainzRelease: Sendable, Codable {
    let title: String? 
    let date: String?  
    let labelInfo: [MusicBrainzLabelInfo]?
    let artistCredits: [MusicBrainzArtistCredit]?

    enum CodingKeys: String, CodingKey {
        case title
        case date
        case labelInfo = "label-info"
        case artistCredits = "artist-credit"
    }
}

struct MusicBrainzRelation: Sendable, Codable {
    let type: String 
    let artist: MusicBrainzArtistCredit
}

struct MusicBrainzArtistCredit: Sendable, Codable {
    let name: String
    let joinphrase: String?
}

struct MusicBrainzGenre: Sendable, Codable {
    let name: String
}

struct MusicBrainzLabelInfo: Sendable, Codable {
    let label: MusicBrainzLabel?
}

struct MusicBrainzLabel: Sendable, Codable {
    let name: String
}

