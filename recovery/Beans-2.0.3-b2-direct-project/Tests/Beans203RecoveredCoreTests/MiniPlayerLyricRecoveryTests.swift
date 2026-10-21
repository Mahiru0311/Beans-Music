import Foundation
import XCTest
@testable import Beans203RecoveredCore

final class MiniPlayerLyricRecoveryTests: XCTestCase {
    private func model(_ pairs: [(Double, String)], artist: String = "artist") -> MiniPlayerLyricLine_2_0_3 {
        var result = MiniPlayerLyricLine_2_0_3()
        result.lyrics = pairs.map { LyricLine_2_0_3(time: $0.0, text: $0.1) }
        result.artist = artist
        return result
    }

    func testEmptyLyricsDisplayArtist() {
        XCTAssertEqual(model([]).displayedText(progress: 100), "artist")
        XCTAssertEqual(model([], artist: "").displayedText(progress: 0), "")
    }

    func testBeforeFirstTimestampDisplaysArtist() {
        XCTAssertEqual(model([(1, "line")]).displayedText(progress: 0.99), "artist")
    }

    func testExactTimestampActivatesLineAndAfterLastKeepsLastLine() {
        let value = model([(1, "one"), (2, "two"), (3, "three")])
        XCTAssertEqual(value.displayedText(progress: 1), "one")
        XCTAssertEqual(value.displayedText(progress: 2.5), "two")
        XCTAssertEqual(value.displayedText(progress: 100), "three")
    }

    func testDuplicateTimestampsChooseLastEqualLine() {
        XCTAssertEqual(model([(1, "first"), (1, "second"), (1, "third")]).displayedText(progress: 1), "third")
    }

    func testPositiveOffsetAdvancesAndNegativeOffsetDelaysSelection() {
        let value = model([(1, "one"), (2, "two")])
        XCTAssertEqual(value.displayedText(progress: 1, lyricOffset: 1), "two")
        XCTAssertEqual(value.displayedText(progress: 1, lyricOffset: -0.01), "artist")
    }

    func testNegativeAndUnorderedTimeClampToZero() {
        let value = model([(0, "zero"), (1, "one")])
        XCTAssertEqual(value.displayedText(progress: -10), "zero")
        XCTAssertEqual(value.displayedText(progress: .nan), "zero")
        XCTAssertEqual(value.displayedText(progress: 1, lyricOffset: .nan), "zero")
        XCTAssertEqual(value.displayedText(progress: .infinity, lyricOffset: -.infinity), "zero")
    }

    func testPositiveInfinitySelectsLastFiniteLine() {
        XCTAssertEqual(model([(1, "one"), (2, "two")]).displayedText(progress: .infinity), "two")
    }

    func testEmptySelectedTextDoesNotFallBackToArtist() {
        XCTAssertEqual(model([(0, "")]).displayedText(progress: 5), "")
        XCTAssertEqual(model([(0, " ")]).displayedText(progress: 5), " ")
    }

    func testDisplaysOriginalTextInsteadOfTranslationOrWords() {
        var value = model([])
        value.lyrics = [LyricLine_2_0_3(time: 0, text: "original", translation: "translated",
                                      words: [LyricWord_2_0_3(text: "word")])]
        XCTAssertEqual(value.displayedText(progress: 0), "original")
    }

    func testPreservesInputOrderRatherThanSortingInDisplayPath() {
        let value = model([(10, "first in input"), (0, "second in input"), (5, "third")])
        XCTAssertEqual(value.displayedText(progress: 1), "second in input")
    }

    func testNaNTimestampDoesNotQualify() {
        XCTAssertEqual(model([(.nan, "invalid")]).displayedText(progress: 100), "artist")
    }

    func testInlineFlagDoesNotChangeTextSelection() {
        var value = model([(0, "line")])
        value.isInline = true
        XCTAssertEqual(value.displayedText(progress: 1), "line")
        value.isInline = false
        XCTAssertEqual(value.displayedText(progress: 1), "line")
    }
}
