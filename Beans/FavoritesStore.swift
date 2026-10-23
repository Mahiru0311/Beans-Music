import Foundation

/// 收藏管理（红心）：酷狗专版，本地持久化 + 酷狗官方歌单镜像。
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    /// 酷狗红心收藏（本地持久化）
    @Published private(set) var kugouFavoriteSongs: [Song] = []
    /// 酷狗官方歌单收藏的本地镜像，用于显示收藏状态，不替代设备本地歌单。
    @Published private(set) var kugouOfficialFavoriteSongs: [Song] = []

    private let defaults = UserDefaults.standard
    private let kugouKey = "beans.fav.kugou.v1"
    private let kugouOfficialKey = "beans.fav.kugou.official.v1"

    private init() {
        kugouFavoriteSongs = Self.loadSongs(kugouKey)
        kugouOfficialFavoriteSongs = Self.loadSongs(kugouOfficialKey)
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

    func markKugouOfficial(_ song: Song, liked: Bool) {
        if liked {
            kugouOfficialFavoriteSongs.removeAll { $0.identityKey == song.identityKey }
            kugouOfficialFavoriteSongs.insert(song, at: 0)
        } else {
            kugouOfficialFavoriteSongs.removeAll { $0.identityKey == song.identityKey }
        }
        saveSongs(kugouOfficialFavoriteSongs, key: kugouOfficialKey)
    }
}
