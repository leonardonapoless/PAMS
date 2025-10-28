//
//  SongResult.swift
//  PAMS
//
//  Created by Leonardo Nápoles on 10/24/25.
//

import Foundation

public struct SearchResult: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let releaseDate: String
    public let songwriter: String
    public let producer: String
    public let album: String
    public let genre: String
    public let duration: String
    public let recordLabel: String
    public let copyright: String
    public let artworkURL: URL?
    public let isrc: String?
    public var links: PlatformLinks

    public init(
        id: String,
        title: String,
        artist: String,
        releaseDate: String,
        songwriter: String,
        producer: String,
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
        self.songwriter = songwriter
        self.producer = producer
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
