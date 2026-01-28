import SwiftUI

struct CoverArtSkeleton: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isAnimating = false
    
    var body: some View {
        Color(.systemGray5)
            .overlay {
                VStack(spacing: 12) {
                    skeletonBlock(width: 140, height: 16, radius: 6)
                    skeletonBlock(width: 100, height: 12, radius: 5)
                    skeletonBlock(width: 70, height: 10, radius: 4)
                    skeletonBlock(width: 50, height: 8, radius: 4)
                }
                .opacity(isAnimating ? 0.4 : 0.9)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: .primary.opacity(colorScheme == .light ? 0.2 : 0), radius: 5, x: 0, y: 5)
            .onAppear { isAnimating = true }
    }
    
    private func skeletonBlock(width: CGFloat, height: CGFloat, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color(.systemGray4))
            .frame(width: width, height: height)
    }
}

#Preview {
    CoverArtSkeleton()
        .frame(width: 280, height: 280)
}
