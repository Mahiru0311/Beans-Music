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
    @State private var tracks: [Song] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var sortMode: PlaylistSortMode = .original
    @AppStorage("beans.homeHeaderHideSort") private var hideSortButton = false
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue

    private var isNativeClean: Bool {
        BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    private var cacheAccountID: String {
        switch playlist.source {
        case .netease:
            return KugouMusicAuth.shared.userId
        case .qq:
            return KugouMusicAuth.shared.userId
        case .kugou:
            return KugouMusicAuth.shared.userId
        }
    }

    var body: some View {
        let _ = theme.accent
        ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                Group {
                if loading {
                    LoadingStateView()
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await load(force: true) }
                    }
                } else {
                    // 1.8.7：按 2.0.3 结构用 ScrollView + LazyVStack（不用 List）：
                    // 小封面头、固定 64pt 行高、底部留 118pt，歌曲行不再被迷你播放器遮住。
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            header
                            ForEach(Array(displayedTracks.enumerated()), id: \.element.identityKey) { index, song in
                                SongCell(
                                    song: song,
                                    showCover: true,
                                    suppressNativeCleanRowGlass: true,
                                    coverSize: 46,
                                    fixedRowHeight: 64,
                                    playbackContext: displayedTracks,
                                    playbackIndex: index
                                ) {
                                    player.play(songs: displayedTracks, startAt: index)
                                }
                                .padding(.horizontal, 22)
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 118)
                    }
                    .beansScrollIndicatorsHidden()
                }
            }
            }
            .navigationTitle(playlist.name)
            .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: isNativeClean ? 18 : 14) {
                CoverImage(url: playlist.coverURL, size: 96, cornerRadius: 18)
                VStack(alignment: .leading, spacing: 6) {
                    Text(playlist.name)
                        .font(BeansFont.appFont(18, .bold))
                        .foregroundStyle(Color.beansLabel)
                        .lineLimit(2)
                    if !playlist.creatorName.isEmpty {
                        Text(playlist.creatorName)
                            .font(BeansFont.appFont(12))
                            .foregroundStyle(Color.beansComment)
                    }
                    Text(beansSongCountText(tracks.count))
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                GlassButton(title: "播放全部", systemName: "play.fill", prominent: true) {
                    player.play(songs: displayedTracks, startAt: 0)
                }
                GlassButton(title: "随机播放", systemName: "shuffle") {
                    if !displayedTracks.isEmpty {
                        player.play(songs: displayedTracks, startAt: Int.random(in: 0..<displayedTracks.count))
                    }
                }
                Spacer()
                // 1.8.7：歌单详情页内的隐藏入口（与我的页 ··· 入口同一存储）。
                Menu {
                    Button("隐藏此歌单", role: .destructive) { hideThisPlaylist() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 38, height: 38)
                        .background { BeansSurface(shape: Circle()) }
                }
                .buttonStyle(GlassPressButtonStyle())
            }
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.beansComment)
                    TextField(beansLocalized("搜索歌单内歌曲", "Search songs in playlist"), text: $searchText)
                        .font(BeansFont.appFont(14))
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.beansComment)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)) }

                if !hideSortButton {
                    Menu {
                        Picker("排序", selection: $sortMode) {
                            ForEach(PlaylistSortMode.allCases) { mode in
                                Text(LocalizedStringKey(mode.rawValue)).tag(mode)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 38, height: 38)
                            .background { BeansSurface(shape: Circle()) }
                    }
                    .buttonStyle(GlassPressButtonStyle())
                }
            }
        }
        .padding(14)
        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 24, style: .continuous)) }
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
        ToastCenter.shared.show("已隐藏，可在设置里恢复")
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
