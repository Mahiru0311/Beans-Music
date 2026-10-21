import Foundation

extension QishuiAPI_2_0_3 {
    /// 0x100564a10 / 0x100564ad0. Public spelling is a reconstruction seam.
    /// Like the original prefix operation, a negative limit is unsupported.
    public func songsByArtist(name: String, limit: Int) async throws -> [Song_2_0_3] {
        let songs = try await searchSongs(keyword: name, limit: max(limit, 100))
        let normalizedName = Self.normalizedArtistName(name)
        let matches = songs.filter { song in
            Self.artistNames(in: song.artists).contains { artist in
                let normalizedArtist = Self.normalizedArtistName(artist)
                return normalizedName.contains(normalizedArtist) || normalizedArtist.contains(normalizedName)
            }
        }
        return Array((matches.isEmpty ? songs : matches).prefix(limit))
    }

    /// 0x1005704f0: locale-sensitive folding, lowercase, then Character properties.
    static func normalizedArtistName(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased().filter { !$0.isWhitespace && !$0.isPunctuation }
    }

    /// 0x10056db1c; separator bytes at Mach-O file offset 0x79a400.
    static func artistNames(in text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: "/／,，、&＆+＋|｜;；"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// 0x100564d38 / 0x100564d58: overfetch songs, then project album groups.
    /// As in the binary, limit must be nonnegative and limit * 4 must fit Int.
    public func albumsByArtist(name: String, limit: Int) async throws -> [Album_2_0_3] {
        let songs = try await songsByArtist(name: name, limit: max(limit * 4, 160))
        return Self.albums(from: songs, limit: limit)
    }

    /// Grouping 0x10056de7c; projection 0x1005725bc; comparison 0x10057467c.
    static func albums(from songs: [Song_2_0_3], limit: Int) -> [Album_2_0_3] {
        var groups: [String: [Song_2_0_3]] = [:]
        for song in songs {
            let name = song.album.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let key = normalizedArtistName(name) + "|" + normalizedArtistName(song.artists)
            groups[key, default: []].append(song)
        }
        let albums = groups.values.compactMap { group -> Album_2_0_3? in
            guard let first = group.first else { return nil }
            // Identity/display use the first song's original strings, not the normalized key.
            return Album_2_0_3(
                id: "qishui-album-" + String(stableID(first.album + "|" + first.artists)),
                name: first.album, artistName: first.artists, coverURL: first.coverURL,
                source: .qishui, trackCount: group.count
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        // Equal-name order inherits dictionary enumeration; the binary has no tie breaker.
        return Array(albums.prefix(limit))
    }
}
