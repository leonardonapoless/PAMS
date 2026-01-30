import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SongViewModel()
    @State private var liveSearchTerm: String = ""
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
                            .zIndex(1)
                    }
                }
                .searchable(text: $liveSearchTerm, prompt: "Search Song or Album")
                .onChange(of: liveSearchTerm) { _, newValue in
                    isTyping = !newValue.isEmpty
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
