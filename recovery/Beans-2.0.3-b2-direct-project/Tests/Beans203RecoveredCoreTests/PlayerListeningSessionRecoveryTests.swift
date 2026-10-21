import Foundation
import AVFoundation
import XCTest
@testable import Beans203RecoveredCore

final class PlayerListeningSessionRecoveryTests: XCTestCase {
    private let durationKey = "beans.playback.listeningDuration.v1"
    private var suite: String!
    private var player: PlayerManager_2_0_3!

    override func setUp() {
        super.setUp()
        suite = "Beans203ListeningSessionTests." + UUID().uuidString
        player = PlayerManager_2_0_3()
        player.defaults = UserDefaults(suiteName: suite)!
        player.defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        player.defaults.removePersistentDomain(forName: suite)
        player = nil
        suite = nil
        super.tearDown()
    }

    func testRepeatedBeginDoesNotReadClockOrResetStart() {
        player.beginListeningSegment { 100 }
        player.beginListeningSegment { XCTFail("Repeated begin must not sample uptime"); return 200 }
        XCTAssertEqual(player.listeningSegmentStartedUptime, 100)
    }

    func testEndAccumulatesFractionalElapsedThenFlushes() {
        player._listeningDuration = 20
        player.pendingListeningDuration = 2
        player.beginListeningSegment { 100 }
        var readings = [103.5, 104.0]
        player.endListeningSegment { readings.removeFirst() }
        XCTAssertEqual(player._listeningDuration, 25.5)
        XCTAssertEqual(player.defaults.double(forKey: durationKey), 25.5)
        XCTAssertEqual(player.pendingListeningDuration, 0)
        XCTAssertNil(player.listeningSegmentStartedUptime)
        XCTAssertEqual(player.lastListeningPublishUptime, 104)
        XCTAssertTrue(readings.isEmpty)
    }

    func testEndWithoutActiveSegmentLeavesPendingAmountUntouched() {
        player.pendingListeningDuration = 3
        player.endListeningSegment { XCTFail("No active segment"); return 100 }
        XCTAssertEqual(player.pendingListeningDuration, 3)
        XCTAssertNil(player.defaults.object(forKey: durationKey))
    }

    func testEndIgnoresNonpositiveOrUnorderedElapsedAndClearsStart() {
        for now in [99.0, 100.0, Double.nan] {
            player.listeningSegmentStartedUptime = 100
            player.endListeningSegment { now }
            XCTAssertNil(player.listeningSegmentStartedUptime)
            XCTAssertEqual(player.pendingListeningDuration, 0)
            XCTAssertNil(player.defaults.object(forKey: durationKey))
        }
    }

    func testEndStillFlushesExistingPendingAfterNonpositiveElapsed() {
        player.listeningSegmentStartedUptime = 100
        player.pendingListeningDuration = 4
        player.endListeningSegment { 99 }
        XCTAssertEqual(player._listeningDuration, 4)
        XCTAssertEqual(player.lastListeningPublishUptime, 99)
    }

    func testFlushSkipsZeroNegativeAndNaNPendingAmounts() {
        for amount in [0.0, -5.0, Double.nan] {
            player.pendingListeningDuration = amount
            player.flushListeningDuration { XCTFail("Skipped flush must not read clock"); return 1 }
            XCTAssertEqual(player._listeningDuration, 0)
            XCTAssertNil(player.defaults.object(forKey: durationKey))
            if amount.isNaN { XCTAssertTrue(player.pendingListeningDuration.isNaN) }
            else { XCTAssertEqual(player.pendingListeningDuration, amount) }
        }
    }

    func testFlushClampsPersistedValueButNotInMemoryTotal() {
        player._listeningDuration = -10
        player.pendingListeningDuration = 2
        player.flushListeningDuration { 50 }
        XCTAssertEqual(player._listeningDuration, -8)
        XCTAssertEqual(player.defaults.double(forKey: durationKey), 0)
        XCTAssertEqual(player.lastListeningPublishUptime, 50)
    }

    func testFlushPersistsZeroForNaNTotalAndKeepsNaNInMemory() {
        player._listeningDuration = .nan
        player.pendingListeningDuration = 1
        player.flushListeningDuration { 50 }
        XCTAssertTrue(player._listeningDuration.isNaN)
        XCTAssertEqual(player.defaults.double(forKey: durationKey), 0)
        XCTAssertEqual(player.pendingListeningDuration, 0)
    }

    func testFlushKeepsPositiveInfinity() {
        player.pendingListeningDuration = .infinity
        player.flushListeningDuration { 50 }
        XCTAssertEqual(player._listeningDuration, .infinity)
        XCTAssertEqual(player.defaults.double(forKey: durationKey), .infinity)
        XCTAssertEqual(player.pendingListeningDuration, 0)
    }

    func testPlayingTickAccumulatesAndFlushesAtExactlyFifteenSeconds() {
        player._isPlaying = true
        player.listeningSegmentStartedUptime = 100
        player.lastListeningPublishUptime = 100
        player.updateListeningDuration(timeControlStatus: .playing) { 114.5 }
        XCTAssertEqual(player.pendingListeningDuration, 14.5)
        XCTAssertEqual(player.listeningSegmentStartedUptime, 114.5)
        XCTAssertNil(player.defaults.object(forKey: durationKey))
        player.updateListeningDuration(timeControlStatus: .playing) { 115 }
        XCTAssertEqual(player._listeningDuration, 15)
        XCTAssertEqual(player.pendingListeningDuration, 0)
        XCTAssertEqual(player.lastListeningPublishUptime, 115)
        XCTAssertEqual(player.listeningSegmentStartedUptime, 115)
    }

    func testFirstPlayingTickSamplesBeginElapsedAndThresholdSeparately() {
        player._isPlaying = true
        player.lastListeningPublishUptime = 100
        var readings = [110.0, 110.25, 110.5]
        player.updateListeningDuration(timeControlStatus: .playing) { readings.removeFirst() }
        XCTAssertEqual(player.pendingListeningDuration, 0.25)
        XCTAssertEqual(player.listeningSegmentStartedUptime, 110.25)
        XCTAssertTrue(readings.isEmpty)
    }

    func testTickPreservesStartForBackwardsOrNaNUptime() {
        player._isPlaying = true
        player.lastListeningPublishUptime = 100
        for now in [99.0, 100.0, Double.nan] {
            player.listeningSegmentStartedUptime = 100
            player.updateListeningDuration(timeControlStatus: .playing) { now }
            XCTAssertEqual(player.listeningSegmentStartedUptime, 100)
            XCTAssertEqual(player.pendingListeningDuration, 0)
            XCTAssertNil(player.defaults.object(forKey: durationKey))
        }
    }

    func testBufferingOrPausedTickEndsSegmentAndResetsLegacyBaselines() {
        player._isPlaying = true
        for status in [AVPlayer.TimeControlStatus.waitingToPlayAtSpecifiedRate, .paused] {
            player.listeningSegmentStartedUptime = 100
            player.lastListeningProgress = 12
            player.lastListeningSongKey = "a"
            player.updateListeningDuration(timeControlStatus: status) { 103 }
            XCTAssertNil(player.listeningSegmentStartedUptime)
            XCTAssertNil(player.lastListeningProgress)
            XCTAssertNil(player.lastListeningSongKey)
        }
        XCTAssertEqual(player._listeningDuration, 6)
    }

    func testNotPlayingStateEndsSegmentEvenWhenAVPlayerReportsPlaying() {
        player._isPlaying = false
        player.listeningSegmentStartedUptime = 100
        player.lastListeningProgress = 9
        player.lastListeningSongKey = "a"
        player.updateListeningDuration(timeControlStatus: .playing) { 105 }
        XCTAssertEqual(player._listeningDuration, 5)
        XCTAssertNil(player.lastListeningProgress)
        XCTAssertNil(player.lastListeningSongKey)
    }

    func testPauseGapAndPlaybackRateDoNotInflateListeningDuration() {
        player._isPlaying = true
        player._rate = 2
        player.progress = 500
        player.beginListeningSegment { 100 }
        player.updateListeningDuration(timeControlStatus: .paused) { 105 }
        player.progress = 2000
        player.updateListeningDuration(timeControlStatus: .playing) { 200 }
        player.updateListeningDuration(timeControlStatus: .paused) { 203 }
        XCTAssertEqual(player._listeningDuration, 8)
    }

    func testBaselineResetDoesNotChangeUptimeSessionOrPendingAmount() {
        player.lastListeningProgress = 9
        player.lastListeningSongKey = "a"
        player.pendingListeningDuration = 3
        player.listeningSegmentStartedUptime = 10
        player.resetListeningProgressBaseline()
        XCTAssertNil(player.lastListeningProgress)
        XCTAssertNil(player.lastListeningSongKey)
        XCTAssertEqual(player.pendingListeningDuration, 3)
        XCTAssertEqual(player.listeningSegmentStartedUptime, 10)
    }
}
