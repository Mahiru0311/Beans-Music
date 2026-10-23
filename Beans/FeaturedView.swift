import SwiftUI

/// 1.8.7 精选页：底栏“精选”标签的内容，走 Co 现有发现页的数据源
/// （酷狗歌单广场推荐 + 酷狗排行榜），不做聚合/平台切换，不带回网易云/QQ 音源。
struct FeaturedView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @State private var playlists: [Playlist] = []
    @State private var tops: [KugouTopInfo] = []
    @State private var loading = true

    var body: some View {
        let _ = theme.accent
        BeansNavigationStack {
            ZStack(alignment: .top) {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                TabBarAppearanceConfigurator()
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        Text("精选")
                            .font(BeansFont.appFont(28, .bold))
                            .foregroundStyle(Color.beansLabel)
                            .padding(.top, 8)
                        if loading {
                            ProgressView().frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            if !playlists.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionHeader(title: "歌单广场")
                                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                        ForEach(playlists) { playlist in
                                            NavigationLink {
                                                PlaylistView(playlist: playlist)
                                                    .environmentObject(player)
                                                    .environmentObject(auth)
                                                    .environmentObject(theme)
                                            } label: {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    // 网格封面不用 CoverImage（它按固定尺寸渲染），直接用
                                                    // AsyncImage 按正方形拉伸裁剪，保证两列等宽等高。
                                                    ZStack {
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .fill(Color.beansGlassFill)
                                                        AsyncImage(url: playlist.coverURL) { phase in
                                                            if case .success(let image) = phase {
                                                                image.resizable().scaledToFill()
                                                            }
                                                        }
                                                    }
                                                    .aspectRatio(1, contentMode: .fit)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                    Text(playlist.name)
                                                        .font(BeansFont.appFont(13, .semibold))
                                                        .foregroundStyle(Color.beansLabel)
                                                        .lineLimit(2)
                                                    if playlist.trackCount > 0 {
                                                        Text("\(playlist.trackCount) 首")
                                                            .font(BeansFont.appFont(11))
                                                            .foregroundStyle(Color.beansComment)
                                                    }
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            if !tops.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionHeader(title: "排行榜")
                                    VStack(spacing: 8) {
                                        ForEach(tops) { top in
                                            NavigationLink {
                                                KugouTopListDetailView(topList: top)
                                                    .environmentObject(player)
                                                    .environmentObject(theme)
                                                    .environmentObject(auth)
                                            } label: {
                                                HStack(spacing: 10) {
                                                    CoverImage(url: top.coverURL, size: 44, cornerRadius: 10)
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(beansChartName(top.name))
                                                            .font(BeansFont.appFont(14, .semibold))
                                                            .foregroundStyle(Color.beansLabel)
                                                            .lineLimit(1)
                                                        if !top.updateFrequency.isEmpty {
                                                            Text(beansChartSubtitle(top.updateFrequency))
                                                                .font(BeansFont.appFont(12))
                                                                .foregroundStyle(Color.beansComment)
                                                                .lineLimit(1)
                                                        }
                                                    }
                                                    Spacer()
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 12, weight: .semibold))
                                                        .foregroundStyle(Color.beansComment.opacity(0.7))
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)) }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            if playlists.isEmpty && tops.isEmpty {
                                Text("精选内容加载失败，下拉回到主页再试")
                                    .font(BeansFont.appFont(13))
                                    .foregroundStyle(Color.beansComment)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 190)
                    .frame(maxWidth: 860)
                    .frame(maxWidth: .infinity)
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("精选")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            guard loading else { return }
            async let pp = try? KugouMusicAPI.shared.recommendPlaylists(limit: 12)
            async let tt = try? KugouMusicAPI.shared.topLists(limit: 10)
            playlists = await pp ?? []
            tops = await tt ?? []
            loading = false
        }
    }
}
