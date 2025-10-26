import SwiftUI

struct oldArtworkCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let strokeWidth: CGFloat
    let innerPadding: CGFloat
    let outerPadding: CGFloat
    let innerAnimationSpeed: Double
    let outerAnimationSpeed: Double

    @Environment(\.colorScheme) private var colorScheme

    init(
        cornerRadius: CGFloat = 32,
        strokeWidth: CGFloat = 1,
        innerPadding: CGFloat = 8,
        outerPadding: CGFloat = 14,
        innerAnimationSpeed: Double = 12,
        outerAnimationSpeed: Double = 18,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.strokeWidth = strokeWidth
        self.innerPadding = innerPadding
        self.outerPadding = outerPadding
        self.innerAnimationSpeed = innerAnimationSpeed
        self.outerAnimationSpeed = outerAnimationSpeed
        self.content = content()
    }

    var body: some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: colorScheme == .dark ? .white.opacity(0.08) : .black.opacity(0.2), radius: 5, x: 0, y: 5)
            .padding(innerPadding)
            .background {
                AnimatedBorder(
                    cornerRadius: cornerRadius - (innerPadding * -1.4),
                    strokeWidth: strokeWidth,
                    strokeColor: colorScheme == .dark ? .white : .black,
                    clockwise: true,
                    speed: innerAnimationSpeed
                )
            }
            .padding(outerPadding)
    }
}

private struct AnimatedBorder: View {
    let cornerRadius: CGFloat
    let strokeWidth: CGFloat
    let strokeColor: Color
    let clockwise: Bool
    let speed: Double

    @State private var rotation: CGFloat = 0

    var body: some View {
        GeometryReader { _ in
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let strokeLength: CGFloat = 0.09

            shape
                .trim(from: rotation, to: rotation + strokeLength)
                .stroke(strokeColor.opacity(0.9), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .onAppear {
                    withAnimation(.linear(duration: speed).repeatForever()) {
                        rotation = clockwise ? 1.0 : -1.0
                    }
                }
        }
        .allowsHitTesting(false)
    }
}

