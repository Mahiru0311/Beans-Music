import Foundation

extension QishuiAPI_2_0_3 {
    /// Async entry 0x100565a28 and continuations through 0x100566e40.
    /// Names/visibility are reconstruction seams; the callback is synchronous on MainActor.
    public func searchSongs(
        keyword: String, limit: Int,
        onProgress: (@MainActor ([Song_2_0_3]) -> Void)? = nil
    ) async throws -> [Song_2_0_3] {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return [] }
        let limit = min(200, max(1, limit))
        let key = catalogCacheKey("songs", query: keyword, limit: limit)
        // The call site uses literal 300/172800, not the stored TTL field.
        let lookup = cacheLookup(songSearchCache, key: key, ttl: 300, staleTTL: 172800)
        if let fresh = lookup.fresh { return fresh }
        var songs: [Song_2_0_3] = []
        var seenIdentifiers = Set<String>()
        var seenOffsets = Set<Int>()
        var offset = 0
        do {
            for _ in 0..<10 {
                if songs.count >= limit { break }
                try Task.checkCancellation()
                guard seenOffsets.insert(offset).inserted else { break }
                let query = ["keywords": keyword, "count": String(min(100, limit - songs.count)),
                             "cursor": String(offset), "offset": String(offset)]
                var response = try await requestObject("/search/mixed", query: query)
                var page = trackDictionaries(response["tracks"] ?? response["data"] ?? response).compactMap(makeSong)
                if page.isEmpty {
                    response = try await requestObject("/search", query: query)
                    page = trackDictionaries(response["tracks"] ?? response["data"] ?? response).compactMap(makeSong)
                }
                guard !page.isEmpty else { break }
                let previousCount = songs.count
                for song in page {
                    // 0x100326c48: Qishui's identity is source prefix plus original ID.
                    // makeSong always supplies a nonempty qishuiID.
                    let identity = "qishui-" + (song.qishuiID ?? String(song.id))
                    if seenIdentifiers.insert(identity).inserted { songs.append(song) }
                    if songs.count >= limit { break }
                }
                if songs.count > previousCount, let onProgress { await onProgress(songs) }
                let pagination = try Self.searchPagination(response, offset: offset, mappedCount: page.count)
                guard pagination.hasMore, pagination.nextOffset > offset else { break }
                offset = pagination.nextOffset
            }
        } catch {
            if Task.isCancelled { throw error }
            // Error continuations return partial results without making them a fresh cache entry.
            if !songs.isEmpty { return songs }
            if let stale = lookup.stale { return stale }
            throw error
        }
        guard !songs.isEmpty else { return lookup.stale ?? [] }
        songSearchCache.setObject(QishuiCacheBox_2_0_3(value: songs), forKey: key as NSString)
        return songs
    }

    /// 0x1005699a0 with lookup/conversion helpers 0x100569c30/0x100569cfc/0x100569ff0.
    static func searchPagination(
        _ object: [String: Any], offset: Int, mappedCount: Int
    ) throws -> (hasMore: Bool, nextOffset: Int) {
        let upstream = object["upstream"] as? [String: Any] ?? [:]
        let upstreamData = upstream["data"] as? [String: Any] ?? [:]
        let pagination = object["pagination"] as? [String: Any]
            ?? upstream["pagination"] as? [String: Any]
            ?? upstreamData["pagination"] as? [String: Any] ?? [:]
        let scopes = [object, upstream, upstreamData, pagination]
        let more = optionalSearchBool(firstPresent(scopes, keys: ["has_more", "hasMore", "has_next", "hasNext"]))
        let proposed = optionalSearchInteger(firstPresent(scopes, keys: [
            "next_offset", "nextOffset", "next_cursor", "nextCursor", "cursor"
        ]))
        let advances = proposed.map { $0 > offset } ?? false
        let next: Int
        if advances, let proposed { next = proposed }
        else {
            let addition = offset.addingReportingOverflow(max(1, mappedCount))
            // Defensive deviation: binary traps on cursor arithmetic overflow.
            guard !addition.overflow else { throw QishuiAPIError_2_0_3.invalidResponse }
            next = addition.partialValue
        }
        return (more ?? advances, next)
    }

    private static func firstPresent(_ scopes: [[String: Any]], keys: [String]) -> Any? {
        for scope in scopes {
            for key in keys { if let value = scope[key] { return value } }
        }
        return nil
    }

    /// Unknown strings return nil; unlike fee flags, "on" is NOT accepted. No trimming.
    private static func optionalSearchBool(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String {
            switch value.lowercased() {
            case "1", "true", "yes": return true
            case "0", "false", "no": return false
            default: return nil
            }
        }
        return nil
    }

    private static func optionalSearchInteger(_ value: Any?) -> Int? {
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
}
