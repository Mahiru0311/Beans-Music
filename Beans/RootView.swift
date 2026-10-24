import SwiftUI
import UIKit
import AVKit

enum RootTab: String, CaseIterable, Identifiable {
    case discover
    case playlists
    case library
    case profile
    case search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discover: return "主页"
        case .playlists: return "精选"
        case .library: return "歌单"
        case .profile: return "我的"
        case .search: return "搜索"
        }
    }

    func icon(for style: CoTabIconStyle) -> String {
        if style == .appleMusic {
            switch self {
            case .discover: return "house.fill"
            case .playlists: return "dot.radiowaves.left.and.right"
            case .library: return "music.note.list"
            case .profile: return "person.crop.circle"
            case .search: return "magnifyingglass"
            }
        }
        if style == .rounded {
            switch self {
            case .discover: return "house.circle"
            case .playlists: return "rectangle.grid.2x2"
            case .library: return "music.note.list"
            case .profile: return "person.circle"
            case .search: return "magnifyingglass.circle"
            }
        }
        switch self {
        case .discover: return "house"
        case .playlists: return "square.grid.2x2"
        case .library: return "music.note.list"
        case .profile: return "person.crop.circle"
        case .search: return "magnifyingglass"
        }
    }

    func assetName(for style: CoTabIconStyle) -> String? {
        guard style == .appleMusic else { return nil }
        switch self {
        case .discover: return "BottomHome"
        case .playlists: return "BottomBroadcast"
        case .library: return "BottomLibrary"
        case .profile, .search: return nil
        }
    }

    static let bottomTabs: [RootTab] = [.discover, .playlists, .library, .profile, .search]
}

enum CoHeaderAccessoryMode: String, CaseIterable, Identifiable {
    case avatar
    case themeToggle
    case hidden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .avatar: return "头像"
        case .themeToggle: return "浅深色切换"
        case .hidden: return "隐藏"
        }
    }
}

struct CoThemeToggleRequest {
    let location: CGPoint
}

extension Notification.Name {
    static let coThemeToggleRequested = Notification.Name("co.themeToggleRequested")
}

private struct SidebarPlaylistGroup: Identifiable {
    let id: String
    let title: String
    let playlists: [Playlist]
}

/// Keeps the legacy tab hierarchy tied to one stable state value instead of
/// rebuilding it from several AppStorage bindings during a presentation.
struct CoTabVisibility: Equatable {
    static let didChangeNotification = Notification.Name("co.tabVisibilityDidChange")

    var discover = true
    var playlists = true
    var library = true
    var profile = true
    var search = true

    static func load(defaults: UserDefaults = .standard) -> Self {
        Self(
            discover: value(for: "co.tab.discover.visible", defaults: defaults),
            playlists: value(for: "co.tab.playlists.visible", defaults: defaults),
            library: value(for: "co.tab.library.visible", defaults: defaults),
            profile: value(for: "co.tab.profile.visible", defaults: defaults),
            search: value(for: "co.tab.search.visible", defaults: defaults)
        )
    }

    mutating func setVisible(_ isVisible: Bool, for tab: RootTab) {
        switch tab {
        case .discover: discover = isVisible
        case .playlists: playlists = isVisible
        case .library: library = isVisible
        case .profile: profile = isVisible
        case .search: search = isVisible
        }
    }

    func isVisible(_ tab: RootTab) -> Bool {
        switch tab {
        case .discover: discover
        case .playlists: playlists
        case .library: library
        case .profile: profile
        case .search: search
        }
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(discover, forKey: "co.tab.discover.visible")
        defaults.set(playlists, forKey: "co.tab.playlists.visible")
        defaults.set(library, forKey: "co.tab.library.visible")
        defaults.set(profile, forKey: "co.tab.profile.visible")
        defaults.set(search, forKey: "co.tab.search.visible")
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    private static func value(for key: String, defaults: UserDefaults, defaultValue: Bool = true) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }
}

struct RootView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var favorites: FavoritesStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var platformPrefs = PlatformPreferenceStore.shared
    @ObservedObject private var localLibrary = LocalLibraryStore.shared
    @ObservedObject private var kugouAuth = KugouMusicAuth.shared
    @AppStorage("co.themeMode") private var themeModeRaw = CoThemeMode.system.rawValue

    @State private var selection: RootTab = .discover
    @State private var unoccludedWindowSize: CGSize = {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?.windows.first(where: \.isKeyWindow)?.bounds.size ?? .zero
    }()
    @State private var showPlayer = false
    @Namespace private var nowPlayingTransition
    @AppStorage("co.disclaimerAccepted") private var disclaimerAccepted = false
    /// 底栏是否显示文字（关闭后只显示图标）
    @AppStorage("co.tabLabelsVisible") private var tabLabelsVisible = true
    @AppStorage("co.tabIconStyle") private var tabIconStyleRaw = CoTabIconStyle.sfSymbols.rawValue
    @State private var tabVisibility = CoTabVisibility.load()
    @AppStorage("co.queueOverlayPresented") private var queueOverlayPresented = false
    @AppStorage("co.uiStyle") private var uiStyleRaw = CoUIStyle.liquid.rawValue
    @AppStorage("co.disableLiquidGlass") private var disableLiquidGlass = false
    @AppStorage("co.homeWallpaperBlur") private var homeWallpaperBlur = 0.0
    @State private var showWhatsNew = false
    @State private var sidebarRemotePlaylists: [Playlist] = []
    @State private var sidebarLocalPlaylist: LocalPlaylist?
    @State private var themeRevealSnapshot: UIImage?
    @State private var themeRevealOrigin = CGPoint.zero
    @State private var themeRevealProgress: CGFloat = 0
    @State private var themeRevealCanvasSize = CGSize.zero
    /// Prevent launch-time geometry/state restoration from animating the root
    /// surface. Page and tab animations are enabled after the first frame.
    @State private var rootLayoutSettled = false

    private var isUITestSmoke: Bool {
        ProcessInfo.processInfo.arguments.contains("--co-ui-smoke")
    }

    private var tabIconStyle: CoTabIconStyle {
        CoTabIconStyle(rawValue: tabIconStyleRaw) ?? .sfSymbols
    }

    private var visibleTabs: [RootTab] {
        if usesStableTabHierarchy {
            return RootTab.bottomTabs
        }
        return RootTab.bottomTabs.filter { tabVisibility.isVisible($0) }
    }

    private func isTabVisible(_ tab: RootTab) -> Bool {
        if usesStableTabHierarchy {
            return true
        }
        return tabVisibility.isVisible(tab)
    }

    /// Older tab hosts are not safe to mutate while another full-screen
    /// interface is being presented. Keep their identity fixed; tab visibility
    /// remains configurable on the newer host.
    private var usesStableTabHierarchy: Bool {
        false
    }

    private func normalizeTabSelection() {
        guard !visibleTabs.isEmpty else {
            tabVisibility = CoTabVisibility()
            tabVisibility.save()
            selection = .discover
            return
        }
        if !isTabVisible(selection) {
            selection = visibleTabs[0]
        }
    }
    @State private var sidebarPlaylist: Playlist?
    @State private var showSidebarQueue = false
    @State private var sidebarPlaylistsExpanded = true
    private var themeMode: CoThemeMode {
        CoThemeMode(rawValue: themeModeRaw) ?? .system
    }


    private var usesPadSidebar: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        let _ = theme.accent
        GeometryReader { proxy in
            let isPadLandscape = CoWindowLayoutPolicy.usesSidebar(
                isPad: usesPadSidebar, window: unoccludedWindowSize, proposed: proxy.size
            )

            ZStack {
                if isPadLandscape {
                    iPadSidebarRoot
                } else {
                    nativeTabs(isPadLandscape: false)
                        .modifier(
                            MiniPlayerAccessoryModifier(
                                isActive: player.currentSong != nil && !queueOverlayPresented,
                                showPlayer: $showPlayer,
                                clock: player.clock,
                                colorScheme: colorScheme,
                                transitionNamespace: nowPlayingTransition
                            )
                        )
                }

                if let themeRevealSnapshot {
                    CoThemeRevealOverlay(
                        snapshot: themeRevealSnapshot,
                        origin: themeRevealOrigin,
                        progress: themeRevealProgress
                    )
                }
            }
            .animation(
                rootLayoutSettled
                    ? .spring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.08)
                    : nil,
                value: isPadLandscape
            )
        }
        .background {
            TabBarAppearanceConfigurator()
        }
        .preferredColorScheme(themeMode.colorScheme)
        // 播放页打开/关闭走系统默认底部滑入，不再用 zoom 变形与根视图动画叠加。
        .fullScreenCover(isPresented: $showPlayer) {
            playerPresentation
        }
        .animation(
            rootLayoutSettled ? .easeInOut(duration: 0.22) : nil,
            value: selection
        )
        .overlay(alignment: .bottom) {
            ToastView(center: ToastCenter.shared)
        }
        .onAppear {
            if disclaimerAccepted, ChangelogStore.shouldShowWhatsNew {
                showWhatsNew = true
            }
            normalizeTabSelection()
            guard !rootLayoutSettled else { return }
            DispatchQueue.main.async {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    rootLayoutSettled = true
                }
            }
        }
        .onChange(of: disclaimerAccepted) { accepted in
            if accepted, ChangelogStore.shouldShowWhatsNew {
                showWhatsNew = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: CoTabVisibility.didChangeNotification)) { _ in
            tabVisibility = CoTabVisibility.load()
            normalizeTabSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .coThemeToggleRequested)) { notification in
            let request = notification.object as? CoThemeToggleRequest
            beginThemeReveal(from: request?.location)
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewSheet()
        }
        .sheet(item: $sidebarLocalPlaylist) { playlist in
            LocalPlaylistDetailSheet(playlistID: playlist.id)
                .environmentObject(player)
                .environmentObject(auth)
                .environmentObject(theme)
        }
        .sheet(item: $sidebarPlaylist) { playlist in
            PlaylistView(playlist: playlist)
                .environmentObject(player)
                .environmentObject(auth)
                .environmentObject(theme)
        }
        .sheet(isPresented: $showSidebarQueue) {
            QueueView()
                .environmentObject(player)
                .environmentObject(theme)
        }
        .task(id: disclaimerAccepted) {
            guard disclaimerAccepted, !isUITestSmoke else { return }
            await RemoteControlStore.shared.refreshIfNeeded(force: true)
        }
    }


    @ViewBuilder
    private var playerPresentation: some View {
        // 下拉收起不能再走系统：19:16 那轮删掉 zoom 过渡后，全屏页走系统默认
        // 底部滑入，而全屏页本身没有下滑收起手势，播放页就关不掉了。
        // 旧版能下拉收起，靠的就是 zoom 过渡带来的系统交互收起；不恢复 zoom
        // （用户已判它僵硬），改用本地下拉手势收起：从顶部区域下拉超过阈值
        // 即关闭，打开仍是系统底部滑入。
        CoNowPlayingPresentation(
            isPresented: $showPlayer,
            usesSystemInteractiveDismissal: false
        ) {
            PlayerView(isPresented: $showPlayer)
                .environmentObject(favorites)
                .environmentObject(player)
                .environmentObject(player.clock)
                .environmentObject(auth)
        }
    }

    /// iOS 26 的系统 Tab 容器：仅 iPad 横屏使用系统侧边栏。
    @ViewBuilder
    private func nativeTabs(isPadLandscape: Bool) -> some View {
        if isPadLandscape {
            nativeTabContent(isPadLandscape: true)
                .tabViewStyle(.sidebarAdaptable)
        } else {
            nativeTabContent(isPadLandscape: false)
        }
    }

    @ViewBuilder
    private func nativeTabContent(isPadLandscape: Bool) -> some View {
        dynamicNativeTabContent(isPadLandscape: isPadLandscape)
    }


    private func dynamicNativeTabContent(isPadLandscape: Bool) -> some View {
        TabView(selection: $selection) {
            if tabVisibility.discover {
                Tab(value: .discover) {
                    DiscoverView()
                } label: {
                    nativeTabLabel(.discover)
                }
            }

            if tabVisibility.playlists {
                Tab(value: .playlists) {
                    PlaylistSquareView()
                } label: {
                    nativeTabLabel(.playlists)
                }
            }

            if tabVisibility.library {
                Tab(value: .library) {
                    LibraryView()
                } label: {
                    nativeTabLabel(.library)
                }
            }

            if tabVisibility.profile {
                Tab(value: .profile) {
                    ProfileView()
                } label: {
                    nativeTabLabel(.profile)
                }
            }

            if tabVisibility.search {
                Tab(value: .search, role: .search) {
                    SearchView()
                } label: {
                    nativeTabLabel(.search)
                }
            }

        }
        .tint(Color.coAmber)
        .tabBarMinimizeBehavior(isPadLandscape || player.currentSong == nil ? .never : .onScrollDown)
        .toolbarBackground(.hidden, for: .tabBar)
        .background(Color.clear)
    }

    private func nativeTabTitle(_ tab: RootTab) -> LocalizedStringKey {
        return tabLabelsVisible ? LocalizedStringKey(tab.title) : LocalizedStringKey("")
    }

    @ViewBuilder
    private func nativeTabLabel(_ tab: RootTab) -> some View {
        Label {
            Text(nativeTabTitle(tab))
        } icon: {
            if let assetName = tab.assetName(for: tabIconStyle) {
                Image(assetName)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 25, height: 25)
            } else {
                Image(systemName: tab.icon(for: tabIconStyle))
                    .font(.system(size: 25, weight: .semibold))
            }
        }
    }

    /// iPad 横屏侧栏：页面复用原有 Tab 内容，歌单与播放列表固定在左侧。
    private var iPadSidebarRoot: some View {
        GeometryReader { proxy in
            ZStack {
                // iPad 横屏只绘制一次完整主页背景，侧栏和迷你播放器都在这张背景之上合成。
                GlassBackdrop(
                    customColor: theme.customBackground,
                    homeMode: true,
                    wallpaperBlur: CGFloat(homeWallpaperBlur)
                )

                HStack(spacing: 0) {
                    iPadSidebar(
                        safeAreaInsets: proxy.safeAreaInsets,
                        reservesMiniPlayerSpace: player.currentSong != nil
                    )
                        .frame(width: min(max(proxy.size.width * 0.17, 176), 228))
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .padding(.leading, 10)
                        .padding(.vertical, 10)
                        .padding(.trailing, 8)

                    // 迷你播放器悬浮在页面之上，而不是占用主页的底部布局空间。
                    // 这样滚动到下方的首页内容会作为玻璃胶囊的真实底图参与合成。
                    ZStack(alignment: .bottom) {
                        activeTabPage(usesSharedRootBackdrop: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if player.currentSong != nil && !queueOverlayPresented {
                            MiniPlayerView(
                                showPlayer: $showPlayer,
                                presentation: .dock,
                                transitionNamespace: nowPlayingTransition
                            )
                                .environmentObject(player.clock)
                                .padding(.horizontal, 16)
                                .padding(.bottom, max(10, proxy.safeAreaInsets.bottom + 4))
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .animation(
            rootLayoutSettled ? .easeInOut(duration: 0.25) : nil,
            value: selection
        )
    }

    private func iPadSidebar(
        safeAreaInsets: EdgeInsets,
        reservesMiniPlayerSpace: Bool
    ) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text("音乐")
                    .font(CoFont.appFont(30, .bold))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)

                ForEach(visibleTabs) { tab in
                    iPadSidebarItem(tab)
                }

                Divider()
                    .overlay(Color.primary.opacity(0.12))
                    .padding(.vertical, 8)

                sidebarSectionHeader("歌单", isExpanded: $sidebarPlaylistsExpanded)

                if sidebarPlaylistsExpanded {
                    Button {
                        selectSidebarTab(.library)
                    } label: {
                        sidebarSystemRow(title: "所有歌单", systemName: "square.grid.2x2")
                    }
                    .buttonStyle(.plain)

                    if !localLibrary.playlists.isEmpty {
                        sidebarSubheading("本地歌单")
                        ForEach(Array(localLibrary.playlists.prefix(5))) { playlist in
                            sidebarLocalPlaylistRow(playlist)
                        }
                    }

                    ForEach(sidebarRemotePlaylistGroups) { group in
                        sidebarSubheading(group.title)
                        ForEach(Array(group.playlists.prefix(5))) { playlist in
                            sidebarRemotePlaylistRow(playlist)
                        }
                    }

                    if localLibrary.playlists.isEmpty && sidebarRemotePlaylistGroups.isEmpty {
                        Text("暂无已同步歌单")
                            .font(CoFont.appFont(12))
                            .foregroundStyle(Color.primary.opacity(0.48))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                }

                Divider()
                    .overlay(Color.primary.opacity(0.12))
                    .padding(.vertical, 8)

                sidebarSectionHeader("播放列表", isExpanded: .constant(true), showsToggle: false)
                Button {
                    CoHaptics.tap()
                    showSidebarQueue = true
                } label: {
                    sidebarSystemRow(title: "所有播放列表", systemName: "list.number")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, max(24, safeAreaInsets.top + 10))
            .padding(
                .bottom,
                max(24, safeAreaInsets.bottom + (reservesMiniPlayerSpace ? 72 : 10))
            )
        }
        .task(id: "\(auth.user?.uid ?? 0)-\(kugouAuth.userId)") {
            await loadSidebarPlaylists()
        }
        .background {
            if disableLiquidGlass {
                Rectangle().fill(.regularMaterial)
            } else {
                GlassEffectContainer {
                    Rectangle()
                        .fill(.clear)
                        .glassEffect(.regular, in: .rect)
                }
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 0.5)
        }
    }

    private var sidebarRemotePlaylistGroups: [SidebarPlaylistGroup] {
        var groups: [SidebarPlaylistGroup] = []
        let kugou = sidebarRemotePlaylists.filter { $0.source == .kugou }
        if !kugou.isEmpty {
            groups.append(SidebarPlaylistGroup(id: "kugou", title: "酷狗音乐", playlists: kugou))
        }
        return groups
    }

    private func sidebarSectionHeader(
        _ title: String,
        isExpanded: Binding<Bool>,
        showsToggle: Bool = true
    ) -> some View {
        Button {
            guard showsToggle else { return }
            CoHaptics.select()
            withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(CoFont.appFont(19, .bold))
                    .foregroundStyle(Color.primary)
                Spacer(minLength: 0)
                if showsToggle {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.coAmber)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .disabled(!showsToggle)
    }

    private func sidebarSubheading(_ title: String) -> some View {
        Text(title)
            .font(CoFont.appFont(11, .semibold))
            .foregroundStyle(Color.primary.opacity(0.48))
            .padding(.leading, 14)
            .padding(.top, 7)
            .padding(.bottom, 1)
    }

    private func sidebarSystemRow(title: String, systemName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.coAmber)
                .frame(width: 26, height: 26)
            Text(title)
                .font(CoFont.appFont(14, .medium))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 42)
        .contentShape(Rectangle())
    }

    private func sidebarLocalPlaylistRow(_ playlist: LocalPlaylist) -> some View {
        Button {
            CoHaptics.tap()
            selectSidebarTab(.library)
            sidebarLocalPlaylist = playlist
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.coAmber)
                    .frame(width: 26, height: 26)
                    .background(Color.coAmber.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(CoFont.appFont(13, .medium))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text(coSongCountText(playlist.songs.count))
                        .font(CoFont.appFont(10))
                        .foregroundStyle(Color.primary.opacity(0.48))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sidebarRemotePlaylistRow(_ playlist: Playlist) -> some View {
        Button {
            CoHaptics.tap()
            selectSidebarTab(.library)
            sidebarPlaylist = playlist
        } label: {
            HStack(spacing: 12) {
                CoverImage(url: playlist.coverURL, size: 30, cornerRadius: 7)
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(CoFont.appFont(13, .medium))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text(coSongCountText(playlist.trackCount))
                        .font(CoFont.appFont(10))
                        .foregroundStyle(Color.primary.opacity(0.48))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func selectSidebarTab(_ tab: RootTab) {
        guard selection != tab else { return }
        withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
            selection = tab
        }
    }

    @MainActor
    private func loadSidebarPlaylists() async {
        var loaded: [Playlist] = []

        if platformPrefs.isEnabled(SearchProvider.kugou), kugouAuth.isLoggedIn {
            let accountID = kugouAuth.userId
            if let cached = SyncedPlaylistCache.shared.cachedPlaylists(source: .kugou, accountID: accountID) {
                loaded.append(contentsOf: cached.playlists)
                if CoNetworkStatus.shared.isReachable,
                   let list = try? await KugouMusicAPI.shared.userPlaylists(), !list.isEmpty {
                    loaded = loaded.filter { $0.source != .kugou }
                    loaded.append(contentsOf: list)
                    SyncedPlaylistCache.shared.savePlaylists(list, source: .kugou, accountID: accountID)
                }
            } else if let list = try? await KugouMusicAPI.shared.userPlaylists(), !list.isEmpty {
                loaded.append(contentsOf: list)
                SyncedPlaylistCache.shared.savePlaylists(list, source: .kugou, accountID: accountID)
            }
        }

        var seen = Set<String>()
        sidebarRemotePlaylists = loaded.filter { seen.insert("\($0.source.rawValue)-\($0.id)").inserted }
    }

    private func iPadSidebarItem(_ tab: RootTab) -> some View {
        let isSelected = selection == tab
        return Button {
            guard selection != tab else { return }
            CoHaptics.select()
            withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                selection = tab
            }
        } label: {
            HStack(spacing: 14) {
                if let assetName = tab.assetName(for: tabIconStyle) {
                    Image(assetName)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                } else {
                    Image(systemName: tab.icon(for: tabIconStyle))
                        .font(.system(size: 25, weight: .semibold))
                        .frame(width: 25, height: 25)
                }

                if tabLabelsVisible {
                    Text(LocalizedStringKey(tab.title))
                        .font(CoFont.appFont(15, .semibold))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Color.coAmber : Color.primary.opacity(0.72))
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .padding(.horizontal, 14)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.coAmber.opacity(0.14) : .clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(LocalizedStringKey(tab.title))
    }

    private var resolvedThemeToggleTarget: CoThemeMode {
        if themeMode == .dark { return .light }
        if themeMode == .light { return .dark }
        return colorScheme == .dark ? .light : .dark
    }

    private func beginThemeReveal(from location: CGPoint?) {
        let target = resolvedThemeToggleTarget
        guard themeRevealSnapshot == nil else { return }

        if reduceMotion {
            themeModeRaw = target.rawValue
            return
        }

        guard let captured = currentWindowSnapshot() else {
            themeModeRaw = target.rawValue
            return
        }

        themeRevealSnapshot = captured.image
        themeRevealCanvasSize = captured.size
        let canvas = captured.size
        let requestedOrigin = location ?? CGPoint(x: canvas.width * 0.5, y: canvas.height * 0.5)
        themeRevealOrigin = CGPoint(
            x: min(max(requestedOrigin.x, 0), canvas.width),
            y: min(max(requestedOrigin.y, 0), canvas.height)
        )
        themeRevealProgress = 0

        // Switch the real view immediately. The captured old frame masks it
        // outside the expanding circle, so the circle reveals live content,
        // rather than showing a blank white/dark placeholder.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            themeModeRaw = target.rawValue
        }
        DispatchQueue.main.async {
            // Keep this deliberately longer than a standard button transition.
            // The mask is transform-driven below, so it can stay smooth without
            // repeatedly relaying out the full root view.
            withAnimation(.timingCurve(0.16, 0.82, 0.22, 1.0, duration: 1.12)) {
                themeRevealProgress = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.22) {
            themeRevealSnapshot = nil
            themeRevealProgress = 0
            themeRevealCanvasSize = .zero
        }
    }

    private func currentWindowSnapshot() -> (image: UIImage, size: CGSize)? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter { $0.windowLevel == .normal && !$0.isHidden }
        guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else { return nil }

        let format = UIGraphicsImageRendererFormat()
        // A full 3x screenshot is expensive on iPad. The reveal is a short-lived
        // mask, so cap the backing scale to keep the first frame responsive.
        format.scale = min(window.screen.scale, 1.5)
        format.opaque = false
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        return (image, window.bounds.size)
    }


    @ViewBuilder
    private func activeTabPage(usesSharedRootBackdrop: Bool = false) -> some View {
        Group {
            switch selection {
            case .discover:
                DiscoverView()
            case .playlists:
                PlaylistSquareView()
            case .search:
                SearchView()
            case .library:
                LibraryView()
            case .profile:
                ProfileView()
            }
        }
        .environment(\.coUsesSharedRootBackdrop, usesSharedRootBackdrop)
    }
}

private struct CoThemeRevealOverlay: View {
    let snapshot: UIImage
    let origin: CGPoint
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let farthestX = max(origin.x, proxy.size.width - origin.x)
            let farthestY = max(origin.y, proxy.size.height - origin.y)
            let radius = hypot(farthestX, farthestY) + 4
            let fullDiameter = max(1, radius * 2)

            Image(uiImage: snapshot)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .mask {
                    CoThemeRevealMask(
                        origin: origin,
                        diameter: fullDiameter,
                        progress: progress
                    )
                }
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// A lightweight inverse circle mask. The animated element only scales, which
/// avoids recalculating a growing view hierarchy for every reveal frame.
private struct CoThemeRevealMask: View {
    let origin: CGPoint
    let diameter: CGFloat
    let progress: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.white)
            .overlay {
                Circle()
                    .fill(Color.black)
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(max(progress, 0.001))
                    .position(origin)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }
}

private enum CoNowPlayingPresentationMetrics {
    static let indicatorTopSpacing: CGFloat = 6
    static let indicatorWidth: CGFloat = 52
    static let indicatorHeight: CGFloat = 5
    static let indicatorHitWidth: CGFloat = 180
    static let indicatorHitHeight: CGFloat = 82
    static let dismissDistance: CGFloat = 110
    static let dismissPrediction: CGFloat = 190
    /// 旧系统的整屏手势仍然覆盖播放器，但只有从顶部区域开始的纵向拖动才关闭，
    /// 避免歌词滚动被误判为返回。
    static let verticalStartZone: CGFloat = 220
    static let dismissAnimation = Animation.spring(
        response: 0.52,
        dampingFraction: 0.90,
        blendDuration: 0.10
    )
}

struct CoNowPlayingPresentation<Content: View>: View {
    @Binding var isPresented: Bool
    let usesSystemInteractiveDismissal: Bool
    let content: Content
    @ObservedObject private var appleLayout = AppleMusicLayoutStore.shared
    @State private var dragOffset: CGFloat = 0

    init(
        isPresented: Binding<Bool>,
        usesSystemInteractiveDismissal: Bool,
        @ViewBuilder content: () -> Content
    ) {
        _isPresented = isPresented
        self.usesSystemInteractiveDismissal = usesSystemInteractiveDismissal
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let isPhone = proxy.size.width < 720
            let playerSurface = ZStack(alignment: .top) {
                content

                if isPhone {
                    dragIndicator(safeAreaTop: proxy.safeAreaInsets.top)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .offset(y: usesSystemInteractiveDismissal ? 0 : dragOffset)
            .contentShape(Rectangle())

            // iOS 26 uses the system's interactive transition; older systems
            // keep the compatible local drag gesture.
            if usesSystemInteractiveDismissal {
                playerSurface
            } else {
                playerSurface
                    .simultaneousGesture(dismissGesture)
            }
        }
        .onAppear { dragOffset = 0 }
        .background {
            if !usesSystemInteractiveDismissal {
                CoPresentedSurfaceClearer()
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func dragIndicator(safeAreaTop: CGFloat) -> some View {
        let surface = ZStack(alignment: .top) {
            Color.clear
            Capsule()
                // Keep the indicator's hit area and gesture, but hide the visual
                // handle so the player uses a clean full-screen surface.
                .fill(.clear)
                .frame(
                    width: CoNowPlayingPresentationMetrics.indicatorWidth,
                    height: CoNowPlayingPresentationMetrics.indicatorHeight
                )
                .padding(.top, CoNowPlayingPresentationMetrics.indicatorTopSpacing)
        }
        .frame(
            width: CoNowPlayingPresentationMetrics.indicatorHitWidth,
            height: CoNowPlayingPresentationMetrics.indicatorHitHeight
        )
        .modifier(AppleMusicLayoutTransform(entry: appleLayout.entry(for: .top)))
        .contentShape(Rectangle())
        .accessibilityLabel("下拉关闭播放页")

        surface
            .padding(.top, safeAreaTop)
            // The parent presentation owns the drag gesture. Keeping this
            // clear decoration out of hit testing prevents it from masking
            // controls that overlap its layout position.
            .allowsHitTesting(false)
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                let vertical = value.translation.height
                let horizontal = value.translation.width
                let isDownwardSwipe = vertical > 0 && vertical > abs(horizontal) * 1.25
                // 旧系统只响应顶部开始的明确下拉。播放器内禁用左侧右滑返回，
                // 避免进度条及其他横向控件触发播放器关闭。
                if value.startLocation.y <= CoNowPlayingPresentationMetrics.verticalStartZone,
                   isDownwardSwipe {
                    dragOffset = max(vertical, 0)
                } else {
                    dragOffset = 0
                }
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                let isTopSwipe = value.startLocation.y <= CoNowPlayingPresentationMetrics.verticalStartZone
                    && vertical > 0
                    && vertical > abs(horizontal) * 1.25
                let translation = isTopSwipe ? max(vertical, 0) : 0
                let predictedVertical = value.predictedEndTranslation.height
                let prediction = isTopSwipe ? max(predictedVertical, 0) : 0
                if translation > CoNowPlayingPresentationMetrics.dismissDistance
                    || prediction > CoNowPlayingPresentationMetrics.dismissPrediction {
                    CoHaptics.medium()
                    withAnimation(CoNowPlayingPresentationMetrics.dismissAnimation) {
                        isPresented = false
                    }
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

/// On pre-iOS-26 full-screen covers, SwiftUI leaves an opaque white host view
/// behind a manually dragged player. Clear that host so the root page remains
/// visible through the exposed area during the interactive dismissal.
private struct CoPresentedSurfaceClearer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            var current: UIViewController? = uiViewController
            while let controller = current {
                controller.view.backgroundColor = .clear
                controller.parent?.view.backgroundColor = .clear
                controller.presentationController?.containerView?.backgroundColor = .clear
                controller.presentationController?.presentedView?.backgroundColor = .clear
                current = controller.parent
            }
        }
    }
}


private struct MiniPlayerAccessoryModifier: ViewModifier {
    let isActive: Bool
    @Binding var showPlayer: Bool
    let clock: PlaybackClock
    let colorScheme: ColorScheme
    let transitionNamespace: Namespace.ID

    @ViewBuilder
    func body(content: Content) -> some View {
        // Keep the TabView at one structural identity while a detail cover is
        // presented. Branching around `content` tears down the cover's owner;
        // its onDisappear then re-enables the accessory and repeats the cycle.
        content.tabViewBottomAccessory(isEnabled: isActive) {
            accessory
        }
    }

    private var accessory: some View {
        RootMiniPlayerAccessory(
            showPlayer: $showPlayer,
            clock: clock,
            transitionNamespace: transitionNamespace
        )
        .environment(\.colorScheme, colorScheme)
    }

}

/// 根据系统 accessory 位置在展开和紧凑布局之间切换。
private struct RootMiniPlayerAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Binding var showPlayer: Bool
    let clock: PlaybackClock
    let transitionNamespace: Namespace.ID

    var body: some View {
        MiniPlayerView(
            showPlayer: $showPlayer,
            presentation: presentation,
            transitionNamespace: transitionNamespace
        )
        .environmentObject(clock)
    }

    private var presentation: MiniPlayerView.Presentation {
        placement.map { $0 == .inline } == true ? .inlineAccessory : .accessory
    }
}


// MARK: - 系统 TabBar 清透风格（实例级配置）
// 系统 TabView 创建之后，`UITabBar.appearance()` 全局代理对已存在的实例不再生效，
// 所以每个 tab 页面内放一个 TabBarAppearanceConfigurator，通过 tabBarController
// 拿到当前 UITabBar 实例，直接设置固定清透外观（全透明、无阴影）。

struct TabBarAppearanceConfigurator: UIViewControllerRepresentable {
    var onHomeLongPress: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onHomeLongPress: onHomeLongPress)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        // 纯外观配置视图：禁止拦截触摸，避免透明全屏视图吃掉页面按钮点击
        controller.view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            Self.apply(
                from: controller,
                coordinator: context.coordinator
            )
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.onHomeLongPress = onHomeLongPress
        DispatchQueue.main.async {
            Self.apply(
                from: uiViewController,
                coordinator: context.coordinator
            )
        }
    }

    /// 固定清透风格：全透明背景、无阴影；选中态用主题色，
    /// 材质与模糊完全交给系统对底层页面内容的渲染，不再支持手动调节透明度
    private static func apply(
        from controller: UIViewController,
        coordinator: Coordinator
    ) {
        guard let tabBar = controller.tabBarController?.tabBar else { return }
        installHomeLongPress(on: tabBar, coordinator: coordinator)
        tabBar.isHidden = false
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        // 超薄材质模糊：与迷你播放器一致的清透玻璃透明度
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = UIColor.coAmber
        tabBar.isTranslucent = true
    }

    private static func installHomeLongPress(on tabBar: UITabBar, coordinator: Coordinator) {
        let controls = tabBar.subviews
            .flatMap { descendants(of: $0) }
            .compactMap { $0 as? UIControl }
            .filter { !$0.isHidden && $0.alpha > 0 && $0.bounds.width > 0 }
            .sorted { $0.frame.minX < $1.frame.minX }
        guard let homeButton = controls.first else { return }
        guard homeButton.gestureRecognizers?.contains(where: { $0.name == Coordinator.gestureName }) != true else { return }

        let gesture = UILongPressGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleHomeLongPress(_:)))
        gesture.name = Coordinator.gestureName
        gesture.minimumPressDuration = 0.45
        gesture.cancelsTouchesInView = true
        homeButton.addGestureRecognizer(gesture)
    }

    private static func descendants(of view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap { descendants(of: $0) }
    }

    final class Coordinator: NSObject {
        static let gestureName = "co.homePlatformLongPress"
        var onHomeLongPress: (() -> Void)?

        init(onHomeLongPress: (() -> Void)?) {
            self.onHomeLongPress = onHomeLongPress
        }

        @objc func handleHomeLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            CoHaptics.select()
            onHomeLongPress?()
        }
    }
}

