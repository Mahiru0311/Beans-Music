import Foundation

/// 收藏管理（红心）：Co 纯酷狗，本地持久化为主，不再走网易云/QQ 云端同步。
/// 旧版红心失效常因云端同步失败回滚本地状态；Co 改为本地先行、永不回滚。
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    /// QQ 红心收藏（本地持久化，供音乐库展示）
    @Published private(set) var qqFavoriteSongs: [Song] = []
    /// 网易云红心收藏（本地缓存 + 云端同步）
    @Published private(set) var neteaseFavoriteSongs: [Song] = []
    /// 酷狗红心收藏（本地持久化，酷狗暂无稳定云端红心写入接口）
    @Published private(set) var kugouFavoriteSongs: [Song] = []

    private let defaults = UserDefaults.standard
    private let neteaseKey = "beans.fav.netease.v1"
    private let qqKey = "beans.fav.qq.v1"
    private let kugouKey = "beans.fav.kugou.v1"

    private init() {
        qqFavoriteSongs = Self.loadSongs(qqKey)
        neteaseFavoriteSongs = Self.loadSongs(neteaseKey)
        kugouFavoriteSongs = Self.loadSongs(kugouKey)
    }

    /// 该歌曲是否已收藏
    func isLiked(_ song: Song?) -> Bool {
        guard let song else { return false }
        switch song.source {
        case .netease:
            return neteaseFavoriteSongs.contains { $0.id == song.id }
        case .qq:
            if let mid = song.qqMid, !mid.isEmpty {
                return qqFavoriteSongs.contains { $0.qqMid == mid || $0.identityKey == song.identityKey }
            }
            return qqFavoriteSongs.contains { $0.identityKey == song.identityKey }
        case .kugou:
            return kugouFavoriteSongs.contains { $0.identityKey == song.identityKey }
        }
    }

    /// 切换收藏状态；返回是否成功（云端同步失败时网易云会回滚）
    @discardableResult
    func toggle(_ song: Song) async -> Bool {
        // Co #5 修复：红心只写本地，云端失败不再回滚（旧版网易云/QQ 同步失败会把红心弹回）。
        let liked = !isLiked(song)
        switch song.source {
        case .netease: updateNetease(song, liked: liked)
        case .qq: updateQQ(song, liked: liked)
        case .kugou: updateKugou(song, liked: liked)
        }
        return true
    }

    /// 移除 QQ 收藏（音乐库侧滑删除）
    func removeQQFavorite(_ song: Song) {
        updateQQ(song, liked: false)
    }

    /// 登录 QQ / 微信后从 QQ 音乐云端同步“我的喜欢”。
    /// 只有云端明确返回歌曲时才覆盖本地，避免接口空响应误清空收藏。
    @MainActor
    func syncQQFromCloud() async {
        // Co 已删 QQ 云端同步：保留签名供旧调用点编译通过，实际不做任何事。
    }

    private func updateNetease(_ song: Song, liked: Bool) {
        if liked {
            neteaseFavoriteSongs.removeAll { $0.id == song.id }
            neteaseFavoriteSongs.insert(song, at: 0)
        } else {
            neteaseFavoriteSongs.removeAll { $0.id == song.id }
        }
        saveSongs(neteaseFavoriteSongs, key: neteaseKey)
    }

    private func updateQQ(_ song: Song, liked: Bool) {
        if liked {
            qqFavoriteSongs.removeAll { existing in
                existing.identityKey == song.identityKey
                    || (existing.qqMid != nil && song.qqMid != nil && existing.qqMid == song.qqMid)
            }
            qqFavoriteSongs.insert(song, at: 0)
        } else {
            qqFavoriteSongs.removeAll { existing in
                existing.identityKey == song.identityKey
                    || (existing.qqMid != nil && song.qqMid != nil && existing.qqMid == song.qqMid)
            }
        }
        saveSongs(qqFavoriteSongs, key: qqKey)
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

    /// 退出网易云登录时清空本地网易云收藏缓存（保留 QQ 收藏）
    func resetNetease() {
        neteaseFavoriteSongs = []
        defaults.removeObject(forKey: neteaseKey)
    }
}
