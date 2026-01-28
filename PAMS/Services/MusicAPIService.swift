import Foundation

// MARK: - Endpoints

private enum SpotifyEndpoint {
    static let api = "https://api.spotify.com/v1"
    static let auth = URL(string: "https://accounts.spotify.com/api/token")!
    
    case search, track(String), albums, artists
    
    var url: URL {
        switch self {
        case .search: URL(string: "\(Self.api)/search")!
        case .track(let id): URL(string: "\(Self.api)/tracks/\(id)")!
        case .albums: URL(string: "\(Self.api)/albums")!
        case .artists: URL(string: "\(Self.api)/artists")!
        }
    }
}

// MARK: - Errors

enum MusicAPIError: Error, LocalizedError {
    case unauthorized
    case rateLimited
    case network(URLError)
    case decoding(Error)
    case invalidResponse(Int)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized: "Session expired"
        case .rateLimited: "Too many requests. Try again shortly"
        case .network: "No internet connection"
        case .decoding: "Failed to parse response"
        case .invalidResponse(let code): "Server error (\(code))"
        }
    }
}

// MARK: - Service

@MainActor
final class MusicAPIService: Sendable {
    static let shared = MusicAPIService()
    private let httpClient = URLSession.shared
    private var spotifyToken: SpotifyTokenResponse?
    private var tokenExpiryTime = Date.distantPast
    private let musicBrainzUserAgent = "PAMS/1.0 ( https://github.com/leonardonapoless )"

    func searchSpotify(term: String) async throws -> (tracks: [SpotifyTrack], albums: [SpotifyAlbum]) {
        let token = try await getSpotifyToken()

        var components = URLComponents(url: SpotifyEndpoint.search.url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: term),
            URLQueryItem(name: "type", value: "track,album"),
            URLQueryItem(name: "limit", value: "20")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRequest(request)
        try validate(response)

        do {
            let result = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
            return (
                tracks: result.tracks?.items ?? [],
                albums: result.albums?.items ?? []
            )
        } catch {
            throw MusicAPIError.decoding(error)
        }
    }

    func getSpotifyTrack(id: String) async throws -> SpotifyTrack? {
        let token = try await getSpotifyToken()

        var request = URLRequest(url: SpotifyEndpoint.track(id).url)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRequest(request)
        try validate(response)

        do {
            return try JSONDecoder().decode(SpotifyTrack.self, from: data)
        } catch {
            throw MusicAPIError.decoding(error)
        }
    }

    func getSpotifyAlbums(ids: [String]) async throws -> [SpotifyAlbum] {
        guard !ids.isEmpty else { return [] }
        let token = try await getSpotifyToken()

        var components = URLComponents(url: SpotifyEndpoint.albums.url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "ids", value: ids.joined(separator: ","))]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRequest(request)
        try validate(response)

        do {
            return try JSONDecoder().decode(SpotifyAlbumsResponse.self, from: data).albums
        } catch {
            throw MusicAPIError.decoding(error)
        }
    }

    func getSpotifyArtists(ids: [String]) async throws -> [SpotifyArtist] {
        guard !ids.isEmpty else { return [] }
        let token = try await getSpotifyToken()

        var components = URLComponents(url: SpotifyEndpoint.artists.url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "ids", value: ids.joined(separator: ","))]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRequest(request)
        try validate(response)

        do {
            return try JSONDecoder().decode(SpotifyArtistsResponse.self, from: data).artists
        } catch {
            throw MusicAPIError.decoding(error)
        }
    }

    func getSonglink(for spotifyURL: String) async -> PlatformLinks? {
        guard let encodedURL = spotifyURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.song.link/v1-alpha.1/links?url=\(encodedURL)") else {
            return nil
        }

        do {
            let (data, _) = try await httpClient.data(from: url)
            return PlatformLinks(from: try JSONDecoder().decode(SonglinkResponse.self, from: data))
        } catch {
            return nil 
        }
    }

    func getMusicBrainzCredits(isrc: String?) async -> MusicBrainzCredits {
        guard let isrc, !isrc.isEmpty else { return .empty }

        let inc = "artist-credits+recording-level-rels+release-level-rels+genres+labels"
        guard let url = URL(string: "https://musicbrainz.org/ws/2/isrc/\(isrc)?fmt=json&inc=\(inc)") else {
            return .empty
        }

        var request = URLRequest(url: url)
        request.setValue(musicBrainzUserAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await httpClient.data(for: request)
            let responseModel = try JSONDecoder().decode(MusicBrainzISRCResponse.self, from: data)

            guard let recording = responseModel.recordings.first else { return .empty }

            return parseMusicBrainzRecording(recording)

        } catch {
            return .empty
        }
    }

    private func parseMusicBrainzRecording(_ recording: MusicBrainzRecording) -> MusicBrainzCredits {
        let genre = recording.genres?.first?.name
        let duration = recording.length.map { "\($0 / 1000 / 60):\(String(format: "%02d", ($0 / 1000) % 60))" }

        let release = recording.releaseList?.releases?.first
        let album = release?.title
        let releaseDate = release?.date
        let recordLabel = release?.labelInfo?.first?.label?.name
        let copyright = release?.artistCredits?.map { credit in
            let raw = "\(credit.name)\(credit.joinphrase ?? "")"
            return raw.cleanedCopyright
        }.joined()

        return MusicBrainzCredits(
            album: album,
            releaseDate: releaseDate,
            genre: genre,
            duration: duration,
            recordLabel: recordLabel,
            copyright: copyright
        )
    }

    // MARK: - Helpers

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await httpClient.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw error
        } catch let error as URLError {
            throw MusicAPIError.network(error)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw MusicAPIError.network(URLError(.notConnectedToInternet))
        }
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw MusicAPIError.invalidResponse(0)
        }
        switch http.statusCode {
        case 200...299: return
        case 401: throw MusicAPIError.unauthorized
        case 429: throw MusicAPIError.rateLimited
        default: throw MusicAPIError.invalidResponse(http.statusCode)
        }
    }

    private func getSpotifyToken() async throws -> SpotifyTokenResponse {
        if let token = spotifyToken, tokenExpiryTime > Date() {
            return token
        }

        let creds = "\(KeyManager.spotifyClientID):\(KeyManager.spotifyClientSecret)"
        guard let authData = creds.data(using: .utf8) else {
            throw MusicAPIError.unauthorized
        }

        var request = URLRequest(url: SpotifyEndpoint.auth)
        request.httpMethod = "POST"
        request.setValue("Basic \(authData.base64EncodedString())", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)

        let (data, response) = try await performRequest(request)
        try validate(response)

        do {
            let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
            self.spotifyToken = tokenResponse
            self.tokenExpiryTime = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn - 300))
            return tokenResponse
        } catch {
            throw MusicAPIError.decoding(error)
        }
    }
}
