//
//  KeyManager.swift
//  PAMS
//
//  Created by Leonardo Nápoles on 10/27/25.
//

import Foundation

enum KeyManager {

    // immutable snapshot loaded on the main actor during bootstrap.
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

    // stored snapshot accessible from any actor after bootstrap
    private static var loaded: LoadedKeys?

    // MARK: - Bootstrap

    @MainActor
    static func bootstrap() {
        let dict = getKeys()

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
            fatalError("CRITICAL: 'SpotifyClientID' missing or not a String in plist.")
        }
        guard let clientSecret = string("SpotifyClientSecret") else {
            fatalError("CRITICAL: 'SpotifyClientSecret' missing or not a String in plist.")
        }

        let ua = string("MusicBrainzUserAgent") ?? "PAMS/1.0 (youremail@example.com)"

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

    // MARK: - Internal loading (MainActor)

    // cache to avoid re-reading from disk repeatedly
    private static var cachedKeys: [String: Any]?

    @MainActor
    private static func getKeys() -> [String: Any] {
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
        // if reached here, couldn't load any plist
        fatalError("CRITICAL: Configuration plist not found.")
    }

    // MARK: - Public accessors (usable from any actor after bootstrap)

    static var spotifyClientID: String {
        guard let l = loaded else {
            fatalError("KeyManager not bootstrapped. Call KeyManager.bootstrap() on the main actor at app startup.")
        }
        return l.spotifyClientID
    }

    static var spotifyClientSecret: String {
        guard let l = loaded else {
            fatalError("KeyManager not bootstrapped. Call KeyManager.bootstrap() on the main actor at app startup.")
        }
        return l.spotifyClientSecret
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

    // musicbrainz user agent (required by musicbrainz default provided if not set)
    // Inside MusicAPIService.swift
    static let musicBrainzUserAgent = "PAMS/1.0 (https://github.com/leonardonapoless)"

}

