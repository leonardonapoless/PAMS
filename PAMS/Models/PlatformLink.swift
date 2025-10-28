import Foundation

public struct PlatformLink: Codable, Sendable, Equatable, Hashable {
    public let webUrl: String?
    public let nativeUrl: String?
}
