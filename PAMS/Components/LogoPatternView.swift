import SwiftUI

struct LogoPatternView: View {

    @Environment(\.colorScheme) var colorScheme
    let strokeWidth: CGFloat
    
    let enableHaptics: Bool
    
    @State private var hapticTrigger: Int = 0
    @State private var isHapticLoopActive: Bool = false
    @State private var hapticPhase: Double = 0.0
    
    init(strokeWidth: CGFloat = 2, enableHaptics: Bool = false) {
        self.strokeWidth = strokeWidth
        self.enableHaptics = enableHaptics
    }

    enum AnimationPhase: CaseIterable {
        case draw, hold, erase, pause
        
        var progress: CGFloat {
            switch self {
            case .draw, .hold: 1
            case .erase, .pause: 0
            }
        }
    }

    var body: some View {
        PhaseAnimator(AnimationPhase.allCases, content: { phase in
            LogoShape()
                .trim(from: 0, to: phase.progress)
                .stroke(
                    colorScheme == .dark ? Color.white : Color.black,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
                )
        }, animation: { phase in
            switch phase {
            case .draw: .easeInOut(duration: 3.0)
            case .hold: .linear(duration: 0.2)
            case .erase: .easeInOut(duration: 5.0)
            case .pause: .linear(duration: 0.3)
            }
        })
        .onAppear {
            if enableHaptics {
                startHapticLoop()
            }
        }
        .onDisappear {
            stopHapticLoop()
        }
        .onChange(of: enableHaptics) { _, newIsHapticsEnabled in
            if newIsHapticsEnabled {
                startHapticLoop()
            } else {
                stopHapticLoop()
            }
        }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.7), trigger: hapticTrigger)
    }

    private func startHapticLoop() {
        guard !isHapticLoopActive else { return }
        isHapticLoopActive = true
        hapticPhase = 0.0
        scheduleNextHapticTick()
    }

    private func scheduleNextHapticTick() {
        guard isHapticLoopActive else { return }

        hapticTrigger += 1

        let baseDelay = 0.15
        let modulation = 0.07
        let speed = 0.05

        let delayModulation = sin(hapticPhase * .pi * 2) * modulation
        let nextDelay = baseDelay + delayModulation

        hapticPhase = (hapticPhase + speed).truncatingRemainder(dividingBy: 1.0)

        DispatchQueue.main.asyncAfter(deadline: .now() + nextDelay) {
            scheduleNextHapticTick()
        }
    }

    private func stopHapticLoop() {
        isHapticLoopActive = false
    }
}

struct LogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        
        let points: [CGPoint] = [
            CGPoint(x: 0.00, y: 0.75),
            CGPoint(x: 0.00, y: 0.00),
            CGPoint(x: 1.00, y: 0.00),
            CGPoint(x: 1.00, y: 1.00),
            CGPoint(x: 0.17, y: 1.00),
            CGPoint(x: 0.17, y: 0.25),
            CGPoint(x: 0.79, y: 0.25),
            CGPoint(x: 0.79, y: 0.80),
            CGPoint(x: 0.33, y: 0.80),
            CGPoint(x: 0.33, y: 0.44),
            CGPoint(x: 0.625, y: 0.44),
            CGPoint(x: 0.625, y: 0.65),
            CGPoint(x: 0.48, y: 0.65),
            CGPoint(x: 0.48, y: 0.56)
        ]
        
        var path = Path()
        
        guard let first = points.first else { return path }
        
        path.move(to: CGPoint(x: first.x * width, y: first.y * height))
        
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x * width, y: point.y * height))
        }
        
        return path
    }
}

#Preview {
    LogoPatternView()
}
