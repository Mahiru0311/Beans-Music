import XCTest
@testable import Beans203RecoveredCore

final class LibraryModelsRecoveryTests: XCTestCase {
    func testLibraryModelsComposeWithRecoveredSongType() {
        let song = Song_2_0_3(id: 1, name: "Song", source: .netease)
        let snapshot = PlaylistSnapshot_2_0_3(key: "playlist", songs: [song])
        let playlist = Playlist_2_0_3(id: 9, name: "List", savedSnapshot: snapshot)
        let persisted = PersistedPlaybackState_2_0_3(queue: [song], currentIndex: 0)

        XCTAssertEqual(playlist.savedSnapshot?.songs.first?.id, 1)
        XCTAssertEqual(persisted.queue.count, 1)
        XCTAssertEqual(persisted.queue.first?.name, "Song")
    }

    func testDownloadModelsPreserveQualityAndURLTypes() {
        let url = URL(string: "https://example.invalid/audio")!
        let resolved = ResolvedDownloadURL_2_0_3(url: url, source: "qq", quality: .flac)
        let result = DownloadResult_2_0_3(
            url: url, requestedQuality: .flac, actualQuality: .kb320,
            downgraded: true, sourceName: "qq"
        )

        XCTAssertEqual(resolved.url, url)
        XCTAssertEqual(resolved.quality, .flac)
        XCTAssertTrue(result.downgraded)
        XCTAssertEqual(result.actualQuality, .kb320)
    }
}
