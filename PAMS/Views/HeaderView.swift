import SwiftUI

struct HeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PAMS")
                    .fontWeight(.black)
                    .monospaced()
                    .font(.largeTitle)

                AnimatedPatternView(strokeWidth: 2)
                    .frame(width: 30, height: 30)
                    .padding(.leading, -4)
                    .padding(.top, 8)
            }
            Text("Platform Agnostic Music Search")
                .fontWeight(.bold)
                .monospaced()
                .font(.headline)
        }
        .padding(.horizontal)
    }
}

#Preview {
    HeaderView()
}
