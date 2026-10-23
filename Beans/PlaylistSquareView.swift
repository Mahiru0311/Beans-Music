import SwiftUI

/// 酷狗专版精选页：只用酷狗歌单广场接口，无平台切换。
struct PlaylistSquareView: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.beansUsesSharedRootBackdrop) private var usesSharedRootBackdrop
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    @State private var playlists: [Playlist] = []
    @State private var selectedCategory = PlaylistSquareCategory.all.id
    @State private var categories: [PlaylistSquareCategory] = [.all]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var expanded = false

    private var isNativeClean: Bool {
        BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    private var visiblePlaylists: [Playlist] {
        expanded ? playlists : Array(playlists.prefix(18))
    }

    private var usesIPadCatalogueLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        let _ = theme.accent
        ZStack {
            if !usesSharedRootBackdrop {
                Color.beansBackground
                    .ignoresSafeArea()
            }
            BeansNavigationStack {
                ZStack {
                    if !usesSharedRootBackdrop {
                        GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                    }
                    VStack(spacing: 0) {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 18) {
                                if categories.count > 1 {
                                    categoryChips
                                }
                                if isLoading && playlists.isEmpty {
                                    playlistLoadingGrid
                                } else if let errorMessage, playlists.isEmpty {
                                    ErrorStateView(message: errorMessage) {
                                        Task { await load(force: true) }
                                    }
                                    .frame(minHeight: 220)
                                } else if playlists.isEmpty {
                                    EmptyStateView(icon: "music.note.list", text: beansLocalized("酷狗歌单广场暂时没有内容", "No Kugou playlists available"))
                                        .frame(maxWidth: .infinity, minHeight: 220)
                                } else {
                                    playlistGrid
                                    if playlists.count > 18 {
                                        expandButton
                                    }
                                }
                                Color.clear.frame(height: 100)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 2)
                        }
                        .beansScrollIndicatorsHidden()
                        .background(Color.clear)
                    }
                }
                .task(id: selectedCategory) {
                    await load(force: false)
                }
                .task {
                    await loadCategories()
                }
                .navigationTitle(beansLocalized("精选", "Curated"))
                .navigationBarTitleDisplayMode(.inline)
            }
            .beansHomeNavigationBarTransparent()
            .background(Color.clear)
        }
        .background(Color.clear)
    }

    private var playlistColumns: [GridItem] {
        if usesIPadCatalogueLayout {
            return [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 16)]
        }
        return [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { category in
                    Button {
                        guard selectedCategory != category.id else { return }
                        BeansHaptics.tap()
                        selectedCategory = category.id
                        playlists = []
                        expanded = false
                    } label: {
                        Text(LocalizedStringKey(category.name))
                            .font(BeansFont.appFont(12, .medium))
                            .foregroundStyle(selectedCategory == category.id ? Color.white : Color.beansComment)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background {
                                ZStack {
                                    BeansGlass(shape: Capsule(), forceLiquid: true)
                                    if selectedCategory == category.id {
                                        Capsule().fill(Color.beansAmber.opacity(0.78))
                                    }
                                }
                            }
                    }
                    .buttonStyle(GlassPressButtonStyle(scale: 0.95))
                }
            }
        }
    }

    private var playlistGrid: some View {
        LazyVGrid(
            columns: playlistColumns,
            alignment: .center,
            spacing: usesIPadCatalogueLayout ? 18 : 20
        ) {
            ForEach(visiblePlaylists) { playlist in
                NavigationLink(destination: PlaylistView(playlist: playlist)) {
                    if usesIPadCatalogueLayout {
                        playlistCard(playlist, showsContainer: false)
                    } else {
                        largePlaylistCard(playlist)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .buttonStyle(GlassPressButtonStyle(scale: 0.97))
            }
        }
    }

    private var playlistLoadingGrid: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
                .tint(Color.beansAmber)
            Text(beansLocalized("正在加载歌单", "Loading playlists"))
                .font(BeansFont.appFont(12))
                .foregroundStyle(Color.beansComment)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private func playlistCard(_ playlist: Playlist, showsContainer: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            CoverImage(url: playlist.coverURL, size: 150, cornerRadius: 11)
            Text(playlist.name)
                .font(BeansFont.appFont(13, .medium))
                .foregroundStyle(Color.beansLabel)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack(spacing: 5) {
                if playlist.playCount > 0 {
                    Label(formatPlaylistPlayCount(playlist.playCount), systemImage: "play.fill")
                }
                if playlist.trackCount > 0 {
                    if playlist.playCount > 0 { Text("·") }
                    Text(beansSongCountText(playlist.trackCount))
                }
                if !playlist.creatorName.isEmpty {
                    if playlist.trackCount > 0 { Text("·") }
                    Text(playlist.creatorName)
                        .lineLimit(1)
                }
            }
            .font(BeansFont.appFont(10.5))
            .foregroundStyle(Color.beansComment)
            .opacity(playlist.trackCount > 0 || !playlist.creatorName.isEmpty ? 1 : 0)
            .frame(height: 14, alignment: .leading)
        }
        .frame(width: 150, alignment: .leading)
        .padding(isNativeClean ? 0 : 8)
        .background {
            if showsContainer, !isNativeClean {
                BeansGlass(shape: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func largePlaylistCard(_ playlist: Playlist) -> some View {
        GeometryReader { proxy in
            VStack(spacing: 8) {
                CoverImage(url: playlist.coverURL, size: proxy.size.width, cornerRadius: 11)
                Text(playlist.name)
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(playlist.creatorName)
                    .font(BeansFont.appFont(12))
                    .foregroundStyle(Color.beansComment)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(width: proxy.size.width, alignment: .top)
        }
        .aspectRatio(0.78, contentMode: .fit)
        .contentShape(Rectangle())
    }

    private func formatPlaylistPlayCount(_ count: Int) -> String {
        if count >= 100_000_000 { return String(format: "%.1f亿", Double(count) / 100_000_000) }
        if count >= 10_000 { return String(format: "%.1f万", Double(count) / 10_000) }
        return "\(count)"
    }

    private var expandButton: some View {
        Button {
            BeansHaptics.select()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                expanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Text(expanded
                     ? beansLocalized("收起歌单", "Collapse playlists")
                     : beansLocalized("展开全部（\(playlists.count)）", "Show all (\(playlists.count))"))
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
            }
            .font(BeansFont.appFont(13, .semibold))
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
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.97))
    }

    private func loadCategories() async {
        guard let cats = try? await KugouMusicAPI.shared.playlistCategories() else { return }
        await MainActor.run { categories = cats }
    }

    private func load(force: Bool) async {
        if !force, !playlists.isEmpty { return }
        let category = categories.first(where: { $0.id == selectedCategory }) ?? .all
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            let list = try await KugouMusicAPI.shared.playlists(categoryID: category.remoteID ?? 0, limit: 30)
            await MainActor.run {
                playlists = list
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
