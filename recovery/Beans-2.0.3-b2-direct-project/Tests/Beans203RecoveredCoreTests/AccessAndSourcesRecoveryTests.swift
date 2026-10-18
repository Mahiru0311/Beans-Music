import XCTest
@testable import Beans203RecoveredCore

final class AccessAndSourcesRecoveryTests: XCTestCase {
    func testThirdPartySourceModelsPreserveIPAFieldTypes() {
        let draft = ThirdPartySourceDraft_2_0_3(
            id: "id", name: "Demo", sourceURL: "https://example.invalid", enabled: true,
            platform: .netease
        )
        let source = ThirdPartySource_2_0_3(
            id: draft.id, name: draft.name, headers: ["X-Test": "1"], script: "return nil",
            sourceURL: draft.sourceURL, enabled: draft.enabled
        )

        XCTAssertEqual(source.id, "id")
        XCTAssertEqual(source.headers["X-Test"], "1")
        XCTAssertEqual(source.script, "return nil")
        XCTAssertEqual(draft.platform, .netease)
    }

    func testAccessAndUpdateRecordsUseOptionalServerFields() {
        let response = BackendResponse_2_0_3(
            ok: true, publicUserID: "public", exclusiveID: true,
            exclusiveBadgeStyle: .classicGold, listeningSeconds: 12,
            downloadUnlocked: false
        )
        let access = BeansExclusiveAccessRecord_2_0_3(
            userID: "user", enabled: true, badgeStyle: .blackPurpleGold
        )
        let update = ServerUpdateRecord_2_0_3(
            version: "2.0.3", title: "Update", notes: ["Fix"], build: "2"
        )

        XCTAssertEqual(response.publicUserID, "public")
        XCTAssertEqual(response.exclusiveBadgeStyle, .classicGold)
        XCTAssertEqual(access.badgeStyle, .blackPurpleGold)
        XCTAssertEqual(update.notes, ["Fix"])
        XCTAssertNil(update.ipaURL)
    }
}
