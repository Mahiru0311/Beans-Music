import Foundation
import XCTest
@testable import Beans203RecoveredCore

private final class QishuiDetailsFixtureProtocol: URLProtocol {
    static let lock = NSLock()
    static var responses: [Data] = []
    static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        let data = Self.responses.isEmpty ? nil : Self.responses.removeFirst()
        Self.lock.unlock()
        guard let data else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)); return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor private final class QishuiDetailsRecorder {
    var snapshots: [[String]] = []
    func record(_ songs: [Song_2_0_3]) { snapshots.append(songs.compactMap(\.qishuiID)) }
}

final class QishuiPlaylistDetailsRecoveryTests: XCTestCase {
    private var api: QishuiAPI_2_0_3!
    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [QishuiDetailsFixtureProtocol.self]
        let defaults = UserDefaults(suiteName: "QishuiDetailsTests.\(UUID().uuidString)")!
        defaults.set("https://fixture.invalid/qishui", forKey: QishuiAPI_2_0_3.baseURLKey)
        api = QishuiAPI_2_0_3(session: URLSession(configuration: configuration), defaults: defaults)
        QishuiDetailsFixtureProtocol.responses = []
        QishuiDetailsFixtureProtocol.requests = []
    }
    override func tearDown() {
        api.session.invalidateAndCancel()
        api.recoveryDefaults.removeObject(forKey: QishuiAPI_2_0_3.baseURLKey)
        api = nil
        super.tearDown()
    }
    private func enqueue(_ object: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: ["data": object])
        QishuiDetailsFixtureProtocol.lock.lock()
        QishuiDetailsFixtureProtocol.responses.append(data)
        QishuiDetailsFixtureProtocol.lock.unlock()
    }
    private func page(_ ids: [String], cursor: Any? = nil, session: String? = nil, title: String? = nil) throws {
        var object: [String: Any] = ["tracks": ids.map { ["id": $0] }]
        object["next_cursor"] = cursor
        object["session_id"] = session
        if let title { object["playlist"] = ["id": "P", "title": title] }
        try enqueue(object)
    }
    private func requests() -> [URLRequest] {
        QishuiDetailsFixtureProtocol.lock.lock()
        defer { QishuiDetailsFixtureProtocol.lock.unlock() }
        return QishuiDetailsFixtureProtocol.requests
    }
    private func query(_ request: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            .queryItems!.map { ($0.name, $0.value!) })
    }
    private func seed(age: TimeInterval, id: String = "P", limit: Int = 3, songs: [Song_2_0_3]? = nil) {
        let key = api.playlistDetailsCacheKey(id: id, limit: limit)
        let result = QishuiPlaylistDetails_2_0_3(playlist: Playlist_2_0_3(name: "Cached"),
            songs: songs ?? [Song_2_0_3(qishuiID: "cached")])
        api.playlistDetailsCache.setObject(QishuiCacheBox_2_0_3(value: result,
            savedAt: Date().addingTimeInterval(-age)), forKey: key as NSString)
    }

    func testInitialRequestPreservesIDClampsMinimumAndMapsMetadata() async throws {
        try page(["a", "b"], title: "Playlist")
        let result = try await api.playlistDetails(id: " P ", limit: 0, forceRefresh: false)
        XCTAssertEqual(result.playlist?.name, "Playlist")
        XCTAssertEqual(result.songs.compactMap(\.qishuiID), ["a"])
        XCTAssertEqual(query(requests()[0]), ["playlist_id": " P ", "count": "1"])
        XCTAssertEqual(requests()[0].url?.path, "/qishui/playlist/detail")
        XCTAssertEqual(requests()[0].timeoutInterval, 20)
    }

    func testEmptyIdentifierStillRequestsServer() async throws {
        try page([])
        let result = try await api.playlistDetails(id: "", limit: 1, forceRefresh: false)
        XCTAssertTrue(result.songs.isEmpty)
        XCTAssertEqual(query(requests()[0])["playlist_id"], "")
    }

    func testStringCursorSessionAndConstantCountAcrossPages() async throws {
        try page(["a"], cursor: "opaque-A", session: "session-one", title: "Original")
        try page(["b"], cursor: "opaque-B", session: "replacement", title: "Later")
        try page(["c"])
        let result = try await api.playlistDetails(id: "P", limit: 3, forceRefresh: false)
        XCTAssertEqual(result.songs.compactMap(\.qishuiID), ["a", "b", "c"])
        XCTAssertEqual(result.playlist?.name, "Original")
        XCTAssertNil(query(requests()[0])["cursor"])
        XCTAssertNil(query(requests()[0])["session_id"])
        XCTAssertEqual(query(requests()[1]), ["playlist_id": "P", "count": "3", "cursor": "opaque-A", "session_id": "session-one"])
        XCTAssertEqual(query(requests()[2])["count"], "3")
        XCTAssertEqual(query(requests()[2])["session_id"], "session-one")
    }

    func testMediaResourcesPrecedenceLateMetadataAndNumericCursor() async throws {
        try enqueue(["media_resources": [["track": ["id": "a"]]], "tracks": [["id": "ignored"]], "next_cursor": 0, "has_more": false])
        try enqueue(["songs": [["id": "b"]], "playlist": ["id": "P", "title": "Late"], "sessionId": "s"])
        let result = try await api.playlistDetails(id: "P", limit: 5, forceRefresh: false)
        XCTAssertEqual(result.songs.compactMap(\.qishuiID), ["a", "b"])
        XCTAssertEqual(result.playlist?.name, "Late")
        XCTAssertEqual(query(requests()[1])["cursor"], "0")
    }

    func testDuplicateOnlyPagesStillEmitProgressAndCycleStops() async throws {
        let recorder = await QishuiDetailsRecorder()
        try page(["a"], cursor: "A")
        try page(["a"], cursor: "B")
        try page(["a"], cursor: "A")
        let result = try await api.playlistDetails(id: "P", limit: 5, forceRefresh: false, onProgress: { recorder.record($0) })
        XCTAssertEqual(result.songs.count, 1); XCTAssertEqual(requests().count, 3)
        let snapshots = await recorder.snapshots
        XCTAssertEqual(snapshots, [["a"], ["a"], ["a"]])
    }

    func testTwentyRoundCapAndHundredItemRequestCap() async throws {
        for n in 0..<20 { try page([String(n)], cursor: "c\(n)") }
        let result = try await api.playlistDetails(id: "P", limit: 2000, forceRefresh: false)
        XCTAssertEqual(result.songs.count, 20); XCTAssertEqual(requests().count, 20)
        XCTAssertTrue(requests().allSatisfy { query($0)["count"] == "100" })
        XCTAssertNotNil(api.playlistDetailsCache.object(forKey: api.playlistDetailsCacheKey(id: "P", limit: 1000) as NSString))
    }

    func testFreshCacheEmitsProgressAndUsesConstantTTL() async throws {
        let recorder = await QishuiDetailsRecorder()
        seed(age: 100)
        api.playlistDetailsTTL = 0
        let result = try await api.playlistDetails(id: "P", limit: 3, forceRefresh: false, onProgress: { recorder.record($0) })
        XCTAssertEqual(result.playlist?.name, "Cached")
        let snapshots = await recorder.snapshots
        XCTAssertEqual(snapshots, [["cached"]]); XCTAssertTrue(requests().isEmpty)
    }

    func testForcedRefreshKeepsFreshCacheAsFailureFallback() async throws {
        seed(age: 1)
        let result = try await api.playlistDetails(id: "P", limit: 3, forceRefresh: true)
        XCTAssertEqual(result.playlist?.name, "Cached"); XCTAssertEqual(requests().count, 1)
    }

    func testDetailFailurePrefersStaleCacheOverPartialSongs() async throws {
        seed(age: 3600)
        try page(["new"], cursor: "next", title: "New")
        let result = try await api.playlistDetails(id: "P", limit: 3, forceRefresh: false)
        XCTAssertEqual(result.playlist?.name, "Cached")
        XCTAssertEqual(result.songs.first?.qishuiID, "cached"); XCTAssertEqual(requests().count, 2)
    }

    func testUncachedPartialFailureThrowsAndDoesNotCache() async throws {
        try page(["new"], cursor: "next")
        do { _ = try await api.playlistDetails(id: "P", limit: 3, forceRefresh: false); XCTFail("Expected error") }
        catch { XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet) }
        XCTAssertNil(api.playlistDetailsCache.object(forKey: api.playlistDetailsCacheKey(id: "P", limit: 3) as NSString))
    }

    func testEmptyResultReturnsMetadataButIsNotCached() async throws {
        try page([], title: "Empty")
        let result = try await api.playlistDetails(id: "P", limit: 3, forceRefresh: false)
        XCTAssertEqual(result.playlist?.name, "Empty"); XCTAssertTrue(result.songs.isEmpty)
        XCTAssertNil(api.playlistDetailsCache.object(forKey: api.playlistDetailsCacheKey(id: "P", limit: 3) as NSString))
    }

    func testEmptyResultUsesStaleCacheAndSevenDayExpiry() async throws {
        seed(age: 3600)
        try page([])
        let stale = try await api.playlistDetails(id: "P", limit: 3, forceRefresh: false)
        XCTAssertEqual(stale.songs.first?.qishuiID, "cached")
        seed(age: 604801)
        try page([])
        let expired = try await api.playlistDetails(id: "P", limit: 3, forceRefresh: false)
        XCTAssertTrue(expired.songs.isEmpty)
    }

    func testPlaylistSongsWrapperAndCaseSensitiveCacheIdentity() async throws {
        try page(["a"])
        let songs = try await api.playlistSongs(id: "P", limit: 3, forceRefresh: false)
        XCTAssertEqual(songs.first?.qishuiID, "a")
        let cached = try await api.playlistSongs(id: "P", limit: 3, forceRefresh: false)
        XCTAssertEqual(cached.first?.qishuiID, "a"); XCTAssertEqual(requests().count, 1)
        XCTAssertEqual(api.playlistDetailsCacheKey(id: " P ", limit: 3), "details|https://fixture.invalid/qishui| P |3")
        XCTAssertNotEqual(api.playlistDetailsCacheKey(id: "P", limit: 3), api.playlistDetailsCacheKey(id: "p", limit: 3))
    }

    func testCancellationDoesNotReturnCachedFallbackDuringForcedRefresh() async {
        seed(age: 1)
        let api = api!
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await api.playlistDetails(id: "P", limit: 3, forceRefresh: true)
        }
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(requests().isEmpty)
    }
}
