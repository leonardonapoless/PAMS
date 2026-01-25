import SwiftUI

struct ResultsListView: View {
    let results: [SearchResultItem]
    let isLoading: Bool
    var status: SearchStatus = .idle
    
    @State var focusedID: String? = nil

    var body: some View {
        ZStack {
            if results.isEmpty && !isLoading {
                statusView
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
    
    var statusView: some View {
        VStack(spacing: 12) {
            if status != .idle {
                Image(systemName: status.icon)
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(status.message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Find your music across platforms")
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    private var lowRelevanceBanner: some View {
        Text(status.message)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .italic()
            .padding(.top, 8)
            .padding(.bottom, -24)
    }
    
    var resultsList: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 20) {
                    if case .lowRelevance = status, !results.isEmpty {
                        lowRelevanceBanner
                    }
                    ForEach(results) { result in
                        SearchResultRow(
                            item: result,
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
        let fullyVisibleThreshold = 0.95
        let fullyVisibleIDs = preferences.filter { $0.value >= fullyVisibleThreshold }.map { $0.key }
        
        if let firstFullyVisible = fullyVisibleIDs.first {
            focusedID = firstFullyVisible
        } else {
            if let max = preferences.max(by: { $0.value < $1.value }) {
                focusedID = max.key
            } else {
                focusedID = nil
            }
        }
    }
}

// MARK: - Previews

private struct StatusPreviewWrapper: View {
    let status: SearchStatus
    
    var body: some View {
        VStack {
            HeaderView()
            NavigationView {
                ResultsListView(results: [], isLoading: false, status: status)
                    .searchable(text: .constant("test search"), prompt: "Search Song or Album")
            }
        }
    }
}

#Preview("Idle") {
    StatusPreviewWrapper(status: .idle)
}

#Preview("No Results") {
    StatusPreviewWrapper(status: .noResults(query: "asdfghjkl"))
}

#Preview("Network Error") {
    StatusPreviewWrapper(status: .networkError)
}

#Preview("Rate Limited") {
    StatusPreviewWrapper(status: .rateLimited)
}

#Preview("Session Expired") {
    StatusPreviewWrapper(status: .sessionExpired)
}

#Preview("Generic Error") {
    StatusPreviewWrapper(status: .genericError)
}

