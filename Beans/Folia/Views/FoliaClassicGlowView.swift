import SwiftUI
import UIKit

struct FoliaClassicGlowView: View {
    let word: FoliaWord
    let time: Double
    let fontSize: Double
    let color: Color
    @State private var measured: [Glyph] = []

    private struct MeasurementKey: Hashable { let text: String; let fontSize: Double; let start: Double; let end: Double }
    private struct Glyph: Identifiable {
        let timing: FoliaGlyphTiming
        let x: CGFloat
        let width: CGFloat
        let totalWidth: CGFloat
        var id: Int { timing.id }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(measured) { glyph in
                    let level = FoliaClassicGlow.level(glyph: glyph.timing, word: word, glyphCount: measured.count, time: time)
                    Text(glyph.timing.text).font(.system(size: fontSize, weight: .bold)).fixedSize()
                        .foregroundStyle(color)
                        .shadow(color: color, radius: 20 * level)
                        .shadow(color: color, radius: 40 * level)
                        .opacity(level)
                        .position(x: (geometry.size.width - glyph.totalWidth) / 2 + glyph.x + glyph.width / 2,
                                  y: geometry.size.height / 2)
                }
            }
        }
        .task(id: MeasurementKey(text: word.text, fontSize: fontSize, start: word.startTime, end: word.endTime)) { measure() }
        .transaction { $0.animation = nil }
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    private func measure() {
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: CGFloat(fontSize))]
        let total = (word.text as NSString).size(withAttributes: attributes).width
        var prefix = ""
        measured = FoliaClassicGlow.glyphs(for: word).map { timing in
            let x = (prefix as NSString).size(withAttributes: attributes).width
            prefix += timing.text
            return Glyph(timing: timing, x: x, width: (timing.text as NSString).size(withAttributes: attributes).width, totalWidth: total)
        }
    }
}
