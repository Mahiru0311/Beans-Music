import XCTest
@testable import Beans

// Behavioral cases from Folia's shared runtime, including gaps and backwards seeks.
final class FoliaTimelineTests: XCTestCase {
    private let lines = [
        FoliaLine(id: "a", startTime: 1, endTime: 3, fullText: "first", translation: nil, romanization: nil, words: []),
        FoliaLine(id: "b", startTime: 5, endTime: 7, fullText: "second", translation: nil, romanization: nil, words: []),
        FoliaLine(id: "c", startTime: 10, endTime: 12, fullText: "third", translation: nil, romanization: nil, words: [])
    ]

    func testGapsAreNotActiveLines() {
        XCTAssertEqual(FoliaTimeline.activeIndex(lines: lines, time: 4), -1)
        XCTAssertEqual(FoliaTimeline.recentCompleted(lines: lines, activeIndex: -1, time: 4)?.id, "a")
    }

    func testUpcomingUsesArrayOrderWhileActive() {
        XCTAssertEqual(FoliaTimeline.upcomingLines(lines: lines, activeIndex: 0).map(\.id), ["b", "c"])
        XCTAssertTrue(FoliaTimeline.upcomingLines(lines: lines, activeIndex: -1).isEmpty)
        XCTAssertNil(FoliaTimeline.recentCompleted(lines: lines, activeIndex: 1, time: 6))
    }

    func testPreheatBoundsAndNilLine() {
        XCTAssertTrue(FoliaTimeline.shouldPreheat(lines[1], time: 4, minLead: 1, maxLead: 2))
        XCTAssertFalse(FoliaTimeline.shouldPreheat(lines[1], time: 6, minLead: 0, maxLead: 2))
        XCTAssertFalse(FoliaTimeline.shouldPreheat(nil, time: 4, minLead: 0, maxLead: 2))
    }

    func testStillHoldsDuringGapsAndAllowsBackwardsSeek() {
        XCTAssertEqual(FoliaTimeline.stillIndex(previous: 1, activeIndex: -1, lineCount: 3), 1)
        XCTAssertEqual(FoliaTimeline.stillIndex(previous: 2, activeIndex: 0, lineCount: 3), 0)
        XCTAssertEqual(FoliaTimeline.stillIndex(previous: 9, activeIndex: -1, lineCount: 3), 0)
    }

    func testInvalidTimeDoesNotProduceActiveIndex() {
        XCTAssertEqual(FoliaTimeline.activeIndex(lines: lines, time: .nan), -1)
        XCTAssertEqual(FoliaTimeline.activeIndex(lines: lines, time: -.infinity), -1)
    }
}
