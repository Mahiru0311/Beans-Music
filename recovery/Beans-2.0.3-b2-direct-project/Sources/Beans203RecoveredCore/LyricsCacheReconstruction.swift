import Foundation

/// Returned value layout from 0x10031b010; public type/name are reconstruction choices.
public struct CachedLyrics_2_0_3 {
    public var lyric: String
    public var translation: String?
    public var wordTiming: String?
    public var wordFormat: KaraokeSyntax_2_0_3?

    public init(lyric: String, translation: String? = nil, wordTiming: String? = nil,
                wordFormat: KaraokeSyntax_2_0_3? = nil) {
        self.lyric = lyric; self.translation = translation
        self.wordTiming = wordTiming; self.wordFormat = wordFormat
    }
}

extension KaraokeSyntax_2_0_3 {
    /// Raw-value word tables at file offsets 0x77a4d8 and 0x77a4f8.
    public var cacheRawValue: String {
        switch self {
        case .parenthesizedAbsolute: return "neteaseYRC"
        case .parenthesizedAutomatic: return "qqQRC"
        case .angleRelative: return "kugouKRC"
        }
    }

    public init?(cacheRawValue: String) {
        switch cacheRawValue {
        case "neteaseYRC": self = .parenthesizedAbsolute
        case "qqQRC": self = .parenthesizedAutomatic
        case "kugouKRC": self = .angleRelative
        default: return nil
        }
    }
}

extension LyricsCache_2_0_3 {
    /// Entry descriptor 0x7c7d9c and CodingKeys 0x7c7dc4; synthesized codec
    /// matches 0x10031a7f8 (decode) and 0x10031ada0 (encode).
    private struct Entry: Codable {
        var lyric: String
        var translation: String?
        var wordTiming: String?
        var wordFormat: String?
        var savedAt: Date
    }

    func storageKey(for key: String) -> String {
        prefix + (key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key)
    }

    /// 0x10031b010: missing/corrupt/expired data returns nil without deleting storage.
    public func load(for key: String) -> CachedLyrics_2_0_3? {
        guard let data = defaults.data(forKey: storageKey(for: key)),
              let entry = try? JSONDecoder().decode(Entry.self, from: data),
              // Literal at 0x77a518: the optimized call site does not read self.maxAge.
              now().timeIntervalSince(entry.savedAt) < 1_209_600,
              !entry.lyric.isEmpty || (entry.wordFormat != nil && !(entry.wordTiming ?? "").isEmpty)
        else { return nil }
        return CachedLyrics_2_0_3(lyric: entry.lyric, translation: entry.translation,
                                 wordTiming: entry.wordTiming,
                                 wordFormat: entry.wordFormat.flatMap(KaraokeSyntax_2_0_3.init(cacheRawValue:)))
    }

    /// 0x10031b3ac: reject empty lyric unless timed text and a format are present.
    /// Rejected writes and JSON errors leave an existing entry untouched.
    public func save(_ value: CachedLyrics_2_0_3, for key: String) {
        guard !value.lyric.isEmpty || (value.wordFormat != nil && !(value.wordTiming ?? "").isEmpty) else { return }
        let entry = Entry(lyric: value.lyric, translation: value.translation,
                          wordTiming: value.wordTiming, wordFormat: value.wordFormat?.cacheRawValue, savedAt: now())
        guard let data = try? JSONEncoder().encode(entry) else { return }
        defaults.set(data, forKey: storageKey(for: key))
    }
}
