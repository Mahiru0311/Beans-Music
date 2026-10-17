import Foundation

// Every href, redirect and transfer is resolved against the configured root, including percent-encoded traversal.
enum WebDAVPaths {
    static func root(for connection: WebDAVConnection) throws -> URL {
        guard var components = URLComponents(string: connection.address.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || (scheme == "http" && connection.allowHTTP),
              components.host?.isEmpty == false, components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              !connection.username.contains(":"), !connection.username.contains("\n") else { throw WebDAVError.invalidAddress }
        components.path = try normalizedPath(components.path)
        if !components.path.hasSuffix("/") { components.path += "/" }
        guard let url = components.url else { throw WebDAVError.invalidAddress }
        return url
    }

    static func resolve(_ href: String, relativeTo directory: URL, root: URL) throws -> URL {
        guard let url = URL(string: href, relativeTo: directory)?.absoluteURL else { throw WebDAVError.outsideRoot }
        return try validate(url, root: root)
    }

    static func validate(_ url: URL, root: URL) throws -> URL {
        guard url.scheme?.lowercased() == root.scheme?.lowercased(), url.host?.lowercased() == root.host?.lowercased(),
              effectivePort(url) == effectivePort(root), url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else { throw WebDAVError.outsideRoot }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let rootComponents = URLComponents(url: root, resolvingAgainstBaseURL: false) else { throw WebDAVError.outsideRoot }
        let path = try normalizedPath(components.path)
        let rootPath = try normalizedPath(rootComponents.path)
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard path == rootPath || path == String(prefix.dropLast()) || path.hasPrefix(prefix) else { throw WebDAVError.outsideRoot }
        components.path = path
        guard let canonical = components.url else { throw WebDAVError.outsideRoot }
        return canonical
    }

    static func relativePath(_ url: URL, root: URL) throws -> String {
        let canonical = try validate(url, root: root)
        let rootPath = URLComponents(url: root, resolvingAgainstBaseURL: false)?.path ?? root.path
        let path = URLComponents(url: canonical, resolvingAgainstBaseURL: false)?.path ?? canonical.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        if path == String(prefix.dropLast()) || path == prefix { return "" }
        return String(path.dropFirst(prefix.count))
    }

    static func fileURL(path: String, root: URL) throws -> URL {
        // Decode once to catch traversal, then reject any remaining encoded separator/dot sequences.
        guard !path.hasPrefix("/"), !path.contains("\\"), !path.contains(":") else { throw WebDAVError.outsideRoot }
        return try validate(root.appendingPathComponent(path), root: root)
    }

    private static func effectivePort(_ url: URL) -> Int { url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80) }

    private static func normalizedPath(_ source: String) throws -> String {
        // URLComponents.path and URL.path have already decoded their percent escapes.
        // A second decode here would change real filenames such as "mix%20demo.mp3".
        let decoded = source
        guard !decoded.contains("\\"), !decoded.unicodeScalars.contains(where: { $0.value < 32 }),
              !decoded.lowercased().contains("%2e"), !decoded.lowercased().contains("%2f"),
              !decoded.lowercased().contains("%5c"),
              !decoded.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0 == ".." || $0 == "." }) else {
            throw WebDAVError.outsideRoot
        }
        return decoded.isEmpty ? "/" : decoded
    }
}
