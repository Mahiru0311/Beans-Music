import XCTest
@testable import Beans

final class FoliaClassicGlowTests: XCTestCase {
    func testExtendedGraphemesAndTimingBoundaries() {
        let word = FoliaWord(id: "x", text: "👨‍👩‍👧‍👦e\u{301}你", startTime: 2, endTime: 5)
        let glyphs = FoliaClassicGlow.glyphs(for: word)
        XCTAssertEqual(glyphs.map(\.text), ["👨‍👩‍👧‍👦", "e\u{301}", "你"])
        XCTAssertEqual(glyphs.map(\.startTime), [2, 3, 4])
        XCTAssertEqual(glyphs.map(\.endTime), [3, 4, 5])
    }

    func testGlyphSweepStartsInOrderAndFadesAfterWord() {
        let word = FoliaWord(id: "x", text: "abcd", startTime: 2, endTime: 4)
        let glyphs = FoliaClassicGlow.glyphs(for: word)
        func level(_ index: Int, _ time: Double) -> Double {
            FoliaClassicGlow.level(glyph: glyphs[index], word: word, glyphCount: glyphs.count, time: time)
        }
        XCTAssertEqual(level(0, 1), 0)
        XCTAssertGreaterThan(level(0, 2.2), 0)
        XCTAssertEqual(level(1, 2.2), 0)
        XCTAssertEqual(level(0, 2.75), 1, accuracy: 0.00001)
        XCTAssertGreaterThan(level(3, 4), 0)
        XCTAssertLessThan(level(3, 4.4), level(3, 4))
        XCTAssertEqual(level(3, 5), 0, accuracy: 0.00001)
        XCTAssertEqual(level(0, 1), 0) // backward seek resets without retained animation state
    }

    func testSingleGlyphSustainsAndDisabledInputDoesNotGlow() {
        let word = FoliaWord(id: "x", text: "你", startTime: 2, endTime: 3)
        let glyph = FoliaClassicGlow.glyphs(for: word)[0]
        XCTAssertEqual(FoliaClassicGlow.level(glyph: glyph, word: word, glyphCount: 1, time: 2.9), 1, accuracy: 0.00001)
        XCTAssertEqual(FoliaClassicGlow.level(glyph: glyph, word: word, glyphCount: 1, time: .nan), 0)
        XCTAssertTrue(FoliaClassicGlow.glyphs(for: FoliaWord(id: "empty", text: "", startTime: 0, endTime: 0)).isEmpty)
    }
}
