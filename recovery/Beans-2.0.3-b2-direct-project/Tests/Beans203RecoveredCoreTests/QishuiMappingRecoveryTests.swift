import Foundation
import XCTest
@testable import Beans203RecoveredCore

final class QishuiMappingRecoveryTests: XCTestCase {
    func testStableIDUsesRecoveredSeedAndUTF8() {
        // Expected values computed independently with BigInt from the disassembled constants.
        for (input, expected) in [("", 1469598103934665603), ("123", 4591456448132287629),
                                  ("9223372036854775809", 5388447165788132911),
                                  ("中文", 2304052513158767911), ("é", 1838887021264154987)] {
            XCTAssertEqual(QishuiAPI_2_0_3.stableID(input), expected)
        }
    }

    func testTrackAndPlaylistContainersHaveDifferentFallbacks() {
        let api = QishuiAPI_2_0_3()
        let a: [String: Any] = ["id": "A"]
        let b: [String: Any] = ["id": "B"]
        XCTAssertEqual(api.trackDictionaries(["tracks": [a], "data": [b]]).first?["id"] as? String, "A")
        XCTAssertEqual(api.trackDictionaries(["media_resources": [a]]).count, 1)
        XCTAssertEqual(api.trackDictionaries(["item": a, "ignored": 1]).count, 1)
        XCTAssertTrue(api.playlistDictionaries(["item": a]).isEmpty)
        XCTAssertEqual(api.playlistDictionaries(["playlists": [a], "data": [b]]).first?["id"] as? String, "A")
        XCTAssertEqual(api.dictionaryArray([a, 7, NSNull()] as [Any]).count, 1)
    }

    func testSongWrapperPrecedenceAndLargeIdentifier() throws {
        let api = QishuiAPI_2_0_3()
        let selected: [String: Any] = ["id": "9223372036854775809", "name": "entity track"]
        let song = try XCTUnwrap(api.makeSong([
            "entity": ["track": selected, "track_wrapper": ["track": ["id": "wrapper"]]],
            "track": ["id": "outer"]
        ]))
        XCTAssertEqual(song.qishuiID, "9223372036854775809")
        XCTAssertEqual(song.id, 5388447165788132911)
        XCTAssertEqual(song.name, "entity track")
        XCTAssertEqual(song.source, .qishui)
        XCTAssertEqual(api.makeSong(["track_wrapper": ["track": ["track_id": "wrapped"]]])?.qishuiID, "wrapped")
        XCTAssertNil(api.makeSong(["name": "missing identifier"]))
    }

    func testSongArtistAlbumArtworkAndDurationPrecedence() throws {
        let api = QishuiAPI_2_0_3()
        let song = try XCTUnwrap(api.makeSong([
            "track_id": "123", "title": "Track",
            "artists": [["name": "A"], ["simple_display_name": "B"]],
            "artist": "ignored", "album": ["name": "Album", "cover_url": "https://image.invalid/second"],
            "raw": ["album": ["url_cover": "https://image.invalid/first"]],
            "duration_ms": 210000, "stats": ["is_paid": "YES"], "fee": 9
        ]))
        XCTAssertEqual(song.artists, "A / B")
        XCTAssertEqual(song.album, "Album")
        XCTAssertEqual(song.coverURL?.absoluteString, "https://image.invalid/first")
        XCTAssertEqual(song.duration, 210)
        XCTAssertEqual(song.fee, 1)
        XCTAssertEqual(api.makeSong(["id": "1", "duration": 1000])?.duration, 1000)
        XCTAssertEqual(api.makeSong(["id": "1", "duration": 1001])?.duration, 1.001)
        XCTAssertEqual(api.makeSong(["id": "1", "stats": ["is_vip": false, "is_paid": true], "fee": 3])?.fee, 3)
    }

    func testPlaylistMappingRetainsIDAndFieldPrecedence() throws {
        let api = QishuiAPI_2_0_3()
        let result = try XCTUnwrap(api.makePlaylist(["playlist": [
            "playlist_id": "9223372036854775809", "title": "Title", "name": "ignored",
            "count_tracks": "12", "track_count": 90,
            "creatorName": "Creator", "intro": "Intro"
        ]]))
        XCTAssertEqual(result.qishuiID, "9223372036854775809")
        XCTAssertEqual(result.name, "Title")
        XCTAssertEqual(result.trackCount, 12)
        XCTAssertEqual(result.creatorName, "Creator")
        XCTAssertEqual(result.playlistDescription, "Intro")
        XCTAssertEqual(result.source, .qishui)
        XCTAssertEqual(api.makePlaylist(["id": 123])?.name, "未命名歌单")
        XCTAssertNil(api.makePlaylist(["id": ""]))
    }

    func testURLPrecedenceAndSchemeValidation() {
        XCTAssertNil(QishuiResourceURL_2_0_3.first(in: "file:///cover.jpg"))
        XCTAssertNil(QishuiResourceURL_2_0_3.first(in: "opaque-cover-id"))
        XCTAssertEqual(QishuiResourceURL_2_0_3.first(in: "  //image.invalid/a  ")?.absoluteString, "https://image.invalid/a")
        let object: [String: Any] = ["url": "https://image.invalid/direct", "urls": ["https://image.invalid/fallback"]]
        XCTAssertEqual(QishuiResourceURL_2_0_3.first(in: object)?.absoluteString, "https://image.invalid/direct")
        XCTAssertEqual(QishuiResourceURL_2_0_3.first(in: [false, "https://image.invalid/array"] as [Any])?.path, "/array")
    }

    func testURLDepthBoundaryAndRelativeTemplate() {
        var nested: Any = "https://image.invalid/deep"
        for _ in 0..<7 { nested = [nested] }
        XCTAssertNotNil(QishuiResourceURL_2_0_3.first(in: nested))
        nested = [nested]
        XCTAssertNil(QishuiResourceURL_2_0_3.first(in: nested))
        let value: [String: Any] = ["uri": "album/cover", "urls": ["https://image.invalid/img/"], "template_prefix": " tplv-test "]
        XCTAssertEqual(QishuiResourceURL_2_0_3.first(in: value)?.absoluteString,
                       "https://image.invalid/img/album/cover~tplv-test-crop-center:720:720.jpg")
    }

    func testPlaylistCoverPrefersRawAndDoesNotDuplicateTemplate() {
        let base = "https://p3-luna.douyinpic.com/img/cover"
        let expected = base + "~tplv-b829550vbb-crop-center:720:720.jpg"
        let input: [String: Any] = ["cover_url": "https://image.invalid/flat", "raw": ["url_cover": base]]
        XCTAssertEqual(QishuiResourceURL_2_0_3.playlistCover(in: input)?.absoluteString, expected)
        XCTAssertEqual(QishuiResourceURL_2_0_3.playlistCover(in: ["cover_url": expected])?.absoluteString, expected)
        XCTAssertEqual(QishuiResourceURL_2_0_3.first(in: base)?.absoluteString, base)
    }
}
