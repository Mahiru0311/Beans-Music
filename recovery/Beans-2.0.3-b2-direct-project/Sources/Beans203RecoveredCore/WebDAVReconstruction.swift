import Foundation

// Reconstructed only from Beans 2.0.3 (build 2) Beans.app/Beans.
// Names and behavior marked "inferred" are based on direct ARM64/Swift metadata evidence.

/// String literals retained in the exact 2.0.3 build 2 binary. These keys are
/// direct evidence; the call sites that consume every key are not all recoverable.
public enum WebDAVConstants_2_0_3 {
    public static let namespace = "com.beans.webdav"
    static let connectionDefaultsKey = "beans.webdav.connection.v1"
    static let profileDefaultsKey = "beans.profile.webdav"
    static let backupMetaKey = "beans.backup.meta"
    static let backupDirectory = "BeansBackups"
    static let cacheMiniPlayerKey = "beans.webdav.mini-player"
    static let moreLabelKey = "beans.webdav.more"
    static let closeLabelKey = "beans.webdav.close"
    static let connectLabelKey = "beans.webdav.connect"
    static let testLabelKey = "beans.webdav.test"
    static let saveLabelKey = "beans.webdav.save"
    static let connectionStatusLabelKey = "beans.webdav.connection-status"
    static let addressLabelKey = "beans.webdav.address"
    static let usernameLabelKey = "beans.webdav.username"
    static let passwordLabelKey = "beans.webdav.password"
    static let httpLabelKey = "beans.webdav.http"
    static let backupRecordLabelKey = "beans.webdav.backup-record"
    static let backupLabelKey = "beans.webdav.backup"
}

public struct WebDAVConnection_2_0_3: Codable, Hashable {
    public var id: UUID
    public var address: String
    public var username: String
    public var allowHTTP: Bool
    public init(id: UUID, address: String, username: String, allowHTTP: Bool) {
        self.id = id; self.address = address; self.username = username; self.allowHTTP = allowHTTP
    }
}

public struct WebDAVTrack_2_0_3: Codable, Hashable {
    public var connectionID: UUID
    public var relativePath: String
    public var accountKey: String?
    public init(connectionID: UUID, relativePath: String, accountKey: String? = nil) {
        self.connectionID = connectionID; self.relativePath = relativePath; self.accountKey = accountKey
    }
}

public struct WebDAVEntry_2_0_3: Hashable {
    public var url: URL
    public var name: String
    public var isDirectory: Bool
    public var size: Int64?
    public init(url: URL, name: String, isDirectory: Bool, size: Int64?) {
        self.url = url; self.name = name; self.isDirectory = isDirectory; self.size = size
    }
}

// Intermediate XML response record (field names are directly present in metadata).
public struct WebDAVListingResponse_2_0_3: Hashable {
    public var href: String = ""
    public var name: String = ""
    public var directory: Bool = false
    public var size: Int64?
    public var successful: Bool = false
    public init() {}
}

public enum WebDAVError_2_0_3: Error {
    case http(Int)
    case keychain
    case invalidAddress
    case outsideRoot
    case invalidListing
    case tooLarge
    case missingConnection
    case invalidBackup
}

/// Field layout is directly present in Swift reflection metadata.
public final class WebDAVListingParser_2_0_3 {
    // Main-binary typeref records resolve both fields to the nominal `Response`
    // record (renamed here to avoid collision with Foundation types).
    var current = WebDAVListingResponse_2_0_3()
    var property = WebDAVListingResponse_2_0_3()
    var stack: [String?] = []
    var text: String = ""
    var responses: [WebDAVListingResponse_2_0_3] = []
    var sawMultistatus: Bool = false
    var rejected: Bool = false

    private var activeResponse = WebDAVListingResponse_2_0_3()
    private var activeProperty = WebDAVListingResponse_2_0_3()
    private var elementStack: [String] = []
    private var baseURL: URL?
    private var inResponse = false
    private var inPropstat = false

    // Reconstructed XMLParser delegate path; element names and size parsing are direct,
    // URL/collection normalization is an evidence-tagged implementation of the same flow.
    public func parse(_ data: Data, baseURL: URL) throws -> [WebDAVEntry_2_0_3] {
        self.baseURL = baseURL
        guard data.count <= 0x800000 else { throw WebDAVError_2_0_3.tooLarge }
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = self
        guard parser.parse(), sawMultistatus, !rejected else { throw WebDAVError_2_0_3.invalidListing }
        return responses.compactMap { response in
            guard response.successful, let url = URL(string: response.href, relativeTo: baseURL)?.absoluteURL else { return nil }
            return WebDAVEntry_2_0_3(url: url, name: response.name,
                                     isDirectory: response.directory, size: response.size)
        }
    }
}

extension WebDAVListingParser_2_0_3: XMLParserDelegate {
    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        let local = (elementName.split(separator: ":").last.map(String.init) ?? elementName).lowercased()
        elementStack.append(local)
        stack = elementStack.map { Optional($0) }
        text = ""
        if local == "multistatus" { sawMultistatus = true }
        if local == "response" {
            activeResponse = WebDAVListingResponse_2_0_3(); inResponse = true
        }
        if local == "propstat" {
            activeProperty = WebDAVListingResponse_2_0_3(); inPropstat = true
        }
        // The binary marks a collection from the nested DAV:collection element;
        // its text is normally empty, so checking resourcetype text alone loses it.
        if local == "collection", elementStack.dropLast().last == "resourcetype" {
            activeProperty.directory = true
        }
        current = activeResponse
        property = activeProperty
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let local = (elementName.split(separator: ":").last.map(String.init) ?? elementName).lowercased()
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch local {
        case "href":
            if inResponse { activeResponse.href = value }
        case "displayname":
            if inPropstat { activeProperty.name = value }
        case "getcontentlength":
            if let n = Int64(value) { activeProperty.size = n }
            else if !value.isEmpty { rejected = true }
        case "status":
            let code = value.split(whereSeparator: { $0 == " " || $0 == "\t" })
                .compactMap { Int($0) }.first
            activeProperty.successful = code.map { (200..<300).contains($0) } ?? false
        case "propstat":
            if inPropstat, activeProperty.successful {
                activeResponse.successful = true
                if !activeProperty.name.isEmpty { activeResponse.name = activeProperty.name }
                activeResponse.directory = activeResponse.directory || activeProperty.directory
                if activeProperty.size != nil { activeResponse.size = activeProperty.size }
            }
            inPropstat = false
        case "response":
            if inResponse { responses.append(activeResponse); inResponse = false }
        default: break
        }
        _ = elementStack.popLast()
        stack = elementStack.map { Optional($0) }
        current = activeResponse
        property = activeProperty
        text = ""
    }

    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
        rejected = true; parser.abortParsing()
    }

    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String,
                publicID: String?, systemID: String?) {
        rejected = true; parser.abortParsing()
    }
}

public final class WebDAVTransfer_2_0_3 {
    var root: URL
    var authorization: String
    var limit: Int
    var lock: NSLock
    var continuation: Any?
    var task: URLSessionDownloadTask?
    var cancelled: Bool

    public init(root: URL, authorization: String, limit: Int, cancelled: Bool = false) {
        self.root = root
        self.authorization = authorization
        self.limit = limit
        self.lock = NSLock()
        self.continuation = nil
        self.task = nil
        self.cancelled = cancelled
    }

    // Inferred async wrapper around the URLSession download continuation used by
    // FUN_1007274f8 and the 100729e68/10072a280 GET state machines.
    public func download(_ request: URLRequest, configuration: URLSessionConfiguration) async throws -> Data {
        try Task.checkCancellation()
        let session = URLSession(configuration: configuration)
        let (fileURL, response) = try await session.download(for: request)
        guard let http = response as? HTTPURLResponse else { throw WebDAVError_2_0_3.invalidListing }
        guard (200..<300).contains(http.statusCode) else { throw WebDAVError_2_0_3.http(http.statusCode) }
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        if let bytes = values.fileSize, bytes > Int64(limit) { throw WebDAVError_2_0_3.tooLarge }
        return try Data(contentsOf: fileURL)
    }

    // Inferred upload wrapper matching the direct PUT request builder.
    public func upload(_ body: Data, request: URLRequest, configuration: URLSessionConfiguration) async throws {
        guard body.count <= limit else { throw WebDAVError_2_0_3.tooLarge }
        try Task.checkCancellation()
        var request = request
        request.httpBody = body
        let session = URLSession(configuration: configuration)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw WebDAVError_2_0_3.invalidBackup }
        guard (200..<300).contains(http.statusCode) else { throw WebDAVError_2_0_3.http(http.statusCode) }
    }

    public func cancel() {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
        task?.cancel()
    }
}

public final class WebDAVStore_2_0_3 {
    var _connection: WebDAVConnection_2_0_3?
    var defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self._connection = nil
        self.defaults = defaults
    }
}

public struct WebDAVClient_2_0_3 {
    public var root: URL
    public var authorization: String
    public var configuration: URLSessionConfiguration

    // FUN_100724adc validates host, credentials, query/fragment, scheme, and trailing path.
    static func validatedRoot(address: String, allowHTTP: Bool) throws -> URL {
        guard var c = URLComponents(string: address), c.host != nil,
              c.user == nil, c.password == nil, c.query == nil, c.fragment == nil,
              let scheme = c.scheme?.lowercased(), scheme == "https" || (scheme == "http" && allowHTTP)
        else { throw WebDAVError_2_0_3.invalidAddress }
        if !c.path.hasSuffix("/") { c.path += "/" }
        guard let url = c.url else { throw WebDAVError_2_0_3.invalidAddress }
        return url
    }

    /// `FUN_10072cd10` calls the root/path validator before constructing every
    /// URLRequest. The host, scheme, effective port, credentials, query and
    /// fragment checks are direct; the path-prefix rule is the corresponding
    /// evidence-tagged reconstruction of `FUN_1007243b4`.
    static func validatedURL(_ url: URL, root: URL) throws -> URL {
        guard url.scheme?.lowercased() == root.scheme?.lowercased(),
              url.host?.lowercased() == root.host?.lowercased(),
              (url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80)) ==
                (root.port ?? (root.scheme?.lowercased() == "https" ? 443 : 80)),
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil
        else { throw WebDAVError_2_0_3.outsideRoot }
        let rootPath = URLComponents(url: root, resolvingAgainstBaseURL: false)?.path ?? root.path
        let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path ?? url.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard path == rootPath || path == String(prefix.dropLast()) || path.hasPrefix(prefix),
              !path.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0 == ".." || $0 == "." })
        else { throw WebDAVError_2_0_3.outsideRoot }
        return url
    }

    // Directly reconstructed from FUN_100728e78 / FUN_10072cd10.
    func makeRequest(url: URL, method: String) throws -> URLRequest {
        var request = URLRequest(url: try Self.validatedURL(url, root: root), cachePolicy: .useProtocolCachePolicy,
                                 timeoutInterval: 60.0)
        request.httpMethod = method
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        return request
    }

    // The binary encodes GET as the compact String value 0x4547 | 0x540000.
    func makeGETRequest(url: URL) throws -> URLRequest {
        try makeRequest(url: url, method: "GET")
    }

    // The binary encodes PUT as the compact String value 0x5550 | 0x540000.
    func makePUTRequest(url: URL) throws -> URLRequest {
        try makeRequest(url: url, method: "PUT")
    }

    // FUN_1007292f4: PROPFIND body and headers are directly visible.
    func makePROPFINDRequest(url: URL) throws -> URLRequest {
        var request = try makeRequest(url: url, method: "PROPFIND")
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Depth")
        let xml = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<d:propfind xmlns:d=\"DAV:\"><d:prop><d:displayname/><d:resourcetype/><d:getcontentlength/></d:prop></d:propfind>"
        request.httpBody = Data(xml.utf8)
        return request
    }

    /// Directly visible continuation setup from `FUN_1007292fc`: the request
    /// body is encoded as UTF-8 XML and handed to the transfer continuation
    /// with an 8 MiB operation-sized argument. The exact private continuation
    /// object is not source-recoverable, so this public wrapper exposes the
    /// request and keeps the observed limit as evidence.
    public func makePROPFINDRequestWithObservedLimit(url: URL) throws -> (request: URLRequest, observedLimit: Int) {
        (try makePROPFINDRequest(url: url), 0x800000)
    }

    // FUN_100729b74: body upload path. The 0x1400000 comparison is a 20 MiB limit.
    func makeBackupPUTRequest(url: URL, body: Data) throws -> URLRequest {
        guard body.count <= 0x1400000 else { throw WebDAVError_2_0_3.tooLarge }
        var request = try makePUTRequest(url: url)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("*", forHTTPHeaderField: "If-None-Match")
        request.httpBody = body
        return request
    }

    // FUN_100729724 creates the BeansBackups directory with MKCOL.
    func backupDirectoryURL() -> URL {
        root.appendingPathComponent(WebDAVConstants_2_0_3.backupDirectory, isDirectory: true)
    }

    func makeMKCOLRequest() throws -> URLRequest {
        try makeRequest(url: backupDirectoryURL(), method: "MKCOL")
    }

    /// `FUN_100730ed0` appends a literal path component with
    /// `isDirectory == true` before entering the next transfer state.
    public func observedBackupDirectoryComponent() -> URL {
        root.appendingPathComponent(WebDAVConstants_2_0_3.backupDirectory, isDirectory: true)
    }

    // FUN_100745570: base + "-" + UUID.uuidString + ".json".
    func backupFilename(base: String, id: UUID = UUID()) -> String {
        "\(base)-\(id.uuidString).json"
    }

    // Inferred listing wrapper around the direct PROPFIND + XML parser path.
    func list(directory: URL) async throws -> [WebDAVEntry_2_0_3] {
        let request = try makePROPFINDRequest(url: directory)
        let session = URLSession(configuration: configuration)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw WebDAVError_2_0_3.invalidListing }
        guard (200..<300).contains(http.statusCode) else { throw WebDAVError_2_0_3.http(http.statusCode) }
        return try WebDAVListingParser_2_0_3().parse(data, baseURL: directory)
    }

    /// Restore-side size gate visible in FUN_10072a39c before MIME/JSON checks.
    /// The exact source error mapping is not recoverable, so this keeps the
    /// direct numeric boundary and uses the reconstructed `tooLarge` case.
    func validateDownloadedRestoreSize(_ bytes: Int64) throws {
        guard bytes > 0, bytes <= 0x20000000 else { throw WebDAVError_2_0_3.tooLarge }
    }

    // Inferred MKCOL/PUT orchestration matching the direct backup state machines.
    func uploadBackup(_ body: Data, baseName: String) async throws {
        let directory = backupDirectoryURL()
        let session = URLSession(configuration: configuration)
        let mkcol = try makeMKCOLRequest()
        let (_, mkResponse) = try await session.data(for: mkcol)
        if let http = mkResponse as? HTTPURLResponse, !(200..<300).contains(http.statusCode) && http.statusCode != 405 {
            throw WebDAVError_2_0_3.http(http.statusCode)
        }
        let filename = backupFilename(base: baseName)
        let url = directory.appendingPathComponent(filename, isDirectory: false)
        let request = try makeBackupPUTRequest(url: url, body: body)
        try await WebDAVTransfer_2_0_3(root: root, authorization: authorization, limit: 0x1400000)
            .upload(body, request: request, configuration: configuration)
    }
}

/// Direct field names from __swift5_fieldmd; element types are partially inferred
/// from Codable metadata and the backup constructor at FUN_100722204.
struct WebDAVBackup_2_0_3: Codable {
    var format: String
    var version: Int
    var createdAt: Date
    var playlists: [WebDAVOpaqueValue_2_0_3]
    var favoriteSongs: [WebDAVOpaqueValue_2_0_3]
    var albums: [WebDAVOpaqueValue_2_0_3]
    var artists: [WebDAVOpaqueValue_2_0_3]
    var favoritePlaylists: [WebDAVOpaqueValue_2_0_3]
    var settings: [String: WebDAVSetting_2_0_3]
}

enum WebDAVOpaqueValue_2_0_3: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: WebDAVOpaqueValue_2_0_3])
    case array([WebDAVOpaqueValue_2_0_3])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let a = try? c.decode([WebDAVOpaqueValue_2_0_3].self) { self = .array(a) }
        else if let o = try? c.decode([String: WebDAVOpaqueValue_2_0_3].self) { self = .object(o) }
        else { self = .string(try c.decode(String.self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
}

enum WebDAVSetting_2_0_3: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else { self = .string(try c.decode(String.self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        }
    }
}

// Listing parser behavior recovered from FUN_100726a40:
// - recognizes displayname, status, propstat, response, getcontentlength
// - parses getcontentlength as signed decimal Int64
// - appends a response record only after a valid response/property state
// - carries current/property state and a multistatus/rejected flag

// Backup naming behavior recovered from FUN_100745570/FUN_1007455bc:
// - append UUID string to the backup base name
// - append ".json"
// - construct the remote URL below BeansBackups
