import XCTest
@testable import Beans203RecoveredCore

final class QishuiCacheRecoveryTests: XCTestCase {
    func testQishuiCachesUseTypedNSCacheBoxes() {
        let api = QishuiAPI_2_0_3()
        let song = Song_2_0_3(id: 1, name: "Cached")
        let playlist = Playlist_2_0_3(id: 2, name: "List")
        let details = QishuiPlaylistDetails_2_0_3(playlist: playlist, songs: [song])

        api.songSearchCache.setObject(
            QishuiCacheBox_2_0_3(value: [song]), forKey: "song"
        )
        api.playlistDetailsCache.setObject(
            QishuiCacheBox_2_0_3(value: details), forKey: "details"
        )

        XCTAssertEqual(api.songSearchCache.object(forKey: "song")?.value.first?.id, 1)
        XCTAssertEqual(api.playlistDetailsCache.object(forKey: "details")?.value.songs.count, 1)
        XCTAssertEqual(api.playlistDetailsCache.object(forKey: "details")?.value.playlist?.id, 2)
    }
}
