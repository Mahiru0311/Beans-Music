import XCTest
@testable import CiliCiliKitRecovered

final class CiliCiliListenSourceTests: XCTestCase {
    private func request(_ bvid: String, aid: Int?, title: String = "title") -> CiliCiliVideoListenRequest_2_0_3 {
        CiliCiliVideoListenRequest_2_0_3(
            bvid: bvid,
            aid: aid,
            cid: 7,
            title: title,
            coverURL: nil,
            duration: 12,
            artist: "artist",
            ownerID: 9
        )
    }

    func testFirstRequestSeedsTheReturnedSource() {
        let runtime = CiliCiliRuntime_2_0_3()
        let source = runtime.listenSource(for: request("BV-first", aid: 1))

        XCTAssertEqual(source.items.map(\.bvid), ["BV-first"])
        XCTAssertEqual(source.items.first?.aid, 1)
    }

    func testMatchingBVIDAndAIDReuseTheExistingSource() {
        let runtime = CiliCiliRuntime_2_0_3()
        let first = runtime.listenSource(for: request("BV-same", aid: 2, title: "first"))
        let second = runtime.listenSource(for: request("BV-same", aid: 2, title: "changed"))

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(second.items.first?.title, "first")
    }

    func testDifferentIdentityStartsANewSource() {
        let runtime = CiliCiliRuntime_2_0_3()
        let first = runtime.listenSource(for: request("BV-one", aid: 3))
        let second = runtime.listenSource(for: request("BV-two", aid: 3))

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(second.items.map(\.bvid), ["BV-two"])
    }
}
