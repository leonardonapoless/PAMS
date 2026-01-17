import Foundation

struct SearchResult: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let artist: String
    let releaseDate: String
    let album: String
    let genre: String
    let duration: String
    let recordLabel: String
    let copyright: String
    let artworkURL: URL?
    let isrc: String?
    var links: PlatformLinks

    init(
        id: String,
        title: String,
        artist: String,
        releaseDate: String,
        album: String,
        genre: String,
        duration: String,
        recordLabel: String,
        copyright: String,
        artworkURL: URL?,
        isrc: String?,
        links: PlatformLinks = PlatformLinks()
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.releaseDate = releaseDate
        self.album = album
        self.genre = genre
        self.duration = duration
        self.recordLabel = recordLabel
        self.copyright = copyright
        self.artworkURL = artworkURL
        self.isrc = isrc
        self.links = links
    }
}
