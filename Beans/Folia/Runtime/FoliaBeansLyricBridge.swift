import Foundation

// Adapts the existing Beans parser output; no second player or invented word timestamps.
enum FoliaBeansLyricBridge {
    static func document(trackIdentity: String, lyrics: [LyricLine], duration: Double) -> FoliaLyricDocument {
        let sorted = lyrics.enumerated().sorted {
            $0.element.time == $1.element.time ? $0.offset < $1.offset : $0.element.time < $1.element.time
        }
        let lines = sorted.enumerated().map { index, entry -> FoliaLine in
            let line = entry.element
            let start = line.time.isFinite ? max(0, line.time) : 0
            let nextStart = sorted.dropFirst(index + 1).first { $0.element.time > start }?.element.time
            let validDuration = duration.isFinite ? max(0, duration) : 0
            let words = (line.words ?? []).enumerated().compactMap { wordIndex, word -> FoliaWord? in
                guard word.start.isFinite, word.duration.isFinite, word.duration >= 0 else { return nil }
                return FoliaWord(id: "\(index):\(wordIndex)", text: word.text,
                                 startTime: max(0, word.start), endTime: max(0, word.start + word.duration))
            }
            // LRC has no explicit end. Infer only the line endpoint, preserving genuine word endpoints.
            let inferredEnd = nextStart ?? (validDuration > start ? validDuration : start + 5)
            let end = max(start, words.map(\.endTime).max() ?? inferredEnd)
            return FoliaLine(id: "\(trackIdentity):\(index)", startTime: start, endTime: end,
                             fullText: line.text, translation: line.translation, romanization: nil, words: words)
        }
        return FoliaLyricDocument(trackIdentity: trackIdentity, lines: lines)
    }
}
