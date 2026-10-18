import XCTest
@testable import Beans203RecoveredCore

final class WebDAVListingParserTests: XCTestCase {
    func testParsesFilesAndCollectionsAndSkipsFailedPropstats() throws {
        let xml = """
        <d:multistatus xmlns:d="DAV:">
          <d:response>
            <d:href>/library/track.flac</d:href>
            <d:propstat>
              <d:prop>
                <d:displayname>Track.flac</d:displayname>
                <d:getcontentlength>512</d:getcontentlength>
                <d:resourcetype/>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
          <d:response>
            <d:href>/library/Album/</d:href>
            <d:propstat>
              <d:prop>
                <d:displayname>Album</d:displayname>
                <d:resourcetype><d:collection/></d:resourcetype>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
          <d:response>
            <d:href>/library/forbidden.flac</d:href>
            <d:propstat>
              <d:prop><d:displayname>Forbidden</d:displayname></d:prop>
              <d:status>HTTP/1.1 404 Not Found</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """

        let base = try XCTUnwrap(URL(string: "https://dav.example.test/root/"))
        let entries = try WebDAVListingParser_2_0_3().parse(Data(xml.utf8), baseURL: base)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].name, "Track.flac")
        XCTAssertEqual(entries[0].url.absoluteString, "https://dav.example.test/library/track.flac")
        XCTAssertFalse(entries[0].isDirectory)
        XCTAssertEqual(entries[0].size, 512)
        XCTAssertEqual(entries[1].name, "Album")
        XCTAssertTrue(entries[1].isDirectory)
    }

    func testRejectsExternalEntityDeclarations() throws {
        let xml = """
        <!DOCTYPE d:multistatus [<!ENTITY ext SYSTEM "file:///etc/passwd">]>
        <d:multistatus xmlns:d="DAV:">
          <d:response><d:href>&ext;</d:href></d:response>
        </d:multistatus>
        """
        let base = try XCTUnwrap(URL(string: "https://dav.example.test/"))

        XCTAssertThrowsError(try WebDAVListingParser_2_0_3().parse(Data(xml.utf8), baseURL: base))
    }

    func testRejectsListingAboveEightMiBLimitBeforeParsing() throws {
        let base = try XCTUnwrap(URL(string: "https://dav.example.test/"))
        let oversized = Data(repeating: 0x20, count: 0x800001)

        XCTAssertThrowsError(try WebDAVListingParser_2_0_3().parse(oversized, baseURL: base)) { error in
            guard case WebDAVError_2_0_3.tooLarge = error else {
                return XCTFail("Expected the parser's listing size limit, got \(error)")
            }
        }
    }
}
