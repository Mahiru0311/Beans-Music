import XCTest
import CiliCiliKit
@testable import Beans

@MainActor
final class BilibiliListenQueueTests: XCTestCase {
    private func item(_ bvid: String, cid: Int? = nil, title: String? = nil,
                      queue: [CiliCiliVideoListenRequest] = []) -> CiliCiliVideoListenRequest {
        CiliCiliVideoListenRequest(bvid: bvid, aid: nil, cid: cid, title: title ?? bvid,
                                  coverURL: nil, duration: 60, artist: "UP", queue: queue)
    }

    func testMiddleSelectionPreservesPreviousAndNext() {
        let request = item("BVmiddle", cid: 22, title: "Resolved", queue: [
            item("BVfirst"), item("BVmiddle", title: "Seed"), item("BVlast")
        ])
        let songs = BilibiliListenQueue.songs(for: request)
        XCTAssertEqual(songs.map(\.bilibiliID), ["BVfirst", "BVmiddle:22", "BVlast"])
        XCTAssertEqual(songs[1].name, "Resolved")
    }

    func testDistinctPartsSurviveDeduplication() {
        let request = item("BVvideo", cid: 2, queue: [
            item("BVvideo", cid: 1), item("BVvideo", cid: 2),
            item("BVvideo", cid: 2), item("BVvideo", cid: 3)
        ])
        XCTAssertEqual(BilibiliListenQueue.songs(for: request).map(\.bilibiliID), ["BVvideo:1", "BVvideo:2", "BVvideo:3"])
    }

    func testMissingCurrentIsInsertedAndEmptyItemsAreSkipped() {
        let request = item("BVcurrent", queue: [item(" "), item("BVnext"), item("BVnext")])
        XCTAssertEqual(BilibiliListenQueue.songs(for: request).map(\.bilibiliID), ["BVcurrent", "BVnext"])
        XCTAssertEqual(BilibiliListenQueue.songs(for: item("BVonly")).count, 1)
    }

    func testHandoffDoesNotInventCIDOrAcceptInvalidDuration() {
        let request = CiliCiliVideoListenRequest(bvid: " BVvideo ", aid: 1, cid: -1, title: "Video",
                                                coverURL: nil, duration: .nan, artist: "")
        let song = BilibiliListenQueue.song(request)
        XCTAssertEqual(song.bilibiliID, "BVvideo")
        XCTAssertEqual(song.duration, 0)
        XCTAssertEqual(song.artists, "哔哩哔哩")
    }

    func testUnresolvedCurrentDoesNotCollapseFollowingParts() {
        let request = item("BVvideo", queue: [item("BVvideo", cid: 1), item("BVvideo", cid: 2), item("BVvideo", cid: 3)])
        XCTAssertEqual(BilibiliListenQueue.songs(for: request).map(\.bilibiliID), ["BVvideo", "BVvideo:2", "BVvideo:3"])
    }
}
