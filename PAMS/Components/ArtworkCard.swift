import SwiftUI

struct ArtworkCard<Front: View, Back: View>: View {
    let front: Front
    let back: Back

    let cornerRadius: CGFloat
    let strokeWidth: CGFloat
    let innerPadding: CGFloat
    let outerPadding: CGFloat
    let innerAnimationSpeed: Double

    @Environment(\.colorScheme) private var colorScheme
    @State private var rotation: Double = 0

    init(
        cornerRadius: CGFloat = 32,
        strokeWidth: CGFloat = 1,
        innerPadding: CGFloat = 8,
        outerPadding: CGFloat = 14,
        innerAnimationSpeed: Double = 12,
        outerAnimationSpeed: Double = 18,
        @ViewBuilder front: () -> Front,
        @ViewBuilder back: () -> Back
    ) {
        self.cornerRadius = cornerRadius
        self.strokeWidth = strokeWidth
        self.innerPadding = innerPadding
        self.outerPadding = outerPadding
        self.innerAnimationSpeed = innerAnimationSpeed
        self.front = front()
        self.back = back()
    }

    // determines if the card's front face should be visible
    private var isFaceUp: Bool {
        let degrees = rotation.truncatingRemainder(dividingBy: 360)
        // the front is visible when the rotation is between 0 and 90 degrees,
        // or between 270 and 360 degrees.
        return (degrees >= 0 && degrees < 90) || (degrees >= 270 && degrees < 360)
    }

    var body: some View {
        ZStack {
            cardFront
            cardBack
        }
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
        .onTapGesture {
            withAnimation(.bouncy(duration: 0.6)) {
                rotation += 180
            }
        }
    }

    // front
    private var cardFront: some View {
        cardBody(front)
            .opacity(isFaceUp ? 1 : 0)
    }

    // back
    private var cardBack: some View {
        cardBody(back)
            .opacity(isFaceUp ? 0 : 1)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            // the drawingGroup is used to improve animation performance of the
            // material background on the back of the card. it composites the
            // view into a bitmap before the rotation, preventing rendering
            // issues during the flip animation
            .drawingGroup()
    }

    private func cardBody(_ v: some View) -> some View {
        v
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .primary.opacity(colorScheme == .light ? 0.2 : 0), radius: 5, x: 0, y: 5)
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
                    withAnimation(.easeIn(duration: speed).repeatForever()) {
                        rotation = clockwise ? 1.0 : -1.0
                    }
                }
        }
        .allowsHitTesting(false)
    }
}

struct FlippableArtworkCard_Previews: PreviewProvider {
    static var previews: some View {
        ArtworkCard {
            // front
            Image(systemName: "music.note")
                .resizable()
                .scaledToFit()
                .padding(40)
                .foregroundColor(.purple)
                .background(Color(.systemGray6))
        } back: {
            // back
            VStack(spacing: 6) {
                Text("Song Name")
                    .font(.headline)
                Text("Artist Name")
                    .font(.subheadline)
                Divider()
                Text("Release: 2024-10-25")
                Text("Length: 3:42")
                Text("Credits: Prod. Leonardo")
            }
            .font(.footnote)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGray6))
        }
        .frame(width: 240, height: 240)
        .padding()
    }
}
