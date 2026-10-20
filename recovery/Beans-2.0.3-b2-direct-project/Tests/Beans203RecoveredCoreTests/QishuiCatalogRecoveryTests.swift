import Foundation
import XCTest
@testable import Beans203RecoveredCore

private final class QishuiFixtureProtocol: URLProtocol {
    static let lock = NSLock()
    static var fixture: Result<(Int, Data), Error> = .failure(URLError(.notConnectedToInternet))
    static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        let fixture = Self.fixture
        Self.lock.unlock()
        switch fixture {
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

final class QishuiCatalogRecoveryTests: XCTestCase {
    private var api: QishuiAPI_2_0_3!
    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [QishuiFixtureProtocol.self]
        let defaults = UserDefaults(suiteName: "QishuiCatalogTests.\(UUID().uuidString)")!
        defaults.set("https://fixture.invalid/qishui", forKey: QishuiAPI_2_0_3.baseURLKey)
        api = QishuiAPI_2_0_3(session: URLSession(configuration: configuration), defaults: defaults, version: "2.0.3")
        QishuiFixtureProtocol.requests = []
        QishuiFixtureProtocol.fixture = .failure(URLError(.notConnectedToInternet))
    }
    override func tearDown() {
        api.session.invalidateAndCancel()
        api.recoveryDefaults.removeObject(forKey: QishuiAPI_2_0_3.baseURLKey)
        api = nil
        super.tearDown()
    }
    private func fixture(_ json: String, status: Int = 200) {
        QishuiFixtureProtocol.lock.lock()
        QishuiFixtureProtocol.fixture = .success((status, Data(json.utf8)))
        QishuiFixtureProtocol.lock.unlock()
    }
    private func requests() -> [URLRequest] {
        QishuiFixtureProtocol.lock.lock()
        defer { QishuiFixtureProtocol.lock.unlock() }
        return QishuiFixtureProtocol.requests
    }
    private func seed(stale: Bool, recommendations: Bool = false, limit: Int = 2) {
        let category = recommendations ? "recommendations" : "playlists"
        let key = api.catalogCacheKey(category, query: recommendations ? "guest" : "music", limit: limit)
        let box = QishuiCacheBox_2_0_3(value: [Playlist_2_0_3(id: 9, name: "Cached")],
                                     savedAt: Date().addingTimeInterval(stale ? -3600 : 0))
        (recommendations ? api.recommendationCache : api.playlistSearchCache).setObject(box, forKey: key as NSString)
    }

    func testSearchMapsResponseClampsLimitAndCachesSuccessfulResults() async throws {
        fixture("{\"code\":0,\"data\":{\"playlists\":[{\"id\":\"one\",\"title\":\"First\"},{\"id\":\"two\",\"title\":\"Second\"}]}}")
        let result = try await api.searchPlaylists(keyword: "  music ", limit: 0)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "First")
        let request = try XCTUnwrap(requests().first)
        XCTAssertEqual(request.url?.path, "/qishui/search/playlist")
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(items.first { $0.name == "keywords" }?.value, "music")
        XCTAssertEqual(items.first { $0.name == "count" }?.value, "1")
        fixture("{}", status: 500)
        let cached = try await api.searchPlaylists(keyword: "MUSIC", limit: 1)
        XCTAssertEqual(cached.first?.name, "First")
        XCTAssertEqual(requests().count, 1)
    }

    func testRecommendationsUseGuestCacheAndUpperLimit() async throws {
        fixture("{\"data\":{\"data\":[{\"playlist\":{\"playlist_id\":\"p\",\"name\":\"Recommended\"}}]}}")
        let result = try await api.recommendedPlaylists(limit: 999)
        XCTAssertEqual(result.first?.name, "Recommended")
        let request = try XCTUnwrap(requests().first)
        XCTAssertEqual(request.url?.path, "/qishui/recommend/playlist")
        XCTAssertEqual(request.url?.query, "count=50")
        let cached = try await api.recommendedPlaylists(limit: 50)
        XCTAssertEqual(cached.first?.qishuiID, "p")
        XCTAssertEqual(requests().count, 1)
    }

    func testEmptyQueryAndFreshCacheAvoidRequests() async throws {
        let empty = try await api.searchPlaylists(keyword: " \n", limit: 2)
        XCTAssertTrue(empty.isEmpty)
        seed(stale: false)
        let cached = try await api.searchPlaylists(keyword: "music", limit: 2)
        XCTAssertEqual(cached.first?.name, "Cached")
        XCTAssertTrue(requests().isEmpty)
    }

    func testStaleCacheSurvivesServerFailureAndEmptyResponse() async throws {
        seed(stale: true)
        fixture("invalid", status: 503)
        let fallback = try await api.searchPlaylists(keyword: "music", limit: 2)
        XCTAssertEqual(fallback.first?.name, "Cached")
        fixture("{\"data\":{\"playlists\":[]}}")
        let emptyFallback = try await api.searchPlaylists(keyword: "music", limit: 2)
        XCTAssertEqual(emptyFallback.first?.name, "Cached")
        seed(stale: true, recommendations: true)
        let recommendation = try await api.recommendedPlaylists(limit: 2)
        XCTAssertEqual(recommendation.first?.name, "Cached")
        XCTAssertEqual(requests().count, 3)
    }

    func testNoCachePropagatesTransportFailureAndArrayObjectMismatch() async {
        do { _ = try await api.searchPlaylists(keyword: "music", limit: 2); XCTFail("Expected transport failure") }
        catch { XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet) }
        fixture("{\"data\":[]}")
        do { _ = try await api.recommendedPlaylists(limit: 2); XCTFail("Expected dictionary response gate") }
        catch { XCTAssertEqual(error as? QishuiAPIError_2_0_3, .invalidResponse) }
    }
}
