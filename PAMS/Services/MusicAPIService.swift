import Foundation

@MainActor
class MusicAPIService {

    // create a shared instance of the service
    static let shared = MusicAPIService()

    // a single, reusable session for all network requests
    private let httpClient = URLSession.shared

    // spotify token caching
    // these are now properties of the @mainactor-isolated class
    private var spotifyToken: SpotifyTokenResponse?
    private var tokenExpiryTime = Date.distantPast

    // musicbrainz requires a user-agent
    private let musicBrainzUserAgent = "PAMS/1.0 ( https://github.com/leonardonapoless )"

    // MARK: - public api functions

    // the main spotify search (the "scout")
    func searchSpotify(term: String) async throws -> [SpotifyTrack] {
        // first, get a valid token (either cached or new)
        guard let token = try await getSpotifyToken() else {
            throw URLError(.userAuthenticationRequired)
        }

        // build the url
        var urlComponents = URLComponents(string: "https://api.spotify.com/v1/search")!
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: term),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "limit", value: "20")
        ]

        guard let url = urlComponents.url else { throw URLError(.badURL) }

        // build the request, adding the token
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")

        // make the call
        let (data, response) = try await httpClient.data(for: request)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // decode the json "blueprint"
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

        let decoder = JSONDecoder()
        let track = try decoder.decode(SpotifyTrack.self, from: data)

        return track
    }

    // get universal links from songlink
    func getSonglink(for spotifyURL: String) async -> PlatformLinks? {
        guard let encodedURL = spotifyURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.song.link/v1-alpha.1/links?url=\(encodedURL)") else {
            return nil
        }

        do {
            let (data, _) = try await httpClient.data(from: url)
            let decoder = JSONDecoder()
            let responseModel = try decoder.decode(SonglinkResponse.self, from: data)

            return PlatformLinks(from: responseModel)
        } catch {
            print("Songlink failed for URL \(spotifyURL): \(error.localizedDescription)")
            return nil // fail gracefully, don't crash
        }
    }

    // get credits from musicbrainz
    // this now returns the clean musicbrainzcredits struct
    func getMusicBrainzCredits(isrc: String?) async -> MusicBrainzCredits {
        guard let isrc, !isrc.isEmpty else {
            return .empty
        }

        let inc = "artist-credits+recording-level-rels+release-level-rels+genres+labels"
        guard let url = URL(string: "https://musicbrainz.org/ws/2/isrc/\(isrc)?fmt=json&inc=\(inc)") else {
            return .empty
        }

        var request = URLRequest(url: url)
        request.setValue(musicBrainzUserAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await httpClient.data(for: request)
            let decoder = JSONDecoder()
            let responseModel = try decoder.decode(MusicBrainzISRCResponse.self, from: data)

            guard let recording = responseModel.recordings.first else {
                return .empty
            }

            return parseMusicBrainzRecording(recording)

        } catch {
            print("MusicBrainz failed for ISRC \(isrc): \(error.localizedDescription)")
            return .empty
        }
    }

    private func parseMusicBrainzRecording(_ recording: MusicBrainzRecording) -> MusicBrainzCredits {
        let songwriters = recording.relations?.filter { $0.type == "songwriter" }.map { $0.artist.name }.joined(separator: ", ")
        let producers = recording.relations?.filter { $0.type == "producer" }.map { $0.artist.name }.joined(separator: ", ")
        let genre = recording.genres?.first?.name
        let duration = recording.length.map { "\($0 / 1000 / 60):\(String(format: "%02d", ($0 / 1000) % 60))" }

        let release = recording.releaseList?.releases?.first
        let album = release?.title
        let releaseDate = release?.date
        let recordLabel = release?.labelInfo?.first?.label?.name
        let copyright = release?.artistCredits?.map { "\($0.name)\($0.joinphrase ?? "")" }.joined()

        return MusicBrainzCredits(
            songwriter: songwriters,
            producer: producers,
            album: album,
            releaseDate: releaseDate,
            genre: genre,
            duration: duration,
            recordLabel: recordLabel,
            copyright: copyright
        )
    }

    // MARK: - private: spotify token logic

    // this function safely gets and caches the spotify access token
    private func getSpotifyToken() async throws -> SpotifyTokenResponse? {

        // if we have a token and it's still valid, return it instantly
        if let token = spotifyToken, tokenExpiryTime > Date() {
            return token
        }

        // get keys safely from keymanager
        let clientID = KeyManager.spotifyClientID
        let clientSecret = KeyManager.spotifyClientSecret

        // prepare the request (base64 encoding)
        guard let authString = "\(clientID):\(clientSecret)".data(using: .utf8) else {
            throw URLError(.badURL)
        }
        let base64AuthString = authString.base64EncodedString()

        // configure the url and request
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(base64AuthString)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)

        // make the call
        let (data, response) = try await httpClient.data(for: request)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.userAuthenticationRequired)
        }

        let decoder = JSONDecoder()
        let tokenResponse = try decoder.decode(SpotifyTokenResponse.self, from: data)

        // cache the new token and set its expiry time
        self.spotifyToken = tokenResponse
        self.tokenExpiryTime = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn - 300))

        return tokenResponse
    }
}

