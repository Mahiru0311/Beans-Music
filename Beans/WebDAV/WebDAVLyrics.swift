import Foundation

enum WebDAVLyrics {
    @MainActor
    static func load(for track: WebDAVTrack) async throws -> String {
        let client = try WebDAVStore.shared.client(for: track)
        let path = (track.relativePath as NSString).deletingPathExtension + ".lrc"
        let url = try WebDAVPaths.fileURL(path: path, root: client.root)
        let file = try await client.download(url, limit: 2 * 1024 * 1024)
        defer { try? FileManager.default.removeItem(at: file) }
        let data = try Data(contentsOf: file)
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else { throw WebDAVError.invalidListing }
        return text
    }
}
