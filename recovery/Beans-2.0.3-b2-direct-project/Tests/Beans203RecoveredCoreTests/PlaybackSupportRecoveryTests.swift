import XCTest
@testable import Beans203RecoveredCore

final class PlaybackSupportRecoveryTests: XCTestCase {
    func testProcessMetricsUsesResourceSnapshotAndOptionalTiming() {
        let date = Date(timeIntervalSince1970: 20)
        let metrics = BeansProcessMetrics_2_0_3()
        metrics.value = BeansResourceSnapshot_2_0_3(
            memoryBytes: 4096,
            cpuPercent: 7.5,
            sampledAt: date,
            available: true
        )
        metrics.previousCPU = 3.25
        metrics.previousUptime = 99.0

        XCTAssertEqual(metrics.value.cpuPercent, 7.5)
        XCTAssertEqual(metrics.value.sampledAt, date)
        XCTAssertEqual(metrics.previousCPU, 3.25)
        XCTAssertEqual(metrics.previousUptime, 99.0)
        XCTAssertNil(metrics.timer)
    }

    func testNowPlayingAndContentStateRoundTripAsCodableModels() throws {
        let attributes = BeansNowPlayingAttributes_2_0_3(
            songKey: "song-1", title: "Title", artist: "Artist"
        )
        let state = BeansContentState_2_0_3(isPlaying: true, lyric: "Line")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let decodedAttributes = try decoder.decode(
            BeansNowPlayingAttributes_2_0_3.self,
            from: encoder.encode(attributes)
        )
        let decodedState = try decoder.decode(
            BeansContentState_2_0_3.self,
            from: encoder.encode(state)
        )

        XCTAssertEqual(decodedAttributes, attributes)
        XCTAssertEqual(decodedState, state)
    }
}
