import Foundation

/// 收藏管理（红心）：酷狗专版，本地持久化 + 酷狗官方歌单镜像。
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    /// 酷狗红心收藏（本地持久化）
    @Published private(set) var kugouFavoriteSongs: [Song] = []
    /// 酷狗官方歌单收藏的本地镜像，用于显示收藏状态，不替代设备本地歌单。
    @Published private(set) var kugouOfficialFavoriteSongs: [Song] = []

    private let defaults = UserDefaults.standard
    private let kugouKey = "co.fav.kugou.v1"
    private let kugouOfficialKey = "co.fav.kugou.official.v1"

    private init() {
        kugouFavoriteSongs = Self.loadSongs(kugouKey)
        kugouOfficialFavoriteSongs = Self.loadSongs(kugouOfficialKey)
        // 一次性找回：旧版播放页爱心只写进了本地歌单库（“我的收藏歌单”），
        // 没写进这里，导致我的页“我喜欢”一直是空。只迁这一个默认收藏歌单，
        // 用户自建的其他本地歌单不迁，避免把“加入某歌单”误当成点爱心。
        let migrationKey = "co.fav.migratedLocalDefault.v1"
        if !defaults.bool(forKey: migrationKey) {
            let localSongs = LocalLibraryStore.shared.playlists
                .first(where: { $0.name == "我的收藏歌单" })?.songs ?? []
            for song in localSongs where !kugouFavoriteSongs.contains(where: { $0.identityKey == song.identityKey }) {
                kugouFavoriteSongs.append(song)
            }
            if !localSongs.isEmpty { saveSongs(kugouFavoriteSongs, key: kugouKey) }
            defaults.set(true, forKey: migrationKey)
        }
    }

    /// 我的页“我喜欢”的唯一读口：红心库 + 官方收藏库去重合并。
    /// 播放页爱心（本地/官方两条路）最终都要落到这两张表里，否则读口永远对不上。
    var allLikedSongs: [Song] {
        var seen = Set<String>()
        var result: [Song] = []
        for song in kugouFavoriteSongs + kugouOfficialFavoriteSongs where seen.insert(song.identityKey).inserted {
            result.append(song)
        }
        return result
    }

    /// 显式置位（不是取反）：播放页爱心本地路用它与本地歌单库同步，
    /// 避免 toggle 在“已官方收藏”时把状态算反。
    func setKugouLiked(_ song: Song, liked: Bool) {
        if liked {
            guard !kugouFavoriteSongs.contains(where: { $0.identityKey == song.identityKey }) else { return }
            kugouFavoriteSongs.insert(song, at: 0)
        } else {
            kugouFavoriteSongs.removeAll { $0.identityKey == song.identityKey }
        }
        saveSongs(kugouFavoriteSongs, key: kugouKey)
    }

    func isLiked(_ song: Song?) -> Bool {
        guard let song else { return false }
        return kugouFavoriteSongs.contains { $0.identityKey == song.identityKey }
            || kugouOfficialFavoriteSongs.contains { $0.identityKey == song.identityKey }
    }

    func isOfficiallyLiked(_ song: Song?) -> Bool {
        guard let song else { return false }
        return kugouOfficialFavoriteSongs.contains { $0.identityKey == song.identityKey }
    }

    @discardableResult
    func toggle(_ song: Song) async -> Bool {
        let liked = !isLiked(song)
        updateKugou(song, liked: liked)
        return true
    }

    private func updateKugou(_ song: Song, liked: Bool) {
        if liked {
            kugouFavoriteSongs.removeAll { $0.identityKey == song.identityKey }
            kugouFavoriteSongs.insert(song, at: 0)
        } else {
            kugouFavoriteSongs.removeAll { $0.identityKey == song.identityKey }
        }
        saveSongs(kugouFavoriteSongs, key: kugouKey)
    }

    private static func loadSongs(_ key: String) -> [Song] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([Song].self, from: data) else { return [] }
        return saved
    }

    private func saveSongs(_ songs: [Song], key: String) {
        if let data = try? JSONEncoder().encode(songs) {
            defaults.set(data, forKey: key)
        }
    }

}
