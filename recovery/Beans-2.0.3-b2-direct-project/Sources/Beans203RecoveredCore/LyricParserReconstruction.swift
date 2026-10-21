import Foundation

/// Plain LRC path reconstructed from the supplied 2.0.3 build 2 executable.
/// Karaoke parsing and its line-merging path remain separate recovery work.
public enum LyricParser_2_0_3 {
    // Exact UTF-8 literals at file offsets 0x79a050, 0x7aa290 and 0x7aa2c0.
    static let offsetPattern = #"\[offset:([+-]?\d+)\]"#
    static let timestampPattern = #"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"#
    static let timestampRemovalPattern = #"\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\]"#

    /// Offset prelude of 0x100327ed0 followed by the plain path 0x100331fac.
    public static func parseLRC(_ text: String, translation: String? = nil) -> [LyricLine_2_0_3] {
        var lines = parseLRC(text, offsetSeconds: offsetSeconds(in: text))
        applyTranslation(translation, to: &lines)
        return lines
    }

    /// First case-sensitive offset tag; milliseconds are added to each timestamp.
    static func offsetSeconds(in text: String) -> Double {
        guard let expression = try? NSRegularExpression(pattern: offsetPattern),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text),
              let milliseconds = Double(text[range]) else { return 0 }
        return milliseconds / 1000
    }

    /// 0x100331fac with enumeration callback 0x1003339f8 (thunk 0x100339908).
    static func parseLRC(_ text: String, offsetSeconds: Double) -> [LyricLine_2_0_3] {
        guard let expression = try? NSRegularExpression(pattern: timestampPattern) else { return [] }
        var lines: [LyricLine_2_0_3] = []
        for raw in text.components(separatedBy: .newlines) {
            let matches = expression.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))
            guard !matches.isEmpty else { continue }
            let content = raw.replacingOccurrences(of: timestampRemovalPattern, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            for match in matches {
                guard let minuteRange = Range(match.range(at: 1), in: raw),
                      let secondRange = Range(match.range(at: 2), in: raw) else { continue }
                let minutes = Double(raw[minuteRange]) ?? 0
                let seconds = Double(raw[secondRange]) ?? 0
                var fraction: Double = 0
                if let fractionRange = Range(match.range(at: 3), in: raw) {
                    let digits = String(raw[fractionRange])
                    fraction = (Double(digits) ?? 0) / pow(10, Double(max(1, digits.count)))
                }
                let shifted = minutes * 60 + seconds + fraction + offsetSeconds
                // ARM64 FCSEL GE chooses zero for both negative and unordered values.
                lines.append(LyricLine_2_0_3(time: shifted >= 0 ? shifted : 0, text: content))
            }
        }
        // 0x100327b14 -> 0x1003355b0; comparator at 0x100335bdc.
        return lines.sorted { $0.time < $1.time }
    }

    /// 0x1003335d0: nearest translated line, strict 0.35-second tolerance.
    static func applyTranslation(_ text: String?, to lines: inout [LyricLine_2_0_3]) {
        guard let text, !text.isEmpty else { return }
        let translations = parseLRC(text, offsetSeconds: offsetSeconds(in: text))
        guard let first = translations.first else { return }
        for index in lines.indices {
            let time = lines[index].time
            var nearest = first
            for candidate in translations.dropFirst() {
                if abs(candidate.time - time) < abs(nearest.time - time) { nearest = candidate }
            }
            // A nearest empty line blocks further candidates; matches are not consumed.
            if abs(nearest.time - time) < 0.35, !nearest.text.isEmpty {
                lines[index].translation = nearest.text
            }
        }
    }
}
