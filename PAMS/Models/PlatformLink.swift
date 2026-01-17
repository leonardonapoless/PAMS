import Foundation

struct PlatformLink: Codable, Sendable, Equatable, Hashable {
    let webUrl: String?
    let nativeUrl: String?
}
