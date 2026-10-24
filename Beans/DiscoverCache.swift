import Foundation

/// 主页数据内存缓存：避免每次切回主页 Tab 都重新请求接口。
/// 排行榜 / 歌单广场缓存 1 小时，每日推荐缓存 6 小时；
/// 点右上角刷新会强制重新加载。
final class DiscoverCache {
    static let shared = DiscoverCache()

    /// 单个平台的主页完整数据快照
    struct Snapshot: Codable {
        var dailySongs: [Song] = []
        var newAlbums: [Album] = []
        var topArtists: [Artist] = []
        var topLists: [TopList] = []
        var personalized: [Playlist] = []
        var kugouTopLists: [KugouTopInfo] = []
        var savedAt: Date = .distantPast

        var isEmpty: Bool {
            dailySongs.isEmpty && newAlbums.isEmpty && topArtists.isEmpty
                && topLists.isEmpty && personalized.isEmpty
                && kugouTopLists.isEmpty
        }
    }

    /// 排行榜 / 歌单广场缓存时长（秒）
    let listTTL: TimeInterval = 3600
    /// 每日推荐缓存时长（秒，推荐内容按天更新）
    let dailyTTL: TimeInterval = 6 * 3600

    private let storageKey = "beans.discover.cache.v2"
    private var store: [String: Snapshot] = [:]

    private init() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snapshots = try? JSONDecoder().decode([String: Snapshot].self, from: data) else {
            return
        }
        store = snapshots
    }

    func cached(for source: SearchProvider) -> Snapshot? {
        store[source.rawValue]
    }

    func save(_ snapshot: Snapshot, for source: SearchProvider) {
        store[source.rawValue] = snapshot
        persist()
    }

    /// 登录账号发生变化时清除该平台的主页快照，避免匿名或旧账号的每日推荐被继续复用。
    func invalidate(_ source: SearchProvider) {
        store.removeValue(forKey: source.rawValue)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(store) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    /// 缓存是否仍然新鲜：每日推荐单独放宽到 6 小时，其余按 1 小时
    func isFresh(_ snapshot: Snapshot, source: SearchProvider? = nil) -> Bool {
        let age = Date().timeIntervalSince(snapshot.savedAt)
        let ttl = snapshot.dailySongs.isEmpty ? listTTL : dailyTTL
        return age < ttl
    }
}
