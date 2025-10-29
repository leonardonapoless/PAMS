import SwiftUI

struct AnimatedPatternView: View {
    @State private var progress: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    let strokeWidth: CGFloat
    
    let enableHaptics: Bool
    
    @State private var hapticTrigger: Int = 0
    @State private var isHapticLoopActive: Bool = false
    @State private var hapticPhase: Double = 0.0
    
    init(strokeWidth: CGFloat = 1, enableHaptics: Bool = false) {
        self.strokeWidth = strokeWidth
        self.enableHaptics = enableHaptics
    }

    var body: some View {
        GreekKeyShape()
            .trim(from: 0, to: progress)
            .stroke(colorScheme == .dark ? Color.white : Color.black, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
            .onAppear {
                startAnimation()
                
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
    
        private func startHapticLoop() {
            guard !isHapticLoopActive else { return } // don't start a new loop
            isHapticLoopActive = true
            hapticPhase = 0.0 // reset the wave
            scheduleNextHapticTick() // start the loop
        }

        // this function recursively calls itself with a changing delay
        private func scheduleNextHapticTick() {
            guard isHapticLoopActive else { return } // the loop stops when this is false

            // fire the haptic
            hapticTrigger += 1
            
            // calculate the next delay using a sine wave
            // this creates a "wave" that oscillates the delay time
            let baseDelay = 0.15  // the average time between vibrations (in seconds)
            let modulation = 0.07 // how much the time will speed up or slow down
            let speed = 0.05      // how fast the wave oscillates
            
            // this calculation will result in a delay between
            // 0.08s (0.15 - 0.07) and 0.22s (0.15 + 0.07)
            let delayModulation = sin(hapticPhase * .pi * 2) * modulation
            let nextDelay = baseDelay + delayModulation
            
            // advance the phase of the wave
            // .truncatingRemainder ensures it loops between 0.0 and 1.0
            hapticPhase = (hapticPhase + speed).truncatingRemainder(dividingBy: 1.0)
            
            // schedule the next tick
            DispatchQueue.main.asyncAfter(deadline: .now() + nextDelay) {
                scheduleNextHapticTick()
            }
        }

        private func stopHapticLoop() {
            isHapticLoopActive = false
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
