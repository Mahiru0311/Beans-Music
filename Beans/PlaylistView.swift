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

    /// 深色底（截图里的深褐底），不跟随系统深浅，歌单页永远按截图的深色呈现。
    private let darkBackground = Color(red: 0.14, green: 0.10, blue: 0.08)

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
                ScrollView {
                    VStack(spacing: 0) {
                        unifiedCoverHeader
                        unifiedTitleBlock
                        unifiedControls
                        if let description = headerData.description, !description.isEmpty {
                            Text(description)
                                .font(BeansFont.appFont(15))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 22)
                                .padding(.bottom, 20)
                        }
                        Divider()
                            .overlay(.white.opacity(0.15))
                            .padding(.horizontal, 22)
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
                            Divider()
                                .overlay(.white.opacity(0.12))
                                .padding(.leading, 86)
                        }
                    }
                    .padding(.bottom, 180)
                }
                .beansScrollIndicatorsHidden()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
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

    /// 封面全幅铺满：正方形封面、宽 = 屏宽，底部渐变到深色底，与标题区衔接。
    private var unifiedCoverHeader: some View {
        let width = UIScreen.main.bounds.width
        return ZStack(alignment: .bottom) {
            CoverImage(url: headerData.coverURL, size: width, cornerRadius: 0)
            LinearGradient(colors: [.clear, darkBackground], startPoint: .top, endPoint: .bottom)
                .frame(height: 120)
        }
        .frame(width: width, height: width)
        .clipped()
    }

    private var unifiedTitleBlock: some View {
        VStack(spacing: 10) {
            Text(headerData.title)
                .font(BeansFont.appFont(30, .bold))
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
        .padding(.top, 8)
    }

    private var unifiedControls: some View {
        HStack(spacing: 20) {
            Button {
                BeansHaptics.tap()
                playShuffled()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
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
                .frame(width: 200, height: 56)
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
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 24)
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

    private func playAll() {
        guard !orderedTracks.isEmpty else { return }
        player.play(songs: orderedTracks, startAt: 0)
    }

    /// 随机播放：整份歌单作队列，从随机一首起播；不改用户全局播放模式。
    private func playShuffled() {
        guard !orderedTracks.isEmpty else { return }
        player.play(songs: orderedTracks, startAt: Int.random(in: 0..<orderedTracks.count))
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
