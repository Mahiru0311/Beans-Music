import Foundation

struct FoliaGlyphTiming: Identifiable, Equatable {
    let id: Int
    let text: String
    let startTime: Double
    let endTime: Double
}

enum FoliaClassicEasing {
    // CSS/framer easeInOut and easeOut curves. Solve x before evaluating y.
    static func value(_ progress: Double, easeOut: Bool = false) -> Double {
        let progress = min(1, max(0, progress))
        let x1 = easeOut ? 0.0 : 0.42
        let x2 = 0.58
        var low = 0.0, high = 1.0
        for _ in 0..<20 {
            let t = (low + high) / 2
            let x = 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t
            if x < progress { low = t } else { high = t }
        }
        let t = (low + high) / 2
        return 3 * (1 - t) * t * t + t * t * t
    }
}

enum FoliaClassicGlow {
    // Same fallback as Folia's buildWordGraphemeTimings: split a genuinely timed
    // word evenly into extended graphemes. These are display times, not new parser words.
    static func glyphs(for word: FoliaWord) -> [FoliaGlyphTiming] {
        let characters = Array(word.text).map(String.init)
        guard !characters.isEmpty, word.startTime.isFinite, word.endTime.isFinite else { return [] }
        let duration = max(0, word.endTime - word.startTime)
        return characters.enumerated().map { index, text in
            FoliaGlyphTiming(id: index, text: text,
                             startTime: word.startTime + duration * Double(index) / Double(characters.count),
                             endTime: index == characters.count - 1 ? word.endTime : word.startTime + duration * Double(index + 1) / Double(characters.count))
        }
    }

    static func level(glyph: FoliaGlyphTiming, word: FoliaWord, glyphCount: Int, time: Double) -> Double {
        guard time.isFinite, word.startTime.isFinite, word.endTime.isFinite else { return 0 }
        let activation = word.startTime - 0.15
        guard time >= activation else { return 0 }
        func activeLevel(_ sample: Double) -> Double {
            if glyphCount <= 1 {
                let duration = max(0.1, word.endTime - word.startTime)
                return FoliaClassicEasing.value((sample - activation) / (duration * 0.9))
            }
            let onset = activation + max(0, glyph.startTime - word.startTime)
            let duration = max(0.001, glyph.endTime - glyph.startTime) * 6
            let position = (sample - onset) / duration
            guard position > 0, position < 1 else { return 0 }
            if position <= 0.3 { return FoliaClassicEasing.value(position / 0.3) }
            return 1 - FoliaClassicEasing.value((position - 0.3) / 0.7)
        }
        if time <= word.endTime { return activeLevel(time) }
        return activeLevel(word.endTime) * (1 - FoliaClassicEasing.value((time - word.endTime) / 0.9, easeOut: true))
    }
}
