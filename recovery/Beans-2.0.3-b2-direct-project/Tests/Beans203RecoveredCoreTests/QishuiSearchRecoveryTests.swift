import Foundation
import XCTest
@testable import Beans203RecoveredCore

private final class QishuiSearchFixtureProtocol: URLProtocol {
    static let lock = NSLock()
    static var responses: [Result<Data, Error>] = []
    static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        let result: Result<Data, Error> = Self.responses.isEmpty
            ? .failure(URLError(.notConnectedToInternet)) : Self.responses.removeFirst()
        Self.lock.unlock()
        switch result {
        case .success(let data):
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error): client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

@MainActor private final class QishuiProgressRecorder {
    var snapshots: [[String]] = []
    func record(_ songs: [Song_2_0_3]) { snapshots.append(songs.compactMap(\.qishuiID)) }
}

final class QishuiSearchRecoveryTests: XCTestCase {
    private var api: QishuiAPI_2_0_3!
    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [QishuiSearchFixtureProtocol.self]
        let defaults = UserDefaults(suiteName: "QishuiSearchTests.\(UUID().uuidString)")!
        defaults.set("https://fixture.invalid/qishui", forKey: QishuiAPI_2_0_3.baseURLKey)
        api = QishuiAPI_2_0_3(session: URLSession(configuration: configuration), defaults: defaults)
        QishuiSearchFixtureProtocol.responses = []
        QishuiSearchFixtureProtocol.requests = []
    }
    override func tearDown() {
        api.session.invalidateAndCancel()
        api.recoveryDefaults.removeObject(forKey: QishuiAPI_2_0_3.baseURLKey)
        api = nil
        super.tearDown()
    }
    private func enqueue(_ object: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: ["data": object])
        QishuiSearchFixtureProtocol.lock.lock()
        QishuiSearchFixtureProtocol.responses.append(.success(data))
        QishuiSearchFixtureProtocol.lock.unlock()
    }
    private func page(_ ids: [String], more: Any? = nil, next: Any? = nil) throws {
        var object: [String: Any] = ["tracks": ids.map { ["id": $0, "name": $0] }]
        object["has_more"] = more
        object["next_cursor"] = next
        try enqueue(object)
    }
    private func requests() -> [URLRequest] {
        QishuiSearchFixtureProtocol.lock.lock()
        defer { QishuiSearchFixtureProtocol.lock.unlock() }
        return QishuiSearchFixtureProtocol.requests
    }
    private func query(_ request: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            .queryItems!.map { ($0.name, $0.value!) })
    }
    private func seed(age: TimeInterval, limit: Int = 3) {
        let key = api.catalogCacheKey("songs", query: "music", limit: limit)
        api.songSearchCache.setObject(QishuiCacheBox_2_0_3(
            value: [Song_2_0_3(name: "Cached", qishuiID: "cached")], savedAt: Date().addingTimeInterval(-age)
        ), forKey: key as NSString)
    }

    func testBlankQueryAndFreshCacheAvoidRequestsAndProgress() async throws {
        let recorder = await QishuiProgressRecorder()
        let empty = try await api.searchSongs(keyword: "   ", limit: 10)
        XCTAssertTrue(empty.isEmpty)
        seed(age: 100)
        api.songSearchTTL = 0 // Binary search call site uses a constant.
        let cached = try await api.searchSongs(keyword: " MUSIC ", limit: 3, onProgress: { recorder.record($0) })
        XCTAssertEqual(cached.first?.name, "Cached")
        let snapshots = await recorder.snapshots
        XCTAssertTrue(snapshots.isEmpty); XCTAssertTrue(requests().isEmpty)
    }

    func testSearchClampsMinimumAndPreservesQueryCase() async throws {
        try page(["a", "b"])
        let result = try await api.searchSongs(keyword: "  MuSiC  ", limit: -1)
        XCTAssertEqual(result.compactMap(\.qishuiID), ["a"])
        XCTAssertEqual(query(requests()[0]), ["keywords": "MuSiC", "count": "1", "cursor": "0", "offset": "0"])
        XCTAssertEqual(requests()[0].url?.path, "/qishui/search/mixed")
        XCTAssertEqual(requests()[0].timeoutInterval, 15)
    }

    func testUpperLimitAndHundredItemPageSize() async throws {
        try page((0..<100).map(String.init), more: true, next: 100)
        try page((100..<205).map(String.init), more: true, next: 205)
        let result = try await api.searchSongs(keyword: "music", limit: 999)
        XCTAssertEqual(result.count, 200); XCTAssertEqual(result.last?.qishuiID, "199")
        XCTAssertEqual(requests().count, 2)
        XCTAssertEqual(query(requests()[0])["count"], "100")
        XCTAssertEqual(query(requests()[1])["count"], "100")
        XCTAssertEqual(query(requests()[1])["cursor"], "100")
    }

    func testMixedEmptyFallbackUsesSameQueryAndFallbackPagination() async throws {
        try enqueue(["tracks": [["name": "no identifier"]], "has_more": false])
        try page(["a"], more: true, next: 7)
        try page(["b"])
        let result = try await api.searchSongs(keyword: "music", limit: 3)
        XCTAssertEqual(result.compactMap(\.qishuiID), ["a", "b"])
        XCTAssertEqual(requests().map { $0.url!.path }, ["/qishui/search/mixed", "/qishui/search", "/qishui/search/mixed"])
        XCTAssertEqual(query(requests()[0]), query(requests()[1]))
        XCTAssertEqual(query(requests()[2])["offset"], "7")
        XCTAssertEqual(query(requests()[2])["count"], "2")
    }

    func testDedupUsesOriginalStringIDAndProgressOnlyOnGrowth() async throws {
        let recorder = await QishuiProgressRecorder()
        try page(["01", "1", "01"], more: true, next: 3)
        try page(["1"], more: true, next: 4)
        try page(["9223372036854775809"], more: false)
        let result = try await api.searchSongs(keyword: "music", limit: 4, onProgress: { recorder.record($0) })
        XCTAssertEqual(result.compactMap(\.qishuiID), ["01", "1", "9223372036854775809"])
        let snapshots = await recorder.snapshots
        XCTAssertEqual(snapshots, [["01", "1"], ["01", "1", "9223372036854775809"]])
        XCTAssertEqual(query(requests()[1])["count"], "2")
    }

    func testTenRoundBoundStopsDuplicatePages() async throws {
        for _ in 0..<10 { try page(["a"], more: true) }
        let result = try await api.searchSongs(keyword: "music", limit: 2)
        XCTAssertEqual(result.count, 1); XCTAssertEqual(requests().count, 10)
        XCTAssertEqual(query(requests().last!)["offset"], "9")
    }

    func testSuccessfulResultsPopulateFreshCache() async throws {
        try page(["a"])
        _ = try await api.searchSongs(keyword: "music", limit: 3)
        let cached = try await api.searchSongs(keyword: "MUSIC", limit: 3)
        XCTAssertEqual(cached.first?.qishuiID, "a"); XCTAssertEqual(requests().count, 1)
    }

    func testEmptyPagesAndTransportFailureUseStaleCache() async throws {
        seed(age: 3600)
        try page([]); try page([])
        let empty = try await api.searchSongs(keyword: "music", limit: 3)
        XCTAssertEqual(empty.first?.qishuiID, "cached")
        let failed = try await api.searchSongs(keyword: "music", limit: 3)
        XCTAssertEqual(failed.first?.qishuiID, "cached")
        XCTAssertEqual(requests().count, 3)
    }

    func testExpiredCacheAndFirstRequestFailurePropagateWithoutFallback() async {
        seed(age: 172801)
        do { _ = try await api.searchSongs(keyword: "music", limit: 3); XCTFail("Expected error") }
        catch { XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet) }
        XCTAssertEqual(requests().count, 1)
    }

    func testLaterFailureReturnsPartialResultsWithoutCachingThem() async throws {
        seed(age: 3600)
        try page(["new"], more: true)
        let partial = try await api.searchSongs(keyword: "music", limit: 3)
        XCTAssertEqual(partial.first?.qishuiID, "new")
        let stale = try await api.searchSongs(keyword: "music", limit: 3)
        XCTAssertEqual(stale.first?.qishuiID, "cached")
        XCTAssertEqual(requests().count, 3)
    }

    func testCancellationIsNotHiddenByStaleCache() async {
        seed(age: 3600)
        let api = api!
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await api.searchSongs(keyword: "music", limit: 3)
        }
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(requests().isEmpty)
    }

    func testPaginationScopeAndKeyPrecedence() throws {
        let value = try QishuiAPI_2_0_3.searchPagination([
            "hasMore": false, "nextCursor": "9",
            "upstream": ["has_more": true, "next_offset": 20]
        ], offset: 0, mappedCount: 2)
        XCTAssertFalse(value.hasMore); XCTAssertEqual(value.nextOffset, 9)
        let nested = try QishuiAPI_2_0_3.searchPagination([
            "upstream": ["data": ["pagination": ["hasNext": "YES", "cursor": "+12"]]]
        ], offset: 5, mappedCount: 1)
        XCTAssertTrue(nested.hasMore); XCTAssertEqual(nested.nextOffset, 12)
    }

    func testPaginationFirstPresentNullDoesNotSkipToOtherKeys() throws {
        let value = try QishuiAPI_2_0_3.searchPagination([
            "has_more": NSNull(), "hasMore": true, "next_offset": NSNull(),
            "next_cursor": 20, "upstream": ["has_more": true, "next_offset": 40]
        ], offset: 5, mappedCount: 2)
        XCTAssertFalse(value.hasMore); XCTAssertEqual(value.nextOffset, 7)
    }

    func testPaginationUnknownBooleanUsesAdvancingCursorOnly() throws {
        for more in ["on", " true ", "unknown"] {
            let value = try QishuiAPI_2_0_3.searchPagination(["has_more": more], offset: 8, mappedCount: 3)
            XCTAssertFalse(value.hasMore); XCTAssertEqual(value.nextOffset, 11)
        }
        let inferred = try QishuiAPI_2_0_3.searchPagination(["next_cursor": 11], offset: 8, mappedCount: 3)
        XCTAssertTrue(inferred.hasMore)
        let explicit = try QishuiAPI_2_0_3.searchPagination(["has_more": true, "cursor": 8], offset: 8, mappedCount: 3)
        XCTAssertTrue(explicit.hasMore); XCTAssertEqual(explicit.nextOffset, 11)
    }

    func testPaginationIntegerConversionAndOverflow() throws {
        let numeric = try QishuiAPI_2_0_3.searchPagination(["next_offset": 10.9], offset: 0, mappedCount: 1)
        XCTAssertEqual(numeric.nextOffset, 10); XCTAssertTrue(numeric.hasMore)
        for text in ["10.9", " 10", "9223372036854775808"] {
            let value = try QishuiAPI_2_0_3.searchPagination(["next_offset": text], offset: 0, mappedCount: 0)
            XCTAssertEqual(value.nextOffset, 1); XCTAssertFalse(value.hasMore)
        }
        XCTAssertThrowsError(try QishuiAPI_2_0_3.searchPagination([:], offset: Int.max, mappedCount: 1))
    }
}
