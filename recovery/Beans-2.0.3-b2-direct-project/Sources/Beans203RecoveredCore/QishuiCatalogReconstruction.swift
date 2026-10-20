import Foundation

extension QishuiAPI_2_0_3 {
    /// Entry 0x1005654d0, result 0x100565708, error 0x10056598c.
    public func searchPlaylists(keyword: String, limit: Int) async throws -> [Playlist_2_0_3] {
        let query = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let count = min(max(limit, 1), 50)
        let key = catalogCacheKey("playlists", query: query, limit: count)
        let lookup = cacheLookup(playlistSearchCache, key: key, ttl: playlistSearchTTL, staleTTL: 604800)
        if let fresh = lookup.fresh { return fresh }
        do {
            let data = try await requestObject("/search/playlist", query: ["keywords": query, "count": String(count)])
            let mapped = playlistDictionaries(data["playlists"] ?? data["data"] ?? data).compactMap(makePlaylist)
            let result = Array(mapped.prefix(count))
            if !result.isEmpty {
                storeInCache(result, cache: playlistSearchCache, key: key)
                return result
            }
            return lookup.stale ?? []
        } catch {
            if Task.isCancelled { throw error }
            if let stale = lookup.stale { return stale }
            throw error
        }
    }

    /// Entry 0x10056726c, result 0x10056743c, error 0x1005676bc.
    public func recommendedPlaylists(limit: Int) async throws -> [Playlist_2_0_3] {
        let count = min(max(limit, 1), 50)
        let key = catalogCacheKey("recommendations", query: "guest", limit: count)
        let lookup = cacheLookup(recommendationCache, key: key, ttl: recommendationTTL, staleTTL: 604800)
        if let fresh = lookup.fresh { return fresh }
        do {
            let data = try await requestObject("/recommend/playlist", query: ["count": String(count)])
            let mapped = playlistDictionaries(data["playlists"] ?? data["data"] ?? data).compactMap(makePlaylist)
            let result = Array(mapped.prefix(count))
            if !result.isEmpty {
                storeInCache(result, cache: recommendationCache, key: key)
                return result
            }
            return lookup.stale ?? []
        } catch {
            if Task.isCancelled { throw error }
            if let stale = lookup.stale { return stale }
            throw error
        }
    }

    /// Array cache insertion 0x10056cdc0; generic spelling is reconstruction scaffolding.
    private func storeInCache<Value>(_ value: Value, cache: NSCache<NSString, QishuiCacheBox_2_0_3<Value>>, key: String) {
        cache.setObject(QishuiCacheBox_2_0_3(value: value), forKey: key as NSString)
    }
}
