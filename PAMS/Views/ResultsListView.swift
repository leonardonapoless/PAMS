import SwiftUI

struct ResultsListView: View {
    let results: [SearchResult]

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 20) {
                    if results.isEmpty {
                        Text("Find your music across platforms")
                            .foregroundStyle(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(results) { result in
                            SearchResultRow(
                                result: result,
                                iconSpotifyBlack: "spotify_icon_black",
                                iconSpotifyWhite: "spotify_icon_white",
                                iconTidalBlack: "tidal_icon_black",
                                iconTidalWhite: "tidal_icon_white",
                                iconYTWhite: "yt_icon_white",
                                iconYTBlack: "yt_icon_black"
                            )
                        }
                    }
                }
                .frame(minHeight: geometry.size.height)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(UIColor.systemBackground))
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        }
    }
}
