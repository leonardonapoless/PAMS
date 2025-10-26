import SwiftUI

struct AnimatedPatternView: View {
    @State private var progress: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        GreekKeyShape()
            .trim(from: 0, to: progress)
            .stroke(colorScheme == .dark ? Color.white : Color.black, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            .onAppear {
                startAnimation()
            }
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: 3)) {
            progress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeInOut(duration: 5)) {
                progress = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 8.5) {
            startAnimation()
        }
    }
}

struct GreekKeyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let unit = w / 12

        path.move(to: CGPoint(x: unit * 2, y: unit * 2))
        path.addLine(to: CGPoint(x: unit * 2, y: unit * 4))
        path.addLine(to: CGPoint(x: unit * 4, y: unit * 4))
        path.addLine(to: CGPoint(x: unit * 4, y: unit * 2))
        path.addLine(to: CGPoint(x: unit * 5, y: unit * 2))
        path.addLine(to: CGPoint(x: unit * 5, y: unit * 5))
        path.addLine(to: CGPoint(x: unit * 2, y: unit * 5))

        path.move(to: CGPoint(x: unit * 10, y: unit * 2))
        path.addLine(to: CGPoint(x: unit * 8, y: unit * 2))
        path.addLine(to: CGPoint(x: unit * 8, y: unit * 4))
        path.addLine(to: CGPoint(x: unit * 10, y: unit * 4))
        path.addLine(to: CGPoint(x: unit * 10, y: unit * 5))
        path.addLine(to: CGPoint(x: unit * 7, y: unit * 5))
        path.addLine(to: CGPoint(x: unit * 7, y: unit * 2))

        path.move(to: CGPoint(x: unit * 10, y: unit * 10))
        path.addLine(to: CGPoint(x: unit * 10, y: unit * 8))
        path.addLine(to: CGPoint(x: unit * 8, y: unit * 8))
        path.addLine(to: CGPoint(x: unit * 8, y: unit * 10))
        path.addLine(to: CGPoint(x: unit * 7, y: unit * 10))
        path.addLine(to: CGPoint(x: unit * 7, y: unit * 7))
        path.addLine(to: CGPoint(x: unit * 10, y: unit * 7))

        path.move(to: CGPoint(x: unit * 2, y: unit * 10))
        path.addLine(to: CGPoint(x: unit * 4, y: unit * 10))
        path.addLine(to: CGPoint(x: unit * 4, y: unit * 8))
        path.addLine(to: CGPoint(x: unit * 2, y: unit * 8))
        path.addLine(to: CGPoint(x: unit * 2, y: unit * 7))
        path.addLine(to: CGPoint(x: unit * 5, y: unit * 7))
        path.addLine(to: CGPoint(x: unit * 5, y: unit * 10))

        return path
    }
}
