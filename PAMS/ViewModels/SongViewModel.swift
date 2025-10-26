import Foundation
import Combine

@MainActor
public final class SongViewModel: ObservableObject {
    @Published public private(set) var results: [SearchResult] = []
    @Published public private(set) var isLoading: Bool = false

    private var searchTask: Task<Void, Never>?

    private let mockResults: [SearchResult] = [
        SearchResult(
            id: "1",
            title: "So What",
            artist: "Miles Davis",
            releaseDate: "",
            songwriter: "",
            producer: "",
            album: "",
            genre: "",
            duration: "",
            recordLabel: "",
            copyright: "",
            artworkURL: URL(string: "https://i.scdn.co/image/ab67616d0000b2731f2334b243bb3e3a1abb2c4d"),
                isrc: "USSM15900113",
            links: PlatformLinks(
            apple: "https://music.apple.com/us/song/so-what/268443097",
            spotify: "https://open.spotify.com/track/4vLYewWIvqHfKtJDk8c8tq?si=aff167f5947840f6",
            tidal: "https://tidal.com/track/2178486/u",
            youtube: "https://youtu.be/ylXk1LBvIqU?si=xeWObPhb3s0pytO6"
        )),
        SearchResult(
            id: "2",
            title: "You've Got the Love",
            artist: "Florence + The Machine",
            releaseDate: "",
            songwriter: "",
            producer: "",
            album: "",
            genre: "",
            duration: "",
            recordLabel: "",
            copyright: "",
            artworkURL: URL(string: "https://img.apmcdn.org/ea6cea838560e6c6aee42190774034c1a19bc074/uncropped/9fe734-20121221-florence-and-the-machine-lungs.jpg"),
            isrc: "GBUM70900237",
            links: PlatformLinks(
            apple: "https://music.apple.com/us/song/youve-got-the-love/1470594155",
            spotify: "https://open.spotify.com/track/244AvzGQ4Ksa5637JQu5Gy?si=a8edf731090647f4",
            tidal: "https://tidal.com/track/6551583/u",
            youtube: "https://youtu.be/PQZhN65vq9E?si=HXF58gSLKBa3X3tr"
        )),
        SearchResult(
            id: "3",
            title: "Brandy (You're A Fine Girl)",
            artist: "Looking Glass",
            releaseDate: "",
            songwriter: "",
            producer: "",
            album: "",
            genre: "",
            duration: "",
            recordLabel: "",
            copyright: "",
            artworkURL: URL(string: "https://i.discogs.com/7EWzfxs2_SMTsZoP12jlja1xZUJv6kE16fkhxm6ItnQ/rs:fit/g:sm/q:90/h:600/w:600/czM6Ly9kaXNjb2dz/LWRhdGFiYXNlLWlt/YWdlcy9SLTE2NzI1/MzgtMTMwMDQ5MDE4/MS5qcGVn.jpeg"),
            isrc: "USSM10903222",
            links: PlatformLinks(
            apple: "https://music.apple.com/us/song/brandy-youre-a-fine-girl/388158216",
            spotify: "https://open.spotify.com/track/2BY7ALEWdloFHgQZG6VMLA?si=576f4e1de9c64796",
            tidal: "https://tidal.com/track/4350147/u",
            youtube: "https://youtu.be/DVx8L7a3MuE?si=YQTCM0F-WCglZuyu"
        )),
        SearchResult(
            id: "4",
            title: "Helter Skelter",
            artist: "The Beatles",
            releaseDate: "11/22/1968",
            songwriter: "Paul McCartney, John Lennon",
            producer: "George Martin",
            album: "The Beatles",
            genre: "Hard Rock",
            duration: "4:30",
            recordLabel: "Apple Records",
            copyright: "1968 Sony/ATV Music Publishing LLC",
            artworkURL: URL(string: "https://preview.redd.it/the-highest-quality-beatles-album-covers-i-could-find-on-v0-nfo15kg44ylc1.png?width=1080&crop=smart&auto=webp&s=18564d87e55786ba8eaf4546376bdc47a05c1231"),
            isrc: "GBAYE0601666",
            links: PlatformLinks(
                apple: "https://music.apple.com/us/song/helter-skelter/1441134207",
                spotify: "https://open.spotify.com/track/0Bs0hUYxz7REyIHH7tRhL2?si=9cb28e89f66c4fb6",
                tidal: "https://tidal.com/track/55163325/u",
                youtube: "https://youtu.be/vWW2SzoAXMo?si=49tv8CwojyAntEnd"
            )),
        SearchResult(
            id: "5",
            title: "The Suburbs",
            artist: "Arcade Fire",
            releaseDate: "",
            songwriter: "",
            producer: "",
            album: "",
            genre: "",
            duration: "",
            recordLabel: "",
            copyright: "",
            artworkURL: URL(string: "https://cdn-images.dzcdn.net/images/cover/d6764ed9d1f942942fb47ecde23919eb/0x1900-000000-80-0-0.jpg"),
            isrc: "GBUM71018417",
            links: PlatformLinks(
            apple: "https://music.apple.com/br/song/the-suburbs/1252758311?l=en-US",
            spotify: "https://open.spotify.com/track/2UWdUez9MB9yzL7Y81Mcip?si=eccaf03b94324c89",
            tidal: "https://tidal.com/track/75572502/u",
            youtube: "https://youtu.be/5Euj9f3gdyM?si=mRZ-dQJprDNaT3BW"
        )),
        SearchResult(
            id: "6",
            title: "Salt + Charcoal",
            artist: "Plini",
            releaseDate: "",
            songwriter: "",
            producer: "",
            album: "",
            genre: "",
            duration: "",
            recordLabel: "",
            copyright: "",
            artworkURL: URL(string: "https://f4.bcbits.com/img/a3458170657_16.jpg"),
            isrc: "TCADS1862883",
            links: PlatformLinks(
            apple: "https://music.apple.com/us/song/salt-charcoal/1562295031",
            spotify: "https://open.spotify.com/track/3eWDuqKzb3uketbWe08kvm?si=80f77cb023134fa1",
            tidal: "https://tidal.com/track/180076363/u",
            youtube: "https://youtu.be/N3tjQ8tR7pw?si=xKflP-_-MjXAEFyU"
        ))
    ]

    public func search(term: String) async {
        searchTask?.cancel()

        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            results = []
            isLoading = false
            return
        }

        isLoading = true

        searchTask = Task {
            // simulate network delay
//            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            if trimmed.isEmpty {
                results = mockResults
            } else {
                results = mockResults.filter { result in
                    result.title.localizedCaseInsensitiveContains(trimmed) ||
                    result.artist.localizedCaseInsensitiveContains(trimmed)
                }
            }
            
            isLoading = false
        }
        await searchTask?.value
    }
}
