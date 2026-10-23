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
    @Environment(\.dismiss) private var dismiss
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
                            immersiveHeader
                            songList
                        }
                        .padding(.bottom, 118)
                    }
                    .beansScrollIndicatorsHidden()
                }
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .task { await load() }
        .onAppear { isStarred = CoStarredPlaylists.isStarred(id: playlist.id) }
        .sheet(isPresented: $showShare) { ShareSheet(items: [shareText]) }
    }

    private var immersiveHeader: some View {
        VStack(spacing: 0) {
            // 全幅封面：铺满顶部约 400pt，顶部略暗保证返回钮可读、底部渐变融入深色底。
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    AsyncImage(url: playlist.coverURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            Color(red: 0.15, green: 0.15, blue: 0.16)
                        }
                    }
                    .frame(width: geo.size.width, height: 400)
                    .clipped()
                    LinearGradient(
                        colors: [.black.opacity(0.35), .clear, pageBackground.opacity(0.0), pageBackground],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(width: geo.size.width, height: 400)
                    // 1.8.9 液态玻璃：返回钮走全站 BeansGlass（iOS26+ 真 glassEffect，
                    // iOS15-25 回落超薄材质；紧凑/简洁样式下 BeansGlass 自带平面回落，不强制液态）。
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background { BeansGlass(shape: Circle()) }
                            .overlay { Circle().stroke(.white.opacity(0.25), lineWidth: 0.5) }
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 16)
                    .padding(.top, geo.safeAreaInsets.top + 6)
                }
            }
            .frame(height: 400)
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
                    Button { player.play(songs: displayedTracks, startAt: 0) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill").font(.system(size: 16, weight: .bold))
                            Text("播放").font(BeansFont.appFont(17, .bold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(.white))
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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                // 1.8.9 液态玻璃：搜索框容器走 BeansGlass，细描边保深色底可读；播放白 pill 不动。
                .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 12, style: .continuous)) }
                .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 0.5) }
                Button {
                    isStarred.toggle()
                    CoStarredPlaylists.setStarred(id: playlist.id, starred: isStarred)
                    ToastCenter.shared.show(isStarred ? "已收藏" : "已取消收藏")
                } label: {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
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
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
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
