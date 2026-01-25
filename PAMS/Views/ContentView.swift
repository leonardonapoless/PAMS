import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SongViewModel()
    @State private var liveSearchTerm: String = ""
    @Debounced(wrappedValue: "", delay: 0.5) private var debouncedSearchTerm: String
    @State private var isTyping: Bool = false
    
    var body: some View {
        VStack {
            HeaderView()
            NavigationView {
                ZStack {
                    resultsListView
                    if viewModel.isLoading {
                        LogoPatternView(strokeWidth: 4, enableHaptics: !isTyping)
                            .frame(width: 80, height: 80)
                            .zIndex(2)
                    }
                }
                .searchable(text: $liveSearchTerm, prompt: "Search Song or Album")
                .onChange(of: liveSearchTerm) { _, newValue in
                    isTyping = true
                    debouncedSearchTerm = newValue
                }
                .onChange(of: debouncedSearchTerm) { _, newValue in
                    isTyping = false
                    viewModel.search(term: newValue)
                }
            }
        }
    }
    
    private var resultsListView: some View {
        ResultsListView(results: viewModel.results, isLoading: viewModel.isLoading, status: viewModel.status)
    }
}

#Preview {
    ContentView()
}
