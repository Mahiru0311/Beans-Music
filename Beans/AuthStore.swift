import Foundation

/// 酷狗账号展示结构（替代原 NetEaseUser，仅作展示/缓存用，无网易云网络代码）。
struct CocoAccount: Identifiable, Hashable, Codable {
    let uid: Int
    let nickname: String
    let avatarURL: URL?
    let vipType: Int

    var id: Int { uid }

    var vipBadge: String? {
        if vipType > 0 { return "VIP" }
        return nil
    }
}

/// 账号库：以酷狗登录为准（KugouMusicAuth 单例），对外保持原 AuthStore 接口，
/// 供 Discover/Library/Profile/AddToPlaylist 等现有界面复用，不再走网易云。
final class AuthStore: ObservableObject {
    @Published var user: CocoAccount?
    @Published var isLoggedIn = false
    @Published var playlists: [Playlist] = []

    private let defaults = UserDefaults.standard
    private let userKey = "beans.coco.user"

    init() {
        syncFromKugou()
        NotificationCenter.default.addObserver(
            forName: .beansKugouLoginDidUpdate, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.syncFromKugou() }
        }
    }

    private func syncFromKugou() {
        let kugou = KugouMusicAuth.shared
        if kugou.isLoggedIn {
            let account = CocoAccount(
                uid: Int(kugou.userId) ?? 0,
                nickname: kugou.nickname,
                avatarURL: kugou.avatarURL,
                vipType: kugou.vipType
            )
            user = account
            isLoggedIn = true
            if let data = try? JSONEncoder().encode(account) {
                defaults.set(data, forKey: userKey)
            }
            if let cached = SyncedPlaylistCache.shared.cachedPlaylists(source: .kugou, accountID: kugou.userId) {
                playlists = cached.playlists
            }
        } else {
            user = nil
            playlists = []
            isLoggedIn = false
        }
    }

    @MainActor
    func finishLogin() async throws {
        // 酷狗登录由 KugouLoginSheet 的二维码流程完成并保存到 KugouMusicAuth；
        // 这里只同步账号与歌单，不再发网易云请求。
        syncFromKugou()
        guard isLoggedIn else {
            throw CocoError.unknown("请先登录酷狗音乐")
        }
        await loadLibrary(force: true)
    }

    @MainActor
    func refreshAccount() async {
        syncFromKugou()
    }

    @MainActor
    func loadLibrary(force: Bool = false) async {
        guard let account = user else { return }
        let accountID = KugouMusicAuth.shared.userId
        if let cached = SyncedPlaylistCache.shared.cachedPlaylists(source: .kugou, accountID: accountID) {
            playlists = cached.playlists
            if !force, SyncedPlaylistCache.shared.isFresh(cached) {
                return
            }
        }
        if let fetched = try? await KugouMusicAPI.shared.userPlaylists(), !fetched.isEmpty {
            playlists = fetched
            SyncedPlaylistCache.shared.savePlaylists(fetched, source: .kugou, accountID: accountID)
        }
        _ = account
    }

    func logout() {
        KugouMusicAuth.shared.logout()
        user = nil
        playlists = []
        isLoggedIn = false
        defaults.removeObject(forKey: userKey)
    }
}
