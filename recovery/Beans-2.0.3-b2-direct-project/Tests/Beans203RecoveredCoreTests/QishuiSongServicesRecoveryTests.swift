import Foundation
import XCTest
@testable import Beans203RecoveredCore

private final class QishuiSongFixtureProtocol: URLProtocol {
    static let lock = NSLock()
    static var responses: [Result<(Int, Data), Error>] = []
    static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        let result = Self.responses.isEmpty
            ? .failure(URLError(.notConnectedToInternet)) : Self.responses.removeFirst()
        Self.lock.unlock()
        switch result {
        case .success(let (status, data)):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error): client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

final class QishuiSongServicesRecoveryTests: XCTestCase {
    private var api: QishuiAPI_2_0_3!
    private let song = Song_2_0_3(qishuiID: "9223372036854775809")
    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [QishuiSongFixtureProtocol.self]
        let defaults = UserDefaults(suiteName: "QishuiSongTests.\(UUID().uuidString)")!
        defaults.set("https://fixture.invalid/qishui", forKey: QishuiAPI_2_0_3.baseURLKey)
        api = QishuiAPI_2_0_3(session: URLSession(configuration: configuration), defaults: defaults, version: "2.0.3")
        QishuiSongFixtureProtocol.responses = []
        QishuiSongFixtureProtocol.requests = []
    }
    override func tearDown() {
        api.session.invalidateAndCancel()
        api.recoveryDefaults.removeObject(forKey: QishuiAPI_2_0_3.baseURLKey)
        api = nil
        super.tearDown()
    }
    private func enqueue(_ object: [String: Any], status: Int = 200) throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        QishuiSongFixtureProtocol.lock.lock()
        QishuiSongFixtureProtocol.responses.append(.success((status, data)))
        QishuiSongFixtureProtocol.lock.unlock()
    }
    private func requests() -> [URLRequest] {
        QishuiSongFixtureProtocol.lock.lock()
        defer { QishuiSongFixtureProtocol.lock.unlock() }
        return QishuiSongFixtureProtocol.requests
    }
    private func query(_ request: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            .queryItems!.map { ($0.name, $0.value!) })
    }

    func testMissingAndEmptyIdentifiersAvoidAllRequests() async throws {
        for song in [Song_2_0_3(), Song_2_0_3(qishuiID: "")] {
            let lyric = try await api.lyrics(for: song)
            let url = try await api.playbackURL(for: song)
            let page = try await api.comments(for: song, limit: 20)
            XCTAssertNil(lyric); XCTAssertNil(url)
            XCTAssertEqual(page.total, 0); XCTAssertTrue(page.hot.isEmpty); XCTAssertTrue(page.comments.isEmpty)
        }
        XCTAssertTrue(requests().isEmpty)
    }

    func testLyricsKeyPriorityAndIdentifierPreservation() async throws {
        try enqueue(["data": ["lyric": "", "lyrics": "[00:01]歌词", "content": "later"]])
        let lyric = try await api.lyrics(for: song)
        XCTAssertEqual(lyric, "[00:01]歌词")
        let request = try XCTUnwrap(requests().first)
        XCTAssertEqual(request.url?.path, "/qishui/lyric")
        XCTAssertEqual(query(request), ["track_id": "9223372036854775809"])
        XCTAssertEqual(request.timeoutInterval, 20)
    }

    func testLyricsNumericWhitespaceAndAbsentFields() async throws {
        try enqueue(["data": ["lrc": 123]])
        try enqueue(["data": ["lyric": " "]])
        try enqueue(["data": ["lyric": ["lyric": "nested is not searched"]]])
        let numeric = try await api.lyrics(for: song)
        let whitespace = try await api.lyrics(for: Song_2_0_3(qishuiID: " "))
        let absent = try await api.lyrics(for: song)
        XCTAssertEqual(numeric, "123"); XCTAssertEqual(whitespace, " "); XCTAssertNil(absent)
        XCTAssertEqual(query(requests()[1])["track_id"], " ")
    }

    func testPlaybackUsesDetailsWithoutUnnecessaryFallback() async throws {
        try enqueue(["data": ["track": ["audio_url": "https://audio.invalid/song"]]])
        let url = try await api.playbackURL(for: song)
        XCTAssertEqual(url?.absoluteString, "https://audio.invalid/song")
        XCTAssertEqual(requests().map { $0.url!.path }, ["/qishui/song/detail"])
    }

    func testPlaybackFallsBackOnlyAfterSuccessfulDetailWithoutURL() async throws {
        try enqueue(["data": ["audio_url": "//audio.invalid/relative"]])
        try enqueue(["data": ["play_url": "https://audio.invalid/fallback"]])
        let url = try await api.playbackURL(for: song)
        XCTAssertEqual(url?.absoluteString, "https://audio.invalid/fallback")
        XCTAssertEqual(requests().map { $0.url!.path }, ["/qishui/song/detail", "/qishui/audio/info"])
        XCTAssertTrue(requests().allSatisfy { query($0) == ["track_id": song.qishuiID!] })
    }

    func testPlaybackReturnsNilAfterTwoEmptyResponses() async throws {
        try enqueue(["data": [:]])
        try enqueue(["data": [:]])
        let url = try await api.playbackURL(for: song)
        XCTAssertNil(url); XCTAssertEqual(requests().count, 2)
    }

    func testPlaybackDetailErrorDoesNotTriggerFallback() async throws {
        try enqueue([:], status: 503)
        do { _ = try await api.playbackURL(for: song); XCTFail("Expected server error") }
        catch { XCTAssertEqual(error as? QishuiAPIError_2_0_3, .server("汽水音乐服务器请求失败")) }
        XCTAssertEqual(requests().count, 1)
    }

    func testPlaybackFallbackErrorPropagates() async throws {
        try enqueue(["data": [:]])
        do { _ = try await api.playbackURL(for: song); XCTFail("Expected transport error") }
        catch { XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet) }
        XCTAssertEqual(requests().count, 2)
    }

    func testPlaybackURLPrioritySchemesAndArrayGate() {
        XCTAssertEqual(QishuiAPI_2_0_3.playbackURL(in: ["audio_url": "custom:one", "play_url": "https://a.invalid"])?.scheme, "custom")
        XCTAssertEqual(QishuiAPI_2_0_3.playbackURL(in: ["audio_url": ["backup_url": "https://a.invalid/nested"], "play_url": "https://a.invalid/later"])?.path, "/nested")
        XCTAssertNil(QishuiAPI_2_0_3.playbackURL(in: ["list": [["play_url": "https://a.invalid/ignored"]]]))
        XCTAssertEqual(QishuiAPI_2_0_3.playbackURL(in: ["list": [["audio_url": NSNull(), "play_url": "https://a.invalid/accepted"]]])?.path, "/accepted")
        XCTAssertNil(QishuiAPI_2_0_3.playbackURL(in: ["audio_url": ["https://a.invalid/string-array"]]))
    }

    func testCommentMappingPriorityAndMilliseconds() throws {
        let comment = try XCTUnwrap(QishuiAPI_2_0_3.makeComment([
            "id": "123", "comment_id": "other", "content": "Hello", "text": "ignored",
            "user_name": "Name", "nickname": "ignored", "user_avatar": "/relative-avatar",
            "timestamp": 1_700_000_000_123.0, "create_time": 1, "like_count": "12.9", "likeCount": 99, "isHot": true
        ]))
        XCTAssertEqual(comment.id, 4_591_456_448_132_287_629)
        XCTAssertEqual(comment.content, "Hello"); XCTAssertEqual(comment.nickname, "Name")
        XCTAssertEqual(comment.avatarURL?.relativeString, "/relative-avatar")
        XCTAssertEqual(comment.time.timeIntervalSince1970, 1_700_000_000.123, accuracy: 0.0001)
        XCTAssertEqual(comment.likedCount, 12); XCTAssertFalse(comment.isHot)
    }

    func testCommentDefaultsTimeBoundaryAndInvalidLikes() throws {
        let now = Date(timeIntervalSince1970: 42)
        let defaults = try XCTUnwrap(QishuiAPI_2_0_3.makeComment(["comment_text": " "], now: now, identifierGenerator: { "123" }))
        XCTAssertEqual(defaults.id, 4_591_456_448_132_287_629)
        XCTAssertEqual(defaults.nickname, "汽水用户"); XCTAssertEqual(defaults.time, now)
        XCTAssertNil(defaults.avatarURL); XCTAssertEqual(defaults.likedCount, 0)
        XCTAssertEqual(QishuiAPI_2_0_3.makeComment(["text": "x", "time": 10_000_000_000.0])?.time.timeIntervalSince1970, 10_000_000_000.0)
        XCTAssertEqual(QishuiAPI_2_0_3.makeComment(["text": "x", "timestamp": 0, "time": 100], now: now)?.time, now)
        XCTAssertNil(QishuiAPI_2_0_3.makeComment(["content": ""]))
        XCTAssertNil(QishuiAPI_2_0_3.makeComment(["content": "x", "like_count": Double.infinity]))
    }

    func testCommentsClampCountMapValidRowsAndIgnoreServerTotal() async throws {
        try enqueue(["data": ["total": 900, "comments": [["id": "1", "text": "first"], ["text": ""], ["id": "2", "text": "second"]]]])
        let page = try await api.comments(for: song, limit: 0)
        XCTAssertEqual(page.total, 2); XCTAssertEqual(page.comments.map(\.content), ["first", "second"])
        XCTAssertTrue(page.hot.isEmpty)
        XCTAssertEqual(query(requests()[0])["count"], "1")
        XCTAssertEqual(requests()[0].url?.path, "/qishui/comment")
        try enqueue(["data": ["data": [["text": "alternate"]]]])
        let alternate = try await api.comments(for: song, limit: 999)
        XCTAssertEqual(alternate.total, 1)
        XCTAssertEqual(query(requests()[1])["count"], "50")
    }

    func testLyricsAndCommentsRejectWrongResponseShape() async throws {
        try enqueue(["data": []])
        try enqueue(["data": []])
        do { _ = try await api.lyrics(for: song); XCTFail("Expected object response") }
        catch { XCTAssertEqual(error as? QishuiAPIError_2_0_3, .invalidResponse) }
        do { _ = try await api.comments(for: song, limit: 1); XCTFail("Expected object response") }
        catch { XCTAssertEqual(error as? QishuiAPIError_2_0_3, .invalidResponse) }
    }
}
