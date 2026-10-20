import Foundation
import XCTest
@testable import Beans203RecoveredCore

final class QishuiRequestRecoveryTests: XCTestCase {
    private func api() -> QishuiAPI_2_0_3 {
        let name = "QishuiRecoveryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return QishuiAPI_2_0_3(defaults: defaults, version: "2.0.3")
    }

    private func response(_ status: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://example.invalid/qishui")!,
                        statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    private func decode(_ json: String, status: Int = 200) throws -> Any {
        try QishuiAPI_2_0_3.decodeResponse(data: Data(json.utf8), response: response(status))
    }

    func testInitializationMatchesFourCacheAndSessionConstants() {
        let client = api()
        XCTAssertEqual(client.songSearchTTL, 300)
        XCTAssertEqual(client.playlistSearchTTL, 300)
        XCTAssertEqual(client.recommendationTTL, 1800)
        XCTAssertEqual(client.playlistDetailsTTL, 1800)
        XCTAssertEqual(client.songSearchCache.countLimit, 40)
        XCTAssertEqual(client.playlistSearchCache.countLimit, 40)
        XCTAssertEqual(client.recommendationCache.countLimit, 8)
        XCTAssertEqual(client.playlistDetailsCache.countLimit, 24)
        XCTAssertEqual(client.session.configuration.timeoutIntervalForRequest, 20)
        XCTAssertEqual(client.session.configuration.timeoutIntervalForResource, 30)
        XCTAssertEqual(client.session.configuration.requestCachePolicy, .reloadIgnoringLocalCacheData)
    }

    func testRequestPreservesBasePathAndExactIdentifierWithoutSendingTraffic() throws {
        let client = api()
        let request = try client.makeRequest("/playlist/detail/", query: [
            "playlist_id": "9223372036854775809", "keywords": "中文 & + /"
        ])
        let components = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.host, "189.24.78.193")
        XCTAssertEqual(components.path, "/qishui/playlist/detail")
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(query["playlist_id"], "9223372036854775809")
        XCTAssertEqual(query["keywords"], "中文 & + /")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "Beans-Music/2.0.3")
        XCTAssertNil(request.httpBody)
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
    }

    func testFastPathMembershipUsesUntrimmedPathLikeBinary() throws {
        let client = api()
        for path in ["/search/mixed", "/search", "/search/playlist", "/recommend/playlist"] {
            XCTAssertEqual(try client.makeRequest(path).timeoutInterval, 15, path)
        }
        for path in ["/playlist/detail", "/search/", "search", "/audio/info"] {
            XCTAssertEqual(try client.makeRequest(path).timeoutInterval, 20, path)
        }
    }

    func testOverrideAndJSONBodyAreApplied() throws {
        let client = api()
        client.recoveryDefaults.set("https://example.invalid/custom?old=1", forKey: QishuiAPI_2_0_3.baseURLKey)
        defer { client.recoveryDefaults.removeObject(forKey: QishuiAPI_2_0_3.baseURLKey) }
        let request = try client.makeRequest("/search", method: "POST", query: ["new": "2"], body: ["id": "123"])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.host, "example.invalid")
        XCTAssertEqual(request.url?.query, "new=2")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: String]
        XCTAssertEqual(body, ["id": "123"])
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
    }

    func testHTTPStatusGateRunsBeforeJSONParsing() throws {
        for code in [199, 300, 401, 500] {
            XCTAssertThrowsError(try decode("not json", status: code)) {
                XCTAssertEqual($0 as? QishuiAPIError_2_0_3, .server("汽水音乐服务器请求失败"))
            }
        }
        for code in [200, 299] { XCTAssertNoThrow(try decode("{}", status: code)) }
        let nonHTTP = URLResponse(url: URL(string: "file:///unused")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        XCTAssertThrowsError(try QishuiAPI_2_0_3.decodeResponse(data: Data("{}".utf8), response: nonHTTP))
    }

    func testJSONShapeAndMissingVersusNullData() throws {
        for json in ["[1,2]", "broken", "null"] {
            XCTAssertThrowsError(try decode(json)) {
                XCTAssertEqual($0 as? QishuiAPIError_2_0_3, .invalidResponse)
            }
        }
        XCTAssertEqual((try decode("{}") as? [String: Any])?.count, 0)
        XCTAssertTrue(try decode("{\"data\":null}") is NSNull)
        XCTAssertEqual(try decode("{\"data\":[1,2]}") as? [Int], [1,2])
        XCTAssertEqual(try decode("{\"data\":\"value\"}") as? String, "value")
    }

    func testApplicationCodesAndOrderedErrorMessages() throws {
        let failures: [(String, String)] = [
            ("{\"code\":7,\"message\":\"first\",\"msg\":\"second\"}", "first"),
            ("{\"code\":\"-1\",\"message\":\"\",\"msg\":\"fallback\"}", "fallback"),
            ("{\"code\":1,\"message\":42}", "42"),
            ("{\"code\":1}", "汽水音乐接口返回失败")
        ]
        for (json, message) in failures {
            XCTAssertThrowsError(try decode(json)) {
                XCTAssertEqual($0 as? QishuiAPIError_2_0_3, .server(message))
            }
        }
        for code in ["\"0\"", "\"not numeric\"", "null", "0.9"] {
            XCTAssertNoThrow(try decode("{\"code\":\(code),\"data\":[]}"))
        }
        for code in ["\"nan\"", "\"inf\"", "1e30"] {
            XCTAssertThrowsError(try decode("{\"code\":\(code)}")) {
                XCTAssertEqual($0 as? QishuiAPIError_2_0_3, .invalidResponse)
            }
        }
    }

    func testCacheKeyNormalizationAndStrictExpiryBoundaries() {
        let client = api()
        XCTAssertEqual(client.catalogCacheKey("songs", query: "  CAFÉ\n", limit: 30),
                       "songs|http://189.24.78.193/qishui|30|cafe")
        let cache = NSCache<NSString, QishuiCacheBox_2_0_3<Int>>()
        let savedAt = Date(timeIntervalSince1970: 1_000)
        cache.setObject(QishuiCacheBox_2_0_3(value: 42, savedAt: savedAt), forKey: "k")
        for (age, fresh, stale) in [(299.0, 42 as Int?, nil as Int?), (300.0, nil, 42), (599.0, nil, 42), (600.0, nil, nil)] {
            let result = client.cacheLookup(cache, key: "k", ttl: 300, staleTTL: 600, now: savedAt.addingTimeInterval(age))
            XCTAssertEqual(result.fresh, fresh)
            XCTAssertEqual(result.stale, stale)
        }
        XCTAssertNotNil(cache.object(forKey: "k"), "The binary does not evict an expired entry during lookup")
        let missing = client.cacheLookup(cache, key: "absent", ttl: 300, staleTTL: 600)
        XCTAssertNil(missing.fresh)
        XCTAssertNil(missing.stale)
    }
}
