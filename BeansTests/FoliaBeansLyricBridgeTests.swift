import XCTest
@testable import Beans

// Timing and identity must survive reparsing, duplicate words, and source changes.
final class FoliaBeansLyricBridgeTests: XCTestCase {
    func testRealWordTimingAndTranslationArePreserved() {
        let original = LyricLine(time: 1, text: "你好", translation: "hello", words: [
            LyricWord(text: "你", start: 1, duration: 0.3),
            LyricWord(text: "好", start: 1.3, duration: 0.5)
        ])
        let result = FoliaBeansLyricBridge.document(trackIdentity: "netease:1", lyrics: [original], duration: 20)
        XCTAssertEqual(result.lines[0].words.map(\.text), ["你", "好"])
        XCTAssertEqual(result.lines[0].endTime, 1.8, accuracy: 0.001)
        XCTAssertEqual(result.lines[0].translation, "hello")
        XCTAssertEqual(result.lines[0].fullText, "你好")
    }

    func testLRCDoesNotInventWordTimingAndIDsAreStable() {
        let a = FoliaBeansLyricBridge.document(trackIdentity: "local:one", lyrics: [LyricLine(time: 1, text: "line")], duration: 10)
        let b = FoliaBeansLyricBridge.document(trackIdentity: "local:one", lyrics: [LyricLine(time: 1, text: "line")], duration: 10)
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.lines[0].words.isEmpty)
        XCTAssertEqual(a.lines[0].endTime, 10)
    }

    func testUnsortedLinesAndDuplicateTimesKeepStableOrder() {
        let input = [LyricLine(time: 3, text: "later"), LyricLine(time: 1, text: "one"), LyricLine(time: 1, text: "translation")]
        let result = FoliaBeansLyricBridge.document(trackIdentity: "x", lyrics: input, duration: 9)
        XCTAssertEqual(result.lines.map(\.fullText), ["one", "translation", "later"])
        XCTAssertEqual(result.lines[0].endTime, 3)
    }
}
