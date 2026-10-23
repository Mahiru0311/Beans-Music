import SwiftUI

struct SongCell: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    @AppStorage("beans.showSongVIPBadge") private var showSongVIPBadge = true
    private let downloadFeatureUnlocked = true

    let song: Song
    var showCover = true
    // 1.8.7（2.0.3 SongCell 同款参数）：歌单详情页用 46pt 封面 + 64pt 固定行高。
    var coverSize: CGFloat = 46
    var fixedRowHeight: CGFloat?
    /// 玻璃行模式：为行添加清透液态玻璃底（二级列表页统一风格用）
    var glassRow = false
    /// 需要整体玻璃容器时，单行保持纯净背景
    var suppressNativeCleanRowGlass = false
    /// 深色详情页专用：1.9.1 修复——SongCell 的 beansLabel/beansComment 是 UIColor
    /// 动态色，只跟 UIKit trait（根主题浅色）走，在强制深色的详情页里仍是黑字；
    /// 本参数为真时歌名/歌手/时长直接用白/浅灰，不依赖 trait，保证深色底可读。
    var darkPage = false
    var playbackContext: [Song] = []
    var playbackIndex: Int?
    var onTap: (() -> Void)?

    @State private var showAddToPlaylist = false
    @State private var shareFile: ShareFileItem?
    @State private var appeared = false

    private var isCurrent: Bool {
        player.currentSong?.identityKey == song.identityKey
    }

    private var isNativeClean: Bool {
        BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    // 1.8.7：歌名/歌手分开展示。部分酷狗歌单数据（尤其缓存过的旧数据）
    // 把“歌手 - 歌名”整个塞进 name、artists 为空，照原样显示就会出现截图里
    // “任贤齐 - 心太软 / 未知歌手”这种行；这里在显示层拆开，artists 仍为空时
    // 副标题只显示专辑、专辑也空就干脆不显示副标题，绝不编造“未知歌手”。
    private var displayName: String {
        if song.artists.isEmpty, let range = song.name.range(of: " - ") {
            return String(song.name[range.upperBound...])
        }
        return song.name
    }
    private var displayArtists: String {
        if !song.artists.isEmpty { return song.artists }
        if let range = song.name.range(of: " - ") {
            return String(song.name[..<range.lowerBound])
        }
        return song.album
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            if showCover {
                CoverImage(url: song.coverURL, size: coverSize, cornerRadius: 10)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(BeansFont.appFont(15, isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? Color.beansAmber : (darkPage ? .white : Color.beansLabel))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    if showSongVIPBadge, song.isVIP {
                        Text("VIP")
                            .font(BeansFont.appFont(9, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Color(red: 0.93, green: 0.25, blue: 0.22)))
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                if !displayArtists.isEmpty {
                    Text(displayArtists)
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(darkPage ? .white.opacity(0.6) : Color.beansComment)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            if isCurrent && player.isPlaying {
                NowPlayingIndicator()
            } else {
                Text(song.formattedDuration)
                    .font(BeansFont.appFont(12, .regular, .monospaced))
                    .foregroundStyle(darkPage ? .white.opacity(0.6) : Color.beansComment)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .frame(height: fixedRowHeight)
        .padding(.vertical, fixedRowHeight == nil ? 6 : 0)
        .contentShape(Rectangle())
        .scaleEffect(isCurrent ? 1.012 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isCurrent)
        .onTapGesture {
            onTap?()
        }
        .contextMenu {
            Button {
                player.playNext(song)
            } label: {
                Label("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            Button {
                showAddToPlaylist = true
            } label: {
                Label("添加到歌单", systemImage: "text.badge.plus")
            }
            if downloadFeatureUnlocked {
                Button {
                    Task { await downloadSong() }
                } label: {
                    Label("下载歌曲", systemImage: "arrow.down.circle")
                }
            }
            if !isCurrent {
                Button {
                    if let playbackIndex, !playbackContext.isEmpty {
                        player.play(songs: playbackContext, startAt: playbackIndex)
                    } else if let index = player.queue.firstIndex(of: song) {
                        player.playQueueIndex(index)
                    } else {
                        player.play(songs: [song], startAt: 0)
                    }
                } label: {
                    Label("立即播放", systemImage: "play.fill")
                }
            }
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToLocalPlaylistSheet(song: song)
                .environmentObject(theme)
        }
        .sheet(item: $shareFile) { item in
            ShareSheet(items: [item.url])
        }
    }

    @MainActor
    private func downloadSong() async {
        // Co：下载功能已删（原 DownloadManager 已删）。
        ToastCenter.shared.show("下载功能已删")
    }

    var body: some View {
        let _ = theme.accent
        Group {
        if glassRow || (isNativeClean && !suppressNativeCleanRowGlass) {
                rowContent
                    .padding(.horizontal, 10)
                    .background {
                                            BeansGlass(shape: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
            } else {
                rowContent
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .animation(.easeOut(duration: 0.28), value: appeared)
        .onAppear { appeared = true }
    }
}
