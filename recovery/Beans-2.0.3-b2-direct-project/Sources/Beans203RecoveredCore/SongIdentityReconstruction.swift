import Foundation

extension SongSource_2_0_3 {
    /// 0x100326ba4 and the eight-entry byte jump table at file offset 0x77abb0.
    /// This API name is descriptive; original source-level spelling is not established.
    public var providerIdentifier: String {
        switch self {
        case .netease: return "netease"
        case .qq: return "qq"
        case .kugou: return "kugou"
        case .kuwo: return "kuwo"
        case .migu: return "migu"
        case .qishui: return "qishui"
        case .bilibili: return "bilibili"
        case .webdav: return "webdav"
        }
    }
}

extension Song_2_0_3 {
    /// 0x100326c48. Playback identity does not use QQ MID or Kugou hash.
    /// An empty optional identifier is present and is not replaced by the Int ID.
    public var playbackKey: String {
        switch source {
        case .qishui:
            return "qishui-" + (qishuiID ?? String(id))
        case .bilibili:
            return "bilibili-" + (bilibiliID ?? String(id))
        case .webdav:
            guard let track = webDAV else { return "webdav-missing-" + String(id) }
            return "webdav-" + (track.accountKey ?? track.connectionID.uuidString) + "-" + track.relativePath
        default:
            return source.providerIdentifier + "-" + String(id)
        }
    }

    /// Cache-key construction inside 0x1003b59b0. WebDAV exits the lyric path
    /// before cache lookup; this optional API represents that observed gate.
    public var lyricCacheKey: String? {
        switch source {
        case .webdav: return nil
        case .qq: return "qq:" + (qqMid ?? playbackKey)
        case .kugou: return "kugou:" + (kugouHash ?? playbackKey)
        case .qishui: return "qishui:" + (qishuiID ?? playbackKey)
        case .bilibili: return "bilibili:" + (bilibiliID ?? playbackKey)
        default: return source.providerIdentifier + ":" + String(id)
        }
    }
}

extension LyricsCache_2_0_3 {
    /// Integration seams exposing the recovered caller's key policy to the cache.
    public func load(for song: Song_2_0_3) -> CachedLyrics_2_0_3? {
        guard let key = song.lyricCacheKey else { return nil }
        return load(for: key)
    }

    public func save(_ value: CachedLyrics_2_0_3, for song: Song_2_0_3) {
        guard let key = song.lyricCacheKey else { return }
        save(value, for: key)
    }
}
