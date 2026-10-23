import SwiftUI

/// 歌单内排序方式
enum PlaylistSortMode: String, CaseIterable, Identifiable {
    case original = "默认"
    case name = "歌名"
    case duration = "时长"
    var id: String { rawValue }
}

struct PlaylistView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var theme: ThemeStore
    @ObservedObject private var favorites = FavoritesStore.shared

    let playlist: Playlist
    /// 1.9.3：路径导航的返回闭包。返回 true 表示已由调用方弹栈，
    /// 返回 false/未传入时回落到 dismiss()（普通 NavigationLink 栈）。
    /// 必须存在的原因：Discover/音乐库走 NavigationStack(path:)，
    /// 该栈里 @Environment dismiss 对路径推送的目的地是无效的
    /// （点按注册了但不弹栈），12:04 截图的每日推荐页就是这条路。
    var onBack: (() -> Bool)? = nil
    @Environment(\.dismiss) private var dismiss
    private func goBack() {
        if onBack?() == true { return }
        dismiss()
    }
    @State private var tracks: [Song] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var sortMode: PlaylistSortMode = .original
    @State private var showShare = false
    @State private var isStarred = false
    @AppStorage("beans.homeHeaderHideSort") private var hideSortButton = false

    // 1.8.9 审计：旧 uiStyleRaw/isNativeClean 在 1.8.8 深色页后已 0 引用，删；
    // 缓存账号三分支返回值全相同，合并为一句（歌单只走酷狗，来源分支已无意义）。
    private var cacheAccountID: String {
        KugouMusicAuth.shared.userId
    }

    // 1.8.8：按用户发的截图布局改回全幅封面沉浸头（1.8.7 的小封面头是改错方向）：
    // 封面铺满顶部、向下渐变到深色底；居中大标题多行、创建者居中、歌曲数居中；
    // 分享圆钮 / 播放白 pill / 随机圆钮一行；搜索 + 收藏星 + ··· 菜单一行；
    // 歌曲行封面 + 歌名 + 歌手 + 时长、深色底、底部留 118pt 不被迷你播放器遮住。
    // 深色页强制深色配色，SongCell 的动态文字色（beansLabel/beansComment）随之变白/灰、可读。
    private var pageBackground: Color { Color(red: 0.08, green: 0.08, blue: 0.09) }
    private var shareText: String {
        "歌单：\(playlist.name)" + (playlist.creatorName.isEmpty ? "" : " · \(playlist.creatorName)") + "（\(tracks.count) 首）"
    }

    var body: some View {
        // 1.9.1：与每日推荐页同病同治——外层取顶安全区，ScrollView 忽略顶安全区，
        // 封面 440 + 顶安全区从屏幕顶边开始画，返回钮在状态栏下方；窗口强制深色让状态栏变浅色。
        GeometryReader { outer in
            ZStack {
                pageBackground.ignoresSafeArea()
                Group {
                    if loading {
                        LoadingStateView()
                    } else if let errorMessage {
                        ErrorStateView(message: errorMessage) {
                            Task { await load(force: true) }
                        }
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                immersiveHeader(topInset: outer.safeAreaInsets.top)
                                songList
                            }
                            .padding(.bottom, 118)
                        }
                        .beansScrollIndicatorsHidden()
                        .ignoresSafeArea(edges: .top)
                    }
                }
            }
            // 1.9.2：返回键悬空固定——从滚动内容里拿出来，盖在整页上方（ZStack 层，
            // 不随 ScrollView 滚动，加载/报错态也一直在）。
            // 1.9.3：位置改用窗口真实顶安全区（CoTopInset），不再用导航栈里
            // 会双重计数的 GeometryReader safeAreaInsets.top；顶距 = 窗口顶安全区+6，
            // 紧贴状态栏下方；点按走 goBack()（路径栈由调用方弹栈，普通栈回落 dismiss），
            // 覆盖层在最上层（zIndex），不被滚动视图挡住。
            .overlay(alignment: .topLeading) {
                CoFloatingBackButton(onTap: goBack)
                    .padding(.leading, 16)
                    .padding(.top, CoTopInset.effective(geometryTop: outer.safeAreaInsets.top) + 6)
            }
            .zIndex(10)
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .coForceDarkPage()
        .task { await load() }
        .onAppear { isStarred = CoStarredPlaylists.isStarred(id: playlist.id) }
        .sheet(isPresented: $showShare) { ShareSheet(items: [shareText]) }
    }

    private func immersiveHeader(topInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            // 1.8.9 更沉浸：封面由 400pt 加高到 440pt、顶部压暗更足（状态栏区与封面连成一片深色）、
            // 底部五段渐变（暗→淡→透明→底色）让标题区与封面的衔接不割裂；结构仍是 1.8.8 截图布局，不改回小封面头。
            // 1.9.1：封面再加顶安全区，从屏幕顶边开始画，返回钮顶距 = 顶安全区 + 6。
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    AsyncImage(url: playlist.coverURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            Color(red: 0.15, green: 0.15, blue: 0.16)
                        }
                    }
                    .frame(width: geo.size.width, height: 440 + topInset)
                    .clipped()
                    LinearGradient(
                        colors: [.black.opacity(0.5), .black.opacity(0.18), .clear, pageBackground.opacity(0.0), pageBackground],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(width: geo.size.width, height: 440 + topInset)
                    // 1.9.3：顶部渐变模糊——在封面最上层加一段模糊带（安全区+约 120pt，
                    // 超薄材质采样背后封面 + 渐变遮罩向底部淡出到底部透明 + 顶部压暗），
                    // 状态栏字与悬空返回键落在模糊区里可读；只盖顶部一段，
                    // 不整张封面糊掉，封面高度与底部五段渐变不动。
                    // 1.9.2：沉浸头里不再放返回钮（已移到整页悬空覆盖层，下滑也不滚走），
                    // 这里只留封面 + 渐变，封面高度与渐变不动。
                    CoTopBlurFade(height: CoTopInset.effective(geometryTop: topInset) + 120)
                        .frame(width: geo.size.width, alignment: .top)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            .frame(height: 440 + topInset)
            // 居中标题区（多行可换行）：歌单名、创建者、歌曲数。
            VStack(spacing: 8) {
                Text(playlist.name)
                    .font(BeansFont.appFont(28, .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                if !playlist.creatorName.isEmpty {
                    Text(playlist.creatorName)
                        .font(BeansFont.appFont(16))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text("\(tracks.count) 首")
                    .font(BeansFont.appFont(14))
                    .foregroundStyle(.white.opacity(0.6))
                // 分享 / 播放 / 随机一行：播放为白色 pill 中间大按钮，两侧为圆形钮。
                // 1.8.8 说明：Co 没有下载功能，截图里的下载圆钮不做成假下载，
                // 右侧圆钮改为真实的随机播放；左侧圆钮为真实的系统分享。
                HStack(spacing: 32) {
                    Button { showShare = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background { BeansGlass(shape: Circle()) }
                            .overlay { Circle().stroke(.white.opacity(0.2), lineWidth: 0.5) }
                    }
                    .buttonStyle(.plain)
                    // 1.9.2：播放全部改液态玻璃胶囊——走全站 BeansGlass 胶囊
                    // （iOS26+ 真 glassEffect、低系统回落半透明，遵循用户界面样式），
                    // 字与图标改白字，压在玻璃/深色底上可读；行位置与功能不动，
                    // 文案统一为“播放全部”（与每日推荐页同款）。
                    Button { player.play(songs: displayedTracks, startAt: 0) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill").font(.system(size: 16, weight: .bold))
                            Text("播放全部").font(BeansFont.appFont(17, .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background { BeansGlass(shape: Capsule()) }
                        .overlay { Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5) }
                    }
                    .buttonStyle(.plain)
                    Button {
                        if !displayedTracks.isEmpty {
                            player.play(songs: displayedTracks, startAt: Int.random(in: 0..<displayedTracks.count))
                        }
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background { BeansGlass(shape: Circle()) }
                            .overlay { Circle().stroke(.white.opacity(0.2), lineWidth: 0.5) }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 14)
            }
            .padding(.top, 4)
            Divider().overlay(Color.white.opacity(0.15)).padding(.vertical, 20)
            // 搜索 + 收藏星 + ··· 菜单（排序与隐藏收进菜单，行面保持截图的干净）。
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                    TextField("搜索歌单内歌曲", text: $searchText)
                        .font(BeansFont.appFont(15))
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
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                // 1.9.3：搜索框改全圆角椭圆形胶囊（Capsule，高约 40pt），
                // 方角圆角矩形已删；放大镜+占位字+清空钮都在胶囊内，
                // 背景仍走液态玻璃胶囊，细描边保深色底可读。
                .background { BeansGlass(shape: Capsule()) }
                .overlay { Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5) }
                // 1.8.9 液态玻璃：收藏星与 ··· 菜单钮也走 BeansGlass 圆钮（与返回/分享/随机同款），
                // 不再是裸白图标；播放白 pill 与歌曲行仍不动。
                Button {
                    isStarred.toggle()
                    CoStarredPlaylists.setStarred(id: playlist.id, starred: isStarred)
                    ToastCenter.shared.show(isStarred ? "已收藏" : "已取消收藏")
                } label: {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background { BeansGlass(shape: Circle()) }
                        .overlay { Circle().stroke(.white.opacity(0.2), lineWidth: 0.5) }
                }
                .buttonStyle(.plain)
                Menu {
                    if !hideSortButton {
                        Picker("排序", selection: $sortMode) {
                            ForEach(PlaylistSortMode.allCases) { mode in
                                Text(LocalizedStringKey(mode.rawValue)).tag(mode)
                            }
                        }
                    }
                    Button("隐藏此歌单", role: .destructive) { hideThisPlaylist() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background { BeansGlass(shape: Circle()) }
                        .overlay { Circle().stroke(.white.opacity(0.2), lineWidth: 0.5) }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private var songList: some View {
        // 1.8.9 审计：VStack 改 LazyVStack，长歌单只渲染可见行，不再整单物化。
        LazyVStack(spacing: 0) {
            ForEach(Array(displayedTracks.enumerated()), id: \.element.identityKey) { index, song in
                SongCell(
                    song: song,
                    showCover: true,
                    coverSize: 50,
                    fixedRowHeight: 72,
                    suppressNativeCleanRowGlass: true,
                    darkPage: true,
                    playbackContext: displayedTracks,
                    playbackIndex: index
                ) {
                    player.play(songs: displayedTracks, startAt: index)
                }
                .padding(.horizontal, 16)
                if index < displayedTracks.count - 1 {
                    Divider().overlay(Color.white.opacity(0.12)).padding(.leading, 82)
                }
            }
        }
    }

    /// 歌单内搜索 + 排序后的列表
    private var displayedTracks: [Song] {
        var list = tracks
        let kw = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !kw.isEmpty {
            list = list.filter { song in
                song.name.lowercased().contains(kw)
                    || song.artists.lowercased().contains(kw)
                    || song.album.lowercased().contains(kw)
            }
        }
        switch sortMode {
        case .original: break
        case .name:
            list.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .duration:
            list.sort { $0.duration < $1.duration }
        }
        return list
    }

    // 1.8.7：详情页隐藏只藏“我的”页显示，不删酷狗里的歌单；
    // 我的页下次出现时按同一存储过滤，设置里可恢复。
    private func hideThisPlaylist() {
        var entries = CoHiddenPlaylists.load(userId: KugouMusicAuth.shared.userId)
        if !entries.contains(where: { $0.id == playlist.id }) {
            entries.append((id: playlist.id, name: playlist.name))
            CoHiddenPlaylists.save(userId: KugouMusicAuth.shared.userId, entries: entries)
        }
        ToastCenter.shared.show("已隐藏")
    }

    private func load(force: Bool = false) async {
        let cache = SyncedPlaylistCache.shared
        if let cached = cache.cachedSongs(playlist: playlist, accountID: cacheAccountID) {
            tracks = cached.songs
            loading = false
            if !force, cache.isFresh(cached) {
                return
            }
        } else {
            loading = true
        }
        errorMessage = nil
        BeansLogger.shared.log("歌单页面打开 source=\(playlist.source.rawValue) id=\(playlist.id) name=\(playlist.name) advertisedCount=\(playlist.trackCount)", level: .info)
        do {
            // Co：歌单曲目只走酷狗（原 QQ/网易云分支已删）。
            tracks = try await KugouMusicAPI.shared.playlistSongs(listID: playlist.id)
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
}
