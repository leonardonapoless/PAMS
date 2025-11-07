import SwiftUI

struct HeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PAMS")
                    .fontWeight(.black)
                    .monospaced()
                    .font(.largeTitle)

                AnimatedPatternView()
                    .frame(width: 32, height: 32)
                    .padding(.leading, -10)
            }
            Text("Platform Agnostic Music Search")
                .fontWeight(.bold)
                .monospaced()
                .font(.headline)
        }
        .padding(.horizontal)
    }
}
