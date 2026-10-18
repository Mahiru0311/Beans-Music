import XCTest
@testable import Beans203RecoveredCore

final class BeansEqualizerRecoveryTests: XCTestCase {
    func testRecoveredEqualizerNominalsKeepTheDirectFieldTypes() {
        XCTAssertEqual(BeansEqualizerPreset_2_0_3.allCases.count, 8)

        let preset = BeansEqualizerCustomPreset_2_0_3(
            id: "custom-1",
            name: "Warm",
            gains: [-2, 0, 3],
            preampGain: 1.5
        )
        XCTAssertEqual(preset.gains, [-2, 0, 3])
        XCTAssertEqual(preset.preampGain, 1.5)

        let coefficients = BiquadCoefficients_2_0_3(b0: 1, b1: 2, b2: 3, a1: 4, a2: 5)
        let state = BiquadState_2_0_3(z1: 0.25, z2: -0.5)
        XCTAssertEqual(coefficients.a2, 5)
        XCTAssertEqual(state.z2, -0.5)
    }

    func testEqualizerPublishedStateStartsWithFlatPreset() {
        let equalizer = BeansEqualizer_2_0_3()

        XCTAssertFalse(equalizer.isEnabled)
        XCTAssertEqual(equalizer.selectedPreset, .flat)
        XCTAssertNil(equalizer.selectedCustomPresetName)
        XCTAssertTrue(equalizer.bandGains.isEmpty)
        XCTAssertTrue(equalizer.customPresets.isEmpty)
        XCTAssertTrue(equalizer.coefficients.isEmpty)
        XCTAssertTrue(equalizer.filterStates.isEmpty)
    }
}
