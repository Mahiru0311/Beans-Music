import XCTest
@testable import Beans203RecoveredCore

final class APIModelRecoveryTests: XCTestCase {
    func testNetEasePersonalFMCacheUsesRecoveredSongArray() {
        let api = NetEaseAPI_2_0_3()
        api.personalFMCache = [Song_2_0_3(id: 4, name: "FM")]
        api.personalFMCacheDate = Date(timeIntervalSince1970: 4)

        XCTAssertEqual(api.personalFMCache.first?.id, 4)
        XCTAssertEqual(api.personalFMCacheDate.timeIntervalSince1970, 4)
    }

    func testChangelogRemoteLogsUseRecoveredVersionLogArray() {
        var view = ChangelogListView_2_0_3()
        view.__remoteLogs = [VersionLog_2_0_3(id: "v1", version: "2.0.3")]

        XCTAssertEqual(view.__remoteLogs.first?.id, "v1")
    }
}
