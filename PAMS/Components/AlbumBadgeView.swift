import SwiftUI

struct AlbumBadgeView: View {
    private let textData: [(String, Double)] = [
        ("A", 0),
        ("L", 13),
        ("B", 26),
        ("U", 40),
        ("M", 56)
    ]
    
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.75, to: 1.0)
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 1))
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-110))
                .offset(x: 10, y: 4)
           
            ForEach(Array(textData.enumerated()), id: \.offset) { _, item in
                let (symbol, angleOffset) = item
                Text(symbol)
                    .font(.system(size: 11, weight: .bold))
                    .offset(x: 2,y: -40)
                    .rotationEffect(.degrees(angleOffset))
                    .rotationEffect(.degrees(4))
            }

            Image(systemName: "square.stack.fill")
                .font(.system(size: 10))
                .rotationEffect(.degrees(-15))
                .offset(x: 0,y: -44)
                .rotationEffect(.degrees(78))
                .rotationEffect(.degrees(4))
        }
        .frame(width: 100, height: 100)
        .offset(x: 10, y: -20)
    }
}

struct AlbumBadgeView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            CoverArtCard(
                isFocused: true,
                front: {
                    ZStack {
                        LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: "music.quarternote.3")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(60)
                            .foregroundColor(.white.opacity(0.8))
                    }
                },
                back: { Color.gray },
                badge: { AlbumBadgeView() }
            )
            .frame(width: 280, height: 280)
        }
        .preferredColorScheme(.dark)
    }
}
