import SwiftUI

// MARK: - 歌手主页（点击播放器顶部歌手名跳转：热门歌曲 + 专辑）

struct ArtistHomeSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss
    let artistName: String
    var artistSource: SongSource = .netease
    var artistID: String?

    init(artist: Artist) {
        self.artistName = artist.name
        self.artistSource = artist.source
        self.artistID = artist.id
        _artist = State(initialValue: artist)
    }

    init(artistName: String, artistSource: SongSource = .netease) {
        self.artistName = artistName
        self.artistSource = artistSource
        self.artistID = nil
        _artist = State(initialValue: nil)
    }

    @State private var artist: Artist?
    @State private var hotSongs: [Song] = []
    @State private var albums: [Album] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    var body: some View {
        BeansNavigationStack {
            ZStack {
                // 歌手页沿用主页壁纸，不受“同步到全部页面”开关影响。
                GlassBackdrop(customColor: theme.customBackground, homeMode: true)
                Group {
                    if loading {
                        LoadingStateView()
                    } else if let errorMessage {
                        ErrorStateView(message: errorMessage) {
                            Task { await load() }
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                artistHeader
                                hotSongsSection
                                if artistSource == .netease {
                                    albumsSection
                                }
                            }
                            .padding(.top, 6)
                            .padding(.bottom, 16)
                        }
                        .beansScrollIndicatorsHidden()
                    }
                }
            }
            .navigationTitle("歌手主页")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .task { await load() }
        .modifier(BeansSheetModifier(detents: [.large], dragIndicator: true))
    }

    private var artistHeader: some View {
        HStack(spacing: 14) {
            AsyncImage(url: artist?.coverURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.beansComment)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .background(Color.beansGlassFill, in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(artist?.name ?? artistName)
                    .font(BeansFont.appFont(20, .bold))
                    .foregroundStyle(Color.beansLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                Text(artistSource == .netease
                     ? beansLocalized("热门歌曲 \(hotSongs.count) 首 · 专辑 \(albums.count) 张", "Popular songs: \(hotSongs.count) · Albums: \(albums.count)")
                     : beansLocalized("热门歌曲 \(hotSongs.count) 首", "Popular songs: \(hotSongs.count)"))
                    .font(BeansFont.appFont(12))
                    .foregroundStyle(Color.beansComment)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var hotSongsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("热门歌曲")
                .font(BeansFont.appFont(17, .bold))
                .foregroundStyle(Color.beansLabel)
                .padding(.horizontal, 16)
            if !hotSongs.isEmpty {
                HStack(spacing: 10) {
                    Button {
                        BeansHaptics.tap()
                        player.play(songs: displayedHotSongs, startAt: 0)
                        dismiss()
                    } label: {
                        Label("播放全部", systemImage: "play.fill")
                            .font(BeansFont.appFont(13, .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Color.beansAmber))
                    }
                    .buttonStyle(.plain)
                    Button {
                        BeansHaptics.tap()
                        player.play(songs: displayedHotSongs.shuffled(), startAt: 0)
                        dismiss()
                    } label: {
                        Label("随机播放", systemImage: "shuffle")
                            .font(BeansFont.appFont(13, .semibold))
                            .foregroundStyle(Color.beansAmber)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Capsule().strokeBorder(Color.beansAmber.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
            }
            if !hotSongs.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.beansComment)
                    TextField(beansLocalized("搜索歌手歌曲", "Search artist songs"), text: $searchText)
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
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
            }
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
                                    .frame(width: 22)
                                CoverImage(url: song.coverURL, size: 40, cornerRadius: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.name)
                                        .font(BeansFont.appFont(14, .medium))
                                        .foregroundStyle(Color.beansLabel)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
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
        VStack(alignment: .leading, spacing: 6) {
            Text("专辑")
                .font(BeansFont.appFont(17, .bold))
                .foregroundStyle(Color.beansLabel)
                .padding(.horizontal, 16)
            if albums.isEmpty {
                Text("暂无专辑")
                    .font(BeansFont.appFont(13))
                    .foregroundStyle(Color.beansComment)
                    .padding(.horizontal, 16)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 12) {
                    ForEach(albums) { album in
                        Button {
                            playAlbum(album)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                CoverImage(url: album.coverURL, size: 88, cornerRadius: 12)
                                    .frame(maxWidth: .infinity)
                                Text(album.name)
                                    .font(BeansFont.appFont(11, .medium))
                                    .foregroundStyle(Color.beansLabel)
                                    .lineLimit(1)
                                if let count = album.trackCount {
                                    Text(beansSongCountText(count))
                                        .font(BeansFont.appFont(10))
                                        .foregroundStyle(Color.beansComment)
                                }
                            }
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 16, style: .continuous)) }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
            }
        }
    }

    private func playAlbum(_ album: Album) {
        // Co：酷狗无专辑曲目直取接口，改用酷狗搜索兜底（原网易云接口已删）。
        BeansHaptics.tap()
        Task {
            if let songs = try? await KugouMusicAPI.shared.searchSongs(keyword: album.name, limit: 30), !songs.isEmpty {
                player.play(songs: songs, startAt: 0)
                dismiss()
            } else {
                ToastCenter.shared.show("专辑歌曲加载失败", duration: 2)
            }
        }
    }

    private func load() async {
        // Co：歌手页只走酷狗（原网易云/QQ 加载已删）。
        loading = true
        errorMessage = nil
        await loadKugouArtist()
    }

    private func loadKugouArtist() async {
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

        hotSongs = songs
        if hotSongs.isEmpty, !primarySongs.isEmpty {
            hotSongs = primarySongs
        }
        hotSongs = Array(hotSongs.prefix(1_000))
        BeansLogger.shared.log("酷狗歌手主页完成：artist=\(artistName) songs=\(hotSongs.count)", level: .debug)
        loading = false
    }
}
