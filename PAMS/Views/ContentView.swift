import SwiftUI

public struct ContentView: View {
    @StateObject private var viewModel = SongViewModel()
    @State private var searchTerm: String = ""

    public var body: some View {
        VStack {
            HeaderView()
            NavigationView {
                ZStack {
                    resultsListView
                    if viewModel.isLoading {
                        AnimatedPatternView(strokeWidth: 4)
                            .frame(width: 100, height: 100)
                    }
                }
                .searchable(text: $searchTerm, prompt: "Search Song or Album")
                .onChange(of: searchTerm) {
                    viewModel.search(term: searchTerm)
                }
            }
        }
    }

    private var resultsListView: some View {
        ResultsListView(results: viewModel.results, isLoading: viewModel.isLoading)
    }
}

#Preview {
    ContentView()
}
