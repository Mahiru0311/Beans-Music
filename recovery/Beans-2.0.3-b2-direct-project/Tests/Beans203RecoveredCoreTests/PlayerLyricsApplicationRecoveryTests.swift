import Foundation
import XCTest
@testable import Beans203RecoveredCore

final class PlayerLyricsApplicationRecoveryTests: XCTestCase {
    func testCurrentSongIsNilForEmptyQueueOrInvalidIndex() {
        let player = PlayerManager_2_0_3()
        XCTAssertNil(player.currentSong)
        player._queue = [Song_2_0_3(id: 10)]
        for index in [-1, Int.min, 1, Int.max] {
            player._currentIndex = index
            XCTAssertNil(player.currentSong)
        }
    }

    func testCurrentSongUsesSelectedIndexAndTracksQueueReplacement() {
        let player = PlayerManager_2_0_3()
        player._queue = [Song_2_0_3(id: 10), Song_2_0_3(id: 20)]
        XCTAssertEqual(player.currentSong?.id, 10)
        player._currentIndex = 1
        XCTAssertEqual(player.currentSong?.id, 20)
        player._queue = [Song_2_0_3(id: 30)]
        XCTAssertNil(player.currentSong)
        player._currentIndex = 0
        XCTAssertEqual(player.currentSong?.id, 30)
    }

    func testMatchingSongReplacesDisplayAndRetainsOriginalLineIdentityAndWords() {
        let song = Song_2_0_3(id: 1)
        let incoming = LyricLine_2_0_3(time: 3, text: "incoming", translation: "译文",
                                      words: [LyricWord_2_0_3(text: "word", start: 3, duration: 1)])
        var displayed = [LyricLine_2_0_3(text: "old")]
        XCTAssertTrue(PlayerLyricsApplication_2_0_3.apply([incoming], requestedSongKey: song.playbackKey,
                                                        currentSong: song, to: &displayed))
        XCTAssertEqual(displayed.count, 1)
        XCTAssertEqual(displayed[0].id, incoming.id)
        XCTAssertEqual(displayed[0].translation, "译文")
        XCTAssertEqual(displayed[0].words?.first?.duration, 1)
    }

    func testNoCurrentSongKeepsExistingLyrics() {
        let original = LyricLine_2_0_3(text: "keep")
        var displayed = [original]
        XCTAssertFalse(PlayerLyricsApplication_2_0_3.apply([LyricLine_2_0_3(text: "new")],
            requestedSongKey: "netease-1", currentSong: nil, to: &displayed))
        XCTAssertEqual(displayed[0].id, original.id)
    }

    func testOldRequestAfterSongSwitchDoesNotOverwriteCurrentLyrics() {
        let original = LyricLine_2_0_3(text: "current")
        var displayed = [original]
        XCTAssertFalse(PlayerLyricsApplication_2_0_3.apply([LyricLine_2_0_3(text: "old request")],
            requestedSongKey: "netease-1", currentSong: Song_2_0_3(id: 2), to: &displayed))
        XCTAssertEqual(displayed[0].id, original.id)
    }

    func testEmptyResultDoesNotClearPreviousLyrics() {
        let original = LyricLine_2_0_3(text: "keep")
        var displayed = [original]
        XCTAssertFalse(PlayerLyricsApplication_2_0_3.apply([], requestedSongKey: "netease-1",
            currentSong: Song_2_0_3(id: 1), to: &displayed))
        XCTAssertEqual(displayed[0].id, original.id)
    }

    func testOneEmptyTextLineStillCountsAsNonemptyResult() {
        let blank = LyricLine_2_0_3(time: 1, text: "")
        var displayed: [LyricLine_2_0_3] = []
        XCTAssertTrue(PlayerLyricsApplication_2_0_3.apply([blank], requestedSongKey: "netease-1",
            currentSong: Song_2_0_3(id: 1), to: &displayed))
        XCTAssertEqual(displayed[0].id, blank.id)
    }

    func testSameNumericIDFromDifferentProviderDoesNotMatch() {
        var displayed: [LyricLine_2_0_3] = []
        XCTAssertFalse(PlayerLyricsApplication_2_0_3.apply([LyricLine_2_0_3(text: "new")],
            requestedSongKey: "qq-1", currentSong: Song_2_0_3(id: 1, source: .netease), to: &displayed))
        XCTAssertTrue(displayed.isEmpty)
    }

    func testQQMetadataAndMIDChangesStillMatchNumericPlaybackIdentity() {
        let old = Song_2_0_3(id: 1, name: "old", source: .qq, qqMid: "one")
        let current = Song_2_0_3(id: 1, name: "new", source: .qq, qqMid: "two")
        var displayed: [LyricLine_2_0_3] = []
        XCTAssertTrue(PlayerLyricsApplication_2_0_3.apply([LyricLine_2_0_3(text: "new")],
            requestedSongKey: old.playbackKey, currentSong: current, to: &displayed))
    }

    func testSwitchingAwayAndBackToSameSongDoesNotIntroduceGenerationGate() {
        let player = PlayerManager_2_0_3()
        player._queue = [Song_2_0_3(id: 1), Song_2_0_3(id: 2)]
        let requestKey = player.currentSong!.playbackKey
        player._currentIndex = 1
        player.loadGeneration = 100
        player._currentIndex = 0
        var displayed: [LyricLine_2_0_3] = []
        XCTAssertTrue(PlayerLyricsApplication_2_0_3.apply([LyricLine_2_0_3(text: "returned")],
            requestedSongKey: requestKey, currentSong: player.currentSong, to: &displayed))
    }
}
