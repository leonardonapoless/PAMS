import SwiftUI

public struct ContentView: View {
    @StateObject private var viewModel = SongViewModel()
    @Debounced(wrappedValue: "", delay: 0.5) private var searchTerm: String

    public var body: some View {
        VStack {
            HeaderView()
            NavigationView {
                resultsListView
                    .searchable(text: $searchTerm, prompt: "Search Song or Album")
                    .onChange(of: searchTerm) {
                        Task {
                            await viewModel.search(term: searchTerm)
                        }
                    }
            }
        }
    }

    private var resultsListView: some View {
        ResultsListView(results: viewModel.results)
    }
}

#Preview {
    ContentView()
}
