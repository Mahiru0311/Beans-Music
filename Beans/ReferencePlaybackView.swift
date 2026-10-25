import SwiftUI
import MediaPlayer
import UIKit

private struct ReferenceLyricCenterKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]

    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct ReferencePlaybackPresentationMetrics {
    static let headerTopSpacing: CGFloat = 20
}

struct ReferencePlaybackView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    @EnvironmentObject private var favorites: FavoritesStore
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var localLibrary = LocalLibraryStore.shared
    @ObservedObject private var appleLayout = AppleMusicLayoutStore.shared
    /// 封面歌词预览开关（与自定义布局编辑器共用同一键）：开 = 隐藏封面页歌词预览。
    @AppStorage("co.coverLyricsHidden") private var hideCoverLyrics = true
    @ObservedObject private var customCovers = CustomSongCoverStore.shared

    let song: Song?
    let lyrics: [LyricLine]
    @Binding var showLyrics: Bool
    @Binding var showQueue: Bool
    let onFavorite: () -> Void
    let onComments: () -> Void
    let onSleepTimer: () -> Void
    let onAddToLocalPlaylist: () -> Void
    let onPlayerSettings: () -> Void
    let onArtist: () -> Void
    // 注意：不要在这里加左上角收起键——用户已明确不要下拉图标，
    // 播放页收起只走下拉手势（RootView 的本地下拉手势）。

    @AppStorage("co.lyricOffset") private var lyricOffset = 0.0
    @AppStorage("co.appleMusic.showVolume") private var showVolumeControl = false
    @AppStorage("co.appleMusic.primaryHex") private var primaryHex = ""
    @AppStorage("co.appleMusic.secondaryHex") private var secondaryHex = ""
    @AppStorage("co.appleMusic.accentHex") private var accentHex = ""
    @AppStorage("co.appleMusic.volumeHex") private var volumeHex = ""
    @AppStorage("co.appleMusic.syncWallpaper") private var syncWallpaper = false
    @AppStorage("co.appleMusic.wallpaperBlur") private var wallpaperBlur = 14.0
    @AppStorage("co.showSongVIPBadge") private var showSongVIPBadge = true
    @Namespace private var coverMorphNamespace
    @State private var lyricCenters: [UUID: CGFloat] = [:]
    /// 封面过渡进度：0 = 封面页，1 = 歌词页。由 @State 持有、不再直接派生自 showLyrics——
    /// 派生值在分支切换时可能丢终态（歌词页里封面弹回大图），@State 跨重建保留，稳态一定对。
    @State private var coverProgress: Double = 0
    @State private var showClearQueueConfirm = false
    @State private var showLandscapeControls = true
    @State private var landscapeDragging = false
    @State private var landscapeScrubTime = 0.0
    @State private var focusedLyricID: UUID?
    @State private var selectedLyricID: UUID?
    @State private var lyricsViewportHeight: CGFloat = 0
    @State private var isDraggingLyrics = false
    @GestureState private var lyricDragActive = false
    @State private var resumeTask: Task<Void, Never>?
    @State private var lyricTapTask: Task<Void, Never>?
    @State private var showSoftwareVolume = false
    @State private var showLyricOffsetSheet = false

    init(
        song: Song?,
        lyrics: [LyricLine],
        showLyrics: Binding<Bool>,
        showQueue: Binding<Bool>,
        onFavorite: @escaping () -> Void,
        onComments: @escaping () -> Void,
        onSleepTimer: @escaping () -> Void,
        onAddToLocalPlaylist: @escaping () -> Void,
        onPlayerSettings: @escaping () -> Void,
        onArtist: @escaping () -> Void = {}
    ) {
        self.song = song
        self.lyrics = lyrics
        self._showLyrics = showLyrics
        self._showQueue = showQueue
        self.onFavorite = onFavorite
        self.onComments = onComments
        self.onSleepTimer = onSleepTimer
        self.onAddToLocalPlaylist = onAddToLocalPlaylist
        self.onPlayerSettings = onPlayerSettings
        self.onArtist = onArtist
    }

    private func layoutEntry(_ part: AppleMusicLayoutPart) -> PlayerLayoutEntry {
        appleLayout.entry(for: part)
    }

    private var displayCoverURL: URL? {
        customCovers.url(for: song) ?? song?.coverURL
    }

    private func displayCoverURL(for song: Song?) -> URL? {
        customCovers.url(for: song) ?? song?.coverURL
    }

    var body: some View {
        GeometryReader { geometry in
            if UIDevice.current.userInterfaceIdiom == .phone && geometry.size.width > geometry.size.height {
                landscapeBody(size: geometry.size)
            } else {
            ZStack {
                playerBackground

                VStack(spacing: 0) {
                    Color.clear.frame(height: ReferencePlaybackPresentationMetrics.headerTopSpacing)

                    ZStack {
                        if showQueue {
                            compactQueuePage
                                .transition(.opacity)
                        } else {
                            // 前端同款结构：封面常驻一层（下面 persistentCover），不再换页换封面——
                            // 封面位置/大小/圆角/阴影全部由 WebCoverProgressModifier 按前端百分比数学算，路径是弧线不是直线。
                            ZStack(alignment: .topLeading) {
                                if showLyrics {
                                    lyricsPage
                                } else {
                                    coverPage(size: geometry.size)
                                }
                                GeometryReader { upperGeometry in
                                    persistentCover(upperSize: upperGeometry.size, fullSize: geometry.size)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // 一个状态开关，全体 0.38s 同一条贝塞尔曲线：封面弧线收进页眉、歌名缩小、歌词淡入上浮。
                    .animation(.timingCurve(0.32, 0.72, 0.28, 1, duration: 0.38), value: showLyrics)
                    .animation(.easeInOut(duration: 0.22), value: showQueue)

                    playbackControls(bottomInset: geometry.safeAreaInsets.bottom)
                }

            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear {
            // 稳态直接对齐：恢复到歌词页打开时，首帧就是小封面，不经过大图闪一下。
            coverProgress = showLyrics ? 1 : 0
        }
        .onChange(of: showLyrics) { newValue in
            withAnimation(.timingCurve(0.32, 0.72, 0.28, 1, duration: 0.38)) {
                coverProgress = newValue ? 1 : 0
            }
        }
        .onDisappear {
            resumeTask?.cancel()
            lyricTapTask?.cancel()
            isDraggingLyrics = false
            selectedLyricID = nil
            focusedLyricID = nil
        }
        .sheet(isPresented: $showSoftwareVolume) {
            CoSoftwareVolumeSheetHost()
                .environmentObject(player)
        }
        .sheet(isPresented: $showLyricOffsetSheet) {
            CoLyricOffsetSheet()
        }
    }

    // 横屏（手机）：封面在左、其余在右。控制直接长在布局里，不做悬浮胶囊：
    // 进度条在封面下边（留空隙，不紧挨着），三颗播放键在右栏底部最靠右边（与歌词留空隙）。
    // 点空白处切换显隐：隐藏后控制占位消失、歌词展开填满（不是留空白），出现/消失带滑出+淡出动画；
    // 内容上下居中：隐藏时不再全堆在上面、底部不再空一大块；显隐时整体平滑移动，封面大小不变。
    private func landscapeBody(size: CGSize) -> some View {
        let artworkSize = min(size.height - 64, size.width * 0.42)
        let duration = clock.duration.isFinite ? max(1, clock.duration) : 1
        return ZStack {
            playerBackground
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { showLandscapeControls.toggle() }
            HStack(spacing: 24) {
                VStack(spacing: 16) {
                    CoverImage(url: displayCoverURL, size: artworkSize, cornerRadius: 16)
                        .frame(width: artworkSize, height: artworkSize)
                    if showLandscapeControls {
                        Slider(value: Binding(get: { landscapeDragging ? landscapeScrubTime : clock.progress }, set: { landscapeScrubTime = $0 }),
                               in: 0...duration, onEditingChanged: { editing in
                            if editing { landscapeScrubTime = clock.progress }
                            landscapeDragging = editing
                            if !editing { player.seekPrecisely(to: landscapeScrubTime) }
                        })
                        .tint(primaryColor)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song?.name ?? "未在播放")
                            .font(CoFont.appFont(22, .bold))
                            .foregroundStyle(primaryColor)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(CoFont.appFont(13.5, .medium))
                            .foregroundStyle(secondaryColor)
                            .lineLimit(1)
                    }
                    AppleMusicLyricsSection(
                        lyrics: lyrics,
                        primary: primaryColor,
                        secondary: secondaryColor,
                        lyricOffset: CGFloat(lyricOffset)
                    ) { line in
                        player.seekPrecisely(to: LyricTiming.seekTime(for: line, userOffset: lyricOffset))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if showLandscapeControls {
                        HStack {
                            Spacer()
                            HStack(spacing: 36) {
                                Button { player.previous() } label: { Image(systemName: "backward.fill").frame(width: 44, height: 44) }
                                Button { player.togglePlayPause() } label: { Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").frame(width: 44, height: 44) }
                                Button { player.next() } label: { Image(systemName: "forward.fill").frame(width: 44, height: 44) }
                            }
                            .font(.title3)
                            .foregroundStyle(primaryColor)
                        }
                        .padding(.top, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(width: size.width, height: size.height)
            .animation(.easeOut(duration: 0.3), value: showLandscapeControls)
        }
    }

    @ViewBuilder
    private var playerBackground: some View {
        ZStack {
            // Full-screen covers need an opaque base so the home page cannot show through
            // while the cover image is loading or when a presentation uses a clear surface.
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            if false {
            } else if syncWallpaper, let image = theme.customBackgroundImage(for: colorScheme) {
                WallpaperImage(image: image)
                    .blur(radius: CGFloat(wallpaperBlur))
                    .scaleEffect(wallpaperBlur > 0 ? 1.08 : 1)
                    .overlay(Color.black.opacity(colorScheme == .dark ? 0.44 : 0.16))
                    .ignoresSafeArea()
            } else if syncWallpaper, let color = theme.customBackground(for: colorScheme) {
                LinearGradient(
                    colors: [color.opacity(0.92), color.opacity(0.58), colorScheme == .dark ? .black.opacity(0.88) : .white.opacity(0.70)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blur(radius: CGFloat(wallpaperBlur * 0.35))
                .ignoresSafeArea()
            } else {
                CoverBlurBackground(url: displayCoverURL, scheme: colorScheme)
                    .overlay {
                        // 前端同款：背景罩不是整块黑 0.48，而是黑色渐变（上 0.22、中 0.10、下 0.42），
                        // 封面颜色透得出来，整体亮到前端那个程度；浅色模式保持原样，保证文字可读。
                        if colorScheme == .dark {
                            LinearGradient(
                                stops: [
                                    .init(color: .black.opacity(0.22), location: 0),
                                    .init(color: .black.opacity(0.10), location: 0.40),
                                    .init(color: .black.opacity(0.42), location: 1),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        } else {
                            Color.black.opacity(0.14)
                        }
                    }
                    .ignoresSafeArea()
            }
        }
    }

    private var previewLyrics: [LyricLine] {
        guard !lyrics.isEmpty else { return [] }
        let current = currentPlaybackLyricIndex ?? 0
        let start = max(current - 1, 0)
        let end = min(start + 3, lyrics.count)
        return Array(lyrics[start..<end])
    }

    private func coverPage(size: CGSize) -> some View {
        let contentWidth = max(size.width - 64, 0)
        let artworkSize = min(contentWidth, min(size.height * 0.50, 390))

        return VStack(spacing: 0) {
            Spacer(minLength: 8)

            // 常驻封面在外层 ZStack 里（persistentCover），这里只留同尺寸占位，标题位置与原来一致。
            Color.clear.frame(width: artworkSize, height: artworkSize)

            VStack(spacing: 5) {
                HStack(spacing: 9) {
                    // VIP 角标在右侧会把歌名顶偏：左侧补一个看不见的同尺寸角标平衡，歌名回到正中，与歌手同轴。
                    if showSongVIPBadge, song?.isVIP == true {
                        Text("VIP")
                            .font(CoFont.appFont(9, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.coThemeRed, in: Capsule())
                            .hidden()
                    }
                Text(song?.name ?? "未在播放")
                    .font(CoFont.appFont(showLyrics ? 15 : 22, .bold))
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contextMenu {
                        Button("复制歌名") {
                            copySongTitle()
                        }
                    }
                    if showSongVIPBadge, song?.isVIP == true {
                        Text("VIP")
                            .font(CoFont.appFont(9, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.coThemeRed, in: Capsule())
                    }
                }
                Text(subtitle)
                    .font(CoFont.appFont(showLyrics ? 12 : 13.5, .medium))
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onArtist)
            }
            .frame(maxWidth: 420)
            .padding(.top, 22)
            .modifier(AppleMusicLayoutTransform(entry: layoutEntry(.title)))
            .matchedGeometryEffect(id: "appleMusicTitle", in: coverMorphNamespace)

            if !hideCoverLyrics {
                // 封面页歌词预览：标题下方三行（上一句/当前句/下一句），点它进歌词页；无歌词时显示“暂无歌词”。
                // 开关在自定义布局编辑器里（隐藏封面歌词），只影响封面页，完整歌词页不受影响。
                MiniLyricsPreview(lines: previewLyrics, primary: primaryColor, secondary: secondaryColor) {
                    CoHaptics.tap()
                    withAnimation(.timingCurve(0.32, 0.72, 0.28, 1, duration: 0.38)) {
                        showLyrics = true
                    }
                }
                .padding(.top, 18)
                .modifier(AppleMusicLayoutTransform(entry: layoutEntry(.previewLyric)))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
    }

    private var lyricsPage: some View {
        VStack(spacing: 0) {
            lyricsHeaderRow
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

            if lyrics.isEmpty {
                emptyLyricsView
                    .transition(.modifier(active: LyricsEnterModifier(opacity: 0, offsetY: 14), identity: LyricsEnterModifier(opacity: 1, offsetY: 0)))
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 26) {
                            Color.clear.frame(height: max(88, lyricsViewportHeight * 0.30))
                            ForEach(lyrics) { line in
                                lyricLine(line, isFocused: line.id == currentVisualLyricID, proxy: proxy)
                                    .id(line.id)
                                    .background {
                                        GeometryReader { rowGeometry in
                                            Color.clear.preference(
                                                key: ReferenceLyricCenterKey.self,
                                                value: [line.id: rowGeometry.frame(in: .named("referenceLyricsViewport")).midY]
                                            )
                                        }
                                    }
                            }
                            Color.clear.frame(height: max(110, lyricsViewportHeight * 0.34))
                        }
                        .padding(.horizontal, 28)
                    }
                    .coordinateSpace(name: "referenceLyricsViewport")
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black, location: 0.12),
                                .init(color: .black, location: 0.84),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .background {
                        GeometryReader { viewport in
                            Color.clear
                                .onAppear { lyricsViewportHeight = viewport.size.height }
                                .onChange(of: viewport.size.height) { lyricsViewportHeight = $0 }
                        }
                    }
                    .onPreferenceChange(ReferenceLyricCenterKey.self) { centers in
                        lyricCenters = centers
                        updateFocusedLyric(from: centers)
                        if isDraggingLyrics, !lyricDragActive { scheduleLyricResume(proxy: proxy) }
                    }
                    .simultaneousGesture(lyricsDragGesture(proxy: proxy))
                    .onChange(of: lyricDragActive) { active in
                        if !active, isDraggingLyrics { scheduleLyricResume(proxy: proxy) }
                    }
                    .onChange(of: lyrics.first?.id) { _ in
                        resumeTask?.cancel()
                        lyricTapTask?.cancel()
                        isDraggingLyrics = false
                        selectedLyricID = nil
                        focusedLyricID = nil
                        scrollToPlaybackLyric(proxy: proxy, animated: false)
                    }
                    .onDisappear {
                        resumeTask?.cancel()
                        lyricTapTask?.cancel()
                        isDraggingLyrics = false
                        selectedLyricID = nil
                        focusedLyricID = nil
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                            scrollToPlaybackLyric(proxy: proxy, animated: false)
                        }
                    }
                    .onChange(of: currentPlaybackLyricID) { _ in
                        guard !isDraggingLyrics else { return }
                        scrollToPlaybackLyric(proxy: proxy, animated: true)
                    }
                }
                .transition(.modifier(active: LyricsEnterModifier(opacity: 0, offsetY: 14), identity: LyricsEnterModifier(opacity: 1, offsetY: 0)))
            }
        }
    }

    private var lyricsHeaderRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(song?.name ?? "未在播放")
                        .font(CoFont.appFont(showLyrics ? 15 : 22, .semibold))
                        .matchedGeometryEffect(id: "appleMusicTitle", in: coverMorphNamespace)
                        .foregroundStyle(primaryColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .contextMenu {
                            Button("复制歌名") {
                                copySongTitle()
                            }
                        }
                    if showSongVIPBadge, song?.isVIP == true {
                        Text("VIP")
                            .font(CoFont.appFont(9, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.coThemeRed, in: Capsule())
                    }
                }
                Text(subtitle)
                    .font(CoFont.appFont(showLyrics ? 12 : 13.5, .medium))
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onArtist)
            }
            .transition(.opacity)
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                favoriteActionButton()
                Menu {
                    Button("定时关闭", action: onSleepTimer)
                    Button("添加到本地歌单", action: onAddToLocalPlaylist)
                    customCoverActions
                    Menu("播放音质") {
                    CoAudioQualityMenu()
                }
                Button("播放器设置", action: onPlayerSettings)
                    Button("歌词偏移") {
                        showLyricOffsetSheet = true
                    }
                    Button("软件音量") {
                        showSoftwareVolume = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(primaryColor.opacity(0.78))
                        .frame(width: 38, height: 38)
                        .contentShape(Rectangle())
                }
            }
            .transition(.opacity)
        }
        // 小封面在常驻层（persistentCover），行高固定 48 与原来一致，标题左移 60 到原来小封面右端。
        .padding(.leading, 60)
        .frame(height: 48)
    }

    private func playbackControls(bottomInset: CGFloat) -> some View {
        AppleMusicPlaybackControls(
            bottomInset: bottomInset,
            primary: primaryColor,
            secondary: secondaryColor,
            accent: accentColor,
            volumeColor: volumeColor,
            showVolume: showVolumeControl,
            lyricsActive: showLyrics,
            queueActive: showQueue,
            layout: AppleMusicPlaybackControlLayout(
                progress: layoutEntry(.progress),
                previous: layoutEntry(.previous),
                play: layoutEntry(.play),
                next: layoutEntry(.next),
                volume: layoutEntry(.volume),
                actions: layoutEntry(.actions),
                container: PlayerLayoutEntry()
            ),
            onLyrics: {
                withAnimation(.timingCurve(0.32, 0.72, 0.28, 1, duration: 0.38)) {
                    if showQueue {
                        showQueue = false
                        showLyrics = true
                    } else {
                        showLyrics.toggle()
                    }
                }
            },
            onQueue: {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showQueue.toggle()
                }
            },
            onComments: onComments
        )
    }

    private var compactQueuePage: some View {
        VStack(spacing: 12) {
            compactQueueHeader
            AppleMusicCompactQueueContent()
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 4)
    }

    private var compactQueueHeader: some View {
        HStack(spacing: 11) {
            CoverImage(url: displayCoverURL, size: 46, cornerRadius: 10)
                .shadow(color: .black.opacity(0.26), radius: 9, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(song?.name ?? "未在播放")
                    .font(CoFont.appFont(16, .bold))
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)
                    .contextMenu {
                        Button("复制歌名") {
                            copySongTitle()
                        }
                    }
                Text(song?.artists ?? "")
                    .font(CoFont.appFont(12, .medium))
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onArtist)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            favoriteActionButton()

            Menu {
                Button("清空播放列表", role: .destructive) {
                    showClearQueueConfirm = true
                }
                Divider()
                Button("定时关闭", action: onSleepTimer)
                Button("添加到本地歌单", action: onAddToLocalPlaylist)
                customCoverActions
                Menu("播放音质") {
                    CoAudioQualityMenu()
                }
                Button("播放器设置", action: onPlayerSettings)
                Button("软件音量") {
                    showSoftwareVolume = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(primaryColor.opacity(0.78))
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .alert("清空播放列表", isPresented: $showClearQueueConfirm) {
                Button("清空", role: .destructive) { player.clearQueue() }
                Button("取消", role: .cancel) { }
            } message: {
                Text("将清空除正在播放外的全部歌曲。")
            }
        }
    }

    @ViewBuilder
    private var customCoverActions: some View {
        if let song {
            if customCovers.isVideoCover(for: song) {
                Toggle(
                    "播放视频封面声音",
                    isOn: Binding(
                        get: { customCovers.videoAudioEnabled(for: customCovers.url(for: song)) },
                        set: { customCovers.setVideoAudioEnabled($0, for: song) }
                    )
                )
            }
            if customCovers.hasCover(for: song) {
                Button("恢复默认封面", role: .destructive) {
                    customCovers.removeCover(for: song)
                    ToastCenter.shared.show("已恢复默认封面")
                }
            }
        }
    }


    private var emptyLyricsView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "quote.bubble")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.white.opacity(0.42))
            Text("暂无歌词")
                .font(CoFont.appFont(15, .semibold))
                .foregroundStyle(.white.opacity(0.86))
            Text("点击封面区域返回歌曲页面")
                .font(CoFont.appFont(12))
                .foregroundStyle(.white.opacity(0.46))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            CoHaptics.tap()
            withAnimation(.timingCurve(0.32, 0.72, 0.28, 1, duration: 0.38)) {
                showLyrics = false
            }
        }
    }

    private var currentPlaybackLyricIndex: Int? {
        guard !lyrics.isEmpty else { return nil }
        let progress = LyricTiming.effectiveProgress(clock.progress, userOffset: lyricOffset)
        var low = 0
        var high = lyrics.count - 1
        var answer: Int?
        while low <= high {
            let mid = (low + high) / 2
            if lyrics[mid].time <= progress {
                answer = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return answer
    }

    private var currentPlaybackLyricID: UUID? {
        guard let index = currentPlaybackLyricIndex, lyrics.indices.contains(index) else { return nil }
        return lyrics[index].id
    }

    private var currentVisualLyricID: UUID? {
        isDraggingLyrics ? (focusedLyricID ?? currentPlaybackLyricID) : currentPlaybackLyricID
    }

    private var subtitle: String {
        guard let song else { return "" }
        let parts = [song.artists, song.album].filter { !$0.isEmpty }
        return parts.isEmpty ? "未知歌曲" : parts.joined(separator: " · ")
    }

    private func copySongTitle() {
        guard let title = song?.name.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return }
        UIPasteboard.general.string = title
        CoHaptics.success()
        ToastCenter.shared.show("歌名已复制")
    }

    private func lyricLine(_ line: LyricLine, isFocused: Bool, proxy: ScrollViewProxy) -> some View {
        let isSelected = selectedLyricID == line.id || (isDraggingLyrics && isFocused)
        let visualFocus = isFocused || isSelected
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(line.text.isEmpty ? " " : line.text)
                    .font(CoFont.appFont(visualFocus ? 27 : 23, visualFocus ? .bold : .semibold))
                    .foregroundStyle(primaryColor.opacity(visualFocus ? 1 : 0.36))
                    .fixedSize(horizontal: false, vertical: true)
                if isSelected {
                    Spacer(minLength: 8)
                    Text(coTimeString(line.time))
                        .font(CoFont.appFont(11, .semibold, .default))
                        .foregroundStyle(secondaryColor.opacity(0.82))
                    Button {
                        lyricTapTask?.cancel()
                        playLyric(line, proxy: proxy)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(accentColor)
                            .frame(width: 24, height: 24)
                            .background(accentColor.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if visualFocus, let translation = line.translation, !translation.isEmpty {
                Text(translation)
                    .font(CoFont.appFont(15, .medium))
                    .foregroundStyle(secondaryColor.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .scaleEffect(visualFocus ? 1.06 : 0.84, anchor: .leading)
        .blur(radius: visualFocus ? 0 : 0.7)
        .onTapGesture {
            scheduleLyricSelection(line.id, proxy: proxy)
        }
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    lyricTapTask?.cancel()
                    playLyric(line, proxy: proxy)
                }
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: visualFocus)
    }

    private func scheduleLyricSelection(_ id: UUID, proxy: ScrollViewProxy) {
        lyricTapTask?.cancel()
        lyricTapTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                selectedLyricID = id
                isDraggingLyrics = true
            }
            scheduleLyricResume(proxy: proxy)
            CoHaptics.tap()
        }
    }

    private func playLyric(_ line: LyricLine, proxy: ScrollViewProxy) {
        selectedLyricID = nil
        resumeTask?.cancel()
        isDraggingLyrics = false
        focusedLyricID = nil
        CoHaptics.tap()
        player.seek(to: LyricTiming.seekTime(for: line, userOffset: lyricOffset))
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.3)) {
            proxy.scrollTo(line.id, anchor: .center)
        }
    }

    private func updateFocusedLyric(from centers: [UUID: CGFloat]) {
        guard lyricsViewportHeight > 0, !centers.isEmpty else { return }
        let center = lyricsViewportHeight / 2
        let nextID = centers.min { abs($0.value - center) < abs($1.value - center) }?.key
        focusedLyricID = nextID
        if isDraggingLyrics {
            selectedLyricID = nextID
        }
    }

    private func scrollToPlaybackLyric(proxy: ScrollViewProxy, animated: Bool) {
        guard let id = currentPlaybackLyricID else { return }
        let action = { proxy.scrollTo(id, anchor: .center) }
        if animated {
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.38)) { action() }
        } else {
            action()
        }
    }

    private func scheduleLyricResume(proxy: ScrollViewProxy) {
        resumeTask?.cancel()
        resumeTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 2_500_000_000) }
            catch { return }
            guard !Task.isCancelled, !lyricDragActive else { return }
            lyricTapTask?.cancel()
            isDraggingLyrics = false
            selectedLyricID = nil
            focusedLyricID = nil
            scrollToPlaybackLyric(proxy: proxy, animated: true)
        }
    }

    private func lyricsDragGesture(proxy: ScrollViewProxy) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($lyricDragActive) { _, active, _ in active = true }
            .onChanged { _ in
                lyricTapTask?.cancel()
                isDraggingLyrics = true
                resumeTask?.cancel()
                updateFocusedLyric(from: lyricCenters)
            }
            .onEnded { _ in
                resumeTask?.cancel()
                if let id = focusedLyricID {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
                scheduleLyricResume(proxy: proxy)
            }
    }

    private var primaryColor: Color {
        if primaryHex.hasPrefix("#"), let color = Color(hex: primaryHex) { return color }
        return .white
    }

    private var secondaryColor: Color {
        if secondaryHex.hasPrefix("#"), let color = Color(hex: secondaryHex) { return color }
        return .white.opacity(0.58)
    }

    private var accentColor: Color {
        if accentHex.hasPrefix("#"), let color = Color(hex: accentHex) { return color }
        return Color.coAppleMusicAccentFallback
    }

    private var volumeColor: Color {
        if volumeHex.hasPrefix("#"), let color = Color(hex: volumeHex) { return color }
        return primaryColor
    }

    private func favoriteActionButton() -> some View {
        Button {
            CoHaptics.tap()
            onFavorite()
        } label: {
            FavoriteHeartView(
                mark: favoriteMark,
                size: 17,
                inactiveColor: primaryColor.opacity(0.78)
            )
            .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
    }

    private var favoriteMark: FavoriteMark {
        guard let song else { return .none }
        let local = localLibrary.containsSong(song)
        let official = favorites.isOfficiallyLiked(song)
        switch (local, official) {
        case (true, true): return .both
        case (true, false): return .local
        case (false, true): return .official
        case (false, false): return .none
        }
    }
}

struct AppleMusicPlaybackControlLayout {
    let progress: PlayerLayoutEntry
    let previous: PlayerLayoutEntry
    let play: PlayerLayoutEntry
    let next: PlayerLayoutEntry
    let volume: PlayerLayoutEntry
    let actions: PlayerLayoutEntry
    let container: PlayerLayoutEntry
}

struct AppleMusicPlaybackControls: View {
    @EnvironmentObject private var player: PlayerManager

    let bottomInset: CGFloat
    let primary: Color
    let secondary: Color
    let accent: Color
    let volumeColor: Color
    let showVolume: Bool
    let lyricsActive: Bool
    let queueActive: Bool
    let layout: AppleMusicPlaybackControlLayout
    let onLyrics: () -> Void
    let onQueue: () -> Void
    let onComments: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            ReferenceScrubber()
                .modifier(AppleMusicLayoutTransform(entry: layout.progress))
                .contentShape(Rectangle())

            VStack(spacing: 15) {
                HStack(spacing: 28) {
                    Button {
                        CoHaptics.tap()
                        player.previous()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 25, weight: .semibold))
                            .frame(width: 42, height: 42)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .modifier(AppleMusicLayoutTransform(entry: layout.previous))

                    Button {
                        CoHaptics.tap()
                        player.togglePlayPause()
                    } label: {
                        PlayPauseMorphIcon(isPlaying: player.isPlaying, size: 24)
                            .frame(width: 66, height: 66)
                            .foregroundStyle(primary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(GlassPressButtonStyle(scale: 0.92))
                    .modifier(AppleMusicLayoutTransform(entry: layout.play))

                    Button {
                        CoHaptics.tap()
                        player.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 25, weight: .semibold))
                            .frame(width: 42, height: 42)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .modifier(AppleMusicLayoutTransform(entry: layout.next))
                }
                .foregroundStyle(primary)
                .frame(maxWidth: 320)

                if showVolume {
                    ReferenceVolumeControl(accent: volumeColor, secondary: secondary)
                        .frame(maxWidth: 420)
                        .modifier(AppleMusicLayoutTransform(entry: layout.volume))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                HStack(spacing: 44) {
                    actionButton(icon: lyricsActive && !queueActive ? "quote.bubble.fill" : "quote.bubble", active: lyricsActive && !queueActive, action: onLyrics)
                    actionButton(icon: "text.bubble", action: onComments)
                    actionButton(icon: "list.bullet", active: queueActive, action: onQueue)
                }
                .frame(maxWidth: 500)
                .modifier(AppleMusicLayoutTransform(entry: layout.actions))
            }
            .modifier(AppleMusicLayoutTransform(entry: layout.container))
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, max(14, bottomInset + 4))
    }

    private func actionButton(
        icon: String,
        active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            CoHaptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(active ? accent : primary.opacity(0.78))
                .frame(width: 58, height: 58)
                .background { CoGlass(shape: Circle(), forceLiquid: true) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}

struct AppleMusicCompactQueueContent: View {
    @EnvironmentObject private var player: PlayerManager
    var body: some View {
        let upcoming = Array(player.upcomingQueue.prefix(100))
        return VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 10) {
                modeButton(
                    mode: .sequential,
                    icon: "arrow.right",
                    label: "顺序播放",
                    isActive: player.playMode == .sequential
                )
                modeButton(
                    mode: .shuffle,
                    icon: "shuffle",
                    label: "随机播放",
                    isActive: player.playMode == .shuffle
                )
                modeButton(
                    mode: .repeatAll,
                    icon: "repeat",
                    label: "列表循环",
                    isActive: player.playMode == .repeatAll
                )
                modeButton(
                    mode: .repeatOne,
                    icon: "repeat.1",
                    label: "单曲循环",
                    isActive: player.playMode == .repeatOne
                )
            }
            .frame(maxWidth: .infinity)

            HStack(alignment: .firstTextBaseline) {
                Text("继续播放")
                    .font(CoFont.appFont(20, .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(player.upcomingQueue.count > 100 ? "\(player.upcomingQueue.count) 首，仅显示前 100 首" : "\(player.upcomingQueue.count) 首")
                    .font(CoFont.appFont(12, .regular, .default))
                    .foregroundStyle(.white.opacity(0.46))
            }

            if upcoming.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 28, weight: .light))
                    Text("播放队列是空的")
                        .font(CoFont.appFont(14, .semibold))
                }
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    // The queue is capped at 100 items. A plain VStack avoids
                    // the old SwiftUI lazy-container metadata crash on iOS 16
                    // while keeping the same visual layout.
                    VStack(spacing: 4) {
                        ForEach(Array(upcoming.enumerated()), id: \.offset) { position, item in
                            AppleMusicCompactQueueRow(
                                index: item.index,
                                position: position,
                                maxPosition: max(upcoming.count - 1, 0),
                                song: item.song,
                            ) { source, destination in
                                player.moveUpcomingQueueItem(from: source, to: destination, persist: false)
                            } onCommit: {
                                player.finishUpcomingQueueReorder()
                            }
                        }
                    }
                }
                .mask(
                    LinearGradient(
                        colors: [.black, .black, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .padding(.top, 6)
    }

    private func modeButton(
        mode: PlayMode,
        icon: String,
        label: String,
        isActive: Bool
    ) -> some View {
        Button {
            activate(mode)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isActive ? Color.black.opacity(0.76) : .white.opacity(0.76))
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(
                    isActive ? AnyShapeStyle(.white.opacity(0.66)) : AnyShapeStyle(.white.opacity(0.1)),
                    in: Capsule()
                )
        }
        .buttonStyle(RecordModePressButtonStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func activate(_ mode: PlayMode) {
        CoHaptics.tap()
        player.setPlayMode(mode)
    }
}

private struct AppleMusicCompactQueueRow: View {
    @EnvironmentObject private var player: PlayerManager
    @ObservedObject private var customCovers = CustomSongCoverStore.shared

    let index: Int
    let position: Int
    let maxPosition: Int
    let song: Song
    let onMove: (Int, Int) -> Void
    let onCommit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                CoHaptics.tap()
                player.playQueueIndex(index)
            } label: {
                HStack(spacing: 11) {
                    CoverImage(url: customCovers.url(for: song) ?? song.coverURL, size: 46, cornerRadius: 8)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(song.name)
                            .font(CoFont.appFont(14, .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                        Text(song.artists)
                            .font(CoFont.appFont(12))
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Text(song.formattedDuration)
                        .font(CoFont.appFont(11, .regular, .default))
                        .foregroundStyle(.white.opacity(0.36))
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            QueueReorderHandle(
                position: position,
                maxPosition: maxPosition,
                rowStep: 60,
                onMove: onMove,
                onCommit: onCommit
            )
            .foregroundStyle(.white.opacity(0.54))
        }
        .contextMenu {
            Button("从播放列表移除", role: .destructive) {
                player.removeFromQueue(at: index)
            }
        }
        .accessibilityLabel("\(song.name)，\(song.artists)")
    }
}

struct ReferenceScrubber: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    @State private var scrubbing = false
    @State private var scrubValue: Double = 0

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let total = max(max(clock.duration, player.currentSong?.duration ?? 0), 1)
                let progress = min(max((scrubbing ? scrubValue : clock.progress) / total, 0), 1)
                let width = geometry.size.width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.18))
                        .frame(height: 4)
                    Capsule()
                        .fill(.white.opacity(0.88))
                        .frame(width: width * progress, height: 4)
                    Circle()
                        .fill(.white)
                        .frame(width: scrubbing ? 18 : 12, height: scrubbing ? 18 : 12)
                        .shadow(color: .white.opacity(scrubbing ? 0.55 : 0.28), radius: scrubbing ? 10 : 3)
                        .offset(x: max(0, min(width - (scrubbing ? 18 : 12), width * progress - (scrubbing ? 9 : 6))))
                }
                .frame(height: 30)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !scrubbing {
                                scrubValue = clock.progress
                                CoHaptics.medium()
                            }
                            scrubbing = true
                            scrubValue = min(max(value.location.x / max(width, 1), 0), 1) * total
                        }
                        .onEnded { _ in
                            player.seek(to: scrubValue)
                            scrubbing = false
                            CoHaptics.tap()
                        }
                )
                .overlay(alignment: .topLeading) {
                    if scrubbing {
                        Text(coTimeString(scrubValue))
                            .font(CoFont.appFont(11, .semibold, .default))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.44), in: Capsule())
                            .offset(x: max(0, min(width - 62, width * progress - 31)), y: -28)
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                    }
                }
            }
            .frame(height: 30)

            HStack {
                Text(coTimeString(scrubbing ? scrubValue : clock.progress))
                Spacer()
                Text(coTimeString(max(clock.duration, player.currentSong?.duration ?? 0)))
            }
            .font(CoFont.appFont(11, .regular, .default))
            .foregroundStyle(.white.opacity(0.52))
        }
        .frame(maxWidth: 420)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: scrubbing)
    }
}

struct AppleMusicLyricsSection: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    @AppStorage("co.lyricKaraokeEnabled") private var karaokeEnabled = true

    let lyrics: [LyricLine]
    let primary: Color
    let secondary: Color
    let lyricOffset: CGFloat
    let centered: Bool = false
    let onTapLine: (LyricLine) -> Void

    @State private var lyricCenters: [UUID: CGFloat] = [:]
    @State private var focusedLyricID: UUID?
    @State private var selectedLyricID: UUID?
    @State private var viewportHeight: CGFloat = 0
    @State private var isDraggingLyrics = false
    @GestureState private var lyricDragActive = false
    @State private var resumeTask: Task<Void, Never>?
    @State private var lyricTapTask: Task<Void, Never>?

    private var currentPlaybackLyricIndex: Int? {
        guard !lyrics.isEmpty else { return nil }
        let progress = LyricTiming.effectiveProgress(clock.progress, userOffset: Double(lyricOffset))
        var low = 0
        var high = lyrics.count - 1
        var answer: Int?
        while low <= high {
            let mid = (low + high) / 2
            if lyrics[mid].time <= progress {
                answer = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return answer
    }

    private var currentPlaybackLyricID: UUID? {
        guard let index = currentPlaybackLyricIndex, lyrics.indices.contains(index) else { return nil }
        return lyrics[index].id
    }

    private var currentVisualLyricID: UUID? {
        isDraggingLyrics ? (focusedLyricID ?? currentPlaybackLyricID) : currentPlaybackLyricID
    }

    var body: some View {
        Group {
            if lyrics.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(secondary.opacity(0.5))
                    Text("暂无歌词")
                        .font(CoFont.appFont(15, .semibold))
                        .foregroundStyle(primary.opacity(0.86))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: centered ? .center : .leading, spacing: 26) {
                            Color.clear.frame(height: max(88, viewportHeight * 0.30))
                            ForEach(lyrics) { line in
                                lyricLine(line, isFocused: line.id == currentVisualLyricID, proxy: proxy)
                                    .id(line.id)
                                    .background {
                                        GeometryReader { rowGeometry in
                                            Color.clear.preference(
                                                key: ReferenceLyricCenterKey.self,
                                                value: [line.id: rowGeometry.frame(in: .named("iPadAppleLyricsViewport")).midY]
                                            )
                                        }
                                    }
                            }
                            Color.clear.frame(height: max(110, viewportHeight * 0.34))
                        }
                        .padding(.horizontal, 28)
                    }
                    .coordinateSpace(name: "iPadAppleLyricsViewport")
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black, location: 0.12),
                                .init(color: .black, location: 0.84),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .background {
                        GeometryReader { viewport in
                            Color.clear
                                .onAppear { viewportHeight = viewport.size.height }
                                .onChange(of: viewport.size.height) { viewportHeight = $0 }
                        }
                    }
                    .onPreferenceChange(ReferenceLyricCenterKey.self) { centers in
                        lyricCenters = centers
                        updateFocusedLyric(from: centers)
                        if isDraggingLyrics, !lyricDragActive { scheduleLyricResume(proxy: proxy) }
                    }
                    .simultaneousGesture(lyricsDragGesture(proxy: proxy))
                    .onChange(of: lyricDragActive) { active in
                        if !active, isDraggingLyrics { scheduleLyricResume(proxy: proxy) }
                    }
                    .onChange(of: lyrics.first?.id) { _ in
                        resumeTask?.cancel()
                        lyricTapTask?.cancel()
                        isDraggingLyrics = false
                        selectedLyricID = nil
                        focusedLyricID = nil
                        scrollToPlaybackLyric(proxy: proxy, animated: false)
                    }
                    .onDisappear {
                        resumeTask?.cancel()
                        lyricTapTask?.cancel()
                        isDraggingLyrics = false
                        selectedLyricID = nil
                        focusedLyricID = nil
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                            scrollToPlaybackLyric(proxy: proxy, animated: false)
                        }
                    }
                    .onChange(of: currentPlaybackLyricID) { _ in
                        guard !isDraggingLyrics else { return }
                        scrollToPlaybackLyric(proxy: proxy, animated: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear {
            resumeTask?.cancel()
            lyricTapTask?.cancel()
            isDraggingLyrics = false
            selectedLyricID = nil
            focusedLyricID = nil
        }
    }

    private func lyricLine(_ line: LyricLine, isFocused: Bool, proxy: ScrollViewProxy) -> some View {
        let isSelected = selectedLyricID == line.id || (isDraggingLyrics && isFocused)
        let visualFocus = isFocused || isSelected
        let isActive = line.id == currentPlaybackLyricID
        return VStack(alignment: centered ? .center : .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                KaraokeLyricText(
                    line: line,
                    currentTime: LyricTiming.effectiveProgress(clock.progress, userOffset: Double(lyricOffset)),
                    isPlaying: player.isPlaying,
                    isActive: isActive,
                    enabled: karaokeEnabled,
                    font: CoFont.appFont(visualFocus ? 27 : 23, visualFocus ? .bold : .semibold),
                    style: primary,
                    fallbackOpacity: visualFocus ? 1 : 0.36
                )
                    .fixedSize(horizontal: false, vertical: true)
                if isSelected {
                    Spacer(minLength: 8)
                    Text(coTimeString(line.time))
                        .font(CoFont.appFont(11, .semibold, .default))
                        .foregroundStyle(secondary.opacity(0.82))
                    Button {
                        lyricTapTask?.cancel()
                        playLyric(line, proxy: proxy)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(primary)
                            .frame(width: 24, height: 24)
                            .background(primary.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if visualFocus, let translation = line.translation, !translation.isEmpty {
                Text(translation)
                    .font(CoFont.appFont(15, .medium))
                    .foregroundStyle(secondary.opacity(0.72))
                    .multilineTextAlignment(centered ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
        .contentShape(Rectangle())
        .scaleEffect(visualFocus ? 1.06 : 0.84, anchor: centered ? .center : .leading)
        .blur(radius: visualFocus ? 0 : 0.7)
        .onTapGesture {
            scheduleLyricSelection(line.id, proxy: proxy)
        }
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    lyricTapTask?.cancel()
                    playLyric(line, proxy: proxy)
                }
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: visualFocus)
    }

    private func scheduleLyricSelection(_ id: UUID, proxy: ScrollViewProxy) {
        lyricTapTask?.cancel()
        lyricTapTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                selectedLyricID = id
                isDraggingLyrics = true
            }
            scheduleLyricResume(proxy: proxy)
            CoHaptics.tap()
        }
    }

    private func playLyric(_ line: LyricLine, proxy: ScrollViewProxy) {
        selectedLyricID = nil
        resumeTask?.cancel()
        isDraggingLyrics = false
        focusedLyricID = nil
        CoHaptics.tap()
        onTapLine(line)
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.3)) {
            proxy.scrollTo(line.id, anchor: .center)
        }
    }

    private func updateFocusedLyric(from centers: [UUID: CGFloat]) {
        guard viewportHeight > 0, !centers.isEmpty else { return }
        let center = viewportHeight / 2
        let nextID = centers.min { abs($0.value - center) < abs($1.value - center) }?.key
        focusedLyricID = nextID
        if isDraggingLyrics {
            selectedLyricID = nextID
        }
    }

    private func scrollToPlaybackLyric(proxy: ScrollViewProxy, animated: Bool) {
        guard let id = currentPlaybackLyricID else { return }
        let action = { proxy.scrollTo(id, anchor: .center) }
        if animated {
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.38)) { action() }
        } else {
            action()
        }
    }

    private func scheduleLyricResume(proxy: ScrollViewProxy) {
        resumeTask?.cancel()
        resumeTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 2_500_000_000) }
            catch { return }
            guard !Task.isCancelled, !lyricDragActive else { return }
            lyricTapTask?.cancel()
            isDraggingLyrics = false
            selectedLyricID = nil
            focusedLyricID = nil
            scrollToPlaybackLyric(proxy: proxy, animated: true)
        }
    }

    private func lyricsDragGesture(proxy: ScrollViewProxy) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($lyricDragActive) { _, active, _ in active = true }
            .onChanged { _ in
                lyricTapTask?.cancel()
                isDraggingLyrics = true
                resumeTask?.cancel()
                updateFocusedLyric(from: lyricCenters)
            }
            .onEnded { _ in
                resumeTask?.cancel()
                if let id = focusedLyricID {
                    selectedLyricID = id
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
                scheduleLyricResume(proxy: proxy)
            }
    }
}

struct ReferenceVolumeControl: View {
    let accent: Color
    let secondary: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(secondary.opacity(0.84))
            ReferenceSystemVolumeView(accent: accent, secondary: secondary)
                .frame(height: 32)
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(secondary.opacity(0.84))
        }
        .frame(height: 34)
    }
}

struct CoSoftwareVolumeSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CoLiquidSheetBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label("软件音量", systemImage: "speaker.wave.2.fill")
                            .font(CoFont.appFont(20, .bold))
                        Spacer()
                        Text("\(Int((player.softwareVolume * 100).rounded()))%")
                            .font(.system(size: 15, weight: .semibold, design: .default))
                            .foregroundStyle(Color.coComment)
                    }

                    Text("只调整 Co 的播放音量，不改变系统音量。适合和其他音频同时播放时降低背景音。")
                        .font(CoFont.appFont(13))
                        .foregroundStyle(Color.coComment)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(Color.coComment)
                        Slider(
                            value: Binding(
                                get: { player.softwareVolume },
                                set: { player.softwareVolume = $0 }
                            ),
                            in: 0...1
                        )
                        .tint(Color.coAmber)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(Color.coComment)
                    }

                    HStack {
                        Button("恢复 100%") {
                            player.softwareVolume = 1
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                        Button("完成") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(24)
            }
        }
        .background(CoSheetPresentationSurfaceClearer())
        .coScrollIndicatorsHidden()
    }
}

struct CoSoftwareVolumeSheetHost: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var theme: ThemeStore

    @ViewBuilder
    var body: some View {
        let content = CoSoftwareVolumeSheet()
            .environmentObject(player)
            .environmentObject(theme)

        content
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.clear)
            .presentationCornerRadius(28)
    }
}

private struct ReferenceSystemVolumeView: UIViewRepresentable {
    let accent: Color
    let secondary: Color

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = false
        styleVolumeSlider(in: view)
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        styleVolumeSlider(in: uiView)
    }

    private func styleVolumeSlider(in view: MPVolumeView) {
        let applyStyle = {
            let sliders = allSubviews(in: view).compactMap { $0 as? UISlider }
            sliders.forEach { slider in
                slider.minimumTrackTintColor = UIColor(accent.opacity(0.88))
                slider.maximumTrackTintColor = UIColor(secondary.opacity(0.32))
                slider.thumbTintColor = UIColor(accent)
            }
        }

        // MPVolumeView creates its internal slider during layout, so apply the tint once more after it settles.
        applyStyle()
        DispatchQueue.main.async {
            applyStyle()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                applyStyle()
            }
        }
    }

    private func allSubviews(in view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap { allSubviews(in: $0) }
    }
}

extension ReferencePlaybackView {
/// 常驻封面：前端只有一个封面元素，Co 之前是两页各一个封面靠形变连——形变只能走直线。
/// 这里封面只存在一个（外层 ZStack 顶层），位置/大小/圆角/阴影全部由进度修饰器按前端百分比数学算。
private func persistentCover(upperSize: CGSize, fullSize: CGSize) -> some View {
    let contentWidth = max(fullSize.width - 64, 0)
    let artworkSize = min(contentWidth, min(fullSize.height * 0.50, 390))
    return Button {
        CoHaptics.tap()
        withAnimation(.timingCurve(0.32, 0.72, 0.28, 1, duration: 0.38)) {
            showLyrics.toggle()
        }
    } label: {
        CoverImage(
            url: displayCoverURL,
            size: artworkSize,
            cornerRadius: 18,
            emptyHint: player.isBuffering ? "等待开始播放…" : nil,
            playsCoverVideoAudio: true
        )
        .scaleEffect(player.isPlaying ? 1 : 0.965)
        .animation(.spring(response: 0.36, dampingFraction: 0.84), value: player.isPlaying)
    }
    .buttonStyle(GlassPressButtonStyle(scale: 0.94))
    .modifier(WebCoverProgressModifier(
        progress: coverProgress,
        width: upperSize.width,
        height: upperSize.height,
        coverSize: artworkSize,
        showsPreview: !hideCoverLyrics
    ))
    .modifier(AppleMusicLayoutTransform(entry: layoutEntry(.cover)))
}

}

/// 前端封面过渡的百分比数学（progress 0 = 封面页，1 = 歌词页，由 showLyrics 翻转 + 同一条贝塞尔驱动插值）：
/// left 是容器宽度的百分比、位移是自身宽度的百分比、容器本身还在缩——三个百分比互相乘，
/// 位置走出来是弧线（先缩小往上收、后半段再往左滑进页眉），不是从右下角斜着缩到左上角。
/// 封面页标题块在封面下方（22 间距 + 约 53 标题高）。封面页内容只剩占位 + 标题时，
/// 占位顶约 0.5H - 200.5；预览显示时内容多约 78（18 间距 + 三行约 60），占位顶约 0.5H - 239.5。
/// fudge 跟预览显隐走：隐藏时 40（封面顶约 0.5H - 203，与占位基本重合，标题留约 24pt），
/// 显示时 76.5（封面顶约 0.5H - 239.5，与占位重合，标题留约 22pt），两种状态标题都不被盖。
/// 歌词页顶为 0（(1-e) 项，e=1 时不受这个常数影响）。
private struct WebCoverProgressModifier: AnimatableModifier {
    var progress: Double
    var width: CGFloat
    var height: CGFloat
    var coverSize: CGFloat
    var showsPreview: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let e = progress
        let size = coverSize + (48 - coverSize) * e
        // 前端 viewArea 收缩的近似：整页高 → 64px（flex 换算，e² 项）。
        let viewHeight = height * (1 - e) + 64 * e * e
        let fudge = showsPreview ? 76.5 : 40
        let top = (1 - e) * (0.5 * viewHeight - size / 2 - fudge)
        let left = (1 - e) * (0.5 * width - size / 2) + 24 * e
        let scale = coverSize > 0 ? size / coverSize : 1
        return content
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: size, height: size, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 18 - 8 * e, style: .continuous))
            .shadow(color: .black.opacity(0.46 - 0.20 * e), radius: 36 - 27 * e, y: 18 - 14 * e)
            .offset(x: left, y: top)
    }
}

/// 封面页歌词预览：三行（上一句/当前句/下一句），点它进歌词页；无歌词时显示“暂无歌词”。
/// 由自定义布局编辑器里的“隐藏封面歌词”开关控制显隐，只在封面页出现。
private struct MiniLyricsPreview: View {
    let lines: [LyricLine]
    let primary: Color
    let secondary: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if lines.isEmpty {
                    Text("暂无歌词")
                        .font(CoFont.appFont(15, .semibold))
                        .foregroundStyle(secondary.opacity(0.54))
                } else {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        Text(line.text.isEmpty ? " " : line.text)
                            .font(CoFont.appFont(index == 1 ? 17 : 15, index == 1 ? .semibold : .medium))
                            .foregroundStyle((index == 1 ? primary : secondary).opacity(index == 1 ? 0.86 : 0.5))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
            }
            .frame(maxWidth: 420, minHeight: 92)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 歌词层进场：原版前端同款——原地淡入 + 上浮 14px，不是从底部整页滑上来。
private struct LyricsEnterModifier: ViewModifier {
    let opacity: Double
    let offsetY: CGFloat
    func body(content: Content) -> some View {
        content.opacity(opacity).offset(y: offsetY)
    }
}
