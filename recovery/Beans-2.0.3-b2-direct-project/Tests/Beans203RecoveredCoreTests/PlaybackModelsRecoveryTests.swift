import XCTest
@testable import Beans203RecoveredCore

final class PlaybackModelsRecoveryTests: XCTestCase {
    func testSongUsesDirectIPAFieldTypes() {
        let url = URL(string: "https://example.invalid/cover")
        let song = Song_2_0_3(
            id: 7, name: "Demo", artists: "Artist", album: "Album", coverURL: url,
            duration: 123.5, source: .qq, qqMid: "mid", kugouQualityHashes: ["128": "hash"],
            fee: 1
        )

        XCTAssertEqual(song.id, 7)
        XCTAssertEqual(song.source, .qq)
        XCTAssertEqual(song.coverURL, url)
        XCTAssertEqual(song.kugouQualityHashes?["128"], "hash")
        XCTAssertEqual(song.fee, 1)
    }

    func testPlaybackStateModelsExposeIPAEnumsAndOptionals() {
        let clock = PlaybackClock_2_0_3()
        clock.progress = 12.5
        clock.duration = 120
        let seek = PlaybackSeekState_2_0_3(pendingRevision: 3)
        let notice = ThirdPartyVIPNotice_2_0_3(songKey: "song", message: "VIP")

        XCTAssertEqual(clock.progress, 12.5)
        XCTAssertEqual(clock.duration, 120)
        XCTAssertEqual(seek.pendingRevision, 3)
        XCTAssertEqual(notice.songKey, "song")
        XCTAssertEqual(PlayMode_2_0_3.allCases, [.sequential, .repeatAll, .repeatOne, .shuffle])
        XCTAssertEqual(ThirdPartyAudioQuality_2_0_3.allCases.count, 8)
    }
}
