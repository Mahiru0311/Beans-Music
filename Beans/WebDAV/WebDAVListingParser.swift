import Foundation

// RFC 4918: consume only successful propstat properties; never treat a failed href as a playable file.
final class WebDAVListingParser: NSObject, XMLParserDelegate {
    private struct Response {
        var href = ""
        var name = ""
        var directory = false
        var size: Int64?
        var successful = false
    }
    private var stack: [String] = []
    private var text = ""
    private var current = Response()
    private var property = Response()
    private var status = ""
    private var responses: [Response] = []
    private var sawMultistatus = false
    private var rejected = false

    static func parse(_ data: Data, directory: URL, root: URL) throws -> [WebDAVEntry] {
        guard data.count <= 8 * 1024 * 1024,
              let xml = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16),
              xml.range(of: "<!DOCTYPE", options: .caseInsensitive) == nil else { throw WebDAVError.invalidListing }
        let delegate = WebDAVListingParser()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), delegate.sawMultistatus, !delegate.rejected else { throw WebDAVError.invalidListing }
        var seen = Set<String>()
        return try delegate.responses.compactMap { response in
            guard response.successful, !response.href.isEmpty else { return nil }
            let resolved = try WebDAVPaths.resolve(response.href, relativeTo: directory, root: root)
            let url = response.directory && !resolved.hasDirectoryPath ? resolved.appendingPathComponent("", isDirectory: true) : resolved
            let normalized = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let currentPath = directory.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard normalized != currentPath, seen.insert(normalized).inserted else { return nil }
            return WebDAVEntry(url: url, name: response.name.isEmpty ? url.lastPathComponent : response.name,
                               isDirectory: response.directory, size: response.size)
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        let element = elementName.lowercased()
        stack.append(namespaceURI == "DAV:" ? element : "foreign:" + element); text = ""
        guard namespaceURI == "DAV:" else { return }
        if stack.count == 1 {
            guard element == "multistatus" else { rejected = true; parser.abortParsing(); return }
            sawMultistatus = true
        }
        if stack == ["multistatus", "response"] { current = Response() }
        if stack == ["multistatus", "response", "propstat"] { property = Response(); status = "" }
        if stack == ["multistatus", "response", "propstat", "prop", "resourcetype", "collection"] { property.directory = true }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        defer { _ = stack.popLast(); text = "" }
        guard namespaceURI == "DAV:" else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName.lowercased() {
        case "href": if stack == ["multistatus", "response", "href"] { current.href = value }
        case "displayname": if stack == ["multistatus", "response", "propstat", "prop", "displayname"] { property.name = value }
        case "getcontentlength": if stack == ["multistatus", "response", "propstat", "prop", "getcontentlength"] { property.size = Int64(value) }
        case "status": if stack == ["multistatus", "response", "propstat", "status"] { status = value }
        case "propstat":
            guard stack == ["multistatus", "response", "propstat"] else { return }
            if let code = status.split(separator: " ").dropFirst().first.flatMap({ Int($0) }), (200..<300).contains(code) {
                current.successful = true
                if !property.name.isEmpty { current.name = property.name }
                current.directory = current.directory || property.directory
                current.size = property.size ?? current.size
            }
        case "response": if stack == ["multistatus", "response"] { responses.append(current) }
        default: break
        }
    }
    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) {
        rejected = true; parser.abortParsing()
    }
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
        rejected = true; parser.abortParsing()
    }
}
