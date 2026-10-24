import SwiftUI
import UIKit

// MARK: - 本地音乐库区块（音乐库页面顶部：本机歌单，可新建 / 播放 / 添加歌曲）

struct LocalMusicSection: View {
    fileprivate enum SyncTarget: String, CaseIterable, Identifiable {
        case kugou = "酷狗音乐"

        var id: String { rawValue }
    }

    @ObservedObject private var store = LocalLibraryStore.shared
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var theme: ThemeStore
    @AppStorage("beans.language") private var languageRaw = AppLanguage.chinese.rawValue

    @State private var showCreate = false
    @State private var showPlaylistOrder = false
    @State private var newName = ""
    @State private var selected: LocalPlaylist?
    @State private var syncing = false
    @State private var syncMessage = ""
    @State private var showSyncPicker = false
    @State private var selectedSyncTargets: Set<SyncTarget> = []

    private var emptyLocalPlaylistText: String {
        if languageRaw == AppLanguage.english.rawValue {
            return "No local playlists yet\nCreate a playlist and save favorite songs on this device"
        }
        return "还没有本地歌单\n新建一个歌单，把喜欢的歌曲收藏到本机"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("本地音乐库")
                    .font(BeansFont.appFont(21, .bold))
                    .foregroundStyle(Color.beansLabel)
                Spacer(minLength: 8)
                Button {
                    newName = ""
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.beansAmber)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("新建本地歌单")
                .help("新建本地歌单")
                Button {
                    showPlaylistOrder = true
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.beansAmber)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("排序本地歌单")
                .help("排序本地歌单")
            }
            VStack(alignment: .leading, spacing: 6) {
                GlassButton(
                    title: syncing ? "正在同步歌单…" : "一键同步歌单",
                    systemName: "arrow.triangle.2.circlepath",
                    prominent: true
                ) {
                    showSyncPicker = true
                }
                .disabled(syncing)
                Text("选择两个或三个平台，合并同步到一个本地歌单")
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
            }
            if !syncMessage.isEmpty {
                Text(syncMessage)
                    .font(BeansFont.appFont(12, .medium))
                    .foregroundStyle(Color.beansSage)
            }
            if store.playlists.isEmpty {
                VStack(spacing: 12) {
                    EmptyStateView(
                        icon: "internaldrive",
                        text: emptyLocalPlaylistText
                    )
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(store.playlists) { playlist in
                        Button {
                            selected = playlist
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    if let coverURL = playlist.coverURL {
                                        CoverImage(url: coverURL, size: 56, cornerRadius: 12)
                                    } else {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(LinearGradient(colors: [Color.beansAmber.opacity(0.75), Color.beansAmber.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 56, height: 56)
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(playlist.name)
                                        .font(BeansFont.appFont(15, .medium))
                                        .foregroundStyle(Color.beansLabel)
                                        .lineLimit(1)
                                    Text([
                                        beansLocalSongCountText(playlist.songs.count),
                                        playlist.sourceName
                                    ].compactMap { $0 }.joined(separator: " · "))
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
                        .contextMenu {
                            Button {
                                store.movePlaylist(id: playlist.id, offset: -1)
                            } label: {
                                Label("移到前面", systemImage: "arrow.up")
                            }
                            Button {
                                store.movePlaylist(id: playlist.id, offset: 1)
                            } label: {
                                Label("移到后面", systemImage: "arrow.down")
                            }
                            Button(role: .destructive) {
                                BeansHaptics.tap()
                                store.deletePlaylist(id: playlist.id)
                                ToastCenter.shared.show("已删除本地歌单")
                            } label: {
                                Label("删除歌单", systemImage: "trash")
                            }
                        }
                        Divider().overlay(Color.beansComment.opacity(0.12))
                    }
                }
                .padding(.vertical, 6)
                .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 22, style: .continuous)) }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .beansCardShadow(radius: 8, y: 3)
            }
        }
        .alert("新建本地歌单", isPresented: $showCreate) {
            TextField("歌单名称", text: $newName)
            Button("创建") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                let playlist = store.createPlaylist(name: name)
                selected = playlist
                newName = ""
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("本地歌单保存在设备上，覆盖安装不会丢失，不依赖平台账号")
        }
        .sheet(isPresented: $showSyncPicker) {
            SyncPlatformPicker(
                selectedTargets: $selectedSyncTargets,
                onCancel: {
                    showSyncPicker = false
                },
                onConfirm: {
                    let targets = selectedSyncTargets
                    showSyncPicker = false
                    Task { await sync(targets: targets) }
                }
            )
        }
        .sheet(isPresented: $showPlaylistOrder) {
            LocalPlaylistOrderSheet()
                .environmentObject(theme)
        }
        .sheet(item: $selected) { playlist in
            LocalPlaylistDetailSheet(playlistID: playlist.id)
                .environmentObject(player)
                .environmentObject(auth)
        }
    }

    private func sync(targets: Set<SyncTarget>) async {
        guard !syncing else { return }
        guard !targets.isEmpty else {
            ToastCenter.shared.show("至少选择一个平台")
            return
        }
        syncing = true
        syncMessage = ""
        var songs: [Song] = []
        var details: [String] = []
        if targets.contains(.kugou), KugouMusicAuth.shared.isLoggedIn {
            do {
                let lists = try await KugouMusicAPI.shared.userPlaylists()
                BeansLogger.shared.log("酷狗歌单 \(lists.map(\.name).joined(separator: "|"))", level: .info)
                let liked = lists.first { list in
                    let name = list.name.replacingOccurrences(of: " ", with: "")
                    return name.contains("喜欢") || name.contains("收藏") || name.contains("红心")
                }
                if let liked {
                    let kugouSongs = try await KugouMusicAPI.shared.playlistSongs(playlist: liked)
                    songs.append(contentsOf: kugouSongs)
                    details.append(platformSongCount("酷狗音乐", kugouSongs.count))
                } else {
                    details.append(NSLocalizedString("酷狗音乐未找到喜欢歌单", comment: ""))
                }
            } catch {
                BeansLogger.shared.log("酷狗同步失败 \(error.localizedDescription)", level: .error)
                details.append(NSLocalizedString("酷狗音乐请求失败", comment: ""))
            }
        } else if targets.contains(.kugou) {
            details.append(NSLocalizedString("酷狗音乐未登录", comment: ""))
        }
        var unique: [Song] = []
        var seen = Set<String>()
        for song in songs where seen.insert(song.identityKey).inserted { unique.append(song) }
        let playlistName: String
        playlistName = targets
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.rawValue)
            .joined(separator: " + ") + "喜欢"
        let added = store.syncSongs(unique, intoPlaylistNamed: playlistName)
        syncing = false
        syncMessage = details.joined(separator: NSLocalizedString("，", comment: "")) + String(format: NSLocalizedString("；合计 %d 首", comment: ""), unique.count)
        ToastCenter.shared.show(unique.isEmpty ? NSLocalizedString("没有获取到该平台的喜欢歌曲", comment: "") : String(format: NSLocalizedString("已同步 %d 首，新增 %d 首到本地歌单“%@”", comment: ""), unique.count, added, playlistName))
    }

    private func platformSongCount(_ platform: String, _ count: Int) -> String {
        String(format: NSLocalizedString("%@ %d 首", comment: ""), NSLocalizedString(platform, comment: ""), count)
    }
}

private struct LocalPlaylistOrderSheet: View {
    @ObservedObject private var store = LocalLibraryStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .active

    var body: some View {
        BeansNavigationStack {
            List {
                ForEach(store.playlists) { playlist in
                    HStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .foregroundStyle(Color.beansAmber)
                        Text(playlist.name)
                            .foregroundStyle(Color.beansLabel)
                        Spacer()
                        Text(beansLocalSongCountText(playlist.songs.count))
                            .font(BeansFont.appFont(12))
                            .foregroundStyle(Color.beansComment)
                    }
                }
                .onMove { offsets, destination in
                    store.movePlaylists(from: offsets, to: destination)
                }
            }
            .environment(\.editMode, $editMode)
            .listStyle(.plain)
            .beansScrollContentBackgroundHidden()
            .navigationTitle("歌单排序")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

fileprivate struct SyncPlatformPicker: View {
    @Binding var selectedTargets: Set<LocalMusicSection.SyncTarget>
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var canConfirm: Bool {
        !selectedTargets.isEmpty
    }

    var body: some View {
        BeansNavigationStack {
            List {
                Section {
                    ForEach(LocalMusicSection.SyncTarget.allCases) { target in
                        Toggle(isOn: Binding(
                            get: { selectedTargets.contains(target) },
                            set: { isSelected in
                                if isSelected {
                                    selectedTargets.insert(target)
                                } else {
                                    selectedTargets.remove(target)
                                }
                            }
                        )) {
                            Label(target.rawValue, systemImage: icon(for: target))
                        }
                    }
                } header: {
                    Text("同步平台")
                } footer: {
                    Text(LocalizedStringKey(canConfirm ? "可同步单个平台，也可以同时合并多个平台的喜欢歌曲。" : "至少选择一个平台。"))
                }
            }
            .navigationTitle("一键同步歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始同步", action: onConfirm)
                        .disabled(!canConfirm)
                }
            }
        }
        .onAppear {
            selectedTargets = []
        }
        .modifier(BeansSheetModifier(detents: [.fraction(0.5)], dragIndicator: true))
    }

    private func icon(for target: LocalMusicSection.SyncTarget) -> String {
        "dog"
    }
}

// MARK: - 本地歌单详情（播放全部 / 单曲播放 / 移除歌曲 / 添加歌曲）

struct LocalPlaylistDetailSheet: View {
    @ObservedObject private var store = LocalLibraryStore.shared
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss

    let playlistID: UUID

    @State private var showSearchAdd = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var playlistSearchText = ""
    @State private var multiSelectMode = false
    @State private var selectedSongKeys: Set<String> = []
    @State private var showAddSelectedDestination = false
    @State private var exportFile: ShareFileItem?
    // 不再读沉浸开关分叉（设置页开关本身不动）：本页永远走下面统一的标题 + 控制排。
    private var playlist: LocalPlaylist? {
        store.playlists.first { $0.id == playlistID }
    }

    @ViewBuilder
    private func localPlaylistRow(index: Int, song: Song, playlist: LocalPlaylist) -> some View {
        if multiSelectMode {
            HStack(spacing: 10) {
                Image(systemName: selectedSongKeys.contains(song.identityKey) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selectedSongKeys.contains(song.identityKey) ? Color.beansAmber : Color.beansComment)
                SongCell(song: song, glassRow: true) {
                    toggleSelection(song)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                toggleSelection(song)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            SongCell(song: song, glassRow: true, playbackContext: playlist.songs, playbackIndex: index) {
                player.play(songs: playlist.songs, startAt: index)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    BeansHaptics.tap()
                    store.removeSong(playlistID: playlistID, songIdentity: song.identityKey)
                } label: {
                    Label("移除", systemImage: "trash")
                }
            }
        }
    }

    private var visibleSongs: [(offset: Int, element: Song)] {
        guard let playlist else { return [] }
        let keyword = playlistSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let songs = Array(playlist.songs.enumerated())
        guard !keyword.isEmpty else { return songs }
        return songs.filter { _, song in
            song.name.lowercased().contains(keyword)
                || song.artists.lowercased().contains(keyword)
                || song.album.lowercased().contains(keyword)
        }
    }

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                Group {
                if let playlist {
                    List {
                        // 等价实现（为什么不照搬歌单页 ScrollView 固定层）：本页是 List 结构，
                        // 歌曲行的左滑删除（swipeActions）、多选、分隔线隐藏都只在 List 里有，
                        // 改成 ScrollView 会丢掉左滑删除；固定封面层也不能放在 List 外面
                        // （List 内容区不透明，固定层会被盖住或压在歌曲行上面）。
                        // 所以统一的是设计语言而非字面结构：首行方形封面（屏宽正方形、
                        // 底部 120pt 渐变淡出、无横线）+ 标题 28pt 居中紧贴封面
                        // + 控制排同款尺寸（播放胶囊 168×50pt、圆键 48×48pt、间距 12pt），
                        // 且不再按沉浸开关分叉。颜色仍走本页 GlassBackdrop 自适应体系
                        // （不像歌单页那样强制深色底），保证浅色下也可读；
                        // 随机键的圆键因此用自适应玻璃 + beansLabel 图标，而不是歌单页
                        // 那支深色底专用的白图标圆键（浅色下白图标会看不见）。
                        // 与歌单页逻辑的差异点（不要含糊说“已统一”）：封面/标题/控制排/
                        // 搜索行都是 List 里的行，随列表一起滚动，上滑时它们与歌曲行是
                        // 同一段内容，不可能像固定层那样单独多跑一截；但下拉放大不是
                        // 歌单页那套（List 没有 ScrollView 的 simultaneousGesture 挂点，
                        // 硬挂会和 List 滚动/左滑冲突），所以本页下拉不放大。
                        // 搜索行已从导航栏抽屉移到播放全部下面的页内行（自适应色）。
                        // 播放/随机/搜索/多选/重命名/导出等功能一律不动。
                        Section {
                            let headerCover: URL? = playlist.coverURL ?? playlist.songs.first?.coverURL
                            let coverWidth = UIScreen.main.bounds.width
                            CoverImage(url: headerCover, size: coverWidth, cornerRadius: 0)
                                .mask(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .black, location: 0),
                                            .init(color: .black, location: max(0, (coverWidth - 120) / coverWidth)),
                                            .init(color: .clear, location: 1),
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            VStack(spacing: 4) {
                                Text(playlist.name)
                                    .font(BeansFont.appFont(28, .bold))
                                    .foregroundStyle(Color.beansLabel)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                Text(beansSongCountText(playlist.songs.count))
                                    .font(BeansFont.appFont(14))
                                    .foregroundStyle(Color.beansComment)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            HStack(spacing: 12) {
                                CoDetailPlayCapsule(title: "播放全部") {
                                    let songs = visibleSongs.map(\.element)
                                    guard !songs.isEmpty else { return }
                                    player.play(songs: songs, startAt: 0)
                                }
                                Button {
                                    BeansHaptics.tap()
                                    let songs = visibleSongs.map(\.element)
                                    guard !songs.isEmpty else { return }
                                    player.play(songs: songs.shuffled(), startAt: 0)
                                } label: {
                                    Image(systemName: "shuffle")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(Color.beansLabel)
                                        .frame(width: 48, height: 48)
                                        .background {
                                            BeansGlass(shape: Circle(), forceLiquid: true)
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("随机播放")
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            // 搜索行在播放全部下面（页内行，不是导航栏抽屉）：与歌手/专辑页
                            // 同一条规则，只是本页是自适应 GlassBackdrop、不是强制深色底，
                            // 所以提示/文字用 beansComment/beansLabel，不用强制深色页的白字。
                            // 过滤逻辑不动，仍是下面的 visibleSongs 按 playlistSearchText 筛。
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.beansComment)
                                ZStack(alignment: .leading) {
                                    if playlistSearchText.isEmpty {
                                        Text("搜索本地歌单歌曲")
                                            .font(BeansFont.appFont(16))
                                            .foregroundStyle(Color.beansComment)
                                            .allowsHitTesting(false)
                                    }
                                    TextField("", text: $playlistSearchText)
                                        .font(BeansFont.appFont(16))
                                        .foregroundStyle(Color.beansLabel)
                                        .autocorrectionDisabled()
                                }
                                if !playlistSearchText.isEmpty {
                                    Button { playlistSearchText = "" } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.beansComment)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 12)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .listRowBackground(Color.clear)
                        Section {
                            if visibleSongs.isEmpty {
                                EmptyStateView(icon: "magnifyingglass", text: "没有找到匹配歌曲")
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            } else {
                                ForEach(visibleSongs, id: \.element.identityKey) { pair in
                                    localPlaylistRow(index: pair.offset, song: pair.element, playlist: playlist)
                                }
                            }
                        }
                    }
                    .beansScrollContentBackgroundHidden()
                    .listStyle(.plain)
                } else {
                    EmptyStateView(icon: "music.note.list", text: "歌单不存在或已删除")
                }
            }
            }
            .navigationTitle(playlist?.name ?? "本地歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            multiSelectMode.toggle()
                            if !multiSelectMode {
                                selectedSongKeys.removeAll()
                            }
                        } label: {
                            Label(multiSelectMode ? "退出多选" : "多选编辑", systemImage: multiSelectMode ? "xmark.circle" : "checklist")
                        }
                        if multiSelectMode {
                            Button {
                                copyAllSongTitles()
                            } label: {
                                Label("复制全部歌名", systemImage: "doc.on.doc")
                            }
                            Button {
                                exportPlaylistAsText()
                            } label: {
                                Label("导出 TXT", systemImage: "square.and.arrow.up")
                            }
                            Button(role: .destructive) {
                                removeSelectedSongs()
                            } label: {
                                Label("移除选中歌曲", systemImage: "trash")
                            }
                            .disabled(selectedSongKeys.isEmpty)
                            Button {
                                showAddSelectedDestination = true
                            } label: {
                                Label("添加到其他本地歌单", systemImage: "folder.badge.plus")
                            }
                            .disabled(selectedSongKeys.isEmpty || !hasOtherPlaylist)
                        }
                        Button {
                            if let song = player.currentSong {
                                store.addSong(song, to: playlistID)
                                BeansHaptics.success()
                                ToastCenter.shared.show("已加入本地歌单")
                            } else {
                                ToastCenter.shared.show("当前没有播放中的歌曲")
                            }
                        } label: {
                            Label("添加当前播放歌曲", systemImage: "plus.circle")
                        }
                        Button {
                            showSearchAdd = true
                        } label: {
                            Label("搜索添加歌曲", systemImage: "magnifyingglass")
                        }
                        Button {
                            renameText = playlist?.name ?? ""
                            showRename = true
                        } label: {
                            Label("重命名歌单", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
        }
        .sheet(isPresented: $showSearchAdd) {
            LocalSearchAddSheet(playlistID: playlistID)
                .environmentObject(player)
                .environmentObject(auth)
        }
        .sheet(item: $exportFile) { item in
            ShareSheet(items: [item.url])
        }
        .alert("重命名歌单", isPresented: $showRename) {
            TextField("歌单名称", text: $renameText)
            Button("保存") {
                let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                store.renamePlaylist(id: playlistID, name: name)
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog(
            "添加 \(selectedSongKeys.count) 首歌曲到其他本地歌单",
            isPresented: $showAddSelectedDestination,
            titleVisibility: .visible
        ) {
            ForEach(store.playlists.filter { $0.id != playlistID }) { target in
                Button(target.name) {
                    addSelectedSongs(to: target.id)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("已选歌曲会复制到目标歌单，当前歌单中的歌曲不会被移除。")
        }
        .modifier(BeansSheetModifier(detents: [.medium, .large], dragIndicator: true))
    }

    private var hasOtherPlaylist: Bool {
        store.playlists.contains { $0.id != playlistID }
    }

    private var selectedSongs: [Song] {
        playlist?.songs.filter { selectedSongKeys.contains($0.identityKey) } ?? []
    }

    private func toggleSelection(_ song: Song) {
        BeansHaptics.select()
        if selectedSongKeys.contains(song.identityKey) {
            selectedSongKeys.remove(song.identityKey)
        } else {
            selectedSongKeys.insert(song.identityKey)
        }
    }

    private func removeSelectedSongs() {
        guard !selectedSongKeys.isEmpty else { return }
        let count = selectedSongKeys.count
        selectedSongKeys.forEach { key in
            store.removeSong(playlistID: playlistID, songIdentity: key)
        }
        selectedSongKeys.removeAll()
        multiSelectMode = false
        BeansHaptics.success()
        ToastCenter.shared.show("已移除 \(count) 首歌曲")
    }

    private func addSelectedSongs(to destinationID: UUID) {
        guard let playlist else { return }
        let songs = playlist.songs.filter { selectedSongKeys.contains($0.identityKey) }
        let added = store.addSongs(songs, to: destinationID)
        selectedSongKeys.removeAll()
        multiSelectMode = false
        BeansHaptics.success()
        let targetName = store.playlists.first(where: { $0.id == destinationID })?.name ?? "目标歌单"
        ToastCenter.shared.show(added == songs.count
            ? "已添加 \(added) 首到「\(targetName)」"
            : "已添加 \(added) 首到「\(targetName)」（重复歌曲已跳过）")
    }

    private func copyAllSongTitles() {
        guard let playlist, !playlist.songs.isEmpty else {
            ToastCenter.shared.show("当前歌单没有歌曲")
            return
        }
        UIPasteboard.general.string = playlist.songs.map(\.name).joined(separator: "\n")
        BeansHaptics.success()
        ToastCenter.shared.show("已复制全部歌名")
    }

    private func exportPlaylistAsText() {
        guard let playlist, !playlist.songs.isEmpty else {
            ToastCenter.shared.show("当前歌单没有歌曲")
            return
        }
        let lines = playlist.songs.map { song in
            let link = song.officialURL?.absoluteString ?? "无"
            return [
                "平台：\(sourceName(for: song))",
                "歌手：\(song.artists.isEmpty ? "未知" : song.artists)",
                "歌名：\(song.name)",
                "时长：\(song.formattedDuration)",
                "官方链接：\(link)",
            ].joined(separator: "\n")
        }
        let content = lines.joined(separator: "\n\n") + "\n"
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(playlist.name)-歌曲清单-\(Int(Date().timeIntervalSince1970)).txt")
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            exportFile = ShareFileItem(url: fileURL)
        } catch {
            ToastCenter.shared.show("导出失败：\(error.localizedDescription)")
        }
    }

    private func sourceName(for song: Song) -> String {
        switch song.source {
        case .netease: return "网易云音乐"
        case .qq: return "QQ音乐"
        case .kugou: return "酷狗音乐"
        case .kuwo: return "酷我音乐"
        case .migu: return "咪咕音乐"
        case .qishui: return "汽水音乐"
        case .bilibili: return "哔哩哔哩"
        case .webdav: return "WebDAV"
        }
    }
}

// MARK: - 本地歌单搜索添加（酷狗）

struct LocalSearchAddSheet: View {
    @ObservedObject private var store = LocalLibraryStore.shared
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    let playlistID: UUID
    @State private var keyword = ""
    @State private var results: [Song] = []
    @State private var searching = false
    @State private var provider: SearchProvider = .kugou
    @State private var task: Task<Void, Never>?

    var body: some View {
        BeansNavigationStack {
            VStack(spacing: 0) {
                if #available(iOS 26, *) {
                    NativeSearchBar(
                        text: $keyword,
                        placeholder: beansLocalized("输入歌名搜索", "Search by song title"),
                        onSubmit: { _ in runSearch() }
                    )
                    .frame(height: 46)
                    .padding(12)
                } else {
                    HStack(spacing: 8) {
                        TextField(beansLocalized("输入歌名搜索", "Search by song title"), text: $keyword)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.beansGlassFill))
                            .submitLabel(.search)
                            .onSubmit { runSearch() }
                        Button {
                            runSearch()
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color.beansAmber))
                        }
                    }
                    .padding(12)
                }
                if searching {
                    Spacer()
                    ProgressView().tint(Color.beansAmber)
                    Spacer()
                } else if results.isEmpty {
                    Spacer()
                    Text("输入歌名搜索，点击结果加入本地歌单")
                        .font(BeansFont.appFont(13))
                        .foregroundStyle(Color.beansComment)
                    Spacer()
                } else {
                    List {
                        ForEach(Array(results.enumerated()), id: \.element.identityKey) { index, song in
                            SongCell(song: song, glassRow: true) {
                                store.addSong(song, to: playlistID)
                                BeansHaptics.success()
                                ToastCenter.shared.show("已加入本地歌单")
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("添加歌曲")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .modifier(BeansSheetModifier(detents: [.medium, .large], dragIndicator: true))
    }

    private func runSearch() {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        task?.cancel()
        task = Task {
            searching = true
            defer { if !Task.isCancelled { searching = false } }
            do {
                let songs: [Song]
                songs = try await KugouMusicAPI.shared.searchSongs(keyword: trimmed)
                guard !Task.isCancelled else { return }
                results = songs
            } catch {
                guard !Task.isCancelled else { return }
                ToastCenter.shared.show("搜索失败，请稍后再试")
            }
        }
    }

}


// MARK: - 加入本地歌单（播放页入口：选择已创建的本地歌单，或新建并加入）

struct AddToLocalPlaylistSheet: View {
    @ObservedObject private var store = LocalLibraryStore.shared
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss

    let song: Song
    /// 由爱心触发时才传：选完歌单后同步到红心库。菜单“加入本地歌单”不传，
    /// 避免把“加入某歌单”误当成点爱心。
    var onAdded: (() -> Void)? = nil
    @State private var showCreateField = false
    @State private var newName = ""
    @State private var message: String?

    var body: some View {
        let _ = theme.accent
        BeansNavigationStack {
            List {
                if store.playlists.isEmpty {
                    Text("还没有本地歌单，先创建一个吧")
                        .foregroundStyle(Color.beansComment)
                } else {
                    Section("选择本地歌单") {
                        ForEach(store.playlists) { playlist in
                            Button {
                                store.addSong(song, to: playlist.id)
                                BeansHaptics.success()
                                ToastCenter.shared.show("已加入「\(playlist.name)」")
                                onAdded?()
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(LinearGradient(colors: [Color.beansAmber.opacity(0.75), Color.beansAmber.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name)
                                            .font(BeansFont.appFont(15, .medium))
                                            .foregroundStyle(Color.beansLabel)
                                            .lineLimit(1)
                                        Text(beansLocalSongCountText(playlist.songs.count))
                                            .font(BeansFont.appFont(11))
                                            .foregroundStyle(Color.beansComment)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color.beansAmber)
                                }
                            }
                        }
                    }
                }

                if showCreateField {
                    Section("新建本地歌单") {
                        TextField("歌单名称", text: $newName)
                            .submitLabel(.done)
                        Button {
                            createAndAdd()
                        } label: {
                            Text("创建并加入")
                                .font(BeansFont.appFont(15, .semibold))
                                .foregroundStyle(Color.beansAmber)
                        }
                    }
                } else {
                    Section {
                        Button {
                            showCreateField = true
                        } label: {
                            Label("新建歌单并加入", systemImage: "plus.circle")
                        }
                    }
                }

                if let message {
                    Section {
                        Text(message)
                            .font(BeansFont.appFont(13))
                            .foregroundStyle(Color.beansSage)
                    }
                }
            }
            .navigationTitle("加入本地歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .modifier(BeansSheetModifier(detents: [.medium, .large], dragIndicator: true))
        .onAppear {
            if store.playlists.isEmpty {
                ToastCenter.shared.show(store.addToDefaultFavorites(song))
                BeansHaptics.success()
                onAdded?()
                dismiss()
            }
        }
    }

    private func createAndAdd() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let playlist = store.createPlaylist(name: name)
        store.addSong(song, to: playlist.id)
        BeansHaptics.success()
        ToastCenter.shared.show("已创建「\(name)」并加入")
        onAdded?()
        dismiss()
    }
}
