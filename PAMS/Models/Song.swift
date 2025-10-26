import Foundation

public struct SongLink: Codable {
    public let apple: String
    public let spotify: String
    public let tidal: String
    public let youtube: String
}

public struct SongData: Codable {
    public let songs: [String: SongLink]
}
