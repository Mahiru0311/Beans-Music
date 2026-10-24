import Foundation

// Native timing and geometry for Folia v0.7.16 classic/Visualizer.tsx.
// Animation state is derived from playback time so seeking works in both directions.
enum FoliaClassicIntensity: String, CaseIterable, Identifiable {
    case calm, normal, chaotic
    var id: String { rawValue }
    var title: String {
        switch self {
        case .calm: return "平静"
        case .normal: return "标准"
        case .chaotic: return "强烈"
        }
    }
    var breathingDuration: Double {
        switch self { case .calm: return 8.5; case .normal: return 6; case .chaotic: return 5 }
    }
    var breathingDistance: Double {
        switch self { case .calm: return 12; case .normal: return 20; case .chaotic: return 26 }
    }
}

enum FoliaClassicWordState: Equatable { case waiting, active, passed }
enum FoliaClassicJustification: Int { case start, center, end, around, between }

struct FoliaClassicWordGeometry: Equatable {
    let x: Double
    let y: Double
    let rotation: Double
    let scale: Double
    let passedRotation: Double
    let legacyMargin: Double
    // 0 = start, 1 = center, 2 = end, nil = inherit line alignment.
    let alignment: Int?
}

enum FoliaClassicMotion {
    static func clamp(_ value: Double, fallback: Double) -> Double {
        value.isFinite ? min(2, max(0, value)) : fallback
    }

    static func state(word: FoliaWord, time: Double) -> FoliaClassicWordState {
        guard time.isFinite, word.startTime.isFinite, word.endTime.isFinite else { return .waiting }
        if time < word.startTime - 0.15 { return .waiting }
        return time <= word.endTime ? .active : .passed
    }

    static func random(seed: Double, index: Int, offset: Int) -> Double {
        let value = sin(seed + Double(index + offset)) * 10000
        return value - floor(value)
    }

    static func geometry(seed: Double, index: Int, intensity: FoliaClassicIntensity,
                         rotationEnabled: Bool, interlude: Bool = false) -> FoliaClassicWordGeometry {
        let seed = seed.isFinite ? max(0, seed) : 0
        func random(_ offset: Int) -> Double { self.random(seed: seed, index: index, offset: offset) }
        if interlude {
            return FoliaClassicWordGeometry(x: 0, y: (random(2) - 0.5) * 15, rotation: 0,
                                             scale: 1.8, passedRotation: 0, legacyMargin: 48, alignment: 1)
        }
        let spread: Double = intensity == .chaotic ? 90 : intensity == .calm ? 0 : 36
        let rotate: Double = intensity == .chaotic ? 45 : intensity == .calm ? 0 : 12
        return FoliaClassicWordGeometry(
            x: (random(1) - 0.5) * spread * 2, y: (random(2) - 0.5) * spread * 2,
            rotation: rotationEnabled ? (random(3) - 0.5) * rotate * 2 : 0,
            scale: intensity == .chaotic ? 0.8 + random(4) * 0.8 : 1.15 + random(4) * 0.35,
            passedRotation: rotationEnabled ? (random(8) - 0.5) * 70 : 0,
            legacyMargin: intensity == .chaotic ? random(5) * 24 : 12.8,
            alignment: intensity == .chaotic && random(6) > 0.7 ? (random(7) > 0.5 ? 0 : 2) : nil
        )
    }

    static func justification(seed: Double, intensity: FoliaClassicIntensity, interlude: Bool) -> FoliaClassicJustification {
        guard intensity != .calm, !interlude, seed.isFinite else { return .center }
        return FoliaClassicJustification(rawValue: Int(floor(max(0, seed).truncatingRemainder(dividingBy: 5)))) ?? .center
    }

    static func alignment(seed: Double, intensity: FoliaClassicIntensity) -> Int {
        guard intensity != .calm, seed.isFinite else { return 1 }
        return Int(floor((max(0, seed) * 2).truncatingRemainder(dividingBy: 3)))
    }

    static func margin(width: Double, nextWidth: Double, geometry: FoliaClassicWordGeometry,
                       next: FoliaClassicWordGeometry?, fontSize: Double, intensity: FoliaClassicIntensity,
                       spacing: Double, legacy: Bool, interlude: Bool) -> Double {
        if legacy || interlude { return geometry.legacyMargin }
        let spacing = clamp(spacing, fallback: 0.7)
        let overflow = width * (geometry.scale * 1.4 - 1) / 2
        let nextOverflow = nextWidth * ((next?.scale ?? (1 / 1.4)) * 1.4 - 1) / 2
        let calculated = (overflow + nextOverflow + geometry.x - (next?.x ?? 0) + 0.05 * fontSize) * spacing
        let minimum = (intensity == .chaotic ? 0.08 : 0.12) * fontSize * spacing
        return (max(minimum, calculated) * 10).rounded() / 10
    }

    // The five upstream keyframes, interpolated with easeInOut per segment.
    static func breathing(elapsed: Double, intensity: FoliaClassicIntensity, multiplier: Double) -> (y: Double, scale: Double) {
        let multiplier = clamp(multiplier, fallback: 1)
        guard elapsed.isFinite, multiplier > 0 else { return (0, 1) }
        let position = max(0, elapsed).truncatingRemainder(dividingBy: intensity.breathingDuration) / intensity.breathingDuration * 4
        let segment = min(3, Int(position))
        let fraction = position - Double(segment)
        let ease = FoliaClassicEasing.value(fraction)
        let heights = [0.0, -1, 0, 0.45, 0]
        let scales = [1.0, 1 + 0.015 * multiplier, 1, 1 - 0.008 * multiplier, 1]
        return ((heights[segment] + (heights[segment + 1] - heights[segment]) * ease) * intensity.breathingDistance * multiplier,
                scales[segment] + (scales[segment + 1] - scales[segment]) * ease)
    }

    static func hasReadableText(_ text: String?) -> Bool {
        guard let text else { return false }
        return text.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }
}
