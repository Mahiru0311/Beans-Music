import Foundation
import XCTest
@testable import Beans203RecoveredCore

final class SongIdentityRecoveryTests: XCTestCase {
    func testEveryProviderNameMatchesOriginalTagTable() {
        XCTAssertEqual(SongSource_2_0_3.allCases.map { $0.providerIdentifier },
                       ["netease", "qq", "kugou", "kuwo", "migu", "qishui", "bilibili", "webdav"])
    }

    func testFiveProvidersUseNumericPlaybackIdentityDespiteOtherIdentifiers() {
        for provider: SongSource_2_0_3 in [.netease, .qq, .kugou, .kuwo, .migu] {
            let song = Song_2_0_3(id: 123, source: provider, qqMid: "mid", kugouHash: "hash",
                                 miguCopyrightId: "copyright", qishuiID: "external", bilibiliID: "BV")
            XCTAssertEqual(song.playbackKey, provider.providerIdentifier + "-123")
        }
    }

    func testQishuiAndBilibiliUseTheirOwnStringIdentifier() {
        XCTAssertEqual(Song_2_0_3(id: 1, source: .qishui, qishuiID: "001/a").playbackKey, "qishui-001/a")
        XCTAssertEqual(Song_2_0_3(id: 1, source: .bilibili, bilibiliID: "BV-A").playbackKey, "bilibili-BV-A")
    }

    func testMissingQishuiAndBilibiliIdentifiersUseNumericFallback() {
        XCTAssertEqual(Song_2_0_3(id: -12, source: .qishui).playbackKey, "qishui--12")
        XCTAssertEqual(Song_2_0_3(id: 0, source: .bilibili).playbackKey, "bilibili-0")
    }

    func testEmptyIdentifiersDoNotTriggerPlaybackFallback() {
        XCTAssertEqual(Song_2_0_3(id: 12, source: .qishui, qishuiID: "").playbackKey, "qishui-")
        XCTAssertEqual(Song_2_0_3(id: 12, source: .bilibili, bilibiliID: "").playbackKey, "bilibili-")
    }

    func testWebDAVUsesAccountKeyAndUnmodifiedRelativePath() {
        let track = WebDAVTrack_2_0_3(connectionID: UUID(), relativePath: "/音乐/a b.flac", accountKey: "host/user")
        XCTAssertEqual(Song_2_0_3(id: 9, source: .webdav, webDAV: track).playbackKey,
                       "webdav-host/user-/音乐/a b.flac")
    }

    func testWebDAVFallsBackToUppercaseConnectionUUID() {
        let uuid = UUID(uuidString: "abcdef12-3456-7890-abcd-ef1234567890")!
        let track = WebDAVTrack_2_0_3(connectionID: uuid, relativePath: "song.mp3")
        XCTAssertEqual(Song_2_0_3(id: 9, source: .webdav, webDAV: track).playbackKey,
                       "webdav-ABCDEF12-3456-7890-ABCD-EF1234567890-song.mp3")
    }

    func testEmptyWebDAVAccountKeyAndPathStayEmpty() {
        let track = WebDAVTrack_2_0_3(connectionID: UUID(), relativePath: "", accountKey: "")
        XCTAssertEqual(Song_2_0_3(id: 9, source: .webdav, webDAV: track).playbackKey, "webdav--")
    }

    func testMissingWebDAVTrackUsesMissingAndNumericID() {
        XCTAssertEqual(Song_2_0_3(id: -7, source: .webdav).playbackKey, "webdav-missing--7")
    }

    func testLyricKeysUseProviderIDsWhereAvailable() {
        XCTAssertEqual(Song_2_0_3(id: 1, source: .qq, qqMid: "mid").lyricCacheKey, "qq:mid")
        XCTAssertEqual(Song_2_0_3(id: 1, source: .kugou, kugouHash: "hash").lyricCacheKey, "kugou:hash")
        XCTAssertEqual(Song_2_0_3(id: 1, source: .qishui, qishuiID: "track").lyricCacheKey, "qishui:track")
        XCTAssertEqual(Song_2_0_3(id: 1, source: .bilibili, bilibiliID: "BV").lyricCacheKey, "bilibili:BV")
    }

    func testLyricKeyMissingProviderIDUsesFullPlaybackKey() {
        for provider: SongSource_2_0_3 in [.qq, .kugou, .qishui, .bilibili] {
            let song = Song_2_0_3(id: 23, source: provider)
            XCTAssertEqual(song.lyricCacheKey, provider.providerIdentifier + ":" + provider.providerIdentifier + "-23")
        }
    }

    func testEmptyProviderIDDoesNotTriggerLyricKeyFallback() {
        XCTAssertEqual(Song_2_0_3(id: 23, source: .qq, qqMid: "").lyricCacheKey, "qq:")
        XCTAssertEqual(Song_2_0_3(id: 23, source: .kugou, kugouHash: "").lyricCacheKey, "kugou:")
        XCTAssertEqual(Song_2_0_3(id: 23, source: .qishui, qishuiID: "").lyricCacheKey, "qishui:")
        XCTAssertEqual(Song_2_0_3(id: 23, source: .bilibili, bilibiliID: "").lyricCacheKey, "bilibili:")
    }

    func testNetEaseKuwoAndMiguLyricKeysUseNumericID() {
        for provider: SongSource_2_0_3 in [.netease, .kuwo, .migu] {
            let song = Song_2_0_3(id: -9, source: provider, miguCopyrightId: "ignored")
            XCTAssertEqual(song.lyricCacheKey, provider.providerIdentifier + ":-9")
        }
    }

    func testWebDAVHasNoKeyForThisLyricLoader() {
        XCTAssertNil(Song_2_0_3(source: .webdav).lyricCacheKey)
        let track = WebDAVTrack_2_0_3(connectionID: UUID(), relativePath: "song.mp3")
        XCTAssertNil(Song_2_0_3(source: .webdav, webDAV: track).lyricCacheKey)
    }

    func testMetadataChangesDoNotChangePlaybackOrLyricKey() {
        let first = Song_2_0_3(id: 17, name: "old", artists: "one", source: .qq, qqMid: "mid")
        let second = Song_2_0_3(id: 17, name: "new", artists: "two", duration: 500, source: .qq, qqMid: "mid")
        XCTAssertEqual(first.playbackKey, second.playbackKey)
        XCTAssertEqual(first.lyricCacheKey, second.lyricCacheKey)
    }

    func testSongCacheOverloadsUseOriginalKeyAndSkipWebDAVWrites() {
        let suite = "Beans203SongCacheTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let cache = LyricsCache_2_0_3(defaults: defaults)
        let song = Song_2_0_3(id: 3, source: .qq, qqMid: "a/b")
        cache.save(CachedLyrics_2_0_3(lyric: "text"), for: song)
        XCTAssertEqual(cache.load(for: song)?.lyric, "text")
        XCTAssertEqual(cache.load(for: "qq:a/b")?.lyric, "text")
        XCTAssertNotNil(defaults.data(forKey: "beans.lyrics.cache.v1.qq%3Aa%2Fb"))
        let originalKeys = defaults.dictionaryRepresentation().keys.sorted()
        let webdav = Song_2_0_3(id: 3, source: .webdav)
        cache.save(CachedLyrics_2_0_3(lyric: "skip"), for: webdav)
        XCTAssertNil(cache.load(for: webdav))
        XCTAssertEqual(defaults.dictionaryRepresentation().keys.sorted(), originalKeys)
    }
}
