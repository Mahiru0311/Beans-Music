import SwiftUI
import UIKit

private enum DiscoverRoute: Hashable {
    case playlist(Playlist)
    case album(Album)
    case artist(Artist)
    case kugouTopList(KugouTopInfo)
    case dailySongs([Song])
}

struct DiscoverView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.beansUsesSharedRootBackdrop) private var usesSharedRootBackdrop
    @ObservedObject private var platformPrefs = PlatformPreferenceStore.shared

    @State private var topLists: [TopList] = []
    @State private var dailySongs: [Song] = []
    @State private var newAlbums: [Album] = []
    @State private var topArtists: [Artist] = []
    @State private var personalized: [Playlist] = []

    @State private var loading = true
    @State private var errorMessage: String?
    @State private var navigationPath: [DiscoverRoute] = []
    @State private var legacyRoute: DiscoverRoute?
    @State private var recommendationActionLoading: String?
    @State private var showProfile = false
    @State private var showSectionSort = false
    /// 主页板块顺序（每日推荐 / 排行榜，可自定义）
    @State private var homeOrder = SectionOrderStore.load(SectionOrderStore.homeKey, defaults: SectionOrderStore.homeDefaults)

    /// 主页只保留每日推荐和排行榜；歌单广场位于独立底栏页面。
    private var availableSections: [String] { SectionOrderStore.homeDefaults }
    /// 首页数据源：记住上次选择，下次打开仍保持该平台（默认哔哩哔哩）
    @AppStorage("beans.homeSource") private var homeSourceRaw = SearchProvider.kugou.rawValue
    /// 每日推荐的旧版横向歌曲卡样式，默认使用新版推荐卡片。
    @AppStorage("beans.home.dailySongsListStyle") private var dailySongsListStyle = false
    @AppStorage("beans.homeGreetingText") private var homeGreetingText = ""
    @AppStorage("beans.homeGreetingSize") private var homeGreetingSize = 30.0
    @AppStorage("beans.homeGreetingHeight") private var homeGreetingHeight = 0.0
    @AppStorage("beans.homeGreetingColorHex") private var homeGreetingColorHex = ""
    @AppStorage("beans.homeGreetingLine1Size") private var homeGreetingLine1Size = 0.0
    @AppStorage("beans.homeGreetingLine2Size") private var homeGreetingLine2Size = 0.0
    @AppStorage("beans.homeGreetingLine3Size") private var homeGreetingLine3Size = 0.0
    @AppStorage("beans.homeGreetingLine1ColorHex") private var homeGreetingLine1ColorHex = ""
    @AppStorage("beans.homeGreetingLine2ColorHex") private var homeGreetingLine2ColorHex = ""
    @AppStorage("beans.homeGreetingLine3ColorHex") private var homeGreetingLine3ColorHex = ""
    @AppStorage("beans.homeGreetingLine1OffsetY") private var homeGreetingLine1OffsetY = 0.0
    @AppStorage("beans.homeGreetingLine2OffsetY") private var homeGreetingLine2OffsetY = 0.0
    @AppStorage("beans.homeGreetingLine3OffsetY") private var homeGreetingLine3OffsetY = 0.0
    @AppStorage("beans.homeGreetingLine1GradientStartHex") private var homeGreetingLine1GradientStartHex = ""
    @AppStorage("beans.homeGreetingLine2GradientStartHex") private var homeGreetingLine2GradientStartHex = ""
    @AppStorage("beans.homeGreetingLine3GradientStartHex") private var homeGreetingLine3GradientStartHex = ""
    @AppStorage("beans.homeGreetingLine1GradientEndHex") private var homeGreetingLine1GradientEndHex = ""
    @AppStorage("beans.homeGreetingLine2GradientEndHex") private var homeGreetingLine2GradientEndHex = ""
    @AppStorage("beans.homeGreetingLine3GradientEndHex") private var homeGreetingLine3GradientEndHex = ""
    @AppStorage("beans.homeGreetingGlowEnabled") private var homeGreetingGlowEnabled = false
    @AppStorage("beans.homeGreetingGlowIntensity") private var homeGreetingGlowIntensity = 0.45
    @AppStorage("beans.homeGreetingUnderline") private var homeGreetingUnderline = false
    @AppStorage("beans.homeGreetingGradient") private var homeGreetingGradient = false
    @AppStorage("beans.homeGreetingGradientStartHex") private var homeGreetingGradientStartHex = ""
    @AppStorage("beans.homeGreetingGradientEndHex") private var homeGreetingGradientEndHex = ""
    @AppStorage("beans.homeGreetingFont") private var homeGreetingFontName = ""
    @AppStorage("beans.homeHideUsername") private var homeHideUsername = false
    @AppStorage("beans.pauseHomeRendering") private var homeRenderingPaused = false
    @AppStorage("beans.homeHeaderHideSort") private var homeHeaderHideSort = false
    @AppStorage("beans.homeHeaderHideRefresh") private var homeHeaderHideRefresh = true
    @AppStorage("beans.homeWallpaperBlur") private var homeWallpaperBlur = 0.0
    @AppStorage(PlatformPreferenceStore.hidePickerKey) private var hidePlatformPicker = false
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    @AppStorage("beans.showSongVIPBadge") private var showSongVIPBadge = true
    private var homeProviders: [SearchProvider] { [.kugou] }
    private var source: SearchProvider { .kugou }
    private var isNativeClean: Bool { BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean }

    @State private var kugouTopLists: [KugouTopInfo] = []
    @State private var playlistCats: [String] = []
    /// 排行榜展开状态：收起显示前 3，展开显示前 10
    @State private var ranksExpanded = false
    /// 歌单广场展开状态：收起显示前 6，展开显示全部
    @State private var playlistsExpanded = false
    /// 首页加载去重：SwiftUI 视图刷新时 .task 可能被重复触发，避免网络请求风暴。
    @State private var activeLoadKey: String?
    /// 当前请求令牌：登录切换触发强制刷新时，旧请求即使晚返回也不能覆盖新账号结果。
    @State private var activeLoadToken: UUID?
    @State private var lastLoadedKey = ""
    @State private var lastLoadedAt = Date.distantPast
    /// 登录后让对应平台绕过缓存重新拉取主页数据。
    @State private var forceHomeReload = false
    @State private var homeReloadToken = 0
    /// 首次启动免责声明：确认进入后若加载失败自动刷新
    @AppStorage("beans.disclaimerAccepted") private var disclaimerAccepted = false
    /// 网易云歌单广场当前分类（「全部」展示官方精品歌单）
    /// 官方歌单分类列表
    /// 网易云歌单广场搜索状态；搜索结果沿用现有歌单卡片和详情路由
    @State private var playlistSearchText = ""
    @State private var playlistSearchResults: [Playlist] = []
    @State private var playlistSearchActive = false
    @State private var playlistSearchLoading = false
    @State private var playlistSearchTask: Task<Void, Never>?

    init() {
        let savedRaw = UserDefaults.standard.string(forKey: "beans.homeSource")
            ?? SearchProvider.kugou.rawValue
        let savedSource = SearchProvider(rawValue: savedRaw) ?? .kugou
        let snapshot = DiscoverCache.shared.cached(for: savedSource)
        _topLists = State(initialValue: snapshot?.topLists ?? [])
        _dailySongs = State(initialValue: snapshot?.dailySongs ?? [])
        _newAlbums = State(initialValue: snapshot?.newAlbums ?? [])
        _topArtists = State(initialValue: snapshot?.topArtists ?? [])
        _personalized = State(initialValue: snapshot?.personalized ?? [])
        _kugouTopLists = State(initialValue: snapshot?.kugouTopLists ?? [])
        _loading = State(initialValue: snapshot == nil || snapshot?.isEmpty == true)
    }

    var body: some View {
        musicHomeContent
    }

    private var musicHomeContent: some View {
        let _ = theme.accent
        return BeansNavigationStackWithPath(path: $navigationPath) {
        ZStack {
            if !usesSharedRootBackdrop {
                // 主页背景：壁纸/背景色永远在发现页生效（homeMode），同步开启时其他页面也生效
                GlassBackdrop(customColor: theme.customBackground, homeMode: true, wallpaperBlur: CGFloat(homeWallpaperBlur))
            }
            // 实例级 UITabBar 清透风格（固定全透明，无需调节）
            TabBarAppearanceConfigurator()
            if #unavailable(iOS 16.0) {
                NavigationLink(
                    destination: discoverDestination(legacyRoute ?? .dailySongs([])),
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
                if !homeRenderingPaused {
                    ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: isNativeClean ? 34 : 26) {
                        header
                        if let errorMessage {
                            ErrorStateView(message: errorMessage) {
                                Task { await load(force: true) }
                            }
                        } else if loading {
                            discoverLoadingState
                        } else {
                            // 板块按用户自定义顺序渲染（可拖拽排序）
                            ForEach(homeOrder.filter { availableSections.contains($0) }, id: \.self) { key in
                                switch key {
                                case "每日推荐":
                                    if !dailySongs.isEmpty {
                                        dailySection
                                            .sectionEntrance(delay: 0)
                                    }
                                case "新碟上架":
                                    if !newAlbums.isEmpty {
                                        newAlbumsSection
                                            .sectionEntrance(delay: 0.04)
                                    }
                                case "歌手":
                                    if source == .kugou || !topArtists.isEmpty {
                                        artistsSection
                                            .sectionEntrance(delay: 0.08)
                                    }
                                case "排行榜":
                                    if hasRankData { topListsSection.sectionEntrance(delay: 0.12) }
                                default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, isNativeClean ? 24 : 16)
                    .padding(.top, isNativeClean ? 32 : 8)
                    .padding(.bottom, 190)
                    .beansAdaptiveContentWidth()
                    }
                }
            }
            .beansScrollIndicatorsHidden()
            .task(id: "\(source.rawValue)-\(homeRenderingPaused)-\(homeReloadToken)") {
                guard !homeRenderingPaused else { return }
                let force = forceHomeReload
                let reloadToken = homeReloadToken
                await load(force: force)
                if force, reloadToken == homeReloadToken {
                    forceHomeReload = false
                }
            }
            .onChange(of: source) { _ in
                guard !homeRenderingPaused else { return }
                clearPlaylistSearch()
                homeOrder = SectionOrderStore.load(SectionOrderStore.homeKey, defaults: availableSections)
            }
            .onChange(of: disclaimerAccepted) { accepted in
                guard !homeRenderingPaused else { return }
                // 免责声明确认进入后：若首页加载失败则自动刷新（无需手动下拉）
                if accepted, errorMessage != nil {
                    Task { await load(force: true) }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .beansKugouLoginDidUpdate)) { _ in
                guard !homeRenderingPaused else { return }
                reloadAfterLoginUpdate(.kugou)
            }
            .sheet(isPresented: $showSectionSort) {
                SectionOrderSheet(
                    title: "主页板块排序",
                    sections: availableSections,
                    order: $homeOrder,
                    platformOrder: Binding(
                        get: { platformPrefs.orderedRaw },
                        set: { platformPrefs.orderedRaw = $0 }
                    )
                )
                    .onDisappear { SectionOrderStore.save(SectionOrderStore.homeKey, homeOrder) }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView(forceHomeBackdrop: true)
                    .environmentObject(theme)
                    .environmentObject(auth)
                    .environmentObject(player)
                    .modifier(BeansProfileSheetBackground())
            }
        }
            .beansNavigationDestination(for: DiscoverRoute.self) { route in
                discoverDestination(route)
            }
            .beansHomeNavigationBarTransparent()
        }
    }

    @ViewBuilder
    private func discoverDestination(_ route: DiscoverRoute) -> some View {
        switch route {
        case .playlist(let playlist):
            PlaylistView(playlist: playlist)
                .environmentObject(player)
                .environmentObject(auth)
        case .album(let album):
            AlbumDetailView(album: album, embeddedInNavigation: true)
                .environmentObject(player)
        case .artist(let artist):
            ArtistHomeSheet(artist: artist, embeddedInNavigation: true)
                .environmentObject(player)
        case .kugouTopList(let info):
            KugouTopListDetailView(topList: info)
                .environmentObject(player)
                .environmentObject(auth)
        case .dailySongs(let songs):
            DailySongsSheet(songs: songs) { refreshedSongs in
                replaceDailySongs(refreshedSongs, for: .kugou)
            }
                .environmentObject(player)
                .environmentObject(auth)
        }
    }

    private func openRoute(_ route: DiscoverRoute) {
        if #available(iOS 16.0, *) {
            navigationPath.append(route)
        } else {
            legacyRoute = route
        }
    }

    /// 顶部问候区：大标题 + 刷新按钮
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(greetingLines.enumerated()), id: \.offset) { index, line in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Group {
                                if homeGreetingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(LocalizedStringKey(line))
                                } else {
                                    Text(verbatim: line)
                                }
                            }
                            .font(BeansFont.greetingFont(isNativeClean ? max(42, greetingLineSize(index)) : greetingLineSize(index), .bold))
                            .foregroundStyle(greetingLineStyle(index))
                                    .overlay(alignment: .bottomLeading) {
                                        if homeGreetingUnderline {
                                            Rectangle()
                                                .fill(greetingLineColor(index))
                                                .frame(height: 1.5)
                                                .offset(y: 2)
                                        }
                                    }
                                    .shadow(
                                        color: homeGreetingGlowEnabled
                                            ? greetingLineColor(index).opacity(min(1, 0.75 * homeGreetingGlowIntensity))
                                            : .clear,
                                        radius: homeGreetingGlowEnabled
                                            ? 8 + 28 * homeGreetingGlowIntensity
                                            : 0
                                    )
                                    .shadow(
                                        color: homeGreetingGlowEnabled
                                            ? greetingLineColor(index).opacity(min(1, 0.95 * homeGreetingGlowIntensity))
                                            : .clear,
                                        radius: homeGreetingGlowEnabled
                                            ? 2 + 10 * homeGreetingGlowIntensity
                                            : 0
                                    )
                                    .fixedSize(horizontal: false, vertical: true)
                                    .offset(y: greetingLineOffsetY(index))
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    if !homeHideUsername {
                        Group {
                            if let nickname = auth.user?.nickname, !nickname.isEmpty {
                                Text(nickname)
                            } else {
                                Text(LocalizedStringKey("发现好音乐"))
                            }
                        }
                        .font(BeansFont.appFont(13))
                        .foregroundStyle(Color.beansComment)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                HStack(spacing: 10) {
                    homeProfileButton
                    if !homeHeaderHideSort {
                        GlassIconButton(systemName: "arrow.up.arrow.down") {
                            BeansHaptics.tap()
                            showSectionSort = true
                        }
                    }
                    if !homeHeaderHideRefresh {
                        GlassIconButton(systemName: "arrow.clockwise") {
                            BeansHaptics.tap()
                            Task { await load(force: true) }
                        }
                    }
                }
            }
        }
        .padding(.top, isNativeClean ? 4 : 8)
        .frame(minHeight: homeGreetingHeight > 0 ? homeGreetingHeight : nil, alignment: .top)
    }

    /// 主页右上角的“我的”入口，复用我的页面头像并保持液态玻璃边框。
    private var homeProfileButton: some View {
        BeansProfileShortcutButton {
            showProfile = true
        }
    }

    private var greeting: String {
        let custom = homeGreetingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return custom }
        let hour = Calendar.current.component(.hour, from: Date())
        if isNativeClean { return "推荐" }
        switch hour {
        case 5..<12: return "早上好"
        case 12..<18: return "下午好"
        default: return "晚上好"
        }
    }

    private var discoverLoadingState: some View {
        VStack(alignment: .leading, spacing: isNativeClean ? 34 : 26) {
            ForEach(homeOrder.filter { availableSections.contains($0) }, id: \.self) { key in
                switch key {
                case "每日推荐":
                    loadingRecommendationSection
                case "新碟上架":
                    loadingHorizontalCoverSection(titleWidth: 116, itemSize: isNativeClean ? 148 : 124, itemCount: 4)
                case "歌手":
                    loadingArtistSection
                case "排行榜":
                    loadingRankSection
                default:
                    EmptyView()
                }
            }
        }
        .accessibilityLabel(Text("加载中"))
    }

    private var loadingRecommendationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !isNativeClean {
                BeansShimmerSkeleton(cornerRadius: 8)
                    .frame(width: 78, height: 24)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(0..<recommendationSkeletonCount, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 0) {
                            BeansShimmerSkeleton(cornerRadius: isNativeClean ? 16 : 18)
                                .frame(
                                    width: recommendationSkeletonSize.width,
                                    height: recommendationSkeletonSize.height
                                )
                            if index == 0 && dailySongsListStyle {
                                BeansShimmerSkeleton(cornerRadius: 5)
                                    .frame(width: 108, height: 12)
                                    .padding(.top, 8)
                                BeansShimmerSkeleton(cornerRadius: 5)
                                    .frame(width: 74, height: 10)
                                    .padding(.top, 8)
                            }
                        }
                    }
                    Color.clear.frame(width: 0, height: 1)
                }
                .padding(.vertical, 3)
                .frame(height: recommendationSkeletonHeight)
            }
            .beansCompatScrollClipDisabled()
            .padding(.trailing, isNativeClean ? -24 : 0)
        }
    }

    private var recommendationSkeletonCount: Int {
        if dailySongsListStyle { return 4 }
        return 2
    }

    private var recommendationSkeletonSize: CGSize {
        if dailySongsListStyle {
            let side = isNativeClean ? 156.0 : 108.0
            return CGSize(width: side, height: side)
        }
        let side = isNativeClean ? 172.0 : 160.0
        return CGSize(width: side, height: side)
    }

    private var recommendationSkeletonHeight: CGFloat {
        if dailySongsListStyle { return isNativeClean ? 198 : 150 }
        return isNativeClean ? 178 : 166
    }

    private func loadingHorizontalCoverSection(titleWidth: CGFloat, itemSize: CGFloat, itemCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            BeansShimmerSkeleton(cornerRadius: 8)
                .frame(width: titleWidth, height: isNativeClean ? 26 : 22)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(0..<itemCount, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 7) {
                            BeansShimmerSkeleton(cornerRadius: 6)
                                .frame(width: itemSize, height: itemSize)
                            BeansShimmerSkeleton(cornerRadius: 5)
                                .frame(width: index.isMultiple(of: 2) ? itemSize * 0.78 : itemSize * 0.58, height: 12)
                            BeansShimmerSkeleton(cornerRadius: 5)
                                .frame(width: itemSize * 0.48, height: 10)
                        }
                        .frame(width: itemSize, alignment: .leading)
                    }
                    Color.clear.frame(width: isNativeClean ? 0 : 8, height: 1)
                }
                .padding(.vertical, 2)
                .frame(height: itemSize + 50)
            }
            .beansCompatScrollClipDisabled()
            .padding(.trailing, isNativeClean ? -24 : 0)
        }
    }

    private var loadingArtistSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            BeansShimmerSkeleton(cornerRadius: 8)
                .frame(width: 64, height: isNativeClean ? 26 : 22)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(0..<5, id: \.self) { index in
                        let size = isNativeClean ? 136.0 : 116.0
                        VStack(spacing: 8) {
                            BeansShimmerSkeleton(cornerRadius: size / 2)
                                .frame(width: size, height: size)
                            BeansShimmerSkeleton(cornerRadius: 5)
                                .frame(width: index.isMultiple(of: 2) ? 72 : 54, height: 12)
                        }
                        .frame(width: size)
                    }
                    Color.clear.frame(width: isNativeClean ? 0 : 8, height: 1)
                }
                .padding(.vertical, 2)
                .frame(height: isNativeClean ? 168 : 146)
            }
            .beansCompatScrollClipDisabled()
            .padding(.trailing, isNativeClean ? -24 : 0)
        }
    }

    @ViewBuilder
    private var loadingRankSection: some View {
        if isNativeClean {
            loadingHorizontalCoverSection(titleWidth: 78, itemSize: 148, itemCount: 4)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                BeansShimmerSkeleton(cornerRadius: 8)
                    .frame(width: 78, height: 22)
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { index in
                        HStack(spacing: 12) {
                            BeansShimmerSkeleton(cornerRadius: 5)
                                .frame(width: 24, height: 18)
                            BeansShimmerSkeleton(cornerRadius: 6)
                                .frame(width: 52, height: 52)
                            VStack(alignment: .leading, spacing: 8) {
                                BeansShimmerSkeleton(cornerRadius: 5)
                                    .frame(width: index == 1 ? 132 : 168, height: 13)
                                BeansShimmerSkeleton(cornerRadius: 5)
                                    .frame(width: 92, height: 10)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                        if index < 2 {
                            Divider().overlay(Color.beansComment.opacity(0.12))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black.opacity(0.06))
                        .background {
                            BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .beansCardShadow(radius: 9, y: 3)
            }
        }
    }


    /// 每日推荐封面右下角播放状态：当前播放中显示动态指示器，暂停显示暂停，其余显示播放
    @ViewBuilder
    private func dailyPlayStateBadge(for song: Song) -> some View {
        let isCurrent = player.currentSong?.identityKey == song.identityKey
        ZStack {
            if isCurrent && player.isPlaying {
                NowPlayingIndicator()
                    .frame(width: 24, height: 24)
                    .background(.black.opacity(0.45), in: Circle())
            } else {
                Image(systemName: isCurrent ? "pause.fill" : "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.black.opacity(0.45), in: Circle())
            }
        }
        .padding(7)
    }

    /// 每平台排行榜最多 10 个（收起只显示前 3，展开显示前 10）
    private var visibleRankCount: Int {
        kugouTopLists.count
    }

    private var displayedRankCount: Int {
        ranksExpanded ? min(visibleRankCount, 10) : min(visibleRankCount, 3)
    }

    /// 是否有排行榜数据
    private var hasRankData: Bool {
        !kugouTopLists.isEmpty
    }

    // MARK: - 排行榜（竖排行列表）

    @ViewBuilder
    private var topListsSection: some View {
        if isNativeClean {
            nativeCleanTopListsSection
        } else {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "排行榜")
            VStack(spacing: 0) {
                if ranksExpanded {
                    rankToggleButton(label: "收起", icon: "chevron.up")
                    Divider().overlay(Color.beansComment.opacity(0.12))
                }
                rankRowsContent
                if !ranksExpanded, visibleRankCount > 3 {
                    rankToggleButton(label: "展开全部（\(min(visibleRankCount, 10))）", icon: "chevron.down")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.06))
                    .background {
                        BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .beansCardShadow(radius: 9, y: 3)
            .id("rankTopSection")
        }
        }
    }

    private var nativeCleanTopListsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "排行榜")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(Array(kugouTopLists.prefix(min(visibleRankCount, 10)).enumerated()), id: \.element.id) { index, info in
                        nativeRankCard(index: index, name: beansChartName(info.name), subtitle: beansChartSubtitle(info.updateFrequency), coverURL: info.coverURL) {
                            openRoute(DiscoverRoute.kugouTopList(info))
                        }
                    }
                    Color.clear.frame(width: 0, height: 1)
                }
                .padding(.vertical, 2)
                .frame(height: 202)
            }
            .beansCompatScrollClipDisabled()
            // 保留首页左侧起始边距，右侧滚动时才延伸到屏幕边缘。
            .padding(.trailing, isNativeClean ? -24 : 0)
        }
        .id("rankTopSection")
    }

    private func nativeRankCard(index: Int, name: String, subtitle: String, coverURL: URL?, action: @escaping () -> Void) -> some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    CoverImage(url: coverURL, size: 148, cornerRadius: 6)
                }
                .frame(width: 148, height: 148)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(name)
                    .font(BeansFont.appFont(15, .bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .frame(width: 148, alignment: .leading)
                Text(subtitle)
                    .font(BeansFont.appFont(12, .medium))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            .frame(width: 148, alignment: .leading)
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.96))
    }

    /// 排行榜行列表（按平台渲染）
    @ViewBuilder
    private var rankRowsContent: some View {
        ForEach(Array(kugouTopLists.prefix(displayedRankCount).enumerated()), id: \.element.id) { index, info in
            rankRow(index: index, name: beansChartName(info.name), subtitle: beansChartSubtitle(info.updateFrequency), coverURL: info.coverURL) {
                BeansHaptics.tap()
                openRoute(DiscoverRoute.kugouTopList(info))
            }
            Divider().overlay(Color.beansComment.opacity(0.12))
        }
    }

    /// 展开 / 收起切换按钮
    private func rankToggleButton(label: String, icon: String) -> some View {
        Button {
            BeansHaptics.select()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { ranksExpanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .font(BeansFont.appFont(13, .medium))
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color.beansAmber)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func rankRow(index: Int, name: String, subtitle: String, coverURL: URL?, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(BeansFont.appFont(16, .bold, .rounded))
                    .foregroundStyle(index < 3 ? Color.beansAmber : Color.beansComment)
                    .frame(width: 24)
                CoverImage(url: coverURL, size: 52, cornerRadius: 6)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(BeansFont.appFont(15, .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.beansComment.opacity(0.6))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// QQ 峰尖榜占位渐变（保留备用）
    private func qqRankGradient(_ name: String) -> LinearGradient {
        let palettes: [[Color]] = [
            [Color(red: 0.35, green: 0.55, blue: 0.95), Color(red: 0.20, green: 0.30, blue: 0.65)],
            [Color(red: 0.95, green: 0.42, blue: 0.36), Color(red: 0.70, green: 0.18, blue: 0.20)],
            [Color(red: 0.20, green: 0.78, blue: 0.62), Color(red: 0.08, green: 0.52, blue: 0.44)],
            [Color(red: 0.92, green: 0.62, blue: 0.25), Color(red: 0.72, green: 0.38, blue: 0.12)],
            [Color(red: 0.62, green: 0.45, blue: 0.90), Color(red: 0.40, green: 0.25, blue: 0.68)],
            [Color(red: 0.30, green: 0.70, blue: 0.85), Color(red: 0.16, green: 0.45, blue: 0.65)]
        ]
        let seed = abs(name.hashValue) % palettes.count
        return LinearGradient(colors: palettes[seed], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - 每日推荐

    @ViewBuilder
    private var dailySection: some View {
        if dailySongsListStyle {
            dailySongCards
        } else {
            kugouRecommendationCards
        }
    }

    private var kugouRecommendationCards: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !isNativeClean {
                SectionHeader(title: "推荐")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    neteaseRecommendationCard(
                        title: "每日推荐",
                        subtitle: dailyRecommendationSubtitle,
                        icon: "calendar",
                        coverURL: dailySongs.first?.coverURL,
                        gradient: [Color(red: 0.95, green: 0.36, blue: 0.28), Color(red: 0.96, green: 0.68, blue: 0.30)],
                        loadingKey: nil,
                        emphasized: true
                    ) {
                        BeansHaptics.tap()
                        openRoute(DiscoverRoute.dailySongs(dailySongs))
                    }

                    neteaseRecommendationCard(
                        title: "私人漫游",
                        subtitle: "从喜欢的歌开始漫游",
                        icon: "wave.3.right.circle.fill",
                        coverURL: nil,
                        gradient: [Color(red: 0.08, green: 0.46, blue: 0.82), Color(red: 0.18, green: 0.72, blue: 0.72)],
                        loadingKey: "kugouFM",
                        emphasized: true
                    ) {
                        startKugouPersonalFM()
                    }
                    Color.clear.frame(width: 0, height: 1)
                }
                .padding(.vertical, 3)
                .frame(height: isNativeClean ? 178 : 166)
            }
            .beansCompatScrollClipDisabled()
            .padding(.trailing, isNativeClean ? -24 : 0)
        }
    }

    private var dailySongCards: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 横滑歌曲卡：每日推荐前 8 首
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(dailySongs.prefix(8).enumerated()), id: \.element.identityKey) { index, song in
                        Button {
                            BeansHaptics.tap()
                            player.play(songs: dailySongs, startAt: index)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                CoverImage(url: song.coverURL, song: song, size: isNativeClean ? 156 : 108, cornerRadius: isNativeClean ? 14 : 16)
                                    .overlay(alignment: .topLeading) {
                                    if showSongVIPBadge, song.isVIP {
                                            Text("VIP")
                                                .font(BeansFont.appFont(9, .bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1.5)
                                                .background(Capsule().fill(Color(red: 0.93, green: 0.25, blue: 0.22)))
                                                .padding(6)
                                        }
                                    }
                                    .overlay(alignment: .bottomTrailing) {
                                        dailyPlayStateBadge(for: song)
                                    }
                                Text(song.name)
                                    .font(BeansFont.appFont(isNativeClean ? 15 : 12, isNativeClean ? .bold : .medium))
                                    .foregroundStyle(Color.beansLabel)
                                    .lineLimit(1)
                                    .frame(width: isNativeClean ? 156 : 108, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                Text(song.artists.isEmpty ? song.album : song.artists)
                                    .font(BeansFont.appFont(10))
                                    .foregroundStyle(Color.beansComment)
                                    .lineLimit(1)
                                    .frame(width: isNativeClean ? 156 : 108, alignment: .leading)
                            }
                        }
                        .buttonStyle(GlassPressButtonStyle(scale: 0.94))
                    }
                    Button {
                        BeansHaptics.tap()
                        openRoute(DiscoverRoute.dailySongs(dailySongs))
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .semibold))
                            Text("查看更多")
                                .font(BeansFont.appFont(11, .semibold))
                        }
                        .foregroundStyle(Color.beansLabel)
                            .frame(width: isNativeClean ? 72 : 68, height: isNativeClean ? 132 : 96)
                        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)) }
                    }
                    .buttonStyle(GlassPressButtonStyle(scale: 0.94))
                    Color.clear.frame(width: isNativeClean ? 0 : 8, height: 1)
                }
                .padding(.vertical, 2)
            }
            .beansCompatScrollClipDisabled()
            // 保留首页左侧起始边距，右侧滚动时才延伸到屏幕边缘。
            .padding(.trailing, isNativeClean ? -24 : 0)
        }
    }

    private var dailyRecommendationSubtitle: String {
        if dailySongs.isEmpty {
            return beansLocalized("每天 6:00 更新", "Refreshes at 6:00 daily")
        }
        return String(format: beansLocalized("%d 首 · 每天 6:00 更新", "%d songs · refreshes at 6:00 daily"), dailySongs.count)
    }

    @ViewBuilder
    private func neteaseRecommendationCard(
        title: String,
        subtitle: String,
        icon: String,
        coverURL: URL?,
        gradient: [Color],
        loadingKey: String?,
        emphasized: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let cardWidth: CGFloat = emphasized ? (isNativeClean ? 172 : 160) : (isNativeClean ? 160 : 148)
        let cardHeight: CGFloat = emphasized ? (isNativeClean ? 172 : 160) : (isNativeClean ? 160 : 148)
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                if let coverURL {
                    CoverImage(url: coverURL, size: cardHeight, aspectRatio: cardWidth / cardHeight, cornerRadius: 6)
                        .frame(width: cardWidth, height: cardHeight)
                        .overlay {
                            LinearGradient(
                                colors: [.black.opacity(0.05), .black.opacity(0.62)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(alignment: .topTrailing) {
                            Circle()
                                .fill(.white.opacity(0.16))
                                .frame(width: 92, height: 92)
                                .blur(radius: 3)
                                .offset(x: 24, y: -26)
                        }
                        .overlay(alignment: .center) {
                            Image(systemName: icon)
                                .font(.system(size: 46, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.32))
                                .offset(x: 34, y: -18)
                        }
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .bold))
                        if let loadingKey, recommendationActionLoading == loadingKey {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.72)
                        }
                    }
                    .foregroundStyle(.white.opacity(0.92))
                    Spacer(minLength: 0)
                    Text(LocalizedStringKey(title))
                        .font(BeansFont.appFont(isNativeClean ? 20 : 18, .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(BeansFont.appFont(12, .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }
                .padding(14)
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: Color.black.opacity(isNativeClean ? 0.06 : 0.12), radius: 16, x: 0, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.95))
        .disabled(loadingKey != nil && recommendationActionLoading != nil)
    }

    private func startKugouPersonalFM() {
        guard KugouMusicAuth.shared.isLoggedIn else {
            ToastCenter.shared.show("请先登录酷狗音乐")
            return
        }
        guard recommendationActionLoading == nil else { return }
        recommendationActionLoading = "kugouFM"
        Task {
            defer { Task { @MainActor in recommendationActionLoading = nil } }
            do {
                let songs = try await KugouMusicAPI.shared.personalFM(limit: 12)
                await MainActor.run {
                    if songs.isEmpty {
                        ToastCenter.shared.show("私人漫游暂时没有推荐")
                    } else {
                        player.play(songs: songs, startAt: 0)
                        ToastCenter.shared.show("已开启私人漫游")
                    }
                }
            } catch {
                await MainActor.run {
                    BeansLogger.shared.log("酷狗私人漫游加载失败：\(error.localizedDescription)", level: .error)
                    ToastCenter.shared.show("私人漫游加载失败")
                }
            }
        }
    }

    @ViewBuilder
    private var catChips: [String] {
        if playlistCats.isEmpty {
            return ["全部", "华语", "流行", "经典", "摇滚", "民谣", "电子", "影视原声", "ACG", "怀旧", "欧美", "日韩", "粤语", "古风", "轻音乐", "治愈", "学习", "运动", "夜晚"]
        }
        return ["全部"] + Array(playlistCats.prefix(18))
    }

    private var personalizedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: playlistSectionTitle)
            if playlistSearchLoading && visiblePersonalizedPlaylists.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .tint(Color.beansAmber)
            } else if visiblePersonalizedPlaylists.isEmpty {
                EmptyStateView(icon: "music.note.list", text: playlistEmptyText)
            } else if isNativeClean && !playlistsExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(visiblePersonalizedPlaylists, id: \.id) { (playlist: Playlist) in
                            Button {
                                BeansHaptics.tap()
                                openRoute(DiscoverRoute.playlist(playlist))
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    CoverImage(url: playlist.coverURL, size: 166, cornerRadius: 6)
                                    Text(playlist.name)
                                        .font(BeansFont.appFont(15, .bold))
                                        .foregroundStyle(Color.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .frame(width: 166, alignment: .leading)
                                    if playlist.trackCount > 0 {
                                        Text(beansSongCountText(playlist.trackCount))
                                            .font(BeansFont.appFont(12, .medium))
                                            .foregroundStyle(Color.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(width: 166, alignment: .leading)
                            }
                            .buttonStyle(GlassPressButtonStyle(scale: 0.96))
                        }
                        Color.clear.frame(width: isNativeClean ? 0 : 8, height: 1)
                    }
                    .padding(.vertical, 2)
                    .frame(height: 238)
                    .beansCompatScrollClipDisabled()
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(visiblePersonalizedPlaylists) { playlist in
                        Button {
                            openRoute(DiscoverRoute.playlist(playlist))
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                CoverImage(url: playlist.coverURL, size: 144, cornerRadius: 6)
                                    .frame(maxWidth: .infinity)
                                Text(playlist.name)
                                    .font(BeansFont.appFont(12, .medium))
                                    .foregroundStyle(Color.beansLabel)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                if isNativeClean {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.primary.opacity(0.04))
                                } else {
                                    BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                }
                            }
                        }
                        .buttonStyle(GlassPressButtonStyle(scale: 0.96))
                    }
                }
            }
            if playlistDisplayItems.count > collapsedPlaylistCount {
                Button {
                    BeansHaptics.select()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        playlistsExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(playlistsExpanded
                             ? beansLocalized("收起歌单广场", "Collapse Playlist Square")
                             : beansLocalized("展开全部（\(playlistDisplayItems.count)）", "Show all (\(playlistDisplayItems.count))"))
                            .font(BeansFont.appFont(13, .semibold))
                        Image(systemName: playlistsExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color.beansAmber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background {
                        if isNativeClean {
                            Capsule().fill(Color.primary.opacity(0.045))
                        } else {
                            BeansGlass(shape: Capsule())
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.97))
            }
        }
    }

    private var playlistSectionTitle: String {
        if playlistSearchActive {
            return beansLocalized("歌单搜索结果", "Playlist Search Results")
        }
        return "歌单广场" 
    }

    private var playlistEmptyText: String {
        if playlistSearchActive {
            return beansLocalized("没有找到相关歌单", "No matching playlists found")
        }
        return "歌单广场暂时没有内容" 
    }

    private var collapsedPlaylistCount: Int { 6 }

    private var playlistDisplayItems: [Playlist] {
        playlistSearchActive ? playlistSearchResults : personalized
    }

    private var visiblePersonalizedPlaylists: [Playlist] {
        playlistsExpanded ? playlistDisplayItems : Array(playlistDisplayItems.prefix(collapsedPlaylistCount))
    }

    @ViewBuilder
    private var playlistSearchField: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer {
                playlistSearchFieldContent
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
        } else {
            playlistSearchFieldContent
                .background {
                    BeansGlass(shape: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
        }
    }

    // MARK: - 新碟与歌手

    private var newAlbumsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: beansLocalized("新碟上架", "New Releases"))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(newAlbums) { album in
                        Button {
                            BeansHaptics.tap()
                            openRoute(.album(album))
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                CoverImage(url: album.coverURL, size: isNativeClean ? 148 : 124, cornerRadius: 6)
                                Text(album.name)
                                    .font(BeansFont.appFont(isNativeClean ? 14 : 12, .semibold))
                                    .foregroundStyle(Color.beansLabel)
                                    .lineLimit(1)
                                    .frame(width: isNativeClean ? 148 : 124, alignment: .leading)
                                Text(album.artistName.isEmpty ? beansLocalized("未知歌手", "Unknown artist") : album.artistName)
                                    .font(BeansFont.appFont(11))
                                    .foregroundStyle(Color.beansComment)
                                    .lineLimit(1)
                                    .frame(width: isNativeClean ? 148 : 124, alignment: .leading)
                            }
                        }
                        .buttonStyle(GlassPressButtonStyle(scale: 0.95))
                    }
                    Color.clear.frame(width: isNativeClean ? 0 : 8, height: 1)
                }
                .padding(.vertical, 2)
                .frame(height: isNativeClean ? 198 : 170)
            }
            .beansCompatScrollClipDisabled()
            .padding(.trailing, isNativeClean ? -24 : 0)
        }
    }

    private var artistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: beansLocalized("歌手", "Artists"))
            if topArtists.isEmpty {
                Text(beansLocalized("暂无音乐人", "No artists available"))
                    .font(BeansFont.appFont(13))
                    .foregroundStyle(Color.beansComment)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 18)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(topArtists) { artist in
                            Button {
                                BeansHaptics.tap()
                                openRoute(.artist(artist))
                            } label: {
                                VStack(spacing: 8) {
                                    CoverImage(url: artist.coverURL, size: isNativeClean ? 136 : 116, cornerRadius: isNativeClean ? 68 : 58)
                                    Text(artist.name)
                                        .font(BeansFont.appFont(isNativeClean ? 14 : 12, .semibold))
                                        .foregroundStyle(Color.beansLabel)
                                        .lineLimit(1)
                                        .frame(width: isNativeClean ? 136 : 116)
                                }
                            }
                            .buttonStyle(GlassPressButtonStyle(scale: 0.95))
                        }
                        Color.clear.frame(width: isNativeClean ? 0 : 8, height: 1)
                    }
                    .padding(.vertical, 2)
                    .frame(height: isNativeClean ? 168 : 146)
                }
                .beansCompatScrollClipDisabled()
                .padding(.trailing, isNativeClean ? -24 : 0)
            }
        }
    }

    @ViewBuilder
    private var playlistSearchFieldContent: some View {
        if #available(iOS 26, *) {
            ZStack(alignment: .trailing) {
                NativeSearchBar(
                    text: $playlistSearchText,
                    placeholder: playlistSearchPrompt,
                    onTextChange: { value in
                        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, playlistSearchActive {
                            clearPlaylistSearch()
                        }
                    },
                    onSubmit: { _ in submitPlaylistSearch() }
                )
                if playlistSearchLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.beansAmber)
                        .padding(.trailing, 14)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 46)
        } else {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.beansComment)

                TextField(playlistSearchPrompt, text: $playlistSearchText)
                    .font(BeansFont.appFont(14))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { submitPlaylistSearch() }

                if playlistSearchLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.beansAmber)
                } else if !playlistSearchText.isEmpty {
                    Button { clearPlaylistSearch() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.beansComment.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }

                Button { submitPlaylistSearch() } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(Color.beansAmber)
                }
                .buttonStyle(.plain)
                .disabled(playlistSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || playlistSearchLoading)
                .opacity(playlistSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
            .padding(.horizontal, 13)
            .frame(height: 42)
            .background {
                BeansGlass(shape: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    @MainActor
    private func submitPlaylistSearch() {
        let keyword = playlistSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        playlistSearchTask?.cancel()
        guard !keyword.isEmpty else {
            clearPlaylistSearch()
            return
        }

        playlistSearchActive = true
        playlistSearchLoading = true
        playlistSearchResults = []
        playlistsExpanded = true

        playlistSearchTask = Task {
            do {
                let results: [Playlist] = []
                guard !Task.isCancelled else { return }
                playlistSearchResults = results
            } catch {
                guard !Task.isCancelled else { return }
                playlistSearchResults = []
            }
            playlistSearchLoading = false
        }
    }

    private var playlistSearchPrompt: String {
        ""
    }

    @MainActor
    private func clearPlaylistSearch() {
        playlistSearchTask?.cancel()
        playlistSearchTask = nil
        playlistSearchText = ""
        playlistSearchResults = []
        playlistSearchActive = false
        playlistSearchLoading = false
        playlistsExpanded = false
    }

    // MARK: - 动作

    @MainActor
    private func load(force: Bool = false) async {
        guard !homeRenderingPaused else { return }
        let cache = DiscoverCache.shared
        let requestedSource = source
        let requestedCat = "全部"
        let loadKey = "\(requestedSource.rawValue)|\(requestedCat)"
        // 普通重复任务直接复用当前请求；强制刷新必须允许替换旧请求，
        // 否则登录通知到达时会被首次启动时尚未完成的匿名请求拦截。
        if activeLoadKey == loadKey, !force {
            return
        }
        if !force,
           lastLoadedKey == loadKey,
           Date().timeIntervalSince(lastLoadedAt) < 20,
           hasAnyData {
            loading = false
            errorMessage = nil
            return
        }
        let loadToken = UUID()
        activeLoadKey = loadKey
        activeLoadToken = loadToken
        defer {
            if activeLoadToken == loadToken {
                activeLoadToken = nil
                activeLoadKey = nil
            }
        }
        let cacheable = true
        if let cached = cache.cached(for: requestedSource), !force, cacheable {
            guard !Task.isCancelled, activeLoadToken == loadToken, requestedSource == source else { return }
            apply(cached)
            loading = false
            errorMessage = nil
            lastLoadedKey = loadKey
            lastLoadedAt = Date()
            if cache.isFresh(cached, source: requestedSource),
               !BeansNetworkStatus.shared.isReachable { return }
            // 缓存过期：先用缓存展示，后台静默刷新
        } else {
            loading = true
            errorMessage = nil
        }

        do {
            let snapshot = try await fetchSnapshot(for: requestedSource, neteaseCat: requestedCat)
            guard !Task.isCancelled, activeLoadToken == loadToken, requestedSource == source else { return }
            apply(snapshot)
            if cacheable, !snapshot.isEmpty {
                cache.save(snapshot, for: requestedSource)
            }
            loading = false
            errorMessage = nil
            lastLoadedKey = loadKey
            lastLoadedAt = Date()
        } catch {
            guard !Task.isCancelled, activeLoadToken == loadToken, requestedSource == source else { return }
            loading = false
            if !hasAnyData {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var greetingLines: [String] {
        let custom = homeGreetingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if custom.isEmpty { return [greeting] }
        return custom.components(separatedBy: .newlines)
    }

    private func greetingLineSize(_ index: Int) -> CGFloat {
        guard index < 3 else { return CGFloat(homeGreetingSize) }
        let value: Double
        switch index {
        case 0: value = homeGreetingLine1Size
        case 1: value = homeGreetingLine2Size
        default: value = homeGreetingLine3Size
        }
        return CGFloat(value > 0 ? value : homeGreetingSize)
    }

    private func greetingLineColor(_ index: Int) -> Color {
        guard index < 3 else { return homeGreetingColor }
        let raw: String
        switch index {
        case 0: raw = homeGreetingLine1ColorHex
        case 1: raw = homeGreetingLine2ColorHex
        default: raw = homeGreetingLine3ColorHex
        }
        return Color(hex: raw) ?? homeGreetingColor
    }

    private func greetingLineStyle(_ index: Int) -> AnyShapeStyle {
        let color = greetingLineColor(index)
        if homeGreetingGradient {
            let startHex: String
            let endHex: String
            switch index {
            case 0:
                startHex = homeGreetingLine1GradientStartHex
                endHex = homeGreetingLine1GradientEndHex
            case 1:
                startHex = homeGreetingLine2GradientStartHex
                endHex = homeGreetingLine2GradientEndHex
            case 2:
                startHex = homeGreetingLine3GradientStartHex
                endHex = homeGreetingLine3GradientEndHex
            default:
                startHex = ""
                endHex = ""
            }
            let start = Color(hex: startHex) ?? Color(hex: homeGreetingGradientStartHex) ?? color
            let end = Color(hex: endHex) ?? Color(hex: homeGreetingGradientEndHex) ?? color.opacity(0.42)
            return AnyShapeStyle(LinearGradient(
                colors: [start, end],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
        return AnyShapeStyle(color)
    }

    private func greetingLineOffsetY(_ index: Int) -> CGFloat {
        guard index < 3 else { return 0 }
        switch index {
        case 0: return CGFloat(homeGreetingLine1OffsetY)
        case 1: return CGFloat(homeGreetingLine2OffsetY)
        default: return CGFloat(homeGreetingLine3OffsetY)
        }
    }

    @MainActor
    private func reloadAfterLoginUpdate(_ provider: SearchProvider) {
        // 登录态会改变推荐内容和会员状态，先切到对应平台，再绕过旧快照刷新。
        forceHomeReload = true
        homeReloadToken += 1
        if source == provider {
            // 刷新令牌会重启 .task，避免在当前视图生命周期中遗留旧缓存。
        } else {
            homeSourceRaw = provider.rawValue
        }
    }

    @MainActor
    private func replaceDailySongs(_ songs: [Song], for source: SearchProvider) {
        guard !songs.isEmpty else { return }
        dailySongs = songs
        guard var snapshot = DiscoverCache.shared.cached(for: source) else { return }
        snapshot.dailySongs = songs
        snapshot.savedAt = Date()
        DiscoverCache.shared.save(snapshot, for: source)
    }

    private var homeGreetingColor: Color {
        if let color = Color(hex: homeGreetingColorHex) { return color }
        return Color.beansLabel
    }

    private func fetchSnapshot(for source: SearchProvider, neteaseCat: String) async throws -> DiscoverCache.Snapshot {
        var snapshot = DiscoverCache.Snapshot()
        snapshot.savedAt = Date()
        async let songs = loadKugouDailySongs(limit: 30)
        async let ranks = KugouMusicAPI.shared.topLists(limit: 10)
        async let albums: [Album] = (try? await KugouMusicAPI.shared.newAlbums(limit: 18)) ?? []
        async let artists: [Artist] = (try? await KugouMusicAPI.shared.topArtists(limit: 18)) ?? []
        async let playlists: [Playlist] = (try? await KugouMusicAPI.shared.recommendPlaylists(limit: 18)) ?? []
        let (daily, top, newAlbums, topArtists, personalized) = await (songs, ranks, albums, artists, playlists)
        snapshot.dailySongs = daily
        snapshot.kugouTopLists = top
        snapshot.newAlbums = newAlbums
        snapshot.topArtists = topArtists
        snapshot.personalized = personalized
        return snapshot
    }

    private func loadKugouDailySongs(limit: Int) async -> [Song] {
        if let songs = try? await KugouMusicAPI.shared.everydayRecommend(limit: limit), !songs.isEmpty {
            return songs
        }
        return (try? await KugouMusicAPI.shared.searchSongs(keyword: "热门歌曲", limit: limit)) ?? []
    }

    @MainActor
    private func apply(_ snapshot: DiscoverCache.Snapshot) {
        dailySongs = snapshot.dailySongs
        newAlbums = snapshot.newAlbums
        topArtists = snapshot.topArtists
        topLists = []
        personalized = snapshot.personalized
        kugouTopLists = snapshot.kugouTopLists
        CoverImagePrefetcher.shared.prefetch(snapshot: snapshot)
    }

    private var hasAnyData: Bool {
        !dailySongs.isEmpty || !newAlbums.isEmpty || !topArtists.isEmpty
            || !personalized.isEmpty || !kugouTopLists.isEmpty
    }
}

// MARK: - 每日推荐全部歌曲

struct DailySongsSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var theme: ThemeStore

    let songs: [Song]
    var onRefreshed: (([Song]) -> Void)? = nil
    private var source: SearchProvider { .kugou }
    @State private var searchText = ""
    @State private var displayedSongs: [Song]
    @State private var isRefreshing = false
    @State private var refreshError: String?

    init(songs: [Song], onRefreshed: (([Song]) -> Void)? = nil) {
        self.songs = songs
        self.onRefreshed = onRefreshed
        _displayedSongs = State(initialValue: songs)
    }

    var body: some View {
        let _ = theme.accent
        ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                Group {
                if displayedSongs.isEmpty {
                    EmptyStateView(icon: "sparkles", text: "今日推荐加载中，请稍后重试")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if let refreshError {
                                Text(refreshError)
                                    .font(BeansFont.appFont(12, .medium))
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, beansDetailContentInset)
                                    .padding(.bottom, 8)
                            }
                            dailyHeader
                            ForEach(Array(filteredSongs.enumerated()), id: \.element.identityKey) { index, song in
                                SongCell(
                                    song: song,
                                    showCover: true,
                                    suppressNativeCleanRowGlass: true,
                                    coverSize: 46,
                                    fixedRowHeight: 64,
                                    playbackContext: filteredSongs,
                                    playbackIndex: index
                                ) {
                                    BeansHaptics.tap()
                                    player.play(songs: filteredSongs, startAt: index)
                                }
                                .padding(.horizontal, beansDetailContentInset)
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 118)
                    }
                    .beansScrollIndicatorsHidden()
                    .refreshable {
                        await refreshDailySongs()
                    }
                }
            }
            }
            .navigationTitle("今日推荐")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: beansLocalized("搜索每日推荐", "Search daily recommendations"))
            .beansDetailProfileToolbar()
            .task {
                await refreshDailySongs()
            }
    }

    private var dailyHeader: some View {
        ChartDetailHeader(
            title: "今日推荐",
            provider: source,
            coverURL: displayedSongs.first?.coverURL,
            trackCount: filteredSongs.count,
            playCount: nil,
            chartDescription: dailyRecommendationDescription,
            filteredCount: filteredSongs.count,
            onPlay: {
                guard !filteredSongs.isEmpty else { return }
                BeansHaptics.tap()
                player.play(songs: filteredSongs, startAt: 0)
            },
        )
    }

    private var dailyRecommendationDescription: String {
        beansLocalized(
            "为你整理的每日推荐歌曲，随时发现新的喜欢。",
            "Daily recommendations picked to help you discover your next favorite songs."
        )
    }

    private var filteredSongs: [Song] {
        let kw = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !kw.isEmpty else { return displayedSongs }
        return displayedSongs.filter { song in
            song.name.lowercased().contains(kw)
                || song.artists.lowercased().contains(kw)
                || song.album.lowercased().contains(kw)
        }
    }

    @MainActor
    private func refreshDailySongs() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        refreshError = nil
        defer { isRefreshing = false }

        do {
            let refreshed: [Song]
            if let songs = try? await KugouMusicAPI.shared.everydayRecommend(limit: 30), !songs.isEmpty {
                refreshed = songs
            } else {
                refreshed = try await KugouMusicAPI.shared.searchSongs(keyword: "热门歌曲", limit: 30)
            }
            guard !refreshed.isEmpty else { throw BeansDailyRecommendError.empty }
            displayedSongs = refreshed
            onRefreshed?(refreshed)
        } catch {
            refreshError = "刷新失败：\(error.localizedDescription)"
        }
    }
}

struct BeansProfileSheetBackground: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationBackground(.clear)
        } else {
            content
        }
    }
}

private enum BeansDailyRecommendError: LocalizedError {
    case empty

    var errorDescription: String? {
        "当前账号没有返回新的每日推荐内容"
    }
}

private struct ChartPlatformBadge: View {
    let provider: SearchProvider
    var creatorName: String? = nil
    var creatorAvatarURL: URL? = nil

    private var imageName: String {
        provider == .kugou ? "BrandKugou" : ""
    }

    var body: some View {
        HStack(spacing: 7) {
            if let creatorAvatarURL {
                CoverImage(url: creatorAvatarURL, size: 22, cornerRadius: 11)
            } else if !imageName.isEmpty {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .clipShape(Circle())
            }
            Text(creatorName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? creatorName!
                : beansPlatformName(provider))
                .font(BeansFont.appFont(14, .medium))
                .foregroundStyle(Color.beansComment)
                .lineLimit(1)
        }
    }
}

private struct ChartDetailHeader: View {
    let title: String
    let provider: SearchProvider
    let coverURL: URL?
    let trackCount: Int
    let playCount: Int?
    let chartDescription: String?
    let filteredCount: Int
    var downloadEnabled: Bool = false
    var creatorName: String? = nil
    var creatorAvatarURL: URL? = nil
    var downloadAccessibilityLabel = "批量下载排行榜"
    let onPlay: () -> Void
    var onDownload: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                CoverImage(url: coverURL, size: 120, cornerRadius: 12)
                VStack(alignment: .leading, spacing: 8) {
                    Text(beansChartName(title))
                        .font(BeansFont.appFont(18, .bold))
                        .foregroundStyle(Color.beansLabel)
                        .lineLimit(3)
                    ChartPlatformBadge(
                        provider: provider,
                        creatorName: creatorName,
                        creatorAvatarURL: creatorAvatarURL
                    )
                    Text(beansChartStatsText(trackCount: trackCount, playCount: playCount))
                        .font(BeansFont.appFont(13, .medium))
                        .foregroundStyle(Color.beansComment)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }

            if let chartDescription,
               !chartDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(beansCleanChartDescription(chartDescription))
                    .font(BeansFont.appFont(14))
                    .foregroundStyle(Color.beansComment)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if filteredCount > 0 {
                Button(action: onPlay) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("播放全部（\(filteredCount)）")
                    }
                    .font(BeansFont.appFont(13, .semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [Color.beansAmber, Color.beansAmber.opacity(0.78)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: Color.beansAmber.opacity(0.26), radius: 6, y: 2)
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.97))

                if downloadEnabled, filteredCount > 1 {
                    HStack {
                        Spacer()
                        Button(action: onDownload) {
                            Label("批量下载", systemImage: "arrow.down.to.line.compact")
                                .font(BeansFont.appFont(12, .semibold))
                                .foregroundStyle(Color.beansAmber)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(downloadAccessibilityLabel)
                        .help("批量下载")
                    }
                }
            }
        }
        .padding(.horizontal, beansDetailContentInset)
        .padding(.bottom, 14)
    }
}

private let beansDetailContentInset: CGFloat = 22

private func beansChartStatsText(trackCount: Int, playCount: Int?) -> String {
    var parts = [beansLocalized("\(trackCount) 首", "\(trackCount) songs")]
    if let playCount, playCount > 0 {
        parts.append(beansLocalized("\(beansCompactChartNumber(playCount)) 次播放", "\(beansCompactChartNumber(playCount)) plays"))
    }
    return parts.joined(separator: " · ")
}

private func beansCompactChartNumber(_ value: Int) -> String {
    let number = Double(max(0, value))
    let divisor: Double
    let suffix: String
    switch number {
    case 1_000_000_000...:
        divisor = 1_000_000_000
        suffix = "B"
    case 1_000_000...:
        divisor = 1_000_000
        suffix = "M"
    case 1_000...:
        divisor = 1_000
        suffix = "K"
    default:
        return String(value)
    }
    let text = String(format: "%.1f", number / divisor)
    return "\(text.hasSuffix(".0") ? String(text.dropLast(2)) : text)\(suffix)"
}

private func beansCleanChartDescription(_ value: String) -> String {
    value
        .replacingOccurrences(of: "<br>", with: " ", options: .caseInsensitive)
        .replacingOccurrences(of: "<br/>", with: " ", options: .caseInsensitive)
        .replacingOccurrences(of: "<br />", with: " ", options: .caseInsensitive)
        .replacingOccurrences(of: "\\n", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - 酷狗排行榜详情

struct KugouTopListDetailView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss

    let topList: KugouTopInfo
    @State private var tracks: [Song] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    init(topList: KugouTopInfo) {
        self.topList = topList
        let cached = DetailSongsCache.shared.cachedSongs(for: "kugou-top-\(topList.id)")
        _tracks = State(initialValue: cached?.songs ?? [])
        _loading = State(initialValue: cached?.songs.isEmpty ?? true)
    }

    var body: some View {
        let _ = theme.accent
        ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                Group {
                if loading {
                    BeansDetailSongsLoadingState(coverSize: 88, rowCount: 10, showsRank: false)
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await load() }
                    }
                } else if tracks.isEmpty {
                    EmptyStateView(icon: "music.note.list", text: beansLocalized("该排行榜暂无歌曲", "This chart has no songs yet"))
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            header
                            ForEach(Array(filteredTracks.enumerated()), id: \.element.identityKey) { index, song in
                                SongCell(
                                    song: song,
                                    showCover: true,
                                    suppressNativeCleanRowGlass: true,
                                    coverSize: 46,
                                    fixedRowHeight: 64,
                                    playbackContext: filteredTracks,
                                    playbackIndex: index
                                ) {
                                    player.play(songs: filteredTracks, startAt: index)
                                }
                                .padding(.horizontal, beansDetailContentInset)
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 118)
                    }
                    .beansScrollIndicatorsHidden()
                }
            }
            }
            .navigationTitle(beansChartName(topList.name))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: beansLocalized("搜索榜单歌曲", "Search chart songs"))
            .beansDetailProfileToolbar()
        .task { await load() }
    }

    private var header: some View {
        ChartDetailHeader(
            title: topList.name,
            provider: .kugou,
            coverURL: topList.coverURL,
            trackCount: topList.trackCount ?? tracks.count,
            playCount: topList.playCount,
            chartDescription: topList.chartDescription,
            filteredCount: filteredTracks.count,
            onPlay: {
                BeansHaptics.tap()
                player.play(songs: filteredTracks, startAt: 0)
            },
        )
    }

    private var filteredTracks: [Song] {
        let kw = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !kw.isEmpty else { return tracks }
        return tracks.filter { song in
            song.name.lowercased().contains(kw)
                || song.artists.lowercased().contains(kw)
                || song.album.lowercased().contains(kw)
        }
    }

    @MainActor
    private func load() async {
        let cache = DetailSongsCache.shared
        let cacheKey = "kugou-top-\(topList.id)"
        if let cached = cache.cachedSongs(for: cacheKey) {
            tracks = cached.songs
            loading = false
            errorMessage = nil
            if cache.isFresh(cached), !BeansNetworkStatus.shared.isReachable {
                return
            }
        } else {
            loading = true
            errorMessage = nil
        }
        do {
            let songs = try await KugouMusicAPI.shared.rankSongs(rankID: topList.id)
            if !songs.isEmpty {
                tracks = songs
                cache.save(songs, for: cacheKey)
            }
            loading = false
        } catch {
            if tracks.isEmpty {
                errorMessage = error.localizedDescription
            } else {
                BeansLogger.shared.log(
                    "酷狗排行榜详情后台刷新失败，继续使用缓存 id=\(topList.id) error=\(error.localizedDescription)",
                    level: .warn
                )
            }
            loading = false
        }
    }
}

private struct HomeUnifiedSearchSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss

    @State private var keyword = ""
    @State private var results: [Song] = []
    @State private var searching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var debounceTask: Task<Void, Never>?
    @State private var searchController = SearchFieldController()

    private var providers: [SearchProvider] {
        [.kugou]
    }

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
            VStack(spacing: 12) {
                searchField
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onChange(of: keyword) { newValue in
            debounceTask?.cancel()
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                results = []
                errorMessage = nil
                return
            }
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 420_000_000)
                guard !Task.isCancelled else { return }
                await startSearch(trimmed)
            }
        }
        .onDisappear {
            debounceTask?.cancel()
            searchTask?.cancel()
        }
    }

    @ViewBuilder
    private var searchField: some View {
        if #available(iOS 26, *) {
            NativeSearchBar(
                text: $keyword,
                controller: searchController,
                placeholder: beansLocalized("搜索酷狗歌曲", "Search Kugou songs"),
                onSubmit: { text in
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    debounceTask?.cancel()
                    Task { await startSearch(trimmed) }
                }
            )
            .frame(height: 46)
        } else {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.beansComment)
                SearchTextField(
                    text: $keyword,
                    controller: searchController,
                    placeholder: beansLocalized("搜索酷狗歌曲", "Search Kugou songs"),
                    textColor: UIColor.beansLabel,
                    onSubmit: { text in
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        debounceTask?.cancel()
                        Task { await startSearch(trimmed) }
                    }
                )
                .frame(height: 34)
                .frame(maxWidth: .infinity)
                ZStack {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.beansAmber)
                        .opacity(searching ? 1 : 0)
                }
                .frame(width: 20, height: 22)
                .animation(nil, value: searching)
                ZStack {
                    Button {
                        keyword = ""
                        results = []
                        errorMessage = nil
                        debounceTask?.cancel()
                        searchTask?.cancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.beansComment.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .opacity(keyword.isEmpty ? 0 : 1)
                    .disabled(keyword.isEmpty)
                }
                .frame(width: 20, height: 22)
                Button {
                    let text = searchController.commit()
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    debounceTask?.cancel()
                    Task { await startSearch(trimmed) }
                } label: {
                    Text("搜索")
                        .font(BeansFont.appFont(13, .semibold))
                        .foregroundStyle(Color.beansAmber)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background { BeansGlass(shape: Capsule()) }
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.9))
                .frame(width: 54, height: 30)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background {
                BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .beansCardShadow(radius: 8, y: 3)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var content: some View {
        if keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyStateView(icon: "magnifyingglass", text: "输入歌名后搜索酷狗音乐")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, results.isEmpty {
            ErrorStateView(message: errorMessage) {
                Task { await startSearch(keyword) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if searching && results.isEmpty {
            unifiedSearchLoadingState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if results.isEmpty {
            EmptyStateView(icon: "music.note", text: "暂未找到相关歌曲")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text(beansLocalized("找到 \(results.count) 首", "Found \(results.count) songs"))
                            .font(BeansFont.appFont(12))
                            .foregroundStyle(Color.beansComment)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .truncationMode(.tail)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)
                        Button {
                            BeansHaptics.tap()
                            player.play(songs: results, startAt: 0)
                        } label: {
                            Label("播放全部", systemImage: "play.fill")
                                .font(BeansFont.appFont(12, .semibold))
                                .foregroundStyle(Color.beansAmber)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background { BeansGlass(shape: Capsule()) }
                        }
                        .buttonStyle(.plain)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)

                    ForEach(Array(results.enumerated()), id: \.element.identityKey) { index, song in
                        SongCell(song: song) {
                            BeansHaptics.tap()
                            player.play(songs: results, startAt: index)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            BeansGlass(shape: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
            .beansScrollIndicatorsHidden()
            .beansScrollDismissesKeyboard()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var unifiedSearchLoadingState: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                HStack(spacing: 8) {
                    BeansShimmerSkeleton(cornerRadius: 5)
                        .frame(width: 168, height: 12)
                    Spacer(minLength: 0)
                    BeansShimmerSkeleton(cornerRadius: 16)
                        .frame(width: 78, height: 30)
                }
                .padding(.vertical, 8)

                ForEach(0..<9, id: \.self) { index in
                    HStack(spacing: 12) {
                        BeansShimmerSkeleton(cornerRadius: 8)
                            .frame(width: 46, height: 46)
                        VStack(alignment: .leading, spacing: 8) {
                            BeansShimmerSkeleton(cornerRadius: 5)
                                .frame(height: 13)
                                .frame(maxWidth: index.isMultiple(of: 3) ? 220 : 160, alignment: .leading)
                            BeansShimmerSkeleton(cornerRadius: 5)
                                .frame(width: index.isMultiple(of: 2) ? 140 : 96, height: 10)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background {
                        BeansGlass(shape: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
        .beansScrollIndicatorsHidden()
        .beansScrollDismissesKeyboard()
    }

    @MainActor
    private func startSearch(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searchTask?.cancel()
        searchTask = Task {
            searching = true
            errorMessage = nil
            BeansLogger.shared.log("主页酷狗搜索：\(trimmed)", level: .info)
            defer { if !Task.isCancelled { searching = false } }

            let kugou: [Song] = await searchSongs(on: .kugou, keyword: trimmed, enabledProviders: providers)
            guard !Task.isCancelled else { return }
            results = deduplicated(kugou)
            if results.isEmpty {
                errorMessage = "酷狗没有返回可展示的歌曲"
            } else {
                BeansHaptics.success()
            }
            BeansLogger.shared.log("主页酷狗搜索完成：\(trimmed) 结果=\(results.count)", level: .info)
        }
        await searchTask?.value
    }

    private func searchSongs(on provider: SearchProvider, keyword: String, enabledProviders: [SearchProvider]) async -> [Song] {
        guard enabledProviders.contains(provider), provider == .kugou else { return [] }
        return (try? await KugouMusicAPI.shared.searchSongs(keyword: keyword, limit: 30)) ?? []
    }

    private func deduplicated(_ songs: [Song]) -> [Song] {
        var seen = Set<String>()
        var output: [Song] = []
        for song in songs {
            let key = "\(song.source.rawValue)-\(song.name.lowercased())-\(song.artists.lowercased())"
            if seen.insert(key).inserted {
                output.append(song)
            }
        }
        return output
    }
}

