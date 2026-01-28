import Foundation
import os

enum KeyManager {

    private struct LoadedKeys {
        let spotifyClientID: String
        let spotifyClientSecret: String
        let spotifyRedirectURI: String?
        let spotifyTokenSwapURL: URL?
        let spotifyTokenRefreshURL: URL?
        let musicBrainzUserAgent: String
        let configName: String?
        let configVersion: String?
    }

    private static var loaded: LoadedKeys?
    private static let logger = Logger(subsystem: "com.pams.app", category: "KeyManager")

    // MARK: - Bootstrap

    @MainActor
    static func bootstrap() {
        guard let dict = getKeys() else {
            logger.error("Configuration plist not found. The app will launch but API features are disabled.")
            return
        }

        func string(_ key: String, trimAndNilIfEmpty: Bool = true) -> String? {
            guard let value = dict[key] as? String else { return nil }
            if trimAndNilIfEmpty {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            return value
        }

        func url(_ key: String) -> URL? {
            guard let s = string(key) else { return nil }
            return URL(string: s)
        }

        guard let clientID = string("SpotifyClientID") else {
            logger.error("SpotifyClientID missing from plist. API features disabled.")
            return
        }
        guard let clientSecret = string("SpotifyClientSecret") else {
            logger.error("SpotifyClientSecret missing from plist. API features disabled.")
            return
        }

        let ua = string("MusicBrainzUserAgent") ?? "PAMS/1.0 (https://github.com/leonardonapoless)"

        loaded = LoadedKeys(
            spotifyClientID: clientID,
            spotifyClientSecret: clientSecret,
            spotifyRedirectURI: string("SpotifyRedirectURI"),
            spotifyTokenSwapURL: url("SpotifyTokenSwapURL"),
            spotifyTokenRefreshURL: url("SpotifyTokenRefreshURL"),
            musicBrainzUserAgent: ua,
            configName: string("ConfigName"),
            configVersion: string("ConfigVersion")
        )
    }

    // MARK: - Internal Loading

    private static var cachedKeys: [String: Any]?

    @MainActor
    private static func getKeys() -> [String: Any]? {
        if let cached = cachedKeys { return cached }

        let candidateNames = ["Keys", "Keys-PAMS"]

        for name in candidateNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "plist"),
               let data = try? Data(contentsOf: url),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                cachedKeys = plist
                return plist
            }
        }
        
        return nil
    }

    // MARK: - Public Accessors

    static var spotifyClientID: String {
        loaded?.spotifyClientID ?? ""
    }

    static var spotifyClientSecret: String {
        loaded?.spotifyClientSecret ?? ""
    }

    static var spotifyRedirectURI: String? {
        loaded?.spotifyRedirectURI
    }

    static var spotifyTokenSwapURL: URL? {
        loaded?.spotifyTokenSwapURL
    }

    static var spotifyTokenRefreshURL: URL? {
        loaded?.spotifyTokenRefreshURL
    }
    
    static let musicBrainzUserAgent = "PAMS/1.0 (https://github.com/leonardonapoless)"
}
