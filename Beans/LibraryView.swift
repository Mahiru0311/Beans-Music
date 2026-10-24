import SwiftUI

private enum LibraryRoute: Hashable {
    case playlist(Playlist)
}

enum LibraryProvider: String, CaseIterable, Identifiable {
    case kugou = "酷狗音乐"

    var id: String { rawValue }

    var tint: LinearGradient {
        LinearGradient(colors: [Color(red: 0.12, green: 0.58, blue: 0.95), Color(red: 0.02, green: 0.32, blue: 0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var icon: String { "music.note" }

    var brandImageName: String? { "BrandKugou" }
}

private extension LibraryProvider {
    var songSource: SongSource { .kugou }
}

struct LibraryView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var favorites: FavoritesStore
    @Environment(\.beansUsesSharedRootBackdrop) private var usesSharedRootBackdrop
    @ObservedObject private var kugouAuth = KugouMusicAuth.shared
    @ObservedObject private var platformPrefs = PlatformPreferenceStore.shared

    @State private var showHistory = false
    @State private var showSectionSort = false
    @State private var showSyncedPlaylistSort = false
    /// 音乐库板块顺序（本地音乐库 / 我的歌单 / 最近播放，可自定义）
    @State private var libraryOrder = SectionOrderStore.load(SectionOrderStore.libraryKey, defaults: SectionOrderStore.libraryDefaults)
    @State private var navigationPath: [LibraryRoute] = []
    @State private var legacyRoute: LibraryRoute?
    @State private var showCreatePlaylist = false
    @State private var newPlaylistName = ""
    @State private var pendingDelete: Playlist?
    @State private var showDeleteConfirm = false
    @AppStorage("beans.homeHeaderHideSort") private var hideSortButton = false
    @AppStorage(PlatformPreferenceStore.hidePickerKey) private var hidePlatformPicker = false
    @State private var kugouPlaylists: [Playlist] = []
    @State private var kugouLoading = false
    @State private var kugouSavedAt = Date.distantPast
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    private var source: LibraryProvider { .kugou }

    private var orderedKugouPlaylists: [Playlist] {
        SyncedPlaylistOrderStore.shared.ordered(kugouPlaylists, source: .kugou)
    }

    private var kugouCacheAccountID: String {
        kugouAuth.userId
    }

    private var syncedPlaylistBinding: Binding<[Playlist]> {
        Binding(
            get: { orderedKugouPlaylists },
            set: { value in
                kugouPlaylists = value
                SyncedPlaylistOrderStore.shared.save(value, source: source.songSource)
            }
        )
    }

    private var isNativeClean: Bool {
        BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    var body: some View {
        let _ = theme.accent
        BeansNavigationStackWithPath(path: $navigationPath) {
        ZStack {
            if !usesSharedRootBackdrop {
                // 页面背景：同步开启时显示壁纸/背景色，否则默认氛围渐变
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
            }
            // 实例级 UITabBar 清透风格（固定全透明，无需调节）
            TabBarAppearanceConfigurator()
            if #unavailable(iOS 16.0) {
                NavigationLink(
                    destination: libraryDestination(legacyRoute ?? .playlist(Playlist(id: 0, name: "", coverURL: nil))),
                    isActive: Binding(
                        get: { legacyRoute != nil },
                        set: { if !$0 { legacyRoute = nil } }
                    )
                ) {
                    EmptyView()
                }
                .hidden()
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: isNativeClean ? 30 : 24) {
                if isNativeClean {
                        appleHeader
                    } else {
                        header
                    }
                    // 板块按用户自定义顺序渲染（可拖拽排序）
                    ForEach(libraryOrder, id: \.self) { key in
                        switch key {
                        case "本地音乐库":
                            LocalMusicSection()
                        case "我的歌单":
                            kugouSection
                        case "最近播放":
                            historySection
                        default:
                            EmptyView()
                        }
                    }
                }
                .padding(.horizontal, isNativeClean ? 24 : 16)
                .padding(.top, isNativeClean ? 20 : 8)
                .padding(.bottom, 190)
                .beansAdaptiveContentWidth()
            }
            .beansScrollIndicatorsHidden()
        }
        .task(id: source) {
            await refreshCurrentSource(force: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .beansKugouLoginDidUpdate)) { _ in
            Task { await loadKugouPlaylists(force: true) }
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
                .environmentObject(player)
                .environmentObject(auth)
                .environmentObject(theme)
        }
        .sheet(isPresented: $showSectionSort) {
            SectionOrderSheet(
                title: "音乐库板块排序",
                sections: SectionOrderStore.libraryDefaults,
                order: $libraryOrder,
                platformOrder: Binding(
                    get: { platformPrefs.orderedRaw },
                    set: { platformPrefs.orderedRaw = $0 }
                )
            )
                .onDisappear { SectionOrderStore.save(SectionOrderStore.libraryKey, libraryOrder) }
        }
        .sheet(isPresented: $showSyncedPlaylistSort) {
            SyncedPlaylistOrderSheet(
                title: "\(source.rawValue)歌单排序",
                source: source.songSource,
                playlists: syncedPlaylistBinding
            )
            .environmentObject(theme)
        }
        .alert("新建歌单", isPresented: $showCreatePlaylist) {
            TextField("歌单名称", text: $newPlaylistName)
            Button("创建") { createPlaylist() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("输入歌单名称，创建后同步到\(source.rawValue)")
        }
        .confirmationDialog("确定删除歌单「\(pendingDelete?.name ?? "")」吗？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) { confirmDeletePlaylist() }
            Button("取消", role: .cancel) {}
        }
        .beansNavigationDestination(for: LibraryRoute.self) { route in
            libraryDestination(route)
        }
    }
    }

    @ViewBuilder
    private func libraryDestination(_ route: LibraryRoute) -> some View {
        switch route {
        case .playlist(let playlist):
            PlaylistView(playlist: playlist)
                .environmentObject(player)
                .environmentObject(auth)
                .environmentObject(theme)
        }
    }

    private func openRoute(_ route: LibraryRoute) {
        if #available(iOS 16.0, *) {
            navigationPath.append(route)
        } else {
            legacyRoute = route
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                    libraryTitleButton
                    Text(librarySubtitle)
                        .font(BeansFont.appFont(13))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer()
                HStack(spacing: 10) {
                if !hideSortButton {
                    GlassIconButton(systemName: "arrow.up.arrow.down", forceLiquid: isNativeClean) {
                        BeansHaptics.tap()
                        showSectionSort = true
                    }
                    GlassIconButton(systemName: "list.number", forceLiquid: isNativeClean) {
                        BeansHaptics.tap()
                        showSyncedPlaylistSort = true
                    }
                }
                }
            }
        }
        .padding(.top, 8)
    }

    private var appleHeader: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center) {
                libraryTitleButton
                Spacer(minLength: 12)
                if !hideSortButton {
                    GlassIconButton(systemName: "arrow.up.arrow.down", forceLiquid: isNativeClean) {
                        BeansHaptics.tap()
                        showSectionSort = true
                    }
                    GlassIconButton(systemName: "list.number", forceLiquid: isNativeClean) {
                        BeansHaptics.tap()
                        showSyncedPlaylistSort = true
                    }
                }
            }
            Text(librarySubtitle)
                .font(BeansFont.appFont(12, .medium))
                .foregroundStyle(Color.beansComment)
                .lineLimit(1)
            Rectangle()
                .fill(Color.beansLabel.opacity(0.10))
                .frame(height: 1)
        }
        .padding(.top, 4)
    }

    private var librarySubtitle: String {
        "酷狗云端歌单"
    }

    private var libraryTitleButton: some View {
        Text("音乐库")
            .font(BeansFont.appFont(isNativeClean ? 34 : 30, .bold))
            .foregroundStyle(Color.beansLabel)
            .contentShape(Rectangle())
    }

    private var createPlaylistCard: some View {
        Button {
            BeansHaptics.tap()
            newPlaylistName = ""
            showCreatePlaylist = true
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundStyle(Color.beansComment.opacity(0.45))
                        .frame(width: 160, height: 160)
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Color.beansComment)
                }
                Text("新建歌单")
                    .font(BeansFont.appFont(12, .medium))
                    .foregroundStyle(Color.beansComment)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background {
                                BeansGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .buttonStyle(.plain)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "最近播放", trailing: "查看全部") {
                showHistory = true
            }
            if player.history.isEmpty {
                EmptyStateView(icon: "clock.arrow.circlepath", text: "暂无播放记录")
            } else {
                VStack(spacing: 0) {
                    ForEach(player.history.prefix(5), id: \.identityKey) { song in
                        SongCell(song: song, suppressNativeCleanRowGlass: isNativeClean) {
                            playFromHistory(song)
                        }
                        Divider().overlay(Color.beansComment.opacity(0.15))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                                        BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .beansCardShadow(radius: 8, y: 3)
            }
        }
    }

    private func refreshCurrentSource(force: Bool) async {
        await loadKugouPlaylists(force: force)
    }

    /// 酷狗模式整体内容：只保留同步歌单
    private var kugouSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            kugouPlaylistsSection
        }
    }

    private var kugouPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "我的酷狗歌单", trailing: kugouAuth.isLoggedIn ? "\(kugouPlaylists.count) 个" : nil)
            if !kugouAuth.isLoggedIn {
                EmptyStateView(icon: "music.note.list", text: "登录酷狗音乐后即可同步云端歌单")
            } else if kugouLoading {
                LoadingStateView()
            } else if kugouPlaylists.isEmpty {
                EmptyStateView(icon: "music.note.list", text: "暂未同步到酷狗歌单，请稍后重试")
            } else {
                VStack(spacing: 0) {
                    ForEach(orderedKugouPlaylists) { playlist in
                        Button {
                            openRoute(LibraryRoute.playlist(playlist))
                        } label: {
                            HStack(spacing: 12) {
                                CoverImage(url: playlist.coverURL, size: 56, cornerRadius: 12)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(playlist.name)
                                        .font(BeansFont.appFont(15, .medium))
                                        .foregroundStyle(Color.beansLabel)
                                        .lineLimit(1)
                                    Text(beansSongCountText(playlist.trackCount))
                                        .font(BeansFont.appFont(12))
                                        .foregroundStyle(Color.beansComment)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.beansComment.opacity(0.6))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.beansComment.opacity(0.12))
                    }
                }
                .padding(.vertical, 6)
                .background {
                    BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .beansCardShadow(radius: 8, y: 3)
            }
        }
    }

    // MARK: - 歌单新建 / 删除

    private func loadKugouPlaylists(force: Bool = false) async {
        guard kugouAuth.isLoggedIn else {
            kugouPlaylists = []
            kugouLoading = false
            return
        }
        let cache = SyncedPlaylistCache.shared
        if kugouPlaylists.isEmpty,
           let cached = cache.cachedPlaylists(source: .kugou, accountID: kugouCacheAccountID) {
            kugouPlaylists = cached.playlists
            kugouSavedAt = cached.savedAt
        }
        if !force, !kugouPlaylists.isEmpty, Date().timeIntervalSince(kugouSavedAt) < cache.playlistTTL { return }
        kugouLoading = kugouPlaylists.isEmpty
        do {
            let list = try await KugouMusicAPI.shared.userPlaylists()
            if !list.isEmpty {
                kugouPlaylists = list
                kugouSavedAt = Date()
                cache.savePlaylists(list, source: .kugou, accountID: kugouCacheAccountID)
            }
        } catch {
            BeansLogger.shared.log("酷狗歌单同步失败：\(error.localizedDescription)", level: .error)
            if kugouPlaylists.isEmpty { kugouPlaylists = [] }
        }
        kugouLoading = false
    }

    private func createPlaylist() {
        let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            ToastCenter.shared.show("请输入歌单名称")
            return
        }
        ToastCenter.shared.show("酷狗歌单暂不支持新建")
    }

    private func requestDelete(_ playlist: Playlist) {
        pendingDelete = playlist
        showDeleteConfirm = true
    }

    private func confirmDeletePlaylist() {
        guard let _ = pendingDelete else { return }
        ToastCenter.shared.show("酷狗歌单暂不支持删除")
    }

    private func playFromHistory(_ song: Song) {
        if let index = player.history.firstIndex(of: song) {
            player.play(songs: player.history, startAt: index)
        }
    }
}


