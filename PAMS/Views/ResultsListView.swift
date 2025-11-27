import SwiftUI

struct ResultsListView: View {
    let results: [SearchResult]
    let isLoading: Bool
    
    @State var focusedID: String? = nil

    var body: some View {
        ZStack {
            if results.isEmpty && !isLoading {
                emptyStateView
            } else {
                resultsList
            }
        }
        .background(Color(UIColor.systemBackground))
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        }
        .onPreferenceChange(VisibilityPreferenceKey.self) { preferences in
            updateFocus(with: preferences)
        }
    }
    
    var emptyStateView: some View {
        Text("Find your music across platforms")
            .foregroundStyle(.secondary)
            .italic()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    var resultsList: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(results) { result in
                        SearchResultRow(
                            result: result,
                            isFocused: focusedID == result.id,
                            listFrame: geometry.frame(in: .global),
                            iconSpotifyBlack: "spotify_icon_black",
                            iconSpotifyWhite: "spotify_icon_white",
                            iconTidalBlack: "tidal_icon_black",
                            iconTidalWhite: "tidal_icon_white",
                            iconYTWhite: "yt_icon_white",
                            iconYTBlack: "yt_icon_black"
                        )
                    }
                }
                .frame(minHeight: geometry.size.height)
                .frame(maxWidth: .infinity)
            }
        }
    }

    func updateFocus(with preferences: [String: Double]) {
        // If any card is > 95% visible, focus it.
        // If multiple are, pick the first one (or could be all, but "focus" implies singular usually).
        // My previous logic allowed multiple. Let's stick to singular for "focus" to be cleaner,
        // or just pick the "most" visible one if none are fully visible.
        
        let fullyVisibleThreshold = 0.95
        let fullyVisibleIDs = preferences.filter { $0.value >= fullyVisibleThreshold }.map { $0.key }
        
        if let firstFullyVisible = fullyVisibleIDs.first {
            focusedID = firstFullyVisible
        } else {
            // Fallback to the most visible one
            if let max = preferences.max(by: { $0.value < $1.value }) {
                focusedID = max.key
            } else {
                focusedID = nil
            }
        }
    }
}
