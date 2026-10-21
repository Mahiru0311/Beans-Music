import Foundation
import XCTest
@testable import Beans203RecoveredCore

final class PlayerListeningStatisticsRecoveryTests: XCTestCase {
    private let durationKey = "beans.playback.listeningDuration.v1"
    private let offsetKey = "beans.playback.listeningPlayCountOffset.v1"
    private let countsKey = "beans.playcounts"
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "Beans203ListeningStatisticsTests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        suite = nil
        super.tearDown()
    }

    private func saveCounts(_ counts: [String: Int]) throws {
        defaults.set(try JSONEncoder().encode(counts), forKey: countsKey)
    }

    func testMissingValuesReturnZeroWithoutCreatingKeys() {
        XCTAssertEqual(PlayerManager_2_0_3.storedListeningDuration(in: defaults), 0)
        XCTAssertEqual(PlayerManager_2_0_3.storedListeningPlayCount(in: defaults), 0)
        XCTAssertNil(defaults.object(forKey: durationKey))
        XCTAssertNil(defaults.object(forKey: offsetKey))
        XCTAssertNil(defaults.object(forKey: countsKey))
    }

    func testDurationPreservesFractionalValue() {
        defaults.set(12.75, forKey: durationKey)
        XCTAssertEqual(PlayerManager_2_0_3.storedListeningDuration(in: defaults), 12.75)
    }

    func testNegativeAndNaNDurationReadAsZeroWithoutRepairingStorage() {
        for value in [-12.5, -Double.infinity, Double.nan] {
            defaults.set(value, forKey: durationKey)
            XCTAssertEqual(PlayerManager_2_0_3.storedListeningDuration(in: defaults), 0)
            let persisted = defaults.double(forKey: durationKey)
            if value.isNaN { XCTAssertTrue(persisted.isNaN) }
            else { XCTAssertEqual(persisted, value) }
        }
    }

    func testPositiveInfinityIsNotClampedByDurationGetter() {
        defaults.set(Double.infinity, forKey: durationKey)
        XCTAssertEqual(PlayerManager_2_0_3.storedListeningDuration(in: defaults), .infinity)
    }

    func testSumsAllJSONCountsAndAddsOffset() throws {
        try saveCounts(["netease:1": 8, "qishui:2": 3, "": 2])
        defaults.set(7, forKey: offsetKey)
        XCTAssertEqual(PlayerManager_2_0_3.storedListeningPlayCount(in: defaults), 20)
    }

    func testNegativeCountsRemainSignedAndNegativeOffsetIsIgnored() throws {
        try saveCounts(["a": -9, "b": 2])
        defaults.set(-3, forKey: offsetKey)
        XCTAssertEqual(PlayerManager_2_0_3.storedListeningPlayCount(in: defaults), -7)
        XCTAssertEqual(defaults.integer(forKey: offsetKey), -3)
    }

    func testMalformedOrWronglyTypedJSONContributesZeroAndIsPreserved() {
        for raw in ["not JSON", "[1,2]", "{\"a\":\"3\"}", "{\"a\":1.5}", "null"] {
            let data = Data(raw.utf8)
            defaults.set(data, forKey: countsKey)
            defaults.set(4, forKey: offsetKey)
            XCTAssertEqual(PlayerManager_2_0_3.storedListeningPlayCount(in: defaults), 4)
            XCTAssertEqual(defaults.data(forKey: countsKey), data)
        }
    }

    func testNativeDefaultsDictionaryIsNotAcceptedAsJSONData() {
        defaults.set(["a": 10], forKey: countsKey)
        XCTAssertEqual(PlayerManager_2_0_3.storedListeningPlayCount(in: defaults), 0)
    }

    func testNilRemoteValuesDoNotReadOrConvertInfiniteDuration() {
        defaults.set(Double.infinity, forKey: durationKey)
        defaults.set(-9, forKey: offsetKey)
        PlayerManager_2_0_3.mergeListeningStatistics(
            listeningSeconds: nil, listeningPlayCount: nil, defaults: defaults)
        XCTAssertEqual(defaults.double(forKey: durationKey), .infinity)
        XCTAssertEqual(defaults.integer(forKey: offsetKey), -9)
    }

    func testRemoteDurationUsesFlooredComparisonAndNeverDecreases() {
        defaults.set(10.9, forKey: durationKey)
        for value in [-1, 0, 9, 10] {
            PlayerManager_2_0_3.mergeListeningStatistics(
                listeningSeconds: value, listeningPlayCount: nil, defaults: defaults)
            XCTAssertEqual(defaults.double(forKey: durationKey), 10.9)
        }
        PlayerManager_2_0_3.mergeListeningStatistics(
            listeningSeconds: 11, listeningPlayCount: nil, defaults: defaults)
        XCTAssertEqual(defaults.double(forKey: durationKey), 11)
    }

    func testZeroRemoteValuesDoNotCreateMissingStorage() {
        PlayerManager_2_0_3.mergeListeningStatistics(
            listeningSeconds: 0, listeningPlayCount: 0, defaults: defaults)
        XCTAssertNil(defaults.object(forKey: durationKey))
        XCTAssertNil(defaults.object(forKey: offsetKey))
    }

    func testHigherRemoteCountOnlyIncreasesOffsetAndRetainsPerSongData() throws {
        try saveCounts(["a": 6, "b": 4])
        let originalData = defaults.data(forKey: countsKey)
        defaults.set(3, forKey: offsetKey)
        PlayerManager_2_0_3.mergeListeningStatistics(
            listeningSeconds: nil, listeningPlayCount: 20, defaults: defaults)
        XCTAssertEqual(defaults.integer(forKey: offsetKey), 10)
        XCTAssertEqual(defaults.data(forKey: countsKey), originalData)
        XCTAssertEqual(PlayerManager_2_0_3.storedListeningPlayCount(in: defaults), 20)
    }

    func testRepeatedOrLowerRemoteCountDoesNotDoubleCount() throws {
        try saveCounts(["a": 7])
        for remote in [15, 15, 12, -5] {
            PlayerManager_2_0_3.mergeListeningStatistics(
                listeningSeconds: nil, listeningPlayCount: remote, defaults: defaults)
            XCTAssertEqual(PlayerManager_2_0_3.storedListeningPlayCount(in: defaults), 15)
            XCTAssertEqual(defaults.integer(forKey: offsetKey), 8)
        }
    }

    func testLocalCountsCanGrowAfterRemoteMerge() throws {
        try saveCounts(["a": 5])
        PlayerManager_2_0_3.mergeListeningStatistics(
            listeningSeconds: nil, listeningPlayCount: 20, defaults: defaults)
        try saveCounts(["a": 6, "b": 1])
        XCTAssertEqual(PlayerManager_2_0_3.storedListeningPlayCount(in: defaults), 22)
        PlayerManager_2_0_3.mergeListeningStatistics(
            listeningSeconds: nil, listeningPlayCount: 21, defaults: defaults)
        XCTAssertEqual(defaults.integer(forKey: offsetKey), 15)
    }

    func testRemoteMergeReplacesNegativeOffsetOnlyWhenIncreaseIsNeeded() throws {
        try saveCounts(["a": 5])
        defaults.set(-4, forKey: offsetKey)
        PlayerManager_2_0_3.mergeListeningStatistics(
            listeningSeconds: nil, listeningPlayCount: 5, defaults: defaults)
        XCTAssertEqual(defaults.integer(forKey: offsetKey), -4)
        PlayerManager_2_0_3.mergeListeningStatistics(
            listeningSeconds: nil, listeningPlayCount: 8, defaults: defaults)
        XCTAssertEqual(defaults.integer(forKey: offsetKey), 3)
    }

    func testRemoteFieldsMergeIndependently() {
        defaults.set(100.25, forKey: durationKey)
        defaults.set(5, forKey: offsetKey)
        PlayerManager_2_0_3.mergeListeningStatistics(
            listeningSeconds: 50, listeningPlayCount: 10, defaults: defaults)
        XCTAssertEqual(defaults.double(forKey: durationKey), 100.25)
        XCTAssertEqual(defaults.integer(forKey: offsetKey), 10)
        PlayerManager_2_0_3.mergeListeningStatistics(
            listeningSeconds: 101, listeningPlayCount: 7, defaults: defaults)
        XCTAssertEqual(defaults.double(forKey: durationKey), 101)
        XCTAssertEqual(defaults.integer(forKey: offsetKey), 10)
    }

    func testSignedBaseCountIsPreservedDuringMerge() throws {
        try saveCounts(["a": -5])
        PlayerManager_2_0_3.mergeListeningStatistics(
            listeningSeconds: nil, listeningPlayCount: -2, defaults: defaults)
        XCTAssertEqual(defaults.integer(forKey: offsetKey), 3)
        XCTAssertEqual(PlayerManager_2_0_3.storedListeningPlayCount(in: defaults), -2)
    }
}
