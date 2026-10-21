import Foundation
import XCTest
@testable import Beans203RecoveredCore

final class QishuiAlbumRecoveryTests: XCTestCase {
    func testBlankAlbumIsExcludedButPunctuationOnlyAlbumIsRetained() {
        let songs = [Song_2_0_3(album: " "), Song_2_0_3(album: ""), Song_2_0_3(album: "---")]
        let result = QishuiAPI_2_0_3.albums(from: songs, limit: 10)
        XCTAssertEqual(result.map { $0.name }, ["---"])
    }

    func testNormalizedGroupKeepsFirstOriginalMetadataAndCountsAllSongs() {
        let cover = URL(string: "https://fixture.invalid/first.jpg")!
        let songs = [
            Song_2_0_3(artists: "BÉ-YONCÉ", album: "  Álbum! ", coverURL: cover),
            Song_2_0_3(artists: "beyonce", album: "album"),
            Song_2_0_3(artists: "Beyoncé", album: "ALBUM")
        ]
        let result = QishuiAPI_2_0_3.albums(from: songs, limit: 10)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "  Álbum! ")
        XCTAssertEqual(result[0].artistName, "BÉ-YONCÉ")
        XCTAssertEqual(result[0].coverURL, cover)
        XCTAssertEqual(result[0].trackCount, 3)
        XCTAssertEqual(result[0].source, .qishui)
        XCTAssertEqual(result[0].id, "qishui-album-" + String(QishuiAPI_2_0_3.stableID("  Álbum! |BÉ-YONCÉ")))
        XCTAssertNil(result[0].releaseType)
        XCTAssertNil(result[0].releaseDate)
        XCTAssertNil(result[0].albumDescription)
    }

    func testWholeArtistStringDistinguishesGroupsAndKeepsCollaboratorOrder() {
        let songs = [
            Song_2_0_3(artists: "A / B", album: "Album"),
            Song_2_0_3(artists: "B / A", album: "Album"),
            Song_2_0_3(artists: "Other", album: "Album")
        ]
        let result = QishuiAPI_2_0_3.albums(from: songs, limit: 10)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(Set(result.map { $0.artistName }), Set(["A / B", "B / A", "Other"]))
    }

    func testMissingFirstCoverDoesNotUseLaterCover() {
        let songs = [Song_2_0_3(album: "Album"),
                     Song_2_0_3(album: "Album", coverURL: URL(string: "https://fixture.invalid/later.jpg"))]
        let result = QishuiAPI_2_0_3.albums(from: songs, limit: 1)
        XCTAssertNil(result[0].coverURL)
        XCTAssertEqual(result[0].trackCount, 2)
    }

    func testLocalizedNaturalSortPrecedesPrefix() {
        let songs = ["Album 10", "Album 2", "Album 1"].map { Song_2_0_3(album: $0) }
        let result = QishuiAPI_2_0_3.albums(from: songs, limit: 2)
        XCTAssertEqual(result.map { $0.name }, ["Album 1", "Album 2"])
    }

    func testEmptyAndZeroLimitReturnNoAlbums() {
        XCTAssertTrue(QishuiAPI_2_0_3.albums(from: [], limit: 2).isEmpty)
        XCTAssertTrue(QishuiAPI_2_0_3.albums(from: [Song_2_0_3(album: "Album")], limit: 0).isEmpty)
    }
}
