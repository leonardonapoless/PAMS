import SwiftUI

public struct ContentView: View {
    @StateObject private var viewModel = SongViewModel()
    @State private var liveSearchTerm: String = ""
    @Debounced(wrappedValue: "", delay: 0.5) private var debouncedSearchTerm: String
    @State private var isTyping: Bool = false
    
    public var body: some View {
        VStack {
            HeaderView()
            NavigationView {
                ZStack {
                    resultsListView
                    if viewModel.isLoading {
                        AnimatedPatternView(strokeWidth: 4, enableHaptics: !isTyping)
                            .frame(width: 100, height: 100)
                    }
                }
                .searchable(text: $liveSearchTerm, prompt: "Search Song or Album")
                .onChange(of: liveSearchTerm) { _, newValue in
                    isTyping = true
                    debouncedSearchTerm = newValue
                }
                .onChange(of: debouncedSearchTerm) { _, newValue in
                                    isTyping = false // User has stopped typing
                                    viewModel.search(term: newValue)
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
