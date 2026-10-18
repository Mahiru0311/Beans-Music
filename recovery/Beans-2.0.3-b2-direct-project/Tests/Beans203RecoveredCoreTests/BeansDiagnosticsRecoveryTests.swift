import XCTest
@testable import Beans203RecoveredCore

final class BeansDiagnosticsRecoveryTests: XCTestCase {
    func testPublishedDiagnosticsStateAndConcreteMonitorFields() {
        let diagnostics = BeansDiagnostics_2_0_3()

        XCTAssertEqual(diagnostics.lastRoute, "")
        XCTAssertNil(diagnostics.lastSnapshotDate)
        XCTAssertFalse(diagnostics.enabled)
        XCTAssertFalse(diagnostics.started)
        XCTAssertNil(diagnostics.timer)
        XCTAssertTrue(diagnostics.observers.isEmpty)

        diagnostics.lastRoute = "player"
        diagnostics.enabled = true
        XCTAssertEqual(diagnostics.lastRoute, "player")
        XCTAssertTrue(diagnostics.enabled)
    }

    func testDiagnosticFileUsesURLAndIntBytes() throws {
        let url = try XCTUnwrap(URL(string: "file:///tmp/beans.log"))
        let file = BeansDiagnosticFile_2_0_3(url: url, bytes: 256)

        XCTAssertEqual(file.url, url)
        XCTAssertEqual(file.bytes, 256)
    }
}
