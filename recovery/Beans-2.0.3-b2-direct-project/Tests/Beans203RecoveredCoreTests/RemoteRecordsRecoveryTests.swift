import XCTest
@testable import Beans203RecoveredCore

final class RemoteRecordsRecoveryTests: XCTestCase {
    func testRemoteConfigAndReleaseRecordsPreserveOptionalFields() {
        let config = RemoteConfig_2_0_3(
            enabled: true, announcement: "Notice", announcementEnabled: true,
            platforms: RemotePlatforms_2_0_3(netease: true, qq: false)
        )
        let releaseURL = URL(string: "https://example.invalid/release")!
        let release = ReleaseInfo_2_0_3(
            version: "2.0.3", name: "Build 2", htmlURL: releaseURL,
            assetURL: URL(string: "https://example.invalid/ipa"), build: "2"
        )

        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.platforms?.netease, true)
        XCTAssertEqual(config.platforms?.qq, false)
        XCTAssertEqual(release.htmlURL, releaseURL)
        XCTAssertEqual(release.build, "2")
    }

    func testVersionLogAndSourceCheckUseIPAEnumsAndArrays() {
        let log = VersionLog_2_0_3(
            id: "r1", version: "2.0.3", title: "Update", fixes: ["Fix"]
        )
        let check = SourceCheckResult_2_0_3(
            status: .available, message: "OK", detail: "reachable"
        )

        XCTAssertEqual(log.fixes, ["Fix"])
        XCTAssertEqual(check.status, .available)
        XCTAssertEqual(SourceCheckStatus_2_0_3.allCases, [.available, .unavailable])
    }
}
