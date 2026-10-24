import SwiftUI

// MARK: - 歌手主页（点击播放器顶部歌手名跳转：热门歌曲 + 专辑）

@MainActor
struct ArtistHomeSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss
    let artistName: String
    var artistSource: SongSource = .netease
    var artistID: String?
    /// 从已有导航栈推入时不再创建嵌套 NavigationStack，也不应用 sheet 专用修饰器。
    var embeddedInNavigation = false

    private static func cachedEntry(
        artistName: String,
        source: SongSource,
        artistID: String?
    ) -> ArtistHomeCache.Entry? {
        let identity = artistID?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? artistName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ArtistHomeCache.shared.cached(for: "\(source.rawValue):\(identity)")
    }

    init(artist: Artist, embeddedInNavigation: Bool = false) {
        self.artistName = artist.name
        self.artistSource = artist.source
        self.artistID = artist.id
        self.embeddedInNavigation = embeddedInNavigation
        let cached = Self.cachedEntry(artistName: artist.name, source: artist.source, artistID: artist.id)
        _artist = State(initialValue: cached?.artist ?? artist)
        _hotSongs = State(initialValue: cached?.songs ?? [])
        _albums = State(initialValue: cached?.albums ?? [])
        _loading = State(initialValue: cached == nil || (cached?.songs.isEmpty == true && cached?.albums.isEmpty == true))
    }

    init(artistName: String, artistSource: SongSource = .netease, embeddedInNavigation: Bool = false) {
        self.artistName = artistName
        self.artistSource = artistSource
        self.artistID = nil
        self.embeddedInNavigation = embeddedInNavigation
        let cached = Self.cachedEntry(artistName: artistName, source: artistSource, artistID: nil)
        _artist = State(initialValue: cached?.artist)
        _hotSongs = State(initialValue: cached?.songs ?? [])
        _albums = State(initialValue: cached?.albums ?? [])
        _loading = State(initialValue: cached == nil || (cached?.songs.isEmpty == true && cached?.albums.isEmpty == true))
    }

    @State private var artist: Artist?
    @State private var hotSongs: [Song] = []
    @State private var albums: [Album] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    // 新版统一布局（与 PlaylistView 同款，见 CoUnifiedDetail.swift）：不再读沉浸开关分叉，
    // body 永远走固定封面 + 28pt 标题 + 同款控制排；设置页开关本身不动。
    @StateObject private var detailScroll = CoDetailScrollState()
    @State private var selectedAlbum: Album?
    @State private var loadTask: Task<Void, Never>?
    @AppStorage("beans.showSongVIPBadge") private var showSongVIPBadge = true

    private var cacheKey: String {
        let identity = artistID?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? artistName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(artistSource.rawValue):\(identity)"
    }

    var body: some View {
        Group {
            if embeddedInNavigation {
                artistPage
            } else {
                BeansNavigationStack { artistPage }
                    .modifier(BeansSheetModifier(detents: [.large], dragIndicator: true))
            }
        }
        .onAppear {
            loadTask?.cancel()
            loadTask = Task { await load() }
        }
        .onDisappear {
            loadTask?.cancel()
        }
        .sheet(item: $selectedAlbum) { album in
            AlbumDetailView(album: album)
                .environmentObject(player)
                .environmentObject(theme)
        }
    }

    @ViewBuilder
    private var artistPage: some View {
        ZStack {
            // 新版底：固定深色底（歌单页同款），整页强制深色外观，行文字按深色取值；
            // 不再用主页壁纸 GlassBackdrop，歌手页不再是“主页壁纸 + 居中大封面/小头像横排”两套。
            coDetailDarkBackground.ignoresSafeArea()
            Group {
                if loading {
                    artistLoadingState
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await load() }
                    }
                } else {
                    ZStack {
                        CoUnifiedDetailCoverLayers(coverURL: artist?.coverURL, scrollUp: detailScroll.scrollUp, pull: detailScroll.pull)
                        ScrollView {
                            VStack(spacing: 0) {
                                CoDetailCoverSpacer()
                                artistTitleBlock
                                if !hotSongs.isEmpty {
                                    CoDetailControlsRow {
                                        CoDetailPlayCapsule(title: "播放全部") {
                                            player.play(songs: displayedHotSongs, startAt: 0)
                                        }
                                    }
                                }
                                hotSongsSection
                                albumsSection
                                    .padding(.top, 16)
                            }
                            .padding(.bottom, 16)
                        }
                        .beansScrollIndicatorsHidden()
                        .ignoresSafeArea(edges: .top)
                        .coDetailScroll(detailScroll)
                    }
                }
            }
        }
        // 标题已在内容里（28pt 居中），导航栏标题留空、背景隐藏，像歌单页一样让封面铺到顶边；
        // 搜索框（navigationBarDrawer）与返回/拖动指示仍在原位，功能不动。
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: beansLocalized("搜索歌手歌曲", "Search artist songs")
        )
    }

    /// 歌单页 unifiedTitleBlock 同款口径：歌手名 28pt 居中、热门/专辑数 14pt；
    /// 字段按歌手真实数据（热门歌曲数、专辑数），不套歌单文案。
    private var artistTitleBlock: some View {
        VStack(spacing: 4) {
            Text(artist?.name ?? artistName)
                .font(BeansFont.appFont(28, .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 24)
            Text(beansLocalized("热门歌曲 \(hotSongs.count) 首 · 专辑 \(albums.count) 张", "Popular songs: \(hotSongs.count) · Albums: \(albums.count)"))
                .font(BeansFont.appFont(14))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var artistLoadingState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    BeansShimmerSkeleton(cornerRadius: 36)
                        .frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: 9) {
                        BeansShimmerSkeleton(cornerRadius: 6)
                            .frame(width: 150, height: 18)
                        BeansShimmerSkeleton(cornerRadius: 5)
                            .frame(width: 180, height: 12)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)

                BeansShimmerSkeleton(cornerRadius: 7)
                    .frame(width: 86, height: 18)
                    .padding(.horizontal, 16)

                HStack(spacing: 10) {
                    BeansShimmerSkeleton(cornerRadius: 16)
                        .frame(height: 38)
                    BeansShimmerSkeleton(cornerRadius: 16)
                        .frame(height: 38)
                }
                .padding(.horizontal, 16)

                BeansSongRowsLoadingState(rowCount: 8, coverSize: 40, showsRank: true, horizontalPadding: 16)
            }
            .padding(.top, 6)
            .padding(.bottom, 170)
        }
        .beansScrollIndicatorsHidden()
    }

    private var hotSongsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("热门歌曲")
                .font(BeansFont.appFont(17, .bold))
                .foregroundStyle(Color.beansLabel)
                .padding(.horizontal, 16)
            // 播放全部已移到标题下的新版控制排（168×50pt 胶囊），这里不再重复放一个按钮。
            if hotSongs.isEmpty {
                Text("暂无歌曲")
                    .font(BeansFont.appFont(13))
                    .foregroundStyle(Color.beansComment)
                    .padding(.horizontal, 16)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(displayedHotSongs.enumerated()), id: \.element.identityKey) { index, song in
                        Button {
                            BeansHaptics.tap()
                            player.play(songs: displayedHotSongs, startAt: index)
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(BeansFont.appFont(13, .semibold, .rounded))
                                    .foregroundStyle(index < 3 ? Color.beansAmber : Color.beansComment)
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(width: 32, alignment: .trailing)
                                CoverImage(url: song.coverURL, song: song, size: 40, cornerRadius: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(song.name)
                                            .font(BeansFont.appFont(14, .medium))
                                            .foregroundStyle(Color.beansLabel)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .layoutPriority(1)
                                        if showSongVIPBadge, song.isVIP {
                                            VIPBadgeView(text: "VIP")
                                        }
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                    Text(song.album)
                                        .font(BeansFont.appFont(11))
                                        .foregroundStyle(Color.beansComment)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                player.playNext(song)
                            } label: {
                                Label("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward")
                            }
                            Button {
                                player.play(songs: displayedHotSongs, startAt: index)
                            } label: {
                                Label("立即播放", systemImage: "play.fill")
                            }
                        }
                    }
                }
            }
        }
    }

    private var displayedHotSongs: [Song] {
        let kw = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !kw.isEmpty else { return hotSongs }
        return hotSongs.filter { song in
            song.name.lowercased().contains(kw)
                || song.artists.lowercased().contains(kw)
                || song.album.lowercased().contains(kw)
        }
    }

    private var albumsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            albumShelf(title: "专辑", albums: studioAlbums)
            albumShelf(title: "EP 与单曲", albums: epsAndSingles)
        }
    }

    private var studioAlbums: [Album] {
        albums.filter { !$0.isEPOrSingle }
    }

    private var epsAndSingles: [Album] {
        albums.filter(\.isEPOrSingle)
    }

    @ViewBuilder
    private func albumShelf(title: String, albums: [Album]) -> some View {
        if !albums.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(BeansFont.appFont(17, .bold))
                    .foregroundStyle(Color.beansLabel)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 16) {
                        ForEach(albums) { album in
                            Button {
                                openAlbum(album)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    CoverImage(url: album.coverURL, size: 160, cornerRadius: 12)
                                    Text(album.name)
                                        .font(BeansFont.appFont(13, .medium))
                                        .foregroundStyle(Color.beansLabel)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .frame(width: 160, alignment: .leading)
                                    Text(album.releaseCaption)
                                        .font(BeansFont.appFont(11))
                                        .foregroundStyle(Color.beansComment)
                                        .lineLimit(1)
                                        .frame(width: 160, alignment: .leading)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func openAlbum(_ album: Album) {
        BeansHaptics.tap()
        selectedAlbum = album
    }

    private func load() async {
        let cache = ArtistHomeCache.shared
        let cachedEntry = cache.cached(for: cacheKey)
        if let cached = cachedEntry {
            artist = cached.artist ?? artist
            hotSongs = songsCreditedToCurrentArtist(cached.songs)
            albums = cached.albums
            loading = false
            errorMessage = nil
            if cache.isFresh(cached), !BeansNetworkStatus.shared.isReachable {
                return
            }
        } else {
            loading = true
        }
        errorMessage = nil
        await loadKugouArtist()
        // A transient catalog response must never replace a visible cached page with
        // empty sections. Keep the last successful section independently while the
        // other section refreshes in the background.
        if let cached = cachedEntry {
            if hotSongs.isEmpty, !cached.songs.isEmpty {
                hotSongs = songsCreditedToCurrentArtist(cached.songs)
            }
            if albums.isEmpty, !cached.albums.isEmpty {
                albums = cached.albums
            }
            if artist == nil {
                artist = cached.artist
            }
        }
        if !hotSongs.isEmpty || !albums.isEmpty {
            cache.save(artist: artist, songs: hotSongs, albums: albums, for: cacheKey)
        }
        loading = false
        if !hotSongs.isEmpty || !albums.isEmpty { errorMessage = nil }
    }

    /// QQ 歌手：优先用歌手 mid 拉热门歌曲，失败则按歌手名搜索 QQ 歌曲（保证不是网易云数据）
    /// 酷狗歌手主页优先走作者歌曲接口，再补 `singer/song` 和综合搜索结果，
    /// 避免部分歌手页只停在首批 19 首。
    private func loadKugouArtist() async {
        async let albumsTask = searchedAlbumsForCurrentArtist()
        let resolvedArtist: Artist?
        if let artistID,
           !artistID.isEmpty,
           !artistID.hasPrefix("qq-") {
            let rawID = artistID.replacingOccurrences(of: "kugou-", with: "")
            resolvedArtist = artist ?? Artist(id: rawID, name: artistName, coverURL: nil, source: .kugou)
        } else {
            resolvedArtist = (try? await KugouMusicAPI.shared.searchArtists(keyword: artistName, limit: 10))?.first
        }
        if let resolvedArtist {
            artist = resolvedArtist
        }
        var songs: [Song] = []
        var primarySongs: [Song] = []
        if let resolvedArtist,
           !resolvedArtist.id.isEmpty,
           !resolvedArtist.id.hasPrefix("qq-") {
            var seen = Set<String>()
            let pageSize = 100
            let maxSongs = 1_000
            for page in 1...(maxSongs / pageSize) {
                let batch = (try? await KugouMusicAPI.shared.artistSongs(
                    authorID: resolvedArtist.id,
                    page: page,
                    limit: pageSize
                )) ?? []
                if batch.isEmpty { break }
                let before = songs.count
                for song in batch where seen.insert(song.identityKey).inserted {
                    songs.append(song)
                    primarySongs.append(song)
                    if songs.count >= maxSongs { break }
                }
                if songs.count >= maxSongs || songs.count == before {
                    break
                }
            }
        }

        // The author endpoint has historically returned only 19 rows for some
        // accounts/charts. Supplement a short result with paged song search.
        if songs.count < 100 {
            async let exact = KugouMusicAPI.shared.searchSongs(keyword: artistName, limit: 300)
            async let works = KugouMusicAPI.shared.searchSongs(keyword: "\(artistName) 歌曲", limit: 300)
            let candidates = [
                (try? await exact) ?? [],
                (try? await works) ?? [],
            ]
            var seen = Set(songs.map(\.identityKey))
            for song in candidates.flatMap({ $0 }) {
                guard seen.insert(song.identityKey).inserted else { continue }
                songs.append(song)
            }
        }

        if songs.isEmpty {
            async let exact = KugouMusicAPI.shared.searchSongs(keyword: artistName, limit: 300)
            async let hot = KugouMusicAPI.shared.searchSongs(keyword: "\(artistName) 热门", limit: 200)
            async let works = KugouMusicAPI.shared.searchSongs(keyword: "\(artistName) 歌曲", limit: 200)
            let batches = [
                (try? await exact) ?? [],
                (try? await hot) ?? [],
                (try? await works) ?? [],
            ]
            var seen = Set<String>()
            songs = batches.flatMap { $0 }.filter { song in
                seen.insert(song.identityKey).inserted
            }
        }

        if !songs.isEmpty {
            hotSongs = songs
        }
        if songs.isEmpty, !primarySongs.isEmpty {
            hotSongs = primarySongs
        }
        if !hotSongs.isEmpty {
            hotSongs = Array(hotSongs.prefix(1_000))
        }
        persistLoadedContent()
        let fetchedAlbums = await albumsTask
        if !fetchedAlbums.isEmpty {
            albums = fetchedAlbums
        }
        BeansLogger.shared.log("酷狗歌手主页完成：artist=\(artistName) songs=\(hotSongs.count)", level: .debug)
        loading = false
    }

    /// 补充目录没有独立的歌手详情接口时，使用同源歌曲搜索构建歌手页，
    /// 不回退到其它平台，避免来源和封面错位。
    private func searchedAlbumsForCurrentArtist() async -> [Album] {
        let candidates: [Album] = (try? await KugouMusicAPI.shared.searchAlbums(keyword: artistName, limit: 60)) ?? []
        let expected = normalizedArtistName(artistName)
        guard !expected.isEmpty else { return Array(candidates.prefix(60)) }
        let matched = candidates.filter { album in
            let albumArtist = normalizedArtistName(album.artistName)
            return !albumArtist.isEmpty && (albumArtist.contains(expected) || expected.contains(albumArtist))
        }
        return Array((matched.isEmpty ? candidates : matched).prefix(60))
    }

    private func normalizedArtistName(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
            .replacingOccurrences(of: #"[(].*?[)]"#, with: "", options: .regularExpression)
            .filter { !$0.isWhitespace && !$0.isPunctuation }
    }

    private func songsCreditedToCurrentArtist(_ songs: [Song]) -> [Song] {
        let expected = Set([artistName, artist?.name]
            .compactMap { $0 }
            .flatMap(artistNameTokens))
        guard !expected.isEmpty else { return songs }
        let matched = songs.filter { song in
            !expected.isDisjoint(with: Set(artistNameTokens(song.artists)))
        }
        return matched.isEmpty ? songs : matched
    }

    private func artistNameTokens(_ value: String) -> [String] {
        let separators = CharacterSet(charactersIn: "/／,，、&＆+＋|｜;；")
        return value
            .components(separatedBy: separators)
            .map(normalizedArtistName)
            .filter { !$0.isEmpty }
    }

    /// 歌曲列表先到时立即落盘，不能因为专辑请求较慢或用户返回上一页而丢掉
    /// 已经成功加载的歌手页内容。
    private func persistLoadedContent() {
        guard !hotSongs.isEmpty || !albums.isEmpty else { return }
        hotSongs = songsCreditedToCurrentArtist(hotSongs)
        ArtistHomeCache.shared.save(artist: artist, songs: hotSongs, albums: albums, for: cacheKey)
    }
}
