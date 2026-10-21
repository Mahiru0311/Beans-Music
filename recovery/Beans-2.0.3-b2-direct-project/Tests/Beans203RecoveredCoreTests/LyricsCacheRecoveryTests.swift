import Foundation
import XCTest
@testable import Beans203RecoveredCore

final class LyricsCacheRecoveryTests: XCTestCase {
    private func withCache(_ body: (LyricsCache_2_0_3, UserDefaults) throws -> Void) rethrows {
        let suite = "Beans203LyricsCacheTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let cache = LyricsCache_2_0_3(defaults: defaults, now: { Date(timeIntervalSinceReferenceDate: 2_000_000) })
        try body(cache, defaults)
    }

    private func put(_ object: [String: Any], for key: String = "song",
                     cache: LyricsCache_2_0_3, defaults: UserDefaults) throws {
        defaults.set(try JSONSerialization.data(withJSONObject: object), forKey: cache.storageKey(for: key))
    }

    func testOriginalPrefixAndAlphanumericPercentEncoding() {
        withCache { cache, _ in
            XCTAssertEqual(cache.prefix, "beans.lyrics.cache.v1.")
            XCTAssertEqual(cache.maxAge, 1_209_600)
            XCTAssertEqual(cache.storageKey(for: "qq:a/b +_%"), "beans.lyrics.cache.v1.qq%3Aa%2Fb%20%2B%5F%25")
            XCTAssertEqual(cache.storageKey(for: ""), cache.prefix)
        }
    }

    func testRoundTripKeepsTextWhitespaceTranslationAndTiming() {
        withCache { cache, _ in
            cache.save(CachedLyrics_2_0_3(lyric: " raw ", translation: "译文",
                                         wordTiming: "timed", wordFormat: .angleRelative), for: "song")
            let result = cache.load(for: "song")
            XCTAssertEqual(result?.lyric, " raw ")
            XCTAssertEqual(result?.translation, "译文")
            XCTAssertEqual(result?.wordTiming, "timed")
            XCTAssertEqual(result?.wordFormat, .angleRelative)
        }
    }

    func testStoredSchemaUsesDeferredDateAndOmitsNilOptionals() throws {
        try withCache { cache, defaults in
            cache.save(CachedLyrics_2_0_3(lyric: "line"), for: "song")
            let data = try XCTUnwrap(defaults.data(forKey: cache.storageKey(for: "song")))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(Set(object.keys), Set(["lyric", "savedAt"]))
            XCTAssertEqual(object["savedAt"] as? Double, 2_000_000)
        }
    }

    func testFormatRawValuesAndCaseSensitivity() {
        let expected: [(KaraokeSyntax_2_0_3, String)] = [(.parenthesizedAbsolute, "neteaseYRC"),
            (.parenthesizedAutomatic, "qqQRC"), (.angleRelative, "kugouKRC")]
        for (format, raw) in expected {
            XCTAssertEqual(format.cacheRawValue, raw)
            XCTAssertEqual(KaraokeSyntax_2_0_3(cacheRawValue: raw), format)
        }
        XCTAssertNil(KaraokeSyntax_2_0_3(cacheRawValue: "QQQRC"))
        XCTAssertNil(KaraokeSyntax_2_0_3(cacheRawValue: ""))
    }

    func testFreshEntryAcceptedAndExactFourteenDayBoundaryRejectedWithoutDeletion() throws {
        try withCache { cache, defaults in
            try put(["lyric": "fresh", "savedAt": 790_400.001], cache: cache, defaults: defaults)
            XCTAssertEqual(cache.load(for: "song")?.lyric, "fresh")
            try put(["lyric": "boundary", "savedAt": 790_400], cache: cache, defaults: defaults)
            XCTAssertNil(cache.load(for: "song"))
            XCTAssertNotNil(defaults.data(forKey: cache.storageKey(for: "song")))
        }
    }

    func testFutureDatesAreAccepted() throws {
        try withCache { cache, defaults in
            try put(["lyric": "future", "savedAt": 3_000_000], cache: cache, defaults: defaults)
            XCTAssertEqual(cache.load(for: "song")?.lyric, "future")
        }
    }

    func testMutatedMetadataMaxAgeDoesNotOverrideLiteralReadGate() throws {
        try withCache { cache, defaults in
            cache.maxAge = 0
            try put(["lyric": "fresh", "savedAt": 1_999_999], cache: cache, defaults: defaults)
            XCTAssertNotNil(cache.load(for: "song"))
        }
    }

    func testMissingWrongTypeAndMalformedDataReturnNilWithoutRemoval() {
        withCache { cache, defaults in
            XCTAssertNil(cache.load(for: "missing"))
            let key = cache.storageKey(for: "song")
            defaults.set("not data", forKey: key)
            XCTAssertNil(cache.load(for: "song"))
            XCTAssertEqual(defaults.string(forKey: key), "not data")
            let bad = Data("not JSON".utf8)
            defaults.set(bad, forKey: key)
            XCTAssertNil(cache.load(for: "song"))
            XCTAssertEqual(defaults.data(forKey: key), bad)
        }
    }

    func testMissingRequiredFieldsAndWrongOptionalTypeRejectEntry() throws {
        try withCache { cache, defaults in
            for object: [String: Any] in [["lyric": "text"], ["savedAt": 2_000_000],
                ["lyric": "text", "savedAt": 2_000_000, "translation": 12]] {
                try put(object, cache: cache, defaults: defaults)
                XCTAssertNil(cache.load(for: "song"))
            }
        }
    }

    func testEmptyLyricCanBeSavedWithNonemptyTimingAndFormat() {
        withCache { cache, _ in
            cache.save(CachedLyrics_2_0_3(lyric: "", wordTiming: "timing",
                                         wordFormat: .parenthesizedAutomatic), for: "song")
            XCTAssertEqual(cache.load(for: "song")?.lyric, "")
            XCTAssertEqual(cache.load(for: "song")?.wordFormat, .parenthesizedAutomatic)
        }
    }

    func testRejectedEmptyWritesKeepPreviousEntry() {
        withCache { cache, _ in
            cache.save(CachedLyrics_2_0_3(lyric: "keep"), for: "song")
            let invalid = [CachedLyrics_2_0_3(lyric: "", translation: "translation alone"),
                CachedLyrics_2_0_3(lyric: "", wordTiming: "timing"),
                CachedLyrics_2_0_3(lyric: "", wordTiming: "", wordFormat: .angleRelative)]
            for value in invalid {
                cache.save(value, for: "song")
                XCTAssertEqual(cache.load(for: "song")?.lyric, "keep")
            }
        }
    }

    func testWhitespaceIsContentRatherThanTrimmedEmpty() {
        withCache { cache, _ in
            cache.save(CachedLyrics_2_0_3(lyric: " "), for: "song")
            XCTAssertEqual(cache.load(for: "song")?.lyric, " ")
        }
    }

    func testUnknownStoredFormatIsNilButRawPresenceAllowsTimedOnlyEntry() throws {
        try withCache { cache, defaults in
            try put(["lyric": "", "wordTiming": "timed", "wordFormat": "future-format",
                     "savedAt": 2_000_000], cache: cache, defaults: defaults)
            let result = try XCTUnwrap(cache.load(for: "song"))
            XCTAssertEqual(result.wordTiming, "timed")
            XCTAssertNil(result.wordFormat)
        }
    }

    func testEmptyStoredFormatStillSatisfiesPresenceGate() throws {
        try withCache { cache, defaults in
            try put(["lyric": "", "wordTiming": "timed", "wordFormat": "",
                     "savedAt": 2_000_000], cache: cache, defaults: defaults)
            XCTAssertNotNil(cache.load(for: "song"))
            XCTAssertNil(cache.load(for: "song")?.wordFormat)
        }
    }

    func testEmptyStoredLyricRequiresNonemptyTimingAndNonNilFormat() throws {
        try withCache { cache, defaults in
            for object: [String: Any] in [["lyric": "", "wordTiming": "timed", "savedAt": 2_000_000],
                ["lyric": "", "wordTiming": "", "wordFormat": "qqQRC", "savedAt": 2_000_000]] {
                try put(object, cache: cache, defaults: defaults)
                XCTAssertNil(cache.load(for: "song"))
            }
        }
    }

    func testEmptyKeyIsAllowedAndDifferentKeysStayIndependent() {
        withCache { cache, _ in
            cache.save(CachedLyrics_2_0_3(lyric: "empty key"), for: "")
            cache.save(CachedLyrics_2_0_3(lyric: "other"), for: "other")
            XCTAssertEqual(cache.load(for: "")?.lyric, "empty key")
            XCTAssertEqual(cache.load(for: "other")?.lyric, "other")
        }
    }
}
