import XCTest
@testable import Beans

final class WebDAVRecoveryTests: XCTestCase {
    private var connection: WebDAVConnection { WebDAVConnection(address: "https://dav.example/music/", username: "tester") }

    func testRootAndEscapedUnicodeFiles() throws {
        let root = try WebDAVPaths.root(for: connection)
        let file = try WebDAVPaths.fileURL(path: "专辑/歌曲 01.mp3", root: root)
        XCTAssertEqual(try WebDAVPaths.relativePath(file, root: root), "专辑/歌曲 01.mp3")
        XCTAssertNil(file.user)
        XCTAssertNil(file.query)
    }

    func testTraversalAndOtherOriginsAreRejected() throws {
        let root = try WebDAVPaths.root(for: connection)
        for address in ["https://dav.example/music-other/a.mp3", "https://other.example/music/a.mp3",
                        "http://dav.example/music/a.mp3", "https://dav.example:8443/music/a.mp3",
                        "https://dav.example/music/%2e%2e/a.mp3", "https://dav.example/music/%252e%252e/a.mp3",
                        "https://dav.example/music/a.mp3?token=test", "https://user@dav.example/music/a.mp3"] {
            XCTAssertThrowsError(try WebDAVPaths.validate(URL(string: address)!, root: root), address)
        }
        XCTAssertThrowsError(try WebDAVPaths.fileURL(path: "../private.mp3", root: root))
    }

    func testHTTPRequiresExplicitOptIn() throws {
        var connection = self.connection
        connection.address = "http://dav.example/music/"
        XCTAssertThrowsError(try WebDAVPaths.root(for: connection))
        connection.allowHTTP = true
        XCTAssertEqual(try WebDAVPaths.root(for: connection).scheme, "http")
        connection.address = "https://user:pass@dav.example/music/"
        XCTAssertThrowsError(try WebDAVPaths.root(for: connection))
    }

    func testMultistatusUsesOnlySuccessfulDAVProperties() throws {
        let root = try WebDAVPaths.root(for: connection)
        let xml = """
        <d:multistatus xmlns:d="DAV:" xmlns:x="urn:unrelated">
        <d:response><d:href>/music/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
        <d:response><d:href>/music/album</d:href><d:propstat><d:prop><d:displayname>Album</d:displayname><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
        <d:response><d:href>/music/track.mp3</d:href><d:propstat><d:prop><d:displayname>Track</d:displayname><d:getcontentlength>1234</d:getcontentlength><x:collection/></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat><d:propstat><d:prop><d:displayname>Wrong</d:displayname></d:prop><d:status>HTTP/1.1 404 Not Found</d:status></d:propstat></d:response>
        <d:response><d:href>/music/fail.mp3</d:href><d:propstat><d:prop/><d:status>HTTP/1.1 403 Forbidden</d:status></d:propstat></d:response>
        </d:multistatus>
        """
        let entries = try WebDAVListingParser.parse(Data(xml.utf8), directory: root, root: root)
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries[0].isDirectory)
        XCTAssertTrue(entries[0].url.hasDirectoryPath)
        XCTAssertEqual(entries[1].name, "Track")
        XCTAssertEqual(entries[1].size, 1234)
        XCTAssertFalse(entries[1].isDirectory)
    }

    func testExternalEntitiesAndOutsideRootHrefFail() throws {
        let root = try WebDAVPaths.root(for: connection)
        XCTAssertThrowsError(try WebDAVListingParser.parse(Data("<!DOCTYPE d [<!ENTITY e SYSTEM 'file:///etc/passwd'>]><d:multistatus xmlns:d='DAV:'/>".utf8), directory: root, root: root))
        let xml = "<d:multistatus xmlns:d='DAV:'><d:response><d:href>https://other.example/file.mp3</d:href><d:propstat><d:prop/><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>"
        XCTAssertThrowsError(try WebDAVListingParser.parse(Data(xml.utf8), directory: root, root: root))
    }

    func testForeignPropertyContainersCannotChangeDAVProperties() throws {
        let root = try WebDAVPaths.root(for: connection)
        let xml = """
        <d:multistatus xmlns:d="DAV:" xmlns:x="urn:unrelated">
        <d:response><d:href>/music/track.mp3</d:href>
        <d:propstat><d:prop><d:displayname>Track</d:displayname>
        <x:resourcetype><d:collection/></x:resourcetype>
        <x:wrapper><d:displayname>Wrong</d:displayname><d:getcontentlength>9999</d:getcontentlength></x:wrapper>
        </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
        <x:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></x:propstat>
        </d:response></d:multistatus>
        """
        let entries = try WebDAVListingParser.parse(Data(xml.utf8), directory: root, root: root)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "Track")
        XCTAssertEqual(entries.first?.isDirectory, false)
        XCTAssertNil(entries.first?.size)
    }

    func testWrappedRootAndUTF16EntitiesAreRejected() throws {
        let root = try WebDAVPaths.root(for: connection)
        let wrapped = "<x:wrapper xmlns:x='urn:unrelated'><d:multistatus xmlns:d='DAV:'/></x:wrapper>"
        XCTAssertThrowsError(try WebDAVListingParser.parse(Data(wrapped.utf8), directory: root, root: root))
        let entity = "<?xml version='1.0' encoding='UTF-16'?><!DOCTYPE d [<!ENTITY e 'value'>]><d:multistatus xmlns:d='DAV:'/>"
        XCTAssertThrowsError(try WebDAVListingParser.parse(entity.data(using: .utf16)!, directory: root, root: root))
        let valid = "<?xml version='1.0' encoding='UTF-16'?><d:multistatus xmlns:d='DAV:'/>"
        XCTAssertTrue(try WebDAVListingParser.parse(valid.data(using: .utf16)!, directory: root, root: root).isEmpty)
    }

    func testBackupRoundTripAndSensitiveFields() throws {
        let suite = "beans-webdav-tests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data([0, 1, 2, 255]), forKey: "beans.localLibrary.playlists")
        defaults.set("do-not-export", forKey: "beans.thirdPartyAPIKeys")
        defaults.set("do-not-export", forKey: "beans.example.password")
        defaults.set("account", forKey: "beans.user")
        let data = try WebDAVBackup.export(defaults: defaults)
        let values = try WebDAVBackup.validated(data)
        XCTAssertEqual(values["beans.localLibrary.playlists"] as? Data, Data([0, 1, 2, 255]))
        XCTAssertNil(values["beans.thirdPartyAPIKeys"])
        XCTAssertNil(values["beans.example.password"])
        XCTAssertNil(values["beans.user"])
        XCTAssertThrowsError(try WebDAVBackup.validated(Data("{\"beans.setting\":true}".utf8)))
    }

    func testSongKeepsRemoteIdentityThroughPersistence() throws {
        let track = WebDAVTrack(connectionID: connection.id, relativePath: "album/track.mp3", accountKey: connection.accountKey)
        let song = Song(id: 12, name: "Track", artists: "WebDAV", album: "Album", coverURL: nil, duration: 0, source: .webdav, webDAVTrack: track)
        let restored = try JSONDecoder().decode(Song.self, from: JSONEncoder().encode(song))
        XCTAssertEqual(restored.webDAVTrack, track)
        XCTAssertEqual(restored.identityKey, song.identityKey)
        XCTAssertNil(restored.officialURL)
        XCTAssertFalse(restored.isVIP)
        XCTAssertTrue(ThirdPartyAudioQuality.supported(for: .webdav).isEmpty)
    }
}
