import Foundation

@MainActor
class MusicAPIService {
    static let shared = MusicAPIService()
    private let httpClient = URLSession.shared
    private var spotifyToken: SpotifyTokenResponse?
    private var tokenExpiryTime = Date.distantPast
    private let musicBrainzUserAgent = "PAMS/1.0 ( https://github.com/leonardonapoless )"

    func searchSpotify(term: String) async throws -> [SpotifyTrack] {
        guard let token = try await getSpotifyToken() else {
            throw URLError(.userAuthenticationRequired)
        }

        var urlComponents = URLComponents(string: "https://api.spotify.com/v1/search")!
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: term),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "limit", value: "50")
        ]

        guard let url = urlComponents.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await httpClient.data(for: request)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        let responseModel = try decoder.decode(SpotifySearchResponse.self, from: data)

        return responseModel.tracks?.items ?? []
    }

    func getSpotifyTrack(id: String) async throws -> SpotifyTrack? {
        guard let token = try await getSpotifyToken() else {
            throw URLError(.userAuthenticationRequired)
        }

        let urlComponents = URLComponents(string: "https://api.spotify.com/v1/tracks/\(id)")!
        guard let url = urlComponents.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await httpClient.data(for: request)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(SpotifyTrack.self, from: data)
    }

    func getSpotifyAlbums(ids: [String]) async throws -> [SpotifyAlbum] {
        guard !ids.isEmpty else { return [] }
        guard let token = try await getSpotifyToken() else {
            throw URLError(.userAuthenticationRequired)
        }

        let idsString = ids.joined(separator: ",")
        var urlComponents = URLComponents(string: "https://api.spotify.com/v1/albums")!
        urlComponents.queryItems = [URLQueryItem(name: "ids", value: idsString)]

        guard let url = urlComponents.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await httpClient.data(for: request)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let responseModel = try JSONDecoder().decode(SpotifyAlbumsResponse.self, from: data)
        return responseModel.albums
    }

    func getSpotifyArtists(ids: [String]) async throws -> [SpotifyArtist] {
        guard !ids.isEmpty else { return [] }
        guard let token = try await getSpotifyToken() else {
            throw URLError(.userAuthenticationRequired)
        }

        let idsString = ids.joined(separator: ",")
        var urlComponents = URLComponents(string: "https://api.spotify.com/v1/artists")!
        urlComponents.queryItems = [URLQueryItem(name: "ids", value: idsString)]

        guard let url = urlComponents.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await httpClient.data(for: request)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let responseModel = try JSONDecoder().decode(SpotifyArtistsResponse.self, from: data)
        return responseModel.artists
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
            print("Songlink failed for URL \(spotifyURL): \(error.localizedDescription)")
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
            print("MusicBrainz failed for ISRC \(isrc): \(error.localizedDescription)")
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
        let copyright = release?.artistCredits?.map { "\($0.name)\($0.joinphrase ?? "")" }.joined()

        return MusicBrainzCredits(
            album: album,
            releaseDate: releaseDate,
            genre: genre,
            duration: duration,
            recordLabel: recordLabel,
            copyright: copyright
        )
    }

    private func getSpotifyToken() async throws -> SpotifyTokenResponse? {
        if let token = spotifyToken, tokenExpiryTime > Date() {
            return token
        }

        let clientID = KeyManager.spotifyClientID
        let clientSecret = KeyManager.spotifyClientSecret

        guard let authString = "\(clientID):\(clientSecret)".data(using: .utf8) else {
            throw URLError(.badURL)
        }
        
        let base64AuthString = authString.base64EncodedString()
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(base64AuthString)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)
        
        let (data, response) = try await httpClient.data(for: request)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.userAuthenticationRequired)
        }

        let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
        
        self.spotifyToken = tokenResponse
        self.tokenExpiryTime = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn - 300))

        return tokenResponse
    }
}

