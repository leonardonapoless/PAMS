import SwiftUI

struct ArtworkCard<Front: View, Back: View>: View {
    let front: Front
    let back: Back
    
    let cornerRadius: CGFloat
    let strokeWidth: CGFloat
    let innerPadding: CGFloat
    let outerPadding: CGFloat
    let innerAnimationSpeed: Double
    let isFocused: Bool
    
    @Environment(\.colorScheme) var colorScheme
    @State var rotation: Double = 0
    
    init(
        cornerRadius: CGFloat = 32,
        strokeWidth: CGFloat = 1,
        innerPadding: CGFloat = 8,
        outerPadding: CGFloat = 14,
        innerAnimationSpeed: Double = 12,
        outerAnimationSpeed: Double = 18,
        isFocused: Bool = true,
        @ViewBuilder front: () -> Front,
        @ViewBuilder back: () -> Back
    ) {
        self.cornerRadius = cornerRadius
        self.strokeWidth = strokeWidth
        self.innerPadding = innerPadding
        self.outerPadding = outerPadding
        self.innerAnimationSpeed = innerAnimationSpeed
        self.isFocused = isFocused
        self.front = front()
        self.back = back()
    }
    
    var isFaceUp: Bool {
        let degrees = rotation.truncatingRemainder(dividingBy: 360)
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
        .sensoryFeedback(.impact(weight: .light), trigger: rotation)
    }
    
    var cardFront: some View {
        cardBody(front)
            .opacity(isFaceUp ? 1 : 0)
    }
    
    var cardBack: some View {
        cardBody(back)
            .opacity(isFaceUp ? 0 : 1)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            .drawingGroup()
    }
    
    func cardBody(_ v: some View) -> some View {
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
                    speed: innerAnimationSpeed,
                    isFocused: isFocused
                )
            }
            .padding(outerPadding)
    }
}

struct AnimatedBorder: View {
    let cornerRadius: CGFloat
    let strokeWidth: CGFloat
    let strokeColor: Color
    let clockwise: Bool
    let speed: Double
    let isFocused: Bool
    
    @State var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let width = geometry.size.width
            let height = geometry.size.height
            
            let straightParts = 2 * (width + height)
            let cornerAdjustment = (2 * CGFloat.pi - 8) * cornerRadius
            let perimeter = straightParts + cornerAdjustment
            
            let strokeLength = perimeter * 0.15
            
            shape
                .stroke(
                    strokeColor.opacity(isFocused ? 0.9 : 0),
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round,
                        dash: [strokeLength, perimeter - strokeLength],
                        dashPhase: phase
                    )
                )
                .animation(.easeInOut(duration: 0.8), value: isFocused)
                .task(id: isFocused) {
                    if isFocused {
                        startAnimation(perimeter: perimeter)
                    } else {
                        try? await Task.sleep(for: .milliseconds(800))
                        if !Task.isCancelled {
                            stopAnimation()
                        }
                    }
                }
        }
        .allowsHitTesting(false)
    }
    
    func startAnimation(perimeter: CGFloat) {
        withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
            phase = clockwise ? -perimeter : perimeter
        }
    }
    
    func stopAnimation() {
        withAnimation(.default) {
            phase = 0
        }
    }
}

struct FlippableArtworkCard_Previews: PreviewProvider {
    static var previews: some View {
        ArtworkCard {
            Image(systemName: "music.note")
                .resizable()
                .scaledToFit()
                .padding(40)
                .foregroundColor(.purple)
                .background(Color(.systemGray6))
        } back: {
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
