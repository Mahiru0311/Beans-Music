import XCTest
@testable import Beans

// A renderer must never claim equivalence merely by registering another mode's name.
final class FoliaModeCatalogTests: XCTestCase {
    func testRegistryContainsAllDistinctUpstreamModes() {
        XCTAssertEqual(FoliaVisualizerMode.allCases.count, 14)
        XCTAssertEqual(Set(FoliaVisualizerMode.allCases.map(\.rawValue)).count, 14)
        XCTAssertEqual(FoliaBackgroundMode.allCases.count, 6)
        XCTAssertEqual(FoliaVisualizerMode.ordered.first, .sonnet)
    }

    func testUnimplementedModesAreNotSilentlyReplaced() {
        XCTAssertEqual(FoliaPreferences.availableMode(rawValue: "classic"), .classic)
        XCTAssertEqual(FoliaVisualizerMode.classic.portStatus, .draft)
        XCTAssertNil(FoliaPreferences.availableMode(rawValue: "sonnet"))
        XCTAssertNil(FoliaPreferences.availableMode(rawValue: "mod:example:lyrics"))
        XCTAssertEqual(FoliaPreferences.availableMode(rawValue: "still"), .still)
        XCTAssertFalse(FoliaVisualizerMode.allCases.contains { $0.portStatus == .verified })
    }
}
