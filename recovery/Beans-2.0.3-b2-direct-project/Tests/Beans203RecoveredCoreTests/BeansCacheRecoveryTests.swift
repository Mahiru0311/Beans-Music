import XCTest
@testable import Beans203RecoveredCore

final class BeansCacheRecoveryTests: XCTestCase {
    func testRecoveredCacheCategoriesAndUsageKeepTheDecodedShape() {
        XCTAssertEqual(BeansCacheCategory_2_0_3.allCases.count, 7)
        let usage = BeansCacheUsage_2_0_3(
            category: .lyrics,
            diskBytes: 4096,
            memoryBytes: 128
        )

        XCTAssertEqual(usage.category, .lyrics)
        XCTAssertEqual(usage.diskBytes, 4096)
        XCTAssertEqual(usage.memoryBytes, 128)
    }

    func testCacheManagerPublishedStateStartsEmptyAndIdle() {
        let manager = BeansCacheManager_2_0_3()

        XCTAssertTrue(manager.usage.isEmpty)
        XCTAssertFalse(manager.working)
        XCTAssertNil(manager.message)
    }
}
