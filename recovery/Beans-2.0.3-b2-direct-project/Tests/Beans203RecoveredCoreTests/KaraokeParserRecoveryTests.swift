import Foundation
import XCTest
@testable import Beans203RecoveredCore

final class KaraokeParserRecoveryTests: XCTestCase {
    func testParenthesizedAbsoluteTimingAndPrefixText() {
        let result = LyricParser_2_0_3.parseKaraoke("[1000,1000](1000,250,0)你(1250,750)好", syntax: .parenthesizedAbsolute)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].time, 1)
        XCTAssertEqual(result[0].text, "你好")
        XCTAssertEqual(result[0].words?.map { $0.text }, ["你", "好"])
        XCTAssertEqual(result[0].words?.map { $0.start }, [1, 1.25])
        XCTAssertEqual(result[0].words?.map { $0.duration }, [0.25, 0.75])
    }

    func testAutomaticModeRecognizesPostfixTagsAndDiscardsTrailingText() {
        let result = LyricParser_2_0_3.parseKaraoke("[1000,1000]你(1000,250)好(1250,750)ignored", syntax: .parenthesizedAutomatic)
        XCTAssertEqual(result[0].text, "你好")
        XCTAssertEqual(result[0].words?.map { $0.start }, [1, 1.25])
    }

    func testAutomaticModeWithLeadingTagKeepsPrefixLayout() {
        let result = LyricParser_2_0_3.parseKaraoke("[1000,1000](1000,250)你(1250,750)好", syntax: .parenthesizedAutomatic)
        XCTAssertEqual(result[0].text, "你好")
    }

    func testAbsoluteModeDoesNotInferPostfixLayout() {
        let result = LyricParser_2_0_3.parseKaraoke("[1000,1000]discard(1000,250)keep(1250,750)tail", syntax: .parenthesizedAbsolute)
        XCTAssertEqual(result[0].text, "keeptail")
    }

    func testAngleModeUsesLineRelativeWordOffsets() {
        let result = LyricParser_2_0_3.parseKaraoke("[2000,1000]<0,250,0>你<250,750>好", syntax: .angleRelative)
        XCTAssertEqual(result[0].time, 2)
        XCTAssertEqual(result[0].words?.map { $0.start }, [2, 2.25])
    }

    func testOffsetClampsLineTimeButNotNegativeWordTime() {
        let result = LyricParser_2_0_3.parseKaraoke("""
        [offset:-2000]
        [1000,1000]<0,0>text
        """, syntax: .angleRelative)
        XCTAssertEqual(result[0].time, 0)
        XCTAssertEqual(result[0].words?.first?.start, -1)
        XCTAssertEqual(result[0].words?.first?.duration, 0.001)
    }

    func testTextWhitespaceAndEmojiAreRetainedWithUTF16Spans() {
        let result = LyricParser_2_0_3.parseKaraoke("[0,1000](0,500)💛 (500,500) 中文 " , syntax: .parenthesizedAbsolute)
        XCTAssertEqual(result[0].text, "💛  中文 ")
        XCTAssertEqual(result[0].words?.map { $0.text }, ["💛 ", " 中文 "])
    }

    func testNoTimingTagsSkipsLineEvenWithPositiveHeaderDuration() {
        XCTAssertTrue(LyricParser_2_0_3.parseKaraoke("[0,1000]plain", syntax: .angleRelative).isEmpty)
        XCTAssertTrue(LyricParser_2_0_3.parseKaraoke("<0,1000>text", syntax: .angleRelative).isEmpty)
    }

    func testPositiveDurationEmptyWordBecomesSpaceWithoutWordArray() {
        let result = LyricParser_2_0_3.parseKaraoke("[0,1000]<0,1000>", syntax: .angleRelative)
        XCTAssertEqual(result[0].text, " ")
        XCTAssertNil(result[0].words)
        XCTAssertTrue(LyricParser_2_0_3.parseKaraoke("[0,0]<0,1000>", syntax: .angleRelative).isEmpty)
    }

    func testWhitespaceOnlyWordRetainsItsWordArray() {
        let result = LyricParser_2_0_3.parseKaraoke("[0,1000]<0,1000> " , syntax: .angleRelative)
        XCTAssertEqual(result[0].text, " ")
        XCTAssertEqual(result[0].words?.count, 1)
    }

    func testHeaderIsUnanchoredAndLinesSortByTime() {
        let result = LyricParser_2_0_3.parseKaraoke("""
        ignored[2000,10]<0,10>later
        [1000,10]<0,10>earlier
        """, syntax: .angleRelative)
        XCTAssertEqual(result.map { $0.text }, ["earlier", "later"])
    }

    func testCombinedParserUsesKaraokeWhenLRCIsAbsentThenAddsTranslation() {
        let result = LyricParser_2_0_3.parse(lrc: "", translation: "[00:01]译文",
                                           karaoke: "[1000,100]<0,100>original", syntax: .angleRelative)
        XCTAssertEqual(result.first?.text, "original")
        XCTAssertEqual(result.first?.translation, "译文")
        XCTAssertEqual(result.first?.words?.count, 1)
    }

    func testCombinedParserKeepsOriginalTimeAndTextWhileAttachingWords() {
        let result = LyricParser_2_0_3.parse(lrc: "[00:01]你 好", karaoke: "[1100,100]<0,50>你<50,50>好", syntax: .angleRelative)
        XCTAssertEqual(result[0].time, 1)
        XCTAssertEqual(result[0].text, "你 好")
        XCTAssertEqual(result[0].words?.count, 2)
    }

    func testKaraokeMatchingIsCaseAndPunctuationSensitive() {
        var lines = [LyricLine_2_0_3(time: 1, text: "word!"), LyricLine_2_0_3(time: 1, text: "WORD")]
        let karaoke = [LyricLine_2_0_3(time: 1, text: "word", words: [LyricWord_2_0_3(text: "word")])]
        LyricParser_2_0_3.attachKaraoke(karaoke, to: &lines)
        XCTAssertTrue(lines.allSatisfy { $0.words == nil })
    }

    func testKaraokeMatchingConsumesCandidateAndChoosesNearestWithFirstTie() {
        let first = LyricWord_2_0_3(text: "first")
        let second = LyricWord_2_0_3(text: "second")
        var lines = [LyricLine_2_0_3(time: 1, text: "same"),
                     LyricLine_2_0_3(time: 1, text: "same"), LyricLine_2_0_3(time: 1, text: "same")]
        let timed = [LyricLine_2_0_3(time: 0.75, text: "same", words: [first]),
                     LyricLine_2_0_3(time: 1.25, text: "same", words: [second])]
        LyricParser_2_0_3.attachKaraoke(timed, to: &lines)
        XCTAssertEqual(lines[0].words?.first?.text, "first")
        XCTAssertEqual(lines[1].words?.first?.text, "second")
        XCTAssertNil(lines[2].words)
    }

    func testKaraokeMatchingUsesStrictToleranceAndRejectsEmptyNormalizedText() {
        var lines = [LyricLine_2_0_3(time: 0, text: "same"), LyricLine_2_0_3(time: 0, text: "  ")]
        let timed = [LyricLine_2_0_3(time: 0.35, text: "same", words: []), LyricLine_2_0_3(time: 0, text: "  ", words: [])]
        LyricParser_2_0_3.attachKaraoke(timed, to: &lines)
        XCTAssertTrue(lines.allSatisfy { $0.words == nil })
    }
}
