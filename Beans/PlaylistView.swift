import SwiftUI

/// 统一歌单详情的数据源适配层：用户歌单、每日推荐、排行榜都走同一个 View 渲染，
/// 只换加载方式与头部数据，不再为每种歌单各做一个页面。
private enum CoPlaylistLoadMode {
    case userPlaylist(Playlist)
    case daily(initialSongs: [Song], onRefreshed: (([Song]) -> Void)?)
    case topList(KugouTopInfo)
}

private struct CoPlaylistHeaderData {
    let title: String
    let sourceName: String
    let coverURL: URL?
    let description: String?
    let creatorAvatarURL: URL?
    let playCount: Int
}

/// 统一歌单详情页：我的页、歌单弹窗、主页每日推荐、榜单、搜索结果、歌单库、侧栏
/// 点进来的都是这一个 View、同一套头部、同一套控制、同一套歌曲行、同一套播放队列。
/// 截图式布局（唯一布局，不再分叉）：封面全幅铺满、居中歌单名、来源、首数、
/// 随机 / 播放 / 下载一排、简介、搜索歌曲 + 收藏星、歌曲行。
/// 用户歌单、每日推荐、榜单一律同用这一套逻辑，不再受沉浸详情界面开关影响；
/// 该开关仍保留给歌手页、本地音乐区、搜索专辑页等其他详情页用。
struct PlaylistView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var theme: ThemeStore
    @ObservedObject private var favorites = FavoritesStore.shared

    private let loadMode: CoPlaylistLoadMode
    @State private var tracks: [Song] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var showDownloadUnsupported = false
    @State private var showCollectUnsupported = false
    // 虚化过渡层用的同一张封面图（只读缓存，不另起下载；没拿到时为 nil，
    // 过渡区直接显示深色底兜底，拿到后再换虚化层，不叠加取色实色底）。
    @State private var coverBlurImage: UIImage? = nil
    @State private var coverBlurRetried = false
    // 歌单页下拉放大（与我的页同套放慢后的参数，见 fixedPlaylistCover）：
    // 下拉量封顶 120pt、放大系数 1 + 下拉量/600（封顶约 1.2 倍）、
    // 框高只跟下拉量的一半走（封顶 +60pt），松手用慢速无弹跳弹簧回 0。
    @State private var coverPull: CGFloat = 0
    @State private var coverPullActive = false
    @State private var coverPullStartedAtTop = false
    @State private var playlistScrollOffset: CGFloat = 0
    // 顶部虚化背景层跟走只用滚动几何这一路读数（首帧定基线，之后不再重定）；
    // 下拉时钳为 0。上一轮固定封面层用的“头部 frame 与滚动几何两路取大值”
    // 正是封面被单独顶上去的根因：两路读数更新时机不同、max 又取大的那一路，
    // 封面位移就比滚动内容多出一截，和歌名、控制排、列表分了层；本轮封面
    // 回到滚动内容里、位移只剩滚动视图本身这一路，不可能再分层。
    @State private var playlistScrollRestOffset: CGFloat? = nil
    private var playlistContentScrollUp: CGFloat {
        guard let rest = playlistScrollRestOffset else { return 0 }
        return max(0, playlistScrollOffset - rest)
    }
    @AppStorage("beans.showSongVIPBadge") private var showSongVIPBadge = true

    init(playlist: Playlist) {
        self.loadMode = .userPlaylist(playlist)
        let cached = Self.initialCachedSongs(for: playlist)
        _tracks = State(initialValue: cached?.songs ?? [])
        _loading = State(initialValue: cached?.songs.isEmpty ?? true)
    }

    init(dailySongs: [Song], onRefreshed: (([Song]) -> Void)? = nil) {
        self.loadMode = .daily(initialSongs: dailySongs, onRefreshed: onRefreshed)
        _tracks = State(initialValue: dailySongs)
        _loading = State(initialValue: dailySongs.isEmpty)
    }

    init(topList: KugouTopInfo) {
        self.loadMode = .topList(topList)
        let cached = DetailSongsCache.shared.cachedSongs(for: "kugou-top-\(topList.id)")
        _tracks = State(initialValue: cached?.songs ?? [])
        _loading = State(initialValue: cached?.songs.isEmpty ?? true)
    }

    private static func initialCachedSongs(for playlist: Playlist) -> SyncedPlaylistCache.SongEntry? {
        let accountID: String = playlist.source == .kugou ? KugouMusicAuth.shared.userId : ""
        return SyncedPlaylistCache.shared.cachedSongs(playlist: playlist, accountID: accountID)
    }

    private var userPlaylist: Playlist? {
        if case .userPlaylist(let playlist) = loadMode { return playlist }
        return nil
    }

    private var cacheAccountID: String {
        guard let playlist = userPlaylist else { return "" }
        return playlist.source == .kugou ? KugouMusicAuth.shared.userId : ""
    }

    /// 深色底（截图里的深褐底），不跟随系统深浅；虚化层没拿到封面图时用它兜底。
    private let darkBackground = Color(red: 0.14, green: 0.10, blue: 0.08)

    /// 封面下面到列表的虚化过渡层：用的就是同一张封面图（滚动内容里那张），
    /// 系统 blur（半径 28，不搞自定义模糊引擎），透明度靠上面压的深色罩控制；
    /// 只贴在标题区顶部往下 520pt 的带子里，越往下越淡，最后融入深色底，
    /// 没有任何线条、没有硬边。没拿到图时这一层什么都不画，直接是深色底兜底，
    /// 不叠加取色实色底。虚化层只影响过渡区，不动封面本身的铺满、缩放、回弹。
    /// 封面下面到列表的虚化过渡层（本轮重构，只剩这一层虚化，不再两层叠加）：
    /// 根部 ZStack 里、滚动视图下面的一层虚化底，用的就是同一张封面图
    /// （coverBlurImage，缓存里读，不另起下载），系统 blur 半径 28。
    /// 关键是交界处不能断档：这一层的深色罩是从 0 开始往下加深的，
    /// 在封面底边往上 120pt 处还是 0，到封面底边处只有黑 0.25，
    /// 再往下才慢慢加深到深色底，交界处没有任何一层是从实色或高不透明度起步的。
    /// 这一层跟固定封面层用同一个上滑读数（playlistContentScrollUp）一起往上移，
    /// 相对位置不变；下拉时移量钳为 0、顶边不动，滚动内容往下带时露出的
    /// 空隙里也是这一层虚化图，不是深色带。封面没拿到图时这一层什么都不画，
    /// 下面就是深色底兜底，同样没有硬边。
    private var blurredCoverUnderlayer: some View {
        Group {
            if let image = coverBlurImage {
                let width = UIScreen.main.bounds.width
                let total = width + 520
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: total)
                    .blur(radius: 28)
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .clear, location: max(0, (width - 120) / total)),
                                .init(color: .black.opacity(0.25), location: width / total),
                                .init(color: .black.opacity(0.7), location: 0.85),
                                .init(color: darkBackground, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipped()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
                    .offset(y: -playlistContentScrollUp)
                    .allowsHitTesting(false)
            }
        }
    }

    /// 固定封面层（我的页 coFixedHeaderWallpaper 同款架构，滚动视图之外）：
    /// 顶边固定在屏幕顶边 0，下拉时只缩放、不下移（offset 只用上滑量，
    /// 下拉时上滑量钳为 0）；上滑时按上滑量整体往上移，移量和滚动内容位移
    /// 是同一路读数（滚动几何内容偏移 - 首帧基线），不是两路取大值，
    /// 所以不可能像上一轮固定层那样多出一截、单独顶上去。
    /// 封面底部不是渐变到实色 darkBackground，而是用 mask 在最后 120pt
    /// 内渐变到透明，露出下面同一张封面图的虚化层（blurredCoverUnderlayer，
    /// 在这段里深色罩还是 0 到 0.25），封面图先虚化、再越往下越淡，
    /// 最后自然融入深色底，封面底边没有一条线、没有一个硬边。
    /// 下拉放大参数与我的页同套放慢后的参数：下拉量硬上限 120pt、
    /// 放大系数 1 + coverPull/600（封顶约 1.2 倍）、框高只跟下拉量的一半走
    /// （基线宽 + coverPull/2，封顶 +60pt），松手 response 0.9 / damping 1.0。
    /// 图按顶部锚点缩放：上面不动、只向左右两边与下方放大，不出现第二张封面；
    /// 框整体 .clipped() 裁到框里。本层不响应触摸。
    private var fixedPlaylistCover: some View {
        let width = UIScreen.main.bounds.width
        let height = width + coverPull / 2
        let zoom = 1 + coverPull / 600
        let fadeStart = max(0, (height - 120) / height)
        return ZStack(alignment: .top) {
            CoverImage(url: headerData.coverURL, size: width, cornerRadius: 0)
                .scaleEffect(zoom, anchor: .top)
        }
        .frame(width: width, height: height)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: fadeStart),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .offset(y: -playlistContentScrollUp)
        .allowsHitTesting(false)
    }

    /// 滚动内容里的封面占位区：高度就是固定封面的基线高（屏宽正方形），
    /// 静止时歌名紧贴封面底边（标题区顶部内边距 0），歌名、控制排、
    /// 歌曲行的位置和封面在滚动内容里时完全一致；下拉时占位区高度不动，
    /// 固定封面框高增长被虚化层盖住，歌名不再被框高增长往下推。
    private var playlistCoverSpacer: some View {
        Color.clear
            .frame(height: UIScreen.main.bounds.width)
    }

    /// 虚化层用图刷新：图只从 BeansCoverImageStore 已有的缓存里读（内存优先，
    /// 再走磁盘 / URLCache 复水），不另起下载；网络图还没回来时 1.5 秒后只重试一次。
    private func refreshCoverBlurImage() {
        let url = CustomSongCoverStore.shared.resolvedURL(for: headerData.coverURL) ?? headerData.coverURL
        guard let url else { coverBlurImage = nil; return }
        if let image = BeansCoverImageStore.memoryImage(for: url) {
            coverBlurImage = image
            return
        }
        BeansCoverImageStore.loadCachedImage(for: url) { image in
            if let image {
                coverBlurImage = image
            } else if !coverBlurRetried {
                coverBlurRetried = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { refreshCoverBlurImage() }
            }
        }
    }

    private var headerData: CoPlaylistHeaderData {
        switch loadMode {
        case .userPlaylist(let playlist):
            let description = playlist.playlistDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            return CoPlaylistHeaderData(
                title: playlist.name,
                sourceName: playlist.creatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "酷狗音乐" : playlist.creatorName,
                coverURL: playlist.coverURL,
                description: description.isEmpty ? nil : description,
                creatorAvatarURL: playlist.creatorAvatarURL,
                playCount: playlist.playCount
            )
        case .daily:
            // 每日推荐专属文案：只对每日推荐用，用户歌单与榜单没有简介时不编。
            return CoPlaylistHeaderData(
                title: "今日推荐",
                sourceName: "酷狗音乐",
                coverURL: tracks.first?.coverURL,
                description: beansLocalized(
                    "为你整理的每日推荐歌曲，随时发现新的喜欢。",
                    "Daily recommendations picked to help you discover your next favorite songs."
                ),
                creatorAvatarURL: nil,
                playCount: 0
            )
        case .topList(let info):
            let description = (info.chartDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return CoPlaylistHeaderData(
                title: beansChartName(info.name),
                sourceName: "酷狗音乐",
                coverURL: info.coverURL,
                description: description.isEmpty ? nil : description,
                creatorAvatarURL: nil,
                playCount: info.playCount ?? 0
            )
        }
    }

    var body: some View {
        unifiedBody
    }

    // MARK: - 统一布局（用户歌单、每日推荐、榜单同用，不再受沉浸开关影响）

    private var unifiedBody: some View {
        let _ = theme.accent
        return ZStack {
            darkBackground.ignoresSafeArea()
            if loading && tracks.isEmpty {
                BeansDetailSongsLoadingState(coverSize: 96, rowCount: 10)
            } else if let errorMessage, tracks.isEmpty {
                ErrorStateView(message: errorMessage) {
                    Task { await load(force: true) }
                }
            } else {
                // 滚动整体架构（本轮改动，封面改回我的页同款固定层、顶边钉在 0）：
                // 深色底 → 虚化底（blurredCoverUnderlayer）→ 固定封面层
                // （fixedPlaylistCover）→ ScrollView（从歌名开始，顶部是透明占位）。
                // 上滑移量只用滚动几何这一路读数（内容偏移 - 首帧基线，钳为 >=0），
                // 固定封面层和虚化底都用这一路一起往上移，移量等于滚动内容位移，
                // 不会多、不会少，所以不会再像上一轮两路取大值那样单独顶上去。
                // 下拉时上滑量钳为 0，固定封面层只缩放、不下移，顶边钉在 0；
                // 滚动内容往下带时，固定封面底边与歌名之间的空隙里露出的就是
                // 同一张封面图的虚化底，不是深色带。下拉放大参数不变（封顶 120pt、
                // 系数 pull/600、框高半速、回弹 response 0.9 / damping 1.0）。
                // 封面底边没有横线：固定封面用 mask 在最后 120pt 渐变到透明，
                // 下面虚化底的深色罩在这段里还是 0 到 0.25，封面图先虚化、
                // 再越往下越淡、最后自然融入深色底。
                ZStack {
                    blurredCoverUnderlayer
                    fixedPlaylistCover
                    ScrollView {
                        VStack(spacing: 0) {
                            playlistCoverSpacer
                            VStack(spacing: 0) {
                                unifiedTitleBlock
                        unifiedControls
                        if let description = headerData.description, !description.isEmpty {
                            Text(description)
                                .font(BeansFont.appFont(15))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 22)
                                // 简介→搜索行间距：参考图约 32pt，之前是简介下 20pt +
                                // 搜索行上下 18pt ≈ 42pt，简介下边距收到 12pt 后约 32pt。
                                .padding(.bottom, 12)
                        }
                        unifiedSearchRow
                        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("在已加载的 \(orderedTracks.count) 首中，筛出 \(displayedTracks.count) 首")
                                .font(BeansFont.appFont(12))
                                .foregroundStyle(.white.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 22)
                                .padding(.bottom, 8)
                        }
                        ForEach(Array(displayedTracks.enumerated()), id: \.element.identityKey) { _, song in
                            Button {
                                BeansHaptics.tap()
                                player.play(songs: orderedTracks, startAt: playbackIndex(for: song))
                            } label: {
                                unifiedSongRow(song)
                            }
                            .buttonStyle(.plain)
                        }
                            }
                            // 标题区以下不铺实色底、不画任何线：标题区本身透明，
                            // 根部虚化底（见 blurredCoverUnderlayer）透在歌名、
                            // 控制排后面、越往下越淡、最后融入深色底；标题区本身
                            // 不加不透明底，否则会把虚化底全盖住。
                    }
                    .padding(.bottom, 180)
                }
                .beansScrollIndicatorsHidden()
                // 内容不满屏时也能回弹下拉（与我的页 .always 同款），短歌单也能拉动放大。
                .scrollBounceBehavior(.always, axes: .vertical)
                // 封面铺到顶边：滚动视图忽略顶部安全区，内容从屏幕顶边 0 开始，
                // 而不是被导航栏 + 状态栏顶到约 134pt 才开始；导航栏背景已隐藏、
                // 配色为深色，系统返回键仍在导航栏位置、压在封面图上、照常可点。
                .ignoresSafeArea(edges: .top)
                // 滚动几何读数（不是 PreferenceKey 回写链）：静止在顶部时偏移约 0，
                // 已下滑时为正；首帧 0 同样算在顶部。基线在首帧定一次，之后不再重定，
                // 避免从别页返回（滚动停在半途）时把半途误当成静止值。这一路读数只
                // 供两处用：下拉放大门控（页面在顶部才放大），以及固定封面层与虚化底
                // 的上滑跟走（上滑量 = 偏移 − 基线，钳为 >=0）。
                .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { _, newValue in
                    if playlistScrollRestOffset == nil { playlistScrollRestOffset = newValue }
                    playlistScrollOffset = newValue
                }
                // 下拉放大：复用我的页验证过的路子——挂在整个滚动视图上的
                // simultaneousGesture 直接驱动，不走 PreferenceKey 回写链；
                // 门控只在手势开始时定一次（页面在顶部才放大），拖动最小距离 8pt，
                // 点按（点歌曲行、点播放、点返回）不到 8pt 不触发，不会被截获。
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            if !coverPullActive {
                                coverPullActive = true
                                coverPullStartedAtTop = playlistScrollOffset <= 20
                            }
                            guard coverPullStartedAtTop else {
                                coverPull = 0
                                return
                            }
                            // 下拉量硬上限 120pt，上滑、横向拖动时高度差为负，钳为 0 不放大。
                            coverPull = min(max(0, value.translation.height), 120)
                        }
                        .onEnded { _ in
                            coverPullActive = false
                            coverPullStartedAtTop = false
                            // 松手慢速平滑回 0：response 0.9、damping 1.0，无弹跳感，
                            // 不是原来我的页那种 response 0.35 的快弹簧。
                            withAnimation(.spring(response: 0.9, dampingFraction: 1.0)) {
                                coverPull = 0
                            }
                        }
                )
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        // 与上一行同义的显式可见性：防止导航栏仍以不透明底盖住封面顶边；
        // 返回键仍在导航栏位置、压在封面图上、照常可点。
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
        // 虚化层用图触发：封面 URL 一换就重取（每日封面是首歌封面，歌曲载入后
        // URL 会变，正好重取）；先清掉上一张封面的图、再取新的，不串图。
        .task(id: headerData.coverURL) {
            coverBlurImage = nil
            coverBlurRetried = false
            refreshCoverBlurImage()
        }
        .alert("暂不支持下载", isPresented: $showDownloadUnsupported) {
            Button("好", role: .cancel) {}
        } message: {
            Text("歌单下载功能尚未上线，当前版本只支持在线播放。")
        }
        .alert("暂不支持收藏歌单", isPresented: $showCollectUnsupported) {
            Button("好", role: .cancel) {}
        } message: {
            Text("酷狗收藏歌单接口尚未接入，点了也不会真的收藏，就不做假的收藏状态了。")
        }
    }

    /// 顶部虚化背景层（本轮新增，解决“固定层撤掉后下拉顶部露深色带”）：
    /// 放在根部 ZStack 里、滚动视图下面，不跟滚动内容走。用的就是同一张封面图
    /// （coverBlurImage，缓存里读，不另起下载），系统 blur 半径 28，上面压一层
    /// 深色罩（黑 0.6 → 深色底），静止时它被滚动内容里不透明的实封面全盖住、
    /// 看不见；下拉时实封面跟着内容往下走，顶部空隙里露出的就是这层虚化图，
    /// 不是深色带；上滑时它按滚动几何的上滑量同步往上移（钳在 0 到封面基线高
    /// 之间），封面滑出视野时它也一起出去，不会钉在顶部盖住歌曲行。
    /// 封面没加载出来时这一层什么都不画，顶部空隙就是深色底兜底，不叠加取色底。
    /// 本层不响应触摸，点歌曲行、点播放、点返回不受影响。
    private var unifiedTitleBlock: some View {
        // 对照参考图量的排布：歌名紧贴封面底边（顶部内边距 0，之前是 8），
        // 歌名→来源、来源→首数两档间距从 10pt 收到 4pt（参考图约 6pt，
        // 余下 2-3pt 是字体行高本身的空隙）；歌名字号 30pt → 28pt
        //（参考图歌名行高约 31pt，对应约 26-28pt 字号，取 28pt 贴近而不冒进）。
        VStack(spacing: 4) {
            Text(headerData.title)
                .font(BeansFont.appFont(28, .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 24)
            Text(headerData.sourceName)
                .font(BeansFont.appFont(16, .medium))
                .foregroundStyle(.white.opacity(0.85))
            // 首数读已加载的真实歌曲数，不读歌单宣称的首数、不编数字。
            Text(beansSongCountText(tracks.count))
                .font(BeansFont.appFont(14))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var unifiedControls: some View {
        // 对照参考图量的排布：原来整排左右只各留约 25pt、胶囊 200pt 宽、
        // 圆键 56pt、间距 20pt，整排几乎撑满屏宽；参考图左右各留约 58pt、
        // 胶囊约 168pt、圆键约 48pt、间距约 12pt。按参考图改：圆键 48pt、
        // 胶囊 168×50pt、间距 12pt，整排 288pt、左右各留约 57pt。
        // 上下内边距改成上 28pt、下 20pt（参考图首数→控制排约 30pt、
        // 控制排→简介约 22pt，之前上下都是 24pt）。
        HStack(spacing: 12) {
            // 播放模式切换键（之前是死图标：写死的 shuffle 图，点它只播一次
            // 随机、图标永远不变）。现在图标读 PlayerManager.playMode.icon，
            // 点它调 togglePlayMode()，图标随模式更换；循环顺序是 PlayerManager
            // 现成的 sequential → repeatAll → repeatOne → shuffle → sequential，
            // 对应图标 arrow.right → repeat → repeat.1 → shuffle → arrow.right。
            // shuffle 时按 PlayerView 的 modeButton 做法给高亮（琥珀色图标 +
            // 更亮的圆底），其他模式不高亮。播放胶囊仍是正常播放：playAll() 走
            // player.play()，play() 里 buildPlayOrder() 按当前模式出队列，
            // 所以胶囊播出来的顺序就是左键当前显示的模式，不再留一个只播一次
            // 随机、图标不动的假随机键。
            Button {
                BeansHaptics.select()
                player.togglePlayMode()
            } label: {
                Image(systemName: player.playMode.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(player.playMode == .shuffle ? Color.beansAmber : .white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(player.playMode == .shuffle ? .white.opacity(0.25) : .white.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.playMode.title)
            Button {
                BeansHaptics.tap()
                playAll()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("播放")
                }
                .font(BeansFont.appFont(18, .semibold))
                .foregroundStyle(.black)
                .frame(width: 168, height: 50)
                .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
            // 下载管线不存在（精简时已删下载管理器与批量下载，唯一的 download 是歌词下载），
            // 不做点了没反应的假下载键：保留截图里的下载键位置，点它明说暂不支持。
            Button {
                BeansHaptics.tap()
                showDownloadUnsupported = true
            } label: {
                Image(systemName: "arrow.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    private var unifiedSearchRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))
                TextField(beansLocalized("搜索歌曲", "Search songs"), text: $searchText)
                    .font(BeansFont.appFont(16))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
            // 收藏歌单没有真实接口（酷狗 API 里只有加歌进歌单、建歌单，没有收藏歌单），
            // 不做点了假装收藏的星：星保持空心，点它明说暂不支持。
            Button {
                BeansHaptics.tap()
                showCollectUnsupported = true
            } label: {
                Image(systemName: "star")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    private func unifiedSongRow(_ song: Song) -> some View {
        let isCurrent = player.currentSong?.identityKey == song.identityKey
        return HStack(spacing: 12) {
            CoverImage(url: song.coverURL, song: song, size: 52, cornerRadius: 10)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(song.name)
                        .font(BeansFont.appFont(16))
                        .foregroundStyle(isCurrent ? Color.beansAmber : .white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if showSongVIPBadge, song.isVIP {
                        VIPBadgeView(text: "VIP")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(song.artists.isEmpty ? "未知歌手" : song.artists)
                    .font(BeansFont.appFont(13))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 时长缺了（duration == 0）就不显示时长，不编一个假时长。
            if song.duration > 0 {
                Text(song.formattedDuration)
                    .font(BeansFont.appFont(13, .regular, .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - 统一播放逻辑（队列永远是这份歌单的完整歌曲列表）

    /// 正常播放：整份歌单作队列，从第一首起播；player.play() 里
    /// buildPlayOrder() 按当前播放模式出队列（shuffle 模式就是随机顺序），
    /// 所以胶囊播出来的顺序就是左键当前显示的模式，不用再单写一个随机入口。
    private func playAll() {
        guard !orderedTracks.isEmpty else { return }
        player.play(songs: orderedTracks, startAt: 0)
    }

    /// The full playlist order remains the playback queue even when the list is filtered.
    /// 截图式布局不提供排序入口，队列永远是歌单原顺序。
    private var orderedTracks: [Song] {
        tracks
    }

    /// Search only changes what is visible, not the queue that follows the selected song.
    /// 歌单内本地过滤：只筛当前已加载的列表；本页的加载本来就是整份歌单拉满，
    /// 所以筛的就是整份歌单，不谎称调了歌单内搜索接口。
    private var displayedTracks: [Song] {
        let kw = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !kw.isEmpty else { return orderedTracks }
        return orderedTracks.filter { song in
            song.name.lowercased().contains(kw)
                || song.artists.lowercased().contains(kw)
                || song.album.lowercased().contains(kw)
        }
    }

    private func playbackIndex(for song: Song) -> Int {
        orderedTracks.firstIndex { $0.identityKey == song.identityKey } ?? 0
    }

    private func load(force: Bool = false) async {
        switch loadMode {
        case .userPlaylist(let playlist):
            await loadUserPlaylist(playlist, force: force)
        case .daily(let initialSongs, let onRefreshed):
            await loadDaily(initialSongs: initialSongs, onRefreshed: onRefreshed)
        case .topList(let info):
            await loadTopList(info)
        }
    }

    private func loadUserPlaylist(_ playlist: Playlist, force: Bool) async {
        let cache = SyncedPlaylistCache.shared
        if let cached = cache.cachedSongs(playlist: playlist, accountID: cacheAccountID) {
            tracks = cached.songs
            loading = false
            if !force, playlist.source == .qishui, cache.isFresh(cached) {
                return
            }
            if !force, cache.isFresh(cached), !BeansNetworkStatus.shared.isReachable {
                return
            }
        } else {
            loading = true
        }
        errorMessage = nil
        BeansLogger.shared.log("歌单页面打开 source=\(playlist.source.rawValue) id=\(playlist.id) name=\(playlist.name) advertisedCount=\(playlist.trackCount)", level: .info)
        do {
            if playlist.source == .kugou {
                tracks = try await KugouMusicAPI.shared.playlistSongs(playlist: playlist)
            } else {
                errorMessage = "该歌单来源已在酷狗专版移除"
                loading = false
                return
            }
            if !tracks.isEmpty {
                cache.saveSongs(tracks, playlist: playlist, accountID: cacheAccountID)
            }
            BeansLogger.shared.log("歌单页面加载完成 source=\(playlist.source.rawValue) id=\(playlist.id) name=\(playlist.name) count=\(tracks.count) error=无", level: tracks.isEmpty ? .warn : .info)
            loading = false
        } catch {
            if tracks.isEmpty {
                errorMessage = error.localizedDescription
            } else {
                BeansLogger.shared.log("歌单页面刷新失败，继续使用缓存 source=\(playlist.source.rawValue) id=\(playlist.id) error=\(error.localizedDescription)", level: .warn)
            }
            BeansLogger.shared.log("歌单页面加载失败 source=\(playlist.source.rawValue) id=\(playlist.id) name=\(playlist.name) error=\(error.localizedDescription)", level: .error)
            loading = false
        }
    }

    private func loadDaily(initialSongs: [Song], onRefreshed: (([Song]) -> Void)?) async {
        // 已有快照先显示，再后台刷新；刷新失败时保留快照、不弹空页。
        if tracks.isEmpty, !initialSongs.isEmpty {
            tracks = initialSongs
        }
        if tracks.isEmpty {
            loading = true
        }
        do {
            let refreshed: [Song]
            if let songs = try? await KugouMusicAPI.shared.everydayRecommend(limit: 30), !songs.isEmpty {
                refreshed = songs
            } else {
                refreshed = try await KugouMusicAPI.shared.searchSongs(keyword: "热门歌曲", limit: 30)
            }
            guard !refreshed.isEmpty else { throw BeansDailyRecommendError.empty }
            tracks = refreshed
            onRefreshed?(refreshed)
            errorMessage = nil
            loading = false
        } catch {
            if tracks.isEmpty {
                errorMessage = error.localizedDescription
            }
            loading = false
        }
    }

    private func loadTopList(_ info: KugouTopInfo) async {
        let cache = DetailSongsCache.shared
        let cacheKey = "kugou-top-\(info.id)"
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
            let songs = try await KugouMusicAPI.shared.rankSongs(rankID: info.id)
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
                    "酷狗排行榜详情后台刷新失败，继续使用缓存 id=\(info.id) error=\(error.localizedDescription)",
                    level: .warn
                )
            }
            loading = false
        }
    }
}

private enum BeansDailyRecommendError: LocalizedError {
    case empty

    var errorDescription: String? {
        "当前账号没有返回新的每日推荐内容"
    }
}
