import Foundation

/// 酷狗专版账号资料（替代原网易云用户类型，字段名保持与旧调用点兼容）。
struct CoUser: Identifiable, Hashable, Codable {
    let uid: Int
    let nickname: String
    let avatarURL: URL?
    let vipType: Int

    var id: Int { uid }

    var vipBadge: String? {
        if vipType >= 11 { return "SVIP" }
        if vipType > 0 { return "VIP" }
        return nil
    }
}

final class AuthStore: ObservableObject {
    @Published var user: CoUser?
    @Published var isLoggedIn = false
    @Published var playlists: [Playlist] = []

    private let defaults = UserDefaults.standard
    private let userKey = "co.user"

    init() {
        syncFromKugou()
        if isLoggedIn {
            playlists = SyncedPlaylistCache.shared
                .cachedPlaylists(source: .kugou, accountID: KugouMusicAuth.shared.userId)?
                .playlists
                .filter { $0.name != "我喜欢的音乐" } ?? []
        }
    }

    private func syncFromKugou() {
        let kugou = KugouMusicAuth.shared
        isLoggedIn = kugou.isLoggedIn
        if kugou.isLoggedIn {
            user = CoUser(
                uid: Int(kugou.userId) ?? 0,
                nickname: kugou.nickname,
                avatarURL: kugou.avatarURL,
                vipType: kugou.vipType
            )
        } else {
            user = nil
        }
    }

    @MainActor
    func finishLogin() async throws {
        syncFromKugou()
        guard isLoggedIn else { throw CoError.unknown("请先登录酷狗音乐") }
        let lists = (try? await KugouMusicAPI.shared.userPlaylists()) ?? []
        playlists = lists.filter { $0.name != "我喜欢的音乐" }
        if !playlists.isEmpty {
            SyncedPlaylistCache.shared.savePlaylists(
                playlists,
                source: .kugou,
                accountID: KugouMusicAuth.shared.userId
            )
        }
        if let user, let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: userKey)
        }
        DiscoverCache.shared.invalidate(.kugou)
    }

    @MainActor
    func refreshAccount() async {
        syncFromKugou()
    }

    @MainActor
    func loadLibrary(force: Bool = false) async {
        syncFromKugou()
        guard isLoggedIn else { return }
        let accountID = KugouMusicAuth.shared.userId
        if let cached = SyncedPlaylistCache.shared.cachedPlaylists(source: .kugou, accountID: accountID) {
            playlists = cached.playlists.filter { $0.name != "我喜欢的音乐" }
            if !force, SyncedPlaylistCache.shared.isFresh(cached), !CoNetworkStatus.shared.isReachable {
                return
            }
        }
        if let cached = try? await KugouMusicAPI.shared.userPlaylists() {
            let filtered = cached.filter { $0.name != "我喜欢的音乐" }
            if !filtered.isEmpty {
                playlists = filtered
                SyncedPlaylistCache.shared.savePlaylists(filtered, source: .kugou, accountID: accountID)
            }
        }
    }

    func logout() {
        KugouMusicAuth.shared.logout()
        user = nil
        playlists = []
        isLoggedIn = false
        defaults.removeObject(forKey: userKey)
        DiscoverCache.shared.invalidate(.kugou)
    }
}
