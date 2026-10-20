import Foundation

/// Reconstructed from 0x100567b94, 0x100568a48, 0x100568e64 and 0x1005691d0.
/// Public names are reconstruction names; behavior is traced from the supplied IPA.
public enum QishuiResourceURL_2_0_3 {
    public static func first(in value: Any?) -> URL? { first(in: value, depth: 0) }

    public static func playlistCover(in playlist: [String: Any]) -> URL? {
        let raw = playlist["raw"] as? [String: Any] ?? playlist
        let keys = ["url_cover", "cover_url", "coverURL", "urlCover", "cover_uri", "cover", "pic_url", "picUrl"]
        for object in [raw, playlist] {
            for key in keys {
                if let url = first(in: object[key]) { return normalizePlaylistCover(url) }
            }
        }
        return nil
    }

    private static func first(in value: Any?, depth: Int) -> URL? {
        guard depth < 8 else { return nil }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            let candidate = trimmed.hasPrefix("//") ? "https:\(trimmed)" : trimmed
            return httpURL(candidate)
        }
        if let array = value as? [Any] {
            for item in array { if let url = first(in: item, depth: depth + 1) { return url } }
            return nil
        }
        guard let object = value as? [String: Any] else { return nil }
        if let direct = first(in: object["url"], depth: depth + 1) { return direct }
        if let uri = object["uri"] as? String,
           let base = first(in: object["urls"] ?? object["url_list"], depth: depth + 1),
           let completed = complete(uri: uri, base: base, template: object["template_prefix"] as? String) {
            return completed
        }
        let keys = ["url", "urls", "url_list", "cover_url", "cover_urls", "url_cover",
                    "origin_url", "origin_url_list", "uri", "cover", "artwork"]
        for key in keys { if let url = first(in: object[key], depth: depth + 1) { return url } }
        // The binary traverses dictionary values; no stable order can be recovered here.
        for value in object.values { if let url = first(in: value, depth: depth + 1) { return url } }
        return nil
    }

    private static func httpURL(_ string: String) -> URL? {
        guard let url = URL(string: string),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        return url
    }

    private static func complete(uri: String, base: URL, template: String?) -> URL? {
        let value = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if let url = httpURL(value) { return url }
        if base.absoluteString.contains(value) { return base }
        guard value.contains("/") || base.path.hasSuffix("/"),
              let url = URL(string: value, relativeTo: base)?.absoluteURL,
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        guard let template = template?.trimmingCharacters(in: .whitespacesAndNewlines),
              !template.isEmpty, !value.contains("~tplv-") else { return url }
        return URL(string: "\(url.absoluteString)~\(template)-crop-center:720:720.jpg") ?? url
    }

    private static func normalizePlaylistCover(_ url: URL) -> URL {
        guard url.host?.lowercased().hasSuffix("douyinpic.com") == true,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.percentEncodedPath.contains("/img/"),
              !components.percentEncodedPath.contains("~tplv-") else { return url }
        components.percentEncodedPath += "~tplv-b829550vbb-crop-center:720:720.jpg"
        return components.url ?? url
    }
}
