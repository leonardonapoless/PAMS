import Foundation

struct SongLink: Codable {
    let apple: String
    let spotify: String
    let tidal: String
    let youtube: String
}

struct SongData: Codable {
    let songs: [String: SongLink]
}
