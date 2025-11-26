import SwiftUI

struct AnimatedPatternView: View {
    @State private var progress: CGFloat = 0
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



struct GreekKeyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        
        let points: [CGPoint] = [
            
            CGPoint(x: 0.00, y: 0.75),
            CGPoint(x: 0.00, y: 0.00),
            CGPoint(x: 1.00, y: 0.00),
            CGPoint(x: 1.00, y: 1.00),
            
            CGPoint(x: 0.170, y: 1.00),
            CGPoint(x: 0.170, y: 0.25),
            CGPoint(x: 0.790, y: 0.25),
            CGPoint(x: 0.790, y: 0.80),
            CGPoint(x: 0.330, y: 0.80),
            CGPoint(x: 0.330, y: 0.44),
            CGPoint(x: 0.625, y: 0.44),
            CGPoint(x: 0.625, y: 0.650),
            CGPoint(x: 0.48, y: 0.650),
            CGPoint(x: 0.48, y: 0.56),
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
    AnimatedPatternView()
}
