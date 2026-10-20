import Foundation

/// Cases: descriptor 0x7c98e0. Messages and dispatch: 0x1005678c0.
public enum QishuiAPIError_2_0_3: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case server(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "汽水音乐接口地址无效"
        case .invalidResponse: return "汽水音乐返回了无法识别的数据"
        case .server(let message): return message
        }
    }
}

extension QishuiAPI_2_0_3 {
    static let baseURLKey = "beans.qishui.apiBaseURL"
    static let defaultBaseURL = "http://189.24.78.193/qishui"

    /// Four Set<String> entries, including immediate small strings: 0x10056a3e4.
    static let fastCatalogPaths: Set<String> = [
        "/search/mixed", "/search", "/search/playlist", "/recommend/playlist"
    ]

    /// Request/response state machine: 0x100571838 and 0x100571e50.
    /// These entry points are exposed for reconstruction tests; original visibility is unknown.
    public func requestValue(
        _ path: String,
        method: String = "GET",
        query: [String: String] = [:],
        body: [String: Any]? = nil
    ) async throws -> Any {
        let request = try makeRequest(path, method: method, query: query, body: body)
        let (data, response) = try await session.data(for: request)
        return try Self.decodeResponse(data: data, response: response)
    }

    /// Wrapper at 0x10056adf4, followed by a dictionary cast in its continuation.
    public func requestObject(
        _ path: String,
        method: String = "GET",
        query: [String: String] = [:],
        body: [String: Any]? = nil
    ) async throws -> [String: Any] {
        let value = try await requestValue(path, method: method, query: query, body: body)
        guard let object = value as? [String: Any] else {
            throw QishuiAPIError_2_0_3.invalidResponse
        }
        return object
    }

    // Split out of the async state machine for offline verification.
    func makeRequest(
        _ path: String, method: String = "GET",
        query: [String: String] = [:], body: [String: Any]? = nil
    ) throws -> URLRequest {
        let base = recoveryDefaults.string(forKey: Self.baseURLKey) ?? Self.defaultBaseURL
        guard let baseURL = URL(string: base),
              var components = URLComponents(
                url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
                resolvingAgainstBaseURL: false
              ) else { throw QishuiAPIError_2_0_3.invalidURL }
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw QishuiAPIError_2_0_3.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = Self.fastCatalogPaths.contains(path) ? 15 : 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let version = recoveryVersion
            ?? (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
            ?? "1.0"
        request.setValue("Beans-Music/\(version)", forHTTPHeaderField: "User-Agent")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    /// HTTP gate precedes JSON decoding; root must be an object, data may have any JSON shape.
    static func decodeResponse(data: Data, response: URLResponse) throws -> Any {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw QishuiAPIError_2_0_3.server("汽水音乐服务器请求失败")
        }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw QishuiAPIError_2_0_3.invalidResponse
        }
        let numericCode = number(root["code"])
        // Deliberate defensive deviation: the binary traps on non-finite/out-of-Int codes.
        guard numericCode.isFinite, numericCode > Double(Int.min), numericCode < Double(Int.max) else {
            throw QishuiAPIError_2_0_3.invalidResponse
        }
        if Int(numericCode) != 0 {
            throw QishuiAPIError_2_0_3.server(
                firstString(root, keys: ["message", "msg"]) ?? "汽水音乐接口返回失败"
            )
        }
        return root["data"] ?? [String: Any]()
    }

    /// 0x10056a6e4: category|base URL|limit|folded, trimmed, lowercased query.
    func catalogCacheKey(_ category: String, query: String, limit: Int) -> String {
        let normalized = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = recoveryDefaults.string(forKey: Self.baseURLKey) ?? Self.defaultBaseURL
        return "\(category)|\(base)|\(limit)|\(normalized)"
    }

    /// Array specialization 0x10056a9a8; details specialization 0x10056aafc.
    /// The generic spelling and clock argument are reconstruction seams. Strict < is preserved.
    func cacheLookup<Value>(
        _ cache: NSCache<NSString, QishuiCacheBox_2_0_3<Value>>,
        key: String, ttl: TimeInterval, staleTTL: TimeInterval, now: Date = Date()
    ) -> (fresh: Value?, stale: Value?) {
        guard let box = cache.object(forKey: key as NSString) else { return (nil, nil) }
        let age = now.timeIntervalSince(box.savedAt)
        if age < ttl { return (box.value, nil) }
        if age < staleTTL { return (nil, box.value) }
        return (nil, nil)
    }

    /// NSNumber then String(Double), otherwise zero: 0x10057157c.
    private static func number(_ value: Any?) -> Double {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) ?? 0 }
        return 0
    }

    /// Ordered nonempty String / NSNumber.stringValue lookup: 0x1005702f0.
    private static func firstString(_ object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String, !value.isEmpty { return value }
            if let value = object[key] as? NSNumber { return value.stringValue }
        }
        return nil
    }
}
