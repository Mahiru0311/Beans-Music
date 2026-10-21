import Foundation
import XCTest
@testable import Beans203RecoveredCore

final class LyricParserRecoveryTests: XCTestCase {
    func testNoTimestampsProducesNoLines() {
        for text in ["", "plain words", "[ar:Singer][ti:Song]", "[offset:100]"] {
            XCTAssertTrue(LyricParser_2_0_3.parseLRC(text).isEmpty)
        }
    }

    func testAllFractionLengthsAndColonSeparator() {
        let parsed = LyricParser_2_0_3.parseLRC("[1:02][01:02.3][001:02.34][001:02:345] words ")
        XCTAssertEqual(parsed.map { $0.time }, [62, 62.3, 62.34, 62.345])
        XCTAssertEqual(parsed.map { $0.text }, Array(repeating: "words", count: 4))
    }

    func testTimestampMayAppearInsideTextAndAllRecognizedTagsAreRemoved() {
        let parsed = LyricParser_2_0_3.parseLRC("前[00:03]中[00:01]后")
        XCTAssertEqual(parsed.map { $0.time }, [1, 3])
        XCTAssertEqual(parsed.map { $0.text }, ["前中后", "前中后"])
    }

    func testMetadataAndMalformedTimestampTextAreNotStripped() {
        let parsed = LyricParser_2_0_3.parseLRC("[ar:Singer][00:01][0:2][1000:02][01:02.1234] words")
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].text, "[ar:Singer][0:2][1000:02][01:02.1234] words")
    }

    func testSecondsAreNotRestrictedToClockRange() {
        let parsed = LyricParser_2_0_3.parseLRC("[999:99]word")
        XCTAssertEqual(parsed.first?.time, 60039)
    }

    func testPositiveOffsetIsAddedAndFirstMatchingTagWins() {
        let text = "[offset:+1500][offset:-500][00:01]word"
        XCTAssertEqual(LyricParser_2_0_3.offsetSeconds(in: text), 1.5)
        let parsed = LyricParser_2_0_3.parseLRC(text)
        XCTAssertEqual(parsed.first?.time, 2.5)
        XCTAssertEqual(parsed.first?.text, "[offset:+1500][offset:-500]word")
    }

    func testOffsetTagIsCaseSensitiveAndRejectsSpacesAndFractions() {
        for tag in ["[OFFSET:1000]", "[offset: 1000]", "[offset:1.5]"] {
            XCTAssertEqual(LyricParser_2_0_3.offsetSeconds(in: tag), 0)
        }
    }

    func testNegativeOffsetClampsToZeroAndKeepsEqualTimeOrder() {
        let text = """
        [offset:-2000]
        [00:01]first
        [00:00]second
        [00:05]last
        """
        let parsed = LyricParser_2_0_3.parseLRC(text)
        XCTAssertEqual(parsed.map { $0.time }, [0, 0, 3])
        XCTAssertEqual(parsed.map { $0.text }, ["first", "second", "last"])
    }

    func testRepeatedTimestampsAreNotDeduplicatedAndReceiveDistinctUUIDs() {
        let parsed = LyricParser_2_0_3.parseLRC("[00:01][00:01]same")
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(Set(parsed.map { $0.id }).count, 2)
        XCTAssertTrue(parsed.allSatisfy { $0.translation == nil && $0.words == nil })
    }

    func testEmptyTimedTextRemainsAValidLine() {
        let parsed = LyricParser_2_0_3.parseLRC("[00:00]   ")
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].text, "")
    }

    func testUnicodeContentAndFoundationNewlineSeparators() {
        let separator = String(UnicodeScalar(0x2028)!)
        let text = "[00:02]  中文💛  " + separator + "[00:01]café"
        let parsed = LyricParser_2_0_3.parseLRC(text)
        XCTAssertEqual(parsed.map { $0.text }, ["café", "中文💛"])
        XCTAssertEqual(parsed.map { $0.time }, [1, 2])
    }

    func testUnicodeDigitMatchesUseNumericConversionFallback() {
        let parsed = LyricParser_2_0_3.parseLRC("[١:٠٢]word")
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].time, 0)
    }

    func testUnorderedShiftUsesBinaryZeroBranch() {
        let parsed = LyricParser_2_0_3.parseLRC("[00:01]word", offsetSeconds: .nan)
        XCTAssertEqual(parsed.first?.time, 0)
    }
}
