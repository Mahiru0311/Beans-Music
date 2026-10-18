import XCTest
@testable import Beans203RecoveredCore

final class NetworkStatusRecoveryTests: XCTestCase {
    func testNetworkConnectionKindCasesMatchIPA() {
        XCTAssertEqual(
            BeansNetworkConnectionKind_2_0_3.allCases,
            [.wifi, .cellular, .other, .unavailable]
        )
    }

    func testNetworkStatusStoresReachabilityAndConnectionKind() {
        let status = BeansNetworkStatus_2_0_3()
        status.reachable = true
        status.currentConnectionKind = .wifi

        XCTAssertTrue(status.reachable)
        XCTAssertEqual(status.currentConnectionKind, .wifi)
    }
}
