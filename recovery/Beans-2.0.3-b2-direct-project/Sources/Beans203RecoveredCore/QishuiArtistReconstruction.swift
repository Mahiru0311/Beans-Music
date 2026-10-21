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
}
