import XCTest
@testable import Beans

final class FoliaClassicMotionTests: XCTestCase {
    func testWordLookaheadEndpointsAndBackwardSeek() {
        let word = FoliaWord(id: "word", text: "hello", startTime: 2, endTime: 3)
        XCTAssertEqual(FoliaClassicMotion.state(word: word, time: 1.84), .waiting)
        XCTAssertEqual(FoliaClassicMotion.state(word: word, time: 1.85), .active)
        XCTAssertEqual(FoliaClassicMotion.state(word: word, time: 3), .active)
        XCTAssertEqual(FoliaClassicMotion.state(word: word, time: 3.01), .passed)
        XCTAssertEqual(FoliaClassicMotion.state(word: word, time: 1), .waiting)
        XCTAssertEqual(FoliaClassicMotion.state(word: word, time: .nan), .waiting)
    }

    func testGeometryUsesTheUpstreamSeedFormula() {
        let geometry = FoliaClassicMotion.geometry(seed: 12.5, index: 2, intensity: .normal, rotationEnabled: true)
        XCTAssertEqual(geometry.x, 6.99277511863329, accuracy: 0.000001)
        XCTAssertEqual(geometry.y, -14.136947649203648, accuracy: 0.000001)
        XCTAssertEqual(geometry.scale, 1.1387630607749089, accuracy: 0.000001)
        XCTAssertEqual(geometry, FoliaClassicMotion.geometry(seed: 12.5, index: 2, intensity: .normal, rotationEnabled: true))
        let disabled = FoliaClassicMotion.geometry(seed: 12.5, index: 2, intensity: .normal, rotationEnabled: false)
        XCTAssertEqual(disabled.x, geometry.x)
        XCTAssertEqual(disabled.rotation, 0)
        XCTAssertEqual(disabled.passedRotation, 0)
    }

    func testMeasuredSpacingIncludesScaleOverflowAndOffsets() {
        let first = FoliaClassicWordGeometry(x: 10, y: 0, rotation: 0, scale: 1.2, passedRotation: 0, legacyMargin: 12.8, alignment: nil)
        let next = FoliaClassicWordGeometry(x: -5, y: 0, rotation: 0, scale: 1.1, passedRotation: 0, legacyMargin: 12.8, alignment: nil)
        XCTAssertEqual(FoliaClassicMotion.margin(width: 100, nextWidth: 80, geometry: first, next: next,
                                                 fontSize: 40, intensity: .normal, spacing: 0.7, legacy: false, interlude: false), 50.8)
        XCTAssertEqual(FoliaClassicMotion.margin(width: 100, nextWidth: 80, geometry: first, next: next,
                                                 fontSize: 40, intensity: .normal, spacing: 0.7, legacy: true, interlude: false), 12.8)
    }

    func testBreathingKeyframesAndDisabledMotion() {
        let peak = FoliaClassicMotion.breathing(elapsed: 1.75, intensity: .normal, multiplier: 1)
        XCTAssertEqual(peak.y, -14, accuracy: 0.000001)
        XCTAssertEqual(peak.scale, 1.01, accuracy: 0.000001)
        let trough = FoliaClassicMotion.breathing(elapsed: 5.25, intensity: .normal, multiplier: 1)
        XCTAssertEqual(trough.y, 6.3, accuracy: 0.000001)
        XCTAssertEqual(trough.scale, 0.995, accuracy: 0.000001)
        let disabled = FoliaClassicMotion.breathing(elapsed: 1.75, intensity: .normal, multiplier: 0)
        XCTAssertEqual(disabled.y, 0)
        XCTAssertEqual(disabled.scale, 1)
        XCTAssertEqual(FoliaClassicMotion.clamp(.nan, fallback: 0.7), 0.7)
    }

    func testSubtitleFiltersInstrumentalMarkers() {
        XCTAssertFalse(FoliaClassicMotion.hasReadableText("...... // ●● —"))
        XCTAssertTrue(FoliaClassicMotion.hasReadableText("译文"))
        XCTAssertTrue(FoliaClassicMotion.hasReadableText("Verse 2"))
    }
}
