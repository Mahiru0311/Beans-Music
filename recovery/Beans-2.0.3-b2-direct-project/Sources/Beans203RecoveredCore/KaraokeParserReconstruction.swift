import Foundation

/// Descriptive reconstruction names for the byte tags tested by 0x100332514.
/// Cache tables map tags 0/1/2 to neteaseYRC/qqQRC/kugouKRC; descriptive case names are retained.
public enum KaraokeSyntax_2_0_3: Int {
    case parenthesizedAbsolute = 0
    case parenthesizedAutomatic = 1
    case angleRelative = 2
}

extension LyricParser_2_0_3 {
    static let karaokeHeaderPattern = #"\[(\d+),(\d+)\]"#
    static let parenthesesWordPattern = #"\((\d+),(\d+)(?:,\d+)?\)"#
    static let angleWordPattern = #"<(\d+),(\d+)(?:,\d+)?>"#

    /// 0x100332514: millisecond headers, per-word spans and provider format switches.
    public static func parseKaraoke(_ text: String, syntax: KaraokeSyntax_2_0_3) -> [LyricLine_2_0_3] {
        let offset = offsetSeconds(in: text)
        let wordPattern = syntax == .angleRelative ? angleWordPattern : parenthesesWordPattern
        guard let headerRegex = try? NSRegularExpression(pattern: karaokeHeaderPattern),
              let wordRegex = try? NSRegularExpression(pattern: wordPattern) else { return [] }
        var result: [LyricLine_2_0_3] = []
        for raw in text.components(separatedBy: .newlines) {
            guard let header = headerRegex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
                  let startRange = Range(header.range(at: 1), in: raw),
                  let durationRange = Range(header.range(at: 2), in: raw),
                  let startMS = Double(raw[startRange]), let durationMS = Double(raw[durationRange]),
                  let headerRange = Range(header.range, in: raw) else { continue }
            let body = String(raw[headerRange.upperBound...])
            let matches = wordRegex.matches(in: body, range: NSRange(body.startIndex..., in: body))
            guard let first = matches.first else { continue }
            let postfix = syntax == .parenthesizedAutomatic && first.range.location > 0
            let lineStart = startMS * 0.001
            var words: [LyricWord_2_0_3] = []
            for (index, match) in matches.enumerated() {
                guard let wordStartRange = Range(match.range(at: 1), in: body),
                      let wordDurationRange = Range(match.range(at: 2), in: body),
                      let wordStartMS = Double(body[wordStartRange]),
                      let wordDurationMS = Double(body[wordDurationRange]) else { continue }
                let lower: Int
                let upper: Int
                if postfix {
                    lower = index == 0 ? 0 : NSMaxRange(matches[index - 1].range)
                    upper = match.range.location
                } else {
                    lower = NSMaxRange(match.range)
                    upper = index + 1 < matches.count ? matches[index + 1].range.location : body.utf16.count
                }
                guard upper >= lower, let contentRange = Range(NSRange(location: lower, length: upper - lower), in: body) else { continue }
                let wordTime = syntax == .angleRelative ? lineStart + wordStartMS * 0.001 : wordStartMS * 0.001
                let duration = wordDurationMS * 0.001
                words.append(LyricWord_2_0_3(text: String(body[contentRange]), start: offset + wordTime,
                                           duration: duration > 0.001 ? duration : 0.001))
            }
            let content = words.map { $0.text }.joined()
            let shifted = offset + lineStart
            let time = shifted >= 0 ? shifted : 0
            if !content.isEmpty {
                result.append(LyricLine_2_0_3(time: time, text: content, words: words))
            } else if durationMS > 0 {
                // Recovered positive-duration blank line is one space, with nil word data.
                result.append(LyricLine_2_0_3(time: time, text: " "))
            }
        }
        return result.sorted { $0.time < $1.time }
    }

    /// 0x100327ed0: preserve plain LRC lines and attach matching karaoke word arrays.
    public static func parse(
        lrc: String, translation: String? = nil,
        karaoke: String? = nil, syntax: KaraokeSyntax_2_0_3? = nil
    ) -> [LyricLine_2_0_3] {
        var lines = parseLRC(lrc, offsetSeconds: offsetSeconds(in: lrc))
        if let karaoke, let syntax {
            let timed = parseKaraoke(karaoke, syntax: syntax)
            if !timed.isEmpty {
                if lines.isEmpty { lines = timed }
                else { attachKaraoke(timed, to: &lines) }
            }
        }
        applyTranslation(translation, to: &lines)
        return lines
    }

    /// Whitespace-only normalization via 0x10033b594; no case/punctuation folding.
    static func attachKaraoke(_ karaoke: [LyricLine_2_0_3], to lines: inout [LyricLine_2_0_3]) {
        let normalized = karaoke.map { $0.text.filter { !$0.isWhitespace } }
        var used = Set<Int>()
        for index in lines.indices {
            let content = lines[index].text.filter { !$0.isWhitespace }
            guard !content.isEmpty else { continue }
            let time = lines[index].time
            var nearest: Int?
            for candidate in karaoke.indices {
                guard !used.contains(candidate), normalized[candidate] == content,
                      abs(karaoke[candidate].time - time) < 0.35 else { continue }
                if let previous = nearest {
                    if abs(karaoke[candidate].time - time) < abs(karaoke[previous].time - time) { nearest = candidate }
                } else { nearest = candidate }
            }
            if let nearest {
                lines[index].words = karaoke[nearest].words
                used.insert(nearest)
            }
        }
    }
}
