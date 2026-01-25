import Foundation

enum SearchResultItem: Identifiable, Hashable, Sendable {
    case track(TrackPresentation)
    case album(AlbumPresentation)
    
    var id: String {
        switch self {
        case .track(let t): return t.id
        case .album(let a): return a.id
        }
    }
}

struct TrackPresentation: Identifiable, Hashable, Sendable {
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
    var isLoading: Bool
    

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
        links: PlatformLinks = PlatformLinks(),
        isLoading: Bool = false
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
        self.isLoading = isLoading
    }
}

struct AlbumPresentation: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let artist: String
    let releaseDate: String
    let genre: String
    let totalTracks: String
    let recordLabel: String
    let copyright: String
    let artworkURL: URL?
    var links: PlatformLinks
    var isLoading: Bool
    
    init(
        id: String,
        title: String,
        artist: String,
        releaseDate: String,
        genre: String,
        totalTracks: String,
        recordLabel: String,
        copyright: String,
        artworkURL: URL?,
        links: PlatformLinks = PlatformLinks(),
        isLoading: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.releaseDate = releaseDate
        self.genre = genre
        self.totalTracks = totalTracks
        self.recordLabel = recordLabel
        self.copyright = copyright
        self.artworkURL = artworkURL
        self.links = links
        self.isLoading = isLoading
    }
}
