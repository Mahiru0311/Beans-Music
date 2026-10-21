import Foundation

extension QishuiAPI_2_0_3 {
    /// 0x10056e530...0x1005702e8. Public names are reconstruction seams.
    /// The binary requests even an empty ID; IDs and cache keys are not normalized.
    public func playlistDetails(
        id: String, limit: Int, forceRefresh: Bool,
        onProgress: (@MainActor ([Song_2_0_3]) -> Void)? = nil
    ) async throws -> QishuiPlaylistDetails_2_0_3 {
        let limit = min(1000, max(1, limit))
        let key = playlistDetailsCacheKey(id: id, limit: limit)
        let lookup = cacheLookup(playlistDetailsCache, key: key, ttl: 1800, staleTTL: 604800)
        if let fresh = lookup.fresh, !forceRefresh {
            if let onProgress { await onProgress(fresh.songs) }
            return fresh
        }
        // A forced refresh retains the fresh value as the failure/empty-result fallback.
        let fallback = lookup.fresh ?? lookup.stale
        let pageCount = min(100, limit)
        var playlist: Playlist_2_0_3?
        var songs: [Song_2_0_3] = []
        var seenSongs = Set<String>()
        var seenCursors = Set<String>()
        var cursor = ""
        var sessionID = ""
        do {
            for _ in 0..<20 {
                if songs.count >= limit { break }
                try Task.checkCancellation()
                var query = ["playlist_id": id, "count": String(pageCount)]
                if !cursor.isEmpty { query["cursor"] = cursor }
                if !sessionID.isEmpty { query["session_id"] = sessionID }
                let object = try await requestObject("/playlist/detail", query: query)
                if sessionID.isEmpty {
                    sessionID = Self.firstString(object, keys: ["session_id", "sessionId"]) ?? ""
                }
                if playlist == nil, let raw = object["playlist"] as? [String: Any] {
                    playlist = makePlaylist(raw)
                }
                let page = trackDictionaries(object["media_resources"] ?? object["tracks"] ?? object["songs"] ?? [])
                    .compactMap(makeSong)
                guard !page.isEmpty else { break }
                for song in page {
                    let identity = "qishui-" + (song.qishuiID ?? String(song.id))
                    if seenSongs.insert(identity).inserted { songs.append(song) }
                    if songs.count >= limit { break }
                }
                // Unlike search, detail progress is emitted on duplicate-only pages too.
                if !songs.isEmpty, let onProgress { await onProgress(songs) }
                let next = Self.firstString(object, keys: ["next_cursor", "nextCursor", "cursor"]) ?? ""
                guard !next.isEmpty, next != cursor, seenCursors.insert(next).inserted else { break }
                cursor = next
            }
        } catch {
            if Task.isCancelled { throw error }
            // Detail errors prefer cached details; uncached partial downloads do not succeed.
            if let fallback { return fallback }
            throw error
        }
        let result = QishuiPlaylistDetails_2_0_3(playlist: playlist, songs: songs)
        guard !songs.isEmpty else { return fallback ?? result }
        playlistDetailsCache.setObject(QishuiCacheBox_2_0_3(value: result), forKey: key as NSString)
        return result
    }

    /// 0x100567750 / 0x10056784c projects the details result's song array.
    public func playlistSongs(
        id: String, limit: Int, forceRefresh: Bool,
        onProgress: (@MainActor ([Song_2_0_3]) -> Void)? = nil
    ) async throws -> [Song_2_0_3] {
        try await playlistDetails(id: id, limit: limit, forceRefresh: forceRefresh, onProgress: onProgress).songs
    }

    /// Literal order at 0x10056e758: details|baseURL|playlistID|clampedLimit.
    func playlistDetailsCacheKey(id: String, limit: Int) -> String {
        let base = recoveryDefaults.string(forKey: Self.baseURLKey) ?? Self.defaultBaseURL
        return "details|\(base)|\(id)|\(limit)"
    }
}
