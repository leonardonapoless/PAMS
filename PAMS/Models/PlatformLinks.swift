import Foundation

public struct PlatformLinks: Codable, Sendable, Equatable, Hashable {
    public let apple: PlatformLink?
    public let spotify: PlatformLink?
    public let tidal: PlatformLink?
    public let youtube: PlatformLink?

    public init(apple: PlatformLink? = nil, spotify: PlatformLink? = nil, tidal: PlatformLink? = nil, youtube: PlatformLink? = nil) {
        self.apple = apple
        self.spotify = spotify
        self.tidal = tidal
        self.youtube = youtube
    }

    init(from songlinkResponse: SonglinkResponse) {
        self.apple = PlatformLink(
            webUrl: songlinkResponse.linksByPlatform["appleMusic"]?.url,
            nativeUrl: songlinkResponse.linksByPlatform["appleMusic"]?.nativeAppUriMobile
        )
        self.spotify = PlatformLink(
            webUrl: songlinkResponse.linksByPlatform["spotify"]?.url,
            nativeUrl: songlinkResponse.linksByPlatform["spotify"]?.nativeAppUriMobile
        )
        self.tidal = PlatformLink(
            webUrl: songlinkResponse.linksByPlatform["tidal"]?.url,
            nativeUrl: songlinkResponse.linksByPlatform["tidal"]?.nativeAppUriMobile
        )
        self.youtube = PlatformLink(
            webUrl: songlinkResponse.linksByPlatform["youtube"]?.url,
            nativeUrl: songlinkResponse.linksByPlatform["youtube"]?.nativeAppUriMobile
        )
    }
}
