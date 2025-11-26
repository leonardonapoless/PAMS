import Foundation

// MARK: - Songlink (Odesli) API Models
struct SonglinkResponse: Sendable, Codable {
    let linksByPlatform: [String: SonglinkPlatformLink]
}

struct SonglinkPlatformLink: Sendable, Codable {
    let url: String
    let nativeAppUriMobile: String?
}
