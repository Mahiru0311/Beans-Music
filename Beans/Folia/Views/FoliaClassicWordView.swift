import SwiftUI

struct FoliaClassicWordView: View {
    let word: FoliaWord
    let time: Double
    let state: FoliaClassicWordState
    let geometry: FoliaClassicWordGeometry
    let intensity: FoliaClassicIntensity
    let fontSize: Double
    let base: Color
    let accent: Color
    let rotationEnabled: Bool
    let reduceMotion: Bool

    private var opacity: Double {
        switch state { case .waiting: return 0; case .active: return 1; case .passed: return intensity == .chaotic ? 0.9 : 0.82 }
    }
    private var scale: Double {
        guard !reduceMotion else { return 1 }
        switch state { case .waiting: return 0.4; case .active: return geometry.scale * 1.6; case .passed: return geometry.scale }
    }
    private var rotation: Double {
        guard !reduceMotion, rotationEnabled else { return 0 }
        switch state {
        case .waiting: return geometry.rotation + 20
        case .active: return geometry.rotation
        case .passed: return geometry.rotation + geometry.passedRotation
        }
    }
    private var animation: Animation? {
        guard !reduceMotion else { return nil }
        switch state {
        case .waiting: return .easeOut(duration: 0.4)
        case .active: return .interpolatingSpring(mass: 1, stiffness: 260, damping: 16, initialVelocity: 0)
        case .passed: return .easeInOut(duration: 0.5)
        }
    }

    var body: some View {
        Text(word.text).font(.system(size: fontSize, weight: .bold)).fixedSize()
            .foregroundStyle(state == .active ? accent : base)
            .animation(reduceMotion ? nil : state == .active ? .linear(duration: max(0.1, word.endTime - word.startTime)) : .easeInOut(duration: 0.8), value: state)
            .background {
                if !reduceMotion { FoliaClassicGlowView(word: word, time: time, fontSize: fontSize, color: accent) }
            }
            .blur(radius: state == .waiting && !reduceMotion ? 14 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: state == .active ? 0.2 : 0.5), value: state)
            .opacity(opacity)
            .animation(reduceMotion ? nil : .easeOut(duration: state == .active ? 0.1 : 0.5), value: state)
            .scaleEffect(scale)
            .offset(x: reduceMotion ? 0 : geometry.x + (state == .waiting ? sin(geometry.y) * 140 : 0),
                    y: reduceMotion ? 0 : geometry.y + (state == .waiting ? cos(geometry.x) * 70 : 0))
            .animation(animation, value: state)
            .rotationEffect(.degrees(rotation))
            .animation(reduceMotion ? nil : state == .passed ? .linear(duration: 5) : animation, value: state)
            .accessibilityHidden(state == .waiting)
    }
}
