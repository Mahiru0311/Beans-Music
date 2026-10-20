import Foundation

extension QishuiAPI_2_0_3 {
    /// 0x100564e54: UTF-8 bytes, recovered (nonstandard) seed, wrapping multiply, positive mask.
    public static func stableID(_ text: String) -> Int {
        var hash: UInt64 = 0x14650fb0739d0383
        for byte in text.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return max(1, Int(hash & 0x7fffffffffffffff))
    }

    /// Dictionary shape precedence: 0x10056af88.
    func trackDictionaries(_ value: Any?) -> [[String: Any]] {
        if let array = value as? [[String: Any]] { return array }
        guard let object = value as? [String: Any] else { return [] }
        for key in ["tracks", "media_resources", "data"] {
            if let array = object[key] as? [[String: Any]] { return array }
        }
        return object.values.compactMap { $0 as? [String: Any] }
    }

    /// 0x10056cfac does not use the track mapper's arbitrary dictionary-values fallback.
    func playlistDictionaries(_ value: Any?) -> [[String: Any]] {
        if let array = value as? [[String: Any]] { return array }
        guard let object = value as? [String: Any] else { return [] }
        for key in ["playlists", "data"] {
            if let array = object[key] as? [[String: Any]] { return array }
        }
        return []
    }

    /// 0x10056d19c and static arrays at 0x100b458d0, 0x100b45918, 0x100b45970.
    func makePlaylist(_ raw: [String: Any]) -> Playlist_2_0_3? {
        let playlist = raw["playlist"] as? [String: Any] ?? raw
        guard let identifier = Self.firstString(playlist, keys: ["id", "playlist_id"]), !identifier.isEmpty else { return nil }
        let count = Self.number(playlist["count_tracks"] ?? playlist["track_count"] ?? playlist["song_count"])
        // Defensive deviation from the binary's Int conversion trap for hostile numeric values.
        guard count.isFinite, count > Double(Int.min), count < Double(Int.max) else { return nil }
        return Playlist_2_0_3(
            id: Self.stableID(identifier),
            name: Self.firstString(playlist, keys: ["title", "name"]) ?? "未命名歌单",
            coverURL: QishuiResourceURL_2_0_3.playlistCover(in: playlist),
            trackCount: Int(count),
            creatorName: Self.firstString(playlist, keys: ["creator_name", "creatorName", "nickname"]) ?? "",
            playlistDescription: Self.firstString(playlist, keys: ["description", "intro"]) ?? "",
            source: .qishui, qishuiID: identifier
        )
    }

    /// 0x100570d3c: typed array first, then compact-map a heterogeneous array.
    func dictionaryArray(_ value: Any?) -> [[String: Any]] {
        if let array = value as? [[String: Any]] { return array }
        return (value as? [Any])?.compactMap { $0 as? [String: Any] } ?? []
    }

    /// 0x10056b350: entity / track_wrapper precedence, album artwork, duration and fee.
    func makeSong(_ raw: [String: Any]) -> Song_2_0_3? {
        let entity = raw["entity"] as? [String: Any]
        let wrapper = (entity?["track_wrapper"] ?? raw["track_wrapper"]) as? [String: Any]
        let track = entity?["track"] as? [String: Any]
            ?? raw["track"] as? [String: Any]
            ?? wrapper?["track"] as? [String: Any]
            ?? raw
        guard let identifier = Self.firstString(track, keys: ["id", "track_id"]), !identifier.isEmpty else { return nil }
        let album = track["album"] as? [String: Any]
        let sourceTrack = track["raw"] as? [String: Any] ?? track
        let sourceAlbum = sourceTrack["album"] as? [String: Any]
        let artists = dictionaryArray(track["artists"]).compactMap {
            Self.firstString($0, keys: ["name", "simple_display_name"])
        }.joined(separator: " / ")
        let coverValues: [Any?] = [sourceAlbum?["url_cover"], sourceAlbum?["cover_url"],
            album?["cover_url"], album?["coverURL"], album?["url_cover"],
            track["cover_url"], track["coverURL"], track["url_cover"], track["cover_uri"]]
        var cover: URL?
        for value in coverValues {
            if let url = QishuiResourceURL_2_0_3.first(in: value) { cover = url; break }
        }
        let rawDuration = Self.number(track["duration"] ?? track["duration_ms"] ?? track["interval"])
        let stats = track["stats"] as? [String: Any] ?? [:]
        let paid = Self.boolean(stats["is_vip"] ?? stats["is_paid"] ?? stats["need_pay"] ?? track["is_vip"])
        let fee = paid ? 1 : Self.number(track["fee"] ?? track["pay_flag"])
        guard fee.isFinite, fee > Double(Int.min), fee < Double(Int.max) else { return nil }
        return Song_2_0_3(
            id: Self.stableID(identifier),
            name: Self.firstString(track, keys: ["name", "trackName", "title"]) ?? "",
            artists: artists.isEmpty ? (Self.firstString(track, keys: ["artists_text", "artist", "singer"]) ?? "") : artists,
            album: album.flatMap { Self.firstString($0, keys: ["name"]) }
                ?? Self.firstString(track, keys: ["album_name", "albumName"]) ?? "",
            coverURL: cover, duration: rawDuration > 1000 ? rawDuration / 1000 : rawDuration,
            source: .qishui, qishuiID: identifier, fee: Int(fee)
        )
    }

    /// Bool/NSNumber/String conversion at 0x1005723d4.
    private static func boolean(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String { return ["1", "true", "yes", "on"].contains(value.lowercased()) }
        return false
    }
}
