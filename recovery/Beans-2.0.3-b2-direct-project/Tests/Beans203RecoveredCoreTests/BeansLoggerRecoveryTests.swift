import XCTest
@testable import Beans203RecoveredCore

final class BeansLoggerRecoveryTests: XCTestCase {
    func testRecoveredLogEntryShapeUsesUUIDDateAndContext() throws {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 10)
        let resources = BeansResourceSnapshot_2_0_3(
            memoryBytes: 2048,
            cpuPercent: 12.5,
            sampledAt: date,
            available: true
        )
        let entry = BeansLogEntry_2_0_3(
            id: id,
            date: date,
            level: .warn,
            message: "slow",
            module: "player",
            file: "Player.swift",
            function: "load",
            sourceLine: 42,
            threadID: 7,
            isMainThread: true,
            device: "iPhone",
            resources: resources,
            context: ["song": "demo"]
        )

        XCTAssertEqual(entry.id, id)
        XCTAssertEqual(entry.level, .warn)
        XCTAssertEqual(entry.context["song"], "demo")
        XCTAssertEqual(entry.resources.cpuPercent, 12.5)
        XCTAssertTrue(entry.isMainThread)
    }

    func testLoggerStartsWithConcreteCollectionsAndFileState() {
        let logger = BeansLogger_2_0_3()

        XCTAssertTrue(logger.entries.isEmpty)
        XCTAssertTrue(logger.snapshot.isEmpty)
        XCTAssertTrue(logger.recent.isEmpty)
        XCTAssertNil(logger.handle)
        XCTAssertNil(logger.activeURL)
        XCTAssertNil(logger.lastPrune)
    }
}
