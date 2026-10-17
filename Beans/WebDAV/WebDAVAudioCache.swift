import CryptoKit
import Foundation

// Remote originals are downloaded to a dedicated cache, with a 1 GiB limit per transfer.
actor WebDAVAudioCache {
    static let shared = WebDAVAudioCache()
    private var retained: [URL: Int] = [:]
    private var cache: URL { FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("BeansWebDAVAudio", isDirectory: true) }

    func file(for track: WebDAVTrack, client: WebDAVClient) async throws -> WebDAVAudioLease {
        let key = SHA256.hash(data: Data((track.accountKey + "|" + track.relativePath).utf8)).map { String(format: "%02x", $0) }.joined()
        let ext = URL(fileURLWithPath: track.relativePath).pathExtension
        let target = cache.appendingPathComponent(key).appendingPathExtension(ext)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: target.path) { return lease(for: target) }
        let url = try WebDAVPaths.fileURL(path: track.relativePath, root: client.root)
        let temporary = try await client.download(url, limit: 1024 * 1024 * 1024)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try Task.checkCancellation()
        // Reentrant actor calls may finish the same track twice; keep the first complete cache entry.
        if !FileManager.default.fileExists(atPath: target.path) { try FileManager.default.moveItem(at: temporary, to: target) }
        return lease(for: target)
    }

    private func lease(for url: URL) -> WebDAVAudioLease {
        retained[url, default: 0] += 1
        return WebDAVAudioLease(url: url, cache: self)
    }

    func release(_ url: URL) { retained[url] = max(0, (retained[url] ?? 1) - 1) }

    func clear() throws {
        guard FileManager.default.fileExists(atPath: cache.path) else { return }
        for file in try FileManager.default.contentsOfDirectory(at: cache, includingPropertiesForKeys: nil) where (retained[file] ?? 0) == 0 {
            try FileManager.default.removeItem(at: file)
        }
    }
}

// The player and any in-flight load retain a lease, so clearing the cache cannot
// delete an AVPlayer file or a file awaiting main-actor installation.
final class WebDAVAudioLease: @unchecked Sendable {
    let url: URL
    private let cache: WebDAVAudioCache
    init(url: URL, cache: WebDAVAudioCache) { self.url = url; self.cache = cache }
    deinit {
        let url = url, cache = cache
        Task { await cache.release(url) }
    }
}
