import SwiftUI
import UIKit


struct PlayerView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    @EnvironmentObject private var favorites: FavoritesStore
    @ObservedObject private var localLibrary = LocalLibraryStore.shared
    @ObservedObject private var customCovers = CustomSongCoverStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    @AppStorage("co.themeMode") private var themeModeRaw = CoThemeMode.system.rawValue

    @State private var lyrics: [LyricLine] = []
    @State private var showLyrics = false
    @AppStorage("co.player.lastLyricsPage") private var lastLyricsPage = false
    @State private var showQueue = false
    @State private var showAppleMusicQueue = false
    @State private var showVinylQueue = false
    @State private var showSleepTimer = false
    @State private var showClearQueueConfirm = false
    @State private var showMoreActions = false
    @State private var showSoftwareVolume = false
    @State private var showLyricOffsetSheet = false
    @State private var showAddToLocalPlaylist = false
    /// 选本地歌单弹窗是否由爱心触发：是才同步到红心库；菜单“添加到本地歌单”
    /// 走同一个弹窗，不能把“加入某歌单”误当成点爱心。
    @State private var localPlaylistSheetMarksFavorite = false
    @State private var showPlayerSettings = false
    @State private var showComments = false
    @AppStorage(FoliaPreferences.modeKey) private var foliaModeRaw = FoliaVisualizerMode.still.rawValue
    @State private var playbackRenderingSuppressed = false
    @State private var showArtistHome = false
    @State private var pickedArtistName = ""
    @State private var showArtistPicker = false
    @State private var vinylFocusedLyricIndex: Int?
    @State private var vinylSelectedLyricIndex: Int?
    @State private var vinylLyricsViewportHeight: CGFloat = 0
    @State private var vinylIsDraggingLyrics = false
    @State private var vinylLyricsResumeTask: Task<Void, Never>?
    @State private var vinylLyricTapTask: Task<Void, Never>?


    private var selectedThemeMode: CoThemeMode {
        CoThemeMode(rawValue: themeModeRaw) ?? .system
    }


    private var displayCoverURL: URL? {
        customCovers.url(for: song) ?? song?.coverURL
    }
    @AppStorage("co.djVisual") private var djVisualEnabled = false
    @AppStorage("co.djVisualIntensity") private var djVisualIntensity = 0.8
    @State private var dominantColor: RGBColor?
    @Namespace private var coverNS
    @AppStorage("co.lyricFontSize") private var lyricFontSize = 17
    @AppStorage("co.lyricColor") private var lyricColorRaw = "accent"
    @AppStorage("co.lyricDimColor") private var lyricDimColorRaw = "dim"
    @AppStorage("co.lyricGlow") private var lyricGlowLevel = 1
    @AppStorage("co.lyricGradStart") private var lyricGradStartRaw = ""
    @AppStorage("co.lyricGradEnd") private var lyricGradEndRaw = ""
    /// 渐变模式：0=跟随封面自动取色（默认），1=始终保持用户自定义渐变
    @AppStorage("co.lyricGradMode") private var lyricGradMode = 0
    /// 歌词行距（14~40，默认 24）
    @AppStorage("co.lyricSpacing") private var lyricLineSpacing = 24
    /// 播放器氛围：背景流动开关 / 速度 / 呼吸光晕强度
    @AppStorage("co.playerBreath") private var playerBreath = 0.6
    @AppStorage("co.playerDustMode") private var playerDustModeRaw = CoPlayerDustMode.off.rawValue
    @AppStorage("co.playerDustDensity") private var playerDustDensity = 1.0
    @AppStorage("co.playerDustSize") private var playerDustSize = 1.0
    /// 播放控件颜色是否跟随封面主色；关闭后使用全局主题色
    @AppStorage("co.playerControlsUseCoverColor") private var controlsUseCoverColor = true
    @AppStorage("co.playerMainIconColorHex") private var playerMainIconColorHex = ""
    @AppStorage("co.playerSecondaryIconColorHex") private var playerSecondaryIconColorHex = ""
    @AppStorage("co.playerPrimaryButtonColorHex") private var playerPrimaryButtonColorHex = ""
    /// 播放器顶部与底部控制按钮的统一样式
    @AppStorage("co.playerButtonStyle") private var playerButtonStyleRaw = CoPlayerButtonStyle.glass.rawValue
    @AppStorage("co.appleMusic.primaryHex") private var appleMusicPrimaryHex = ""
    @AppStorage("co.appleMusic.secondaryHex") private var appleMusicSecondaryHex = ""
    @AppStorage("co.appleMusic.accentHex") private var appleMusicAccentHex = ""
    /// 进度条样式：0 流光 / 1 辉光 / 2 极光 / 3 波浪
    @AppStorage("co.progressBarStyle") private var progressBarStyle = 0
    /// 进度条单独强调色；空值时跟随播放控件颜色
    @AppStorage("co.progressAccentHex") private var progressAccentHex = ""
    /// 封面页歌词预览开关：开 = 隐藏封面页歌词预览（只影响封面页，完整歌词页不受影响）；默认开，保持刚确认过的干净封面页。
    @AppStorage("co.coverLyricsHidden") private var hideCoverLyrics = true
    /// 播放器布局自由调整：开关 + 各组件 x/y/z 数据 + 当前选中组件
    @State private var layoutMode = false
    @AppStorage("co.playerLayoutSelectedPart") private var layoutPartRaw = PlayerLayoutPart.progress.rawValue
    @State private var layoutData: [String: PlayerLayoutEntry] = PlayerLayoutStore.load()
    @State private var vinylLayoutData: [String: PlayerLayoutEntry] = VinylPlayerLayoutStore.load()
    @State private var iPadLandscapeLayoutData = IPadLandscapeLayoutStore.load()
    @State private var layoutPart: PlayerLayoutPart = .progress
    @ObservedObject private var appleLayout = AppleMusicLayoutStore.shared
    @State private var appleLayoutPart: AppleMusicLayoutPart = .cover
    @State private var iPadLandscapeLayoutPart: IPadLandscapeLayoutPart = .artwork
    @State private var layoutEditorStyleRaw = CoCoverPlayerStyle.appleMusic.rawValue
    @State private var layoutEditorUsesIPadLandscape = false
    @State private var layoutPreviewShowLyrics = false
    @State private var layoutPreviewShowQueue = false
    /// 调整页使用真实播放器视口比例，避免 iPad 预览与实际布局不一致。
    @State private var playerViewportSize: CGSize = .zero
    /// 歌词布局：对齐样式 / 水平偏移 / 垂直重心（底部更多或顶部更多歌词）
    @AppStorage("co.lyricAlignRaw") private var lyricAlignRaw = "center"
    @AppStorage("co.lyricOffsetX") private var lyricOffsetX = 0.0
    @AppStorage("co.lyricAnchorY") private var lyricAnchorY = 0.0
    /// 歌词大小缩放（布局调整弹窗「大小」滑杆）
    @AppStorage("co.lyricScale") private var lyricScale = 1.0
    /// 圆形封面模式（播放器大封面 / 歌词页左上角小封面）
    @AppStorage("co.circularCover") private var circularCover = true
    /// 圆形封面自动旋转
    @AppStorage("co.circularCoverSpin") private var circularCoverSpin = true
    /// 歌词自定义发光颜色（留空跟随当前行颜色 / 封面取色）
    @AppStorage("co.lyricGlowColorRaw") private var lyricGlowColorRaw = ""
    /// 侧边滑动切歌（抖音式刷视频交互，默认开启）
    @AppStorage("co.swipeSwitchSong") private var swipeSwitchSong = true
    /// 歌词模糊控制：起始距离（距当前行几行开始模糊）+ 模糊强度（0 = 关闭）
    @AppStorage("co.lyricBlurStart") private var lyricBlurStart = 1
    @AppStorage("co.lyricBlurAmount") private var lyricBlurAmount = 1.1
    /// 歌词 3D 倾斜角度（0 = 关闭；顶部向后倒，立体透视感）
    @AppStorage("co.lyricTilt") private var lyricTilt = 0
    /// 歌词左右倾斜角度（0 = 关闭；负值向左、正值向右，立体透视感）
    @AppStorage("co.lyricTiltY") private var lyricTiltY = 0
    /// 歌词进度偏移（秒）：歌词与音频不同步时手动校正，正数提前、负数延后
    @AppStorage("co.lyricOffset") private var lyricOffset = 0.0
    /// 歌词界面自定义背景
    @AppStorage("co.lyricBackground.image") private var lyricBackgroundImagePath = ""
    @AppStorage("co.lyricBackground.blur") private var lyricBackgroundBlur = 12.0
    @AppStorage("co.lyricBackground.syncCover") private var lyricBackgroundSyncCover = false
    @AppStorage("co.albumTitleColorHex") private var albumTitleColorHex = ""
    @AppStorage("co.albumArtistColorHex") private var albumArtistColorHex = ""
    @AppStorage("co.albumPreviewLyricColorHex") private var albumPreviewLyricColorHex = ""
    @AppStorage("co.albumPreviewDimColorHex") private var albumPreviewDimColorHex = ""
    @AppStorage("co.albumTextGradient") private var albumTextGradient = false
    @AppStorage("co.albumTextGlow") private var albumTextGlow = false
    @AppStorage("co.albumTextGlowIntensity") private var albumTextGlowIntensity = 1.0
    @AppStorage("co.coverPlayerStyle") private var coverPlayerStyleRaw = CoCoverPlayerStyle.appleMusic.rawValue
    @AppStorage("co.appleMusic.showVolume") private var appleShowVolume = false
    @AppStorage("co.appleMusic.primaryHex") private var applePrimaryHex = ""
    @AppStorage("co.appleMusic.secondaryHex") private var appleSecondaryHex = ""
    @AppStorage("co.appleMusic.accentHex") private var appleAccentHex = ""
    @AppStorage("co.appleMusic.volumeHex") private var appleVolumeHex = ""
    @AppStorage("co.appleMusic.syncWallpaper") private var appleSyncWallpaper = false
    @AppStorage("co.appleMusic.wallpaperBlur") private var appleWallpaperBlur = 14.0
    @AppStorage("co.showSongVIPBadge") private var showSongVIPBadge = true
    /// 侧边滑动手势当前位移（刷视频式切歌过渡）
    @State private var swipeOffset: CGFloat = 0
    @State private var coverDrag: CGSize = .zero
    @State private var coverSwitchPulse = false
    @State private var animatedSongKey = ""

    private var song: Song? { player.currentSong }

    private func isIPadLandscape(in size: CGSize) -> Bool {
        UIDevice.current.userInterfaceIdiom == .pad && size.width > size.height
    }
    private let rateOptions: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    /// 封面主色联动调色板：背景渐变 / 进度条 / 播放暂停键 / 功能按钮 / 歌词高亮等全部跟随封面主色。
    /// 安全机制：只在切歌（.task(id: song?.identityKey)）时一次性提取并更新，绝不随封面加载过程高频重算 @State，
    /// 避免整页反复重绘导致的布局错乱与发烫。深浅模式切换时及时重算配色。
    /// 自定义歌词发光颜色
    private var lyricGlowColor: Color? {
        Color.fromHexPrefixedOrNil(lyricGlowColorRaw)
    }

    /// 歌词对齐样式（居中 / 全部居左）
    private var lyricAlign: HorizontalAlignment {
        lyricAlignRaw == "left" ? .leading : .center
    }

    /// 歌词垂直重心：0.5 居中；<0.5 当前行偏上（显示更多后续歌词），>0.5 偏下（显示更多已唱歌词）
    private var lyricAnchor: UnitPoint {
        let y = 0.5 + CGFloat(lyricAnchorY) / 200
        return UnitPoint(x: 0.5, y: min(max(y, 0.15), 0.85))
    }

    private var palette: CoverPalette {
        if let dominantColor {
            return CoverPalette.make(dominant: dominantColor, colorScheme: colorScheme)
        }
        return CoverPalette.fallback(colorScheme: colorScheme)
    }

    private var controlAccent: Color {
        Color.fromHexPrefixed(playerPrimaryButtonColorHex, fallback: controlsUseCoverColor ? palette.accent : Color.coAmber)
    }

    private var controlAccentSoft: Color {
        return controlsUseCoverColor ? palette.accentSoft : Color.coAmber.opacity(0.28)
    }

    private var playerButtonStyle: CoPlayerButtonStyle {
        CoPlayerButtonStyle(rawValue: playerButtonStyleRaw) ?? .glass
    }

    private var coverPlayerStyle: CoCoverPlayerStyle {
        CoCoverPlayerStyle.resolved(rawValue: coverPlayerStyleRaw)
    }

    private var layoutEditorStyle: CoCoverPlayerStyle {
        CoCoverPlayerStyle.resolved(rawValue: layoutEditorStyleRaw)
    }

    /// 编辑页预览使用正在编辑的样式，正常播放页始终使用用户当前选择的样式。
    private var layoutRenderingStyle: CoCoverPlayerStyle {
        layoutMode ? layoutEditorStyle : coverPlayerStyle
    }

    private var layoutRenderingShowLyrics: Bool {
        layoutMode ? layoutPreviewShowLyrics : showLyrics
    }

    private var landscapeApplePrimaryColor: Color {
        Color.fromHexPrefixed(appleMusicPrimaryHex, fallback: .white)
    }

    private var landscapeAppleSecondaryColor: Color {
        Color.fromHexPrefixed(appleMusicSecondaryHex, fallback: .white.opacity(0.58))
    }

    private var landscapeAppleAccentColor: Color {
        Color.fromHexPrefixed(appleMusicAccentHex, fallback: Color.coAppleMusicAccentFallback)
    }

    private enum VinylLayoutDefaults {
        static let lyricTopRows = 3
        static let lyricBottomRows = 3
    }


    private func favoriteMark(for song: Song?) -> FavoriteMark {
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

    private func toggleLocalFavorite(_ song: Song) {
        if localLibrary.containsSong(song) {
            removeLocalFavorite(song)
        } else {
            saveFavoriteLocally(song)
        }
    }


    private func removeLocalFavorite(_ song: Song) {
        let removed = localLibrary.removeSongFromAllPlaylists(song)
        // 同步到我的页“我喜欢”：只写本地歌单库的话，读口（红心库）永远看不到。
        if removed > 0 { favorites.setKugouLiked(song, liked: false) }
        ToastCenter.shared.show(removed > 0 ? "已取消本地收藏" : "歌曲不在本地歌单中")
        CoHaptics.success()
    }


    private func saveFavoriteLocally(_ song: Song) {
        if localLibrary.playlists.count > 1 {
            // 走选歌单弹窗：选完才算收藏上，弹窗回调里再同步到红心库。
            localPlaylistSheetMarksFavorite = true
            showAddToLocalPlaylist = true
        } else {
            ToastCenter.shared.show(localLibrary.addToDefaultFavorites(song))
            favorites.setKugouLiked(song, liked: true)
            CoHaptics.success()
        }
    }

    @MainActor

    private var playerDustMode: CoPlayerDustMode {
        return CoPlayerDustMode(rawValue: playerDustModeRaw) ?? .off
    }

    private var playerButtonText: Color {
        if playerButtonStyle == .appleMusic { return .white }
        return Color.fromHexPrefixed(playerMainIconColorHex, fallback: palette.text)
    }

    private var playerButtonSecondaryText: Color {
        if playerButtonStyle == .appleMusic { return .white.opacity(0.88) }
        return Color.fromHexPrefixed(playerSecondaryIconColorHex, fallback: palette.secondary)
    }

    private var albumTitleColor: Color {
        Color.fromHexPrefixed(albumTitleColorHex, fallback: palette.text)
    }

    private var albumArtistColor: Color {
        Color.fromHexPrefixed(albumArtistColorHex, fallback: palette.secondary)
    }

    private var albumPreviewLyricColor: Color {
        Color.fromHexPrefixed(albumPreviewLyricColorHex, fallback: palette.text)
    }

    private var albumPreviewDimColor: Color {
        Color.fromHexPrefixed(albumPreviewDimColorHex, fallback: palette.secondary)
    }

    private var progressAccent: Color {
        Color.fromHexPrefixed(progressAccentHex, fallback: controlAccent)
    }

    private var albumTitleForeground: AnyShapeStyle {
        albumForeground(primary: albumTitleColor, secondary: albumPreviewLyricColor)
    }

    private var albumArtistForeground: AnyShapeStyle {
        albumForeground(primary: albumArtistColor, secondary: albumTitleColor)
    }

    private var albumPreviewForeground: AnyShapeStyle {
        albumForeground(primary: albumPreviewLyricColor, secondary: albumTitleColor)
    }

    private var albumPreviewDimForeground: AnyShapeStyle {
        albumTextGradient
            ? AnyShapeStyle(LinearGradient(colors: [albumPreviewDimColor.opacity(0.72), albumArtistColor.opacity(0.62)], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(albumPreviewDimColor)
    }

    private func albumForeground(primary: Color, secondary: Color) -> AnyShapeStyle {
        if albumTextGradient {
            return AnyShapeStyle(LinearGradient(colors: [primary, secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(primary)
    }

    private func albumGlow(_ color: Color, strong: Bool = false) -> Color {
        albumTextGlow ? color.opacity((strong ? 0.46 : 0.30) * albumTextGlowIntensity) : .clear
    }

    private var playerVisualsActive: Bool {
        player.isPlaying && !showPlayerSettings && !layoutMode
    }

    /// 播放器封面页上划打开评论，覆盖内部封面和控件的手势区域。
    private var commentSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard !showLyrics,
                      !layoutMode,
                      value.translation.height < -54,
                      abs(value.translation.height) > abs(value.translation.width),
                      song != nil else { return }
                CoHaptics.medium()
                showComments = true
            }
    }

    private func openPlayerSettings() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.08)) {
            showPlayerSettings = true
        }
    }

    private func closePlayerSettings() {
        withAnimation(.easeOut(duration: 0.24)) {
            showPlayerSettings = false
        }
    }

    /// 设置页和布局编辑器显示期间暂停播放器界面的高频刷新，音频播放继续进行。
    private func syncPlaybackRenderingSuppression() {
        let shouldSuppress = showPlayerSettings || layoutMode
        guard shouldSuppress != playbackRenderingSuppressed else { return }
        playbackRenderingSuppressed = shouldSuppress
        if shouldSuppress {
            PlaybackRenderGate.shared.beginSuppression()
        } else {
            PlaybackRenderGate.shared.endSuppression()
        }
    }

    private func releasePlaybackRenderingSuppression() {
        guard playbackRenderingSuppressed else { return }
        playbackRenderingSuppressed = false
        PlaybackRenderGate.shared.endSuppression()
    }

    /// 当前行歌词颜色（可自定义；配色模式关闭时自动跟随封面取色）
    private var lyricCurrentColor: Color {
        guard lyricGradMode == 1 else { return palette.accent }
        switch lyricColorRaw {
        case "white": return .white
        case "amber": return Color.coAmber
        case "cyan": return Color(red: 0.35, green: 0.85, blue: 0.96)
        case "pink": return Color(red: 1.0, green: 0.62, blue: 0.82)
        case "green": return Color(red: 0.42, green: 0.90, blue: 0.62)
        default:
            if lyricColorRaw.hasPrefix("#"), let c = Color(hex: lyricColorRaw) { return c }
            return palette.accent
        }
    }

    /// 未播放歌词颜色（可自定义；配色模式关闭时自动跟随封面取色）
    private var lyricDimColor: Color {
        guard lyricGradMode == 1 else { return palette.secondary }
        switch lyricDimColorRaw {
        case "white": return .white.opacity(0.78)
        case "bluegray": return Color(red: 0.72, green: 0.78, blue: 0.86)
        case "gray": return Color.gray.opacity(0.85)
        case "dark": return Color.black.opacity(0.55)
        default:
            if lyricDimColorRaw.hasPrefix("#"), let c = Color(hex: lyricDimColorRaw) { return c }
            return palette.secondary
        }
    }

    /// 当前行歌词渐变（可自定义起止色；未设置时自动从封面强调色派生，深浅模式自适应）
    /// 配色模式：开（保持自定义）时歌词颜色与渐变都一直用用户选色且切歌后不重置；关（默认）时全部自动跟随封面取色
    private var lyricGradStart: Color {
        if lyricGradMode == 1, lyricGradStartRaw.hasPrefix("#"), let c = Color(hex: lyricGradStartRaw) { return c }
        return lyricCurrentColor
    }
    private var lyricGradEnd: Color {
        if lyricGradMode == 1, lyricGradEndRaw.hasPrefix("#"), let c = Color(hex: lyricGradEndRaw) { return c }
        return mixedColor(lyricCurrentColor, with: colorScheme == .dark ? .white : .black, amount: 0.45)
    }
    private func mixedColor(_ c: Color, with other: Color, amount: CGFloat) -> Color {
        let ui = UIColor(c)
        let ui2 = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ui.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ui2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let a = min(max(amount, 0), 1)
        return Color(red: r1 * (1 - a) + r2 * a, green: g1 * (1 - a) + g2 * a, blue: b1 * (1 - a) + b2 * a)
    }

    /// 发光强度对应的 shadow 半径（0 关闭，最大 32，叠双层光晕更亮）
    private var lyricGlowRadius: CGFloat {
        switch lyricGlowLevel {
        case 0: return 0
        case 1: return 6
        case 2: return 12
        case 3: return 18
        case 4: return 25
        default: return 32
        }
    }

    var body: some View {
        let _ = theme.accent
        GeometryReader { rootGeometry in
        Group {
            if coverPlayerStyle == .folia {
                FoliaStageView(song: song, lyrics: lyrics, onBack: {
                    closePlayer()
                }, onSettings: {
                    openPlayerSettings()
                })
            } else if isIPadLandscape(in: rootGeometry.size) && showLyrics && coverPlayerStyle != .record {
                iPadLandscapeLyricsView
                    .id("landscape-\(layoutRenderingStyle.rawValue)-\(rootGeometry.size.width > rootGeometry.size.height)")
            } else if coverPlayerStyle == .appleMusic {
                ZStack {
                    ReferencePlaybackView(
                        song: song,
                        lyrics: lyrics,
                        showLyrics: $showLyrics,
                        showQueue: $showAppleMusicQueue,
                        onFavorite: {
                            guard let song else { return }
                            toggleLocalFavorite(song)
                        },
                        onComments: {
                            // Apple Music 样式：最小版只读评论（见文件末尾 CoHotCommentsSheet）。
                            // 唱片样式的评论入口已接通同一只读评论页；仅布局编辑器预览里仍为占位提示。
                            if song != nil { showComments = true }
                        },
                        onSleepTimer: {
                            showSleepTimer = true
                        },
                        onAddToLocalPlaylist: {
                            showAddToLocalPlaylist = true
                        },
                        onPlayerSettings: {
                            openPlayerSettings()
                        },
                        onArtist: {
                            openArtistHome()
                        }
                    )

                    if showMoreActions {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                                    showMoreActions = false
                                }
                            }
                            .zIndex(70)

                        playerMoreActionsPanel
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, 76)
                            .zIndex(80)
                            .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
                    }
                }
                .contentShape(Rectangle())
            } else if coverPlayerStyle == .record {
                RecordPlayerView(
                    song: song,
                    lyrics: lyrics,
                    layoutData: vinylLayoutData,
                    isFavorite: song.map { localLibrary.containsSong($0) } ?? false,
                    favoriteMark: favoriteMark(for: song),
                    onFavorite: {
                        guard let song else { return }
                        toggleLocalFavorite(song)
                    },
                    onComments: {
                        // 评论已接回：唱片样式不再弹“已移除”，走同一张只读评论页。
                        if song != nil { showComments = true }
                    },
                    onSettings: {
                        openPlayerSettings()
                    },
                    onArtist: {
                        openArtistHome()
                    },
                    onSleepTimer: {
                        showSleepTimer = true
                    },
                    onAddToLocalPlaylist: {
                        showAddToLocalPlaylist = true
                    },
                )
            } else if coverPlayerStyle == .vinyl {
                GeometryReader { geo in
                    ZStack {
                        background
                            .ignoresSafeArea()

                        content(geo: geo)

                        controlDeck(bottomInset: geo.safeAreaInsets.bottom)
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: .infinity, alignment: .bottom)

                        if showMoreActions {
                            Color.black.opacity(0.001)
                                .ignoresSafeArea()
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                                        showMoreActions = false
                                    }
                                }
                                .zIndex(70)

                            playerMoreActionsPanel
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .padding(.top, 76)
                                .zIndex(80)
                                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
                        }
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(commentSwipeGesture, including: .all)
                }
            } else {
                GeometryReader { geo in
                    ZStack {
                        background
                            .ignoresSafeArea()

                        VStack(spacing: 0) {
                            headerBar
                            content(geo: geo)
                        }
                        .foregroundStyle(palette.text)
                        .zIndex(10)

                        controlDeck(bottomInset: geo.safeAreaInsets.bottom)
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .zIndex(9)

                        if showMoreActions {
                            Color.black.opacity(0.001)
                                .ignoresSafeArea()
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                                        showMoreActions = false
                                    }
                                }
                                .zIndex(70)

                            playerMoreActionsPanel
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .padding(.top, 76)
                                .zIndex(80)
                                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
                        }
                    }
                }
            }
        }
        .onAppear {
            playerViewportSize = rootGeometry.size
            syncPlaybackRenderingSuppression()
        }
        .onChange(of: rootGeometry.size) { newSize in
            playerViewportSize = newSize
        }
        }
        .task(id: song?.identityKey) {
            let songKey = song?.identityKey ?? ""
            dominantColor = nil
            await MainActor.run {
                coverDrag = .zero
                lyrics = []
                vinylFocusedLyricIndex = nil
                vinylSelectedLyricIndex = nil
                vinylIsDraggingLyrics = false
                vinylLyricsViewportHeight = 0
                vinylLyricsResumeTask?.cancel()
                vinylLyricsResumeTask = nil
                vinylLyricTapTask?.cancel()
                vinylLyricTapTask = nil
                let shouldPulse = !animatedSongKey.isEmpty && animatedSongKey != songKey
                animatedSongKey = songKey
                coverSwitchPulse = shouldPulse
                if shouldPulse {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.easeOut(duration: 0.20)) {
                            coverSwitchPulse = false
                        }
                    }
                }
            }
            await loadLyrics()
            await extractCoverPalette()
        }
        .onChange(of: layoutData) { newValue in
            PlayerLayoutStore.save(newValue)
        }
        .onChange(of: vinylLayoutData) { newValue in
            VinylPlayerLayoutStore.save(newValue)
        }
        .onChange(of: iPadLandscapeLayoutData) { newValue in
            IPadLandscapeLayoutStore.save(newValue)
        }
        .onAppear {
            // 布局编辑只在当前播放器会话内有效，不保留上次退出时的打开状态。
            UserDefaults.standard.removeObject(forKey: "co.playerLayoutMode")
            layoutMode = false
            layoutPart = PlayerLayoutPart(rawValue: layoutPartRaw) ?? .progress
            showLyrics = lastLyricsPage
            if let path = LyricBackgroundStore.restoreFromBackup(), lyricBackgroundImagePath != path {
                lyricBackgroundImagePath = path
            }
        }
        .onChange(of: showLyrics) { newValue in
            lastLyricsPage = newValue
        }
        .onChange(of: layoutPartRaw) { rawValue in
            layoutPart = PlayerLayoutPart(rawValue: rawValue) ?? .progress
        }
        .onChange(of: layoutMode) { enabled in
            if enabled {
                prepareLayoutEditor()
            }
            syncPlaybackRenderingSuppression()
        }
        .onChange(of: showPlayerSettings) { _ in
            syncPlaybackRenderingSuppression()
        }
        .onDisappear {
            releasePlaybackRenderingSuppression()
        }
        .fullScreenCover(isPresented: $layoutMode) {
            Group {
                iOS26LayoutPreviewEditor
            }
            .environmentObject(theme)
            .environmentObject(player)
            .environmentObject(clock)
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
                .environmentObject(player)
                .environmentObject(theme)
        }
        .sheet(isPresented: $showSleepTimer) {
            SleepTimerSheetHost()
                .environmentObject(player)
                .environmentObject(theme)
        }
        .sheet(isPresented: $showPlayerSettings) {
            PlayerSettingsSheet(layoutMode: $layoutMode, onDismiss: closePlayerSettings)
                .environmentObject(theme)
                .environmentObject(player)
        }
        .sheet(isPresented: $showComments) {
            if let song {
                CoHotCommentsSheet(song: song)
            }
        }
        .sheet(isPresented: $showSoftwareVolume) {
            CoSoftwareVolumeSheetHost()
                .environmentObject(player)
        }
        .sheet(isPresented: $showLyricOffsetSheet) {
            CoLyricOffsetSheet()
        }
        .sheet(isPresented: $showAddToLocalPlaylist, onDismiss: { localPlaylistSheetMarksFavorite = false }) {
            if let song {
                AddToLocalPlaylistSheet(song: song) {
                    if localPlaylistSheetMarksFavorite {
                        favorites.setKugouLiked(song, liked: true)
                    }
                }
            }
        }
        .sheet(isPresented: $showArtistHome) {
            if !pickedArtistName.isEmpty {
                ArtistHomeSheet(artistName: pickedArtistName, artistSource: song?.source ?? .kugou)
                    .environmentObject(player)
            }
        }
        .confirmationDialog("选择歌手", isPresented: $showArtistPicker, titleVisibility: .visible) {
            ForEach(Array(artistNames.enumerated()), id: \.offset) { _, name in
                Button(name) {
                    pickedArtistName = name
                    CoHaptics.tap()
                    showArtistHome = true
                }
            }
            Button("取消", role: .cancel) {}
        }
        .overlay(alignment: .bottom) {
            ToastView(center: ToastCenter.shared)
        }
        // The record player uses a dark presentation surface by design, but its
        // child sheets must continue to follow the app's selected appearance.
        .preferredColorScheme(selectedThemeMode.colorScheme)
    }

    // MARK: - 背景（主题渐变兜底 + 封面毛玻璃 + 可读性遮罩）
    // 毛玻璃封面为 UIKit 独立图层（CoverBlurBackground），加载/换图不经过 SwiftUI
    // 布局，因此封面加载完成不会引发布局重算，彻底避免"封面加载后错乱"。

    private var background: some View {
        ZStack {
            // 静态渐变：随封面主色取色，不流动（用户要求封面外液态 UI 飘动效果暂停，保持静止）
            LinearGradient(
                colors: [palette.backgroundTop, palette.backgroundBottom],
                startPoint: .top, endPoint: .bottom
            )
            if !lyricBackgroundImagePath.isEmpty && (layoutRenderingShowLyrics || lyricBackgroundSyncCover) {
                lyricPlayerBackgroundLayer
            } else if theme.backgroundSyncAll, let image = theme.customBackgroundImage(for: colorScheme) {
                WallpaperImage(image: image)
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [.black.opacity(0.40), .black.opacity(0.58)]
                        : [.white.opacity(0.12), .black.opacity(0.24)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                CoverBlurBackground(url: displayCoverURL, scheme: colorScheme)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            AmbientGlowView(
                accent: palette.accent,
                secondary: palette.secondary,
                isPlaying: playerVisualsActive,
                dustMode: playerDustMode,
                dustDensity: playerDustDensity,
                dustSize: playerDustSize,
                breath: playerBreath
            )
            if djVisualEnabled {
                DJVisualView(
                    accent: palette.accent,
                    secondary: palette.secondary,
                    isPlaying: playerVisualsActive,
                    intensity: djVisualIntensity
                )
            }
            LinearGradient(
                colors: colorScheme == .dark
                    ? [.black.opacity(0.22), .clear, .black.opacity(0.34)]
                    : [.white.opacity(0.08), .clear, .black.opacity(0.12)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .allowsHitTesting(false)
    }

    // MARK: - iPad 横屏歌词

    /// 横屏时将唱片与歌词并排展示，竖屏继续使用各自的原有播放器布局。
    private var iPadLandscapeLyricsView: some View {
        GeometryReader { geo in
            ZStack {
                background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    iPadLandscapeLyricsHeader
                        .modifier(IPadLandscapeLayoutable(
                            part: .header,
                            style: layoutRenderingStyle,
                            enabled: layoutMode && layoutEditorUsesIPadLandscape,
                            data: $iPadLandscapeLayoutData
                        ))

                    HStack(alignment: .center, spacing: 34) {
                        VStack(spacing: 2) {
                            iPadLandscapeArtwork(
                                size: min(geo.size.height * 0.46, geo.size.width * 0.30)
                            )
                            .modifier(IPadLandscapeLayoutable(
                                part: .artwork,
                                style: layoutRenderingStyle,
                                enabled: layoutMode && layoutEditorUsesIPadLandscape,
                                data: $iPadLandscapeLayoutData
                            ))

                            iPadLandscapeControlDeck(bottomInset: 0)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: geo.size.width * 0.46)

                        Group {
                            if (layoutRenderingStyle == .appleMusic && showAppleMusicQueue)
                                || ((layoutRenderingStyle == .vinyl || layoutRenderingStyle == .record) && showVinylQueue) {
                                AppleMusicCompactQueueContent()
                                    .transition(.opacity)
                            } else {
                                iPadLandscapeLyricsColumn(geo: geo)
                                    .transition(.opacity)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .modifier(IPadLandscapeLayoutable(
                            part: .lyrics,
                            style: layoutRenderingStyle,
                            enabled: layoutMode && layoutEditorUsesIPadLandscape,
                            data: $iPadLandscapeLayoutData
                        ))
                        .animation(.easeInOut(duration: 0.22), value: showAppleMusicQueue)
                    }
                    .padding(.horizontal, 34)
                    .padding(.top, 4)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 8)
                }
            }
        }
    }

    @ViewBuilder
    private func iPadLandscapeLyricsColumn(geo: GeometryProxy) -> some View {
        Group {
            switch layoutRenderingStyle {
            case .appleMusic:
                AppleMusicLyricsSection(
                    lyrics: lyrics,
                    primary: landscapeApplePrimaryColor,
                    secondary: landscapeAppleSecondaryColor,
                    lyricOffset: CGFloat(lyricOffset)
                ) { line in
                    CoHaptics.tap()
                    seekToLyric(line)
                }
            case .vinyl, .record, .folia:
                iPadLandscapeVinylLyricsColumn(geo: geo)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { toggleLyrics() }
    }

    private func iPadLandscapeVinylLyricsColumn(geo: GeometryProxy) -> some View {
        Group {
            if lyrics.isEmpty {
                vinylEmptyLyricsView
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 34) {
                            Color.clear.frame(height: max(vinylLyricsLineSlotHeight * CGFloat(VinylLayoutDefaults.lyricTopRows), vinylLyricsViewportHeight * 0.18))
                            ForEach(lyrics.indices, id: \.self) { index in
                                vinylLyricLine(lyrics[index], index: index, isFocused: vinylCurrentVisualIndex == index, proxy: proxy)
                                    .id(index)
                                    .background {
                                        GeometryReader { rowGeometry in
                                            Color.clear.preference(
                                                key: LyricCenterPreferenceKey.self,
                                                value: [index: rowGeometry.frame(in: .named("iPadVinylLyricsViewport")).midY]
                                            )
                                        }
                                    }
                            }
                            Color.clear.frame(height: max(vinylLyricsLineSlotHeight * CGFloat(VinylLayoutDefaults.lyricBottomRows), vinylLyricsViewportHeight * 0.18))
                        }
                        .padding(.horizontal, 28)
                    }
                    .coordinateSpace(name: "iPadVinylLyricsViewport")
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
                                .onAppear { vinylLyricsViewportHeight = viewport.size.height }
                                .onChange(of: viewport.size.height) { vinylLyricsViewportHeight = $0 }
                        }
                    }
                    .onPreferenceChange(LyricCenterPreferenceKey.self) { centers in
                        vinylUpdateFocusedLyric(from: centers)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { _ in
                                vinylIsDraggingLyrics = true
                                vinylLyricsResumeTask?.cancel()
                            }
                            .onEnded { _ in
                                vinylScheduleLyricsResume(proxy: proxy)
                            }
                    )
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                            vinylScrollToCurrentLyric(proxy: proxy, animated: false)
                        }
                    }
                    .onChange(of: vinylCurrentLyricIndex) { _ in
                        guard !vinylIsDraggingLyrics else { return }
                        vinylScrollToCurrentLyric(proxy: proxy, animated: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear {
            vinylLyricsResumeTask?.cancel()
            vinylLyricTapTask?.cancel()
        }
    }

    @ViewBuilder
    private var iPadLandscapeLyricsHeader: some View {
        switch layoutRenderingStyle {
        case .appleMusic:
            iPadLandscapeAppleMusicLyricsHeader
        case .vinyl, .record, .folia:
            iPadLandscapeVinylLyricsHeader
        }
    }

    private var iPadLandscapeAppleMusicLyricsHeader: some View {
        HStack(spacing: 12) {
            Button {
                CoHaptics.tap()
                toggleLyrics()
            } label: {
                CoverImage(url: displayCoverURL, size: 48, cornerRadius: 10)
                    .shadow(color: .black.opacity(0.26), radius: 9, y: 4)
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.94))

            VStack(alignment: .leading, spacing: 3) {
                Text(song?.name ?? "未在播放")
                    .font(CoFont.appFont(15, .semibold))
                    .foregroundStyle(landscapeApplePrimaryColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contextMenu {
                        Button("复制歌名") { copyCurrentSongTitle() }
                    }
                Text(subtitle)
                    .font(CoFont.appFont(12, .medium))
                    .foregroundStyle(landscapeAppleSecondaryColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentShape(Rectangle())
                    .onTapGesture { openArtistHome() }
            }

            Spacer(minLength: 0)

            HStack(spacing: 0) {
                Button {
                    CoHaptics.tap()
                    if let song {
                        toggleLocalFavorite(song)
                    }
                } label: {
                    FavoriteHeartView(mark: favoriteMark(for: song), size: 17, inactiveColor: landscapeApplePrimaryColor.opacity(0.78))
                        .frame(width: 38, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Menu {
                    Button("清空播放列表", role: .destructive) {
                        showClearQueueConfirm = true
                    }
                    Divider()
                    Button("定时关闭") { showSleepTimer = true }
                    Button("添加到本地歌单") { showAddToLocalPlaylist = true }
                    Button("播放器设置") { openPlayerSettings() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(landscapeApplePrimaryColor.opacity(0.78))
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
        .padding(.horizontal, 30)
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
    }

    private var iPadLandscapeVinylLyricsHeader: some View {
        HStack(spacing: 18) {
            HStack(spacing: 12) {
                Button {
                    CoHaptics.tap()
                    toggleLyrics()
                } label: {
                    CoverImage(url: displayCoverURL, size: 48, cornerRadius: 10)
                        .shadow(color: .black.opacity(0.26), radius: 9, y: 4)
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.94))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(song?.name ?? "未在播放")
                            .font(CoFont.appFont(15, .semibold))
                            .foregroundStyle(albumTitleForeground)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .contextMenu {
                                Button("复制歌名") { copyCurrentSongTitle() }
                            }
                        if showSongVIPBadge, song?.isVIP == true {
                            Text("VIP")
                                .font(CoFont.appFont(8, .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(Color.coThemeRed))
                        }
                    }
                    Text(subtitle)
                        .font(CoFont.appFont(12, .medium))
                        .foregroundStyle(albumArtistForeground)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .contentShape(Rectangle())
                        .onTapGesture { openArtistHome() }
                }
                .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            HStack(spacing: 0) {
                Button {
                    CoHaptics.tap()
                    if let song {
                        toggleLocalFavorite(song)
                    }
                } label: {
                    FavoriteHeartView(mark: favoriteMark(for: song), size: 17, inactiveColor: albumTitleColor.opacity(0.78))
                        .frame(width: 38, height: 38)
                        .background { CoGlass(shape: Circle(), forceLiquid: true) }
                        .clipShape(Circle())
                        .contentShape(Rectangle())
                }
                .buttonStyle(GlassPressButtonStyle())

                Menu {
                    Button("定时关闭") { showSleepTimer = true }
                    Button("添加到本地歌单") { showAddToLocalPlaylist = true }
                    customCoverActions
                    Button("播放器设置") { openPlayerSettings() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(albumTitleForeground.opacity(0.78))
                        .frame(width: 38, height: 38)
                        .background { CoGlass(shape: Circle(), forceLiquid: true) }
                        .clipShape(Circle())
                        .contentShape(Rectangle())
                }
                .buttonStyle(GlassPressButtonStyle())
            }
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)
        }
        .padding(.horizontal, 30)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64, alignment: .leading)
    }

    @ViewBuilder
    private func iPadLandscapeControlDeck(bottomInset: CGFloat) -> some View {
        switch layoutRenderingStyle {
        case .appleMusic:
            iPadLandscapeAppleMusicControlDeck(bottomInset: bottomInset)
        case .vinyl, .record, .folia:
            iPadLandscapeCompactControlDeck(bottomInset: bottomInset)
        }
    }

    private func iPadLandscapeCompactControlDeck(bottomInset: CGFloat) -> some View {
        VStack(spacing: 8) {
            progressBlock(
                styleOverride: 0,
                accentOverride: .white.opacity(0.92)
            )
            .modifier(IPadLandscapeLayoutable(
                part: .progress,
                style: layoutRenderingStyle,
                enabled: layoutMode && layoutEditorUsesIPadLandscape,
                data: $iPadLandscapeLayoutData
            ))

            HStack(spacing: 0) {
                vinylSideControl(icon: player.playMode.icon, active: player.playMode == .shuffle, part: .loop, appliesPortraitLayout: false) {
                    player.togglePlayMode()
                }
                .frame(maxWidth: .infinity)
                vinylTransportControl(icon: "backward.fill", size: 22, part: .previous, appliesPortraitLayout: false) {
                    player.previous()
                }
                .frame(maxWidth: .infinity)
                Button {
                    CoHaptics.tap()
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 29, weight: .bold))
                        .frame(width: 58, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                vinylTransportControl(icon: "forward.fill", size: 22, part: .next, appliesPortraitLayout: false) {
                    player.next()
                }
                .frame(maxWidth: .infinity)
                vinylSideControl(icon: "list.bullet", part: .queue, appliesPortraitLayout: false) {
                    if layoutRenderingStyle == .vinyl || layoutRenderingStyle == .record {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showVinylQueue.toggle()
                        }
                    } else {
                        showQueue = true
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(.white)
            .modifier(IPadLandscapeLayoutable(
                part: .controls,
                style: layoutRenderingStyle,
                enabled: layoutMode && layoutEditorUsesIPadLandscape,
                data: $iPadLandscapeLayoutData
            ))
        }
        .frame(maxWidth: 640)
        .padding(.horizontal, 26)
        .padding(.top, 6)
        .padding(.bottom, max(10, bottomInset + 2))
        .frame(maxWidth: .infinity)
        .simultaneousGesture(
            layoutRenderingStyle == .vinyl || layoutRenderingStyle == .record
                ? AnyGesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { value in
                            guard value.translation.height < -54,
                                  abs(value.translation.height) > abs(value.translation.width) else { return }
                            CoHaptics.medium()
                            showComments = true
                        }
                )
                : nil
        )
    }

    private func iPadLandscapeAppleMusicControlDeck(bottomInset: CGFloat) -> some View {
        let progress = IPadLandscapeLayoutStore.displayEntry(
            for: .progress,
            style: layoutRenderingStyle,
            in: iPadLandscapeLayoutData
        )
        let controls = IPadLandscapeLayoutStore.displayEntry(
            for: .controls,
            style: layoutRenderingStyle,
            in: iPadLandscapeLayoutData
        )

        return AppleMusicPlaybackControls(
            bottomInset: bottomInset,
            primary: landscapeApplePrimaryColor,
            secondary: landscapeAppleSecondaryColor,
            accent: landscapeAppleAccentColor,
            volumeColor: landscapeApplePrimaryColor,
            showVolume: appleShowVolume,
            lyricsActive: true,
            queueActive: showAppleMusicQueue,
            layout: AppleMusicPlaybackControlLayout(
                progress: progress,
                previous: PlayerLayoutEntry(),
                play: PlayerLayoutEntry(),
                next: PlayerLayoutEntry(),
                volume: PlayerLayoutEntry(),
                actions: PlayerLayoutEntry(),
                container: controls
            ),
            onLyrics: {
                if showAppleMusicQueue {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showAppleMusicQueue = false
                    }
                } else {
                    toggleLyrics()
                }
            },
            onQueue: {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showAppleMusicQueue.toggle()
                }
            },
            onComments: { showComments = true }
        )
    }

    @ViewBuilder
    private func iPadLandscapeArtwork(size: CGFloat) -> some View {
        VStack(spacing: 14) {
            if layoutRenderingStyle == .vinyl || layoutRenderingStyle == .record {
                VinylTurntableView(
                    coverURL: displayCoverURL,
                    isPlaying: playerVisualsActive,
                    trackId: song?.id,
                    size: size,
                    playsCoverVideoAudio: true,
                    onTap: { toggleLyrics() },
                    onNextTrack: { player.next() },
                    onPreviousTrack: { player.previous() }
                )
            } else {
                let cornerRadius: CGFloat = 18
                CoverImage(url: displayCoverURL, size: size, cornerRadius: cornerRadius, playsCoverVideoAudio: true)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.38), radius: 24, y: 12)
            }

            VStack(spacing: 4) {
                Text(song?.name ?? "未在播放")
                    .font(CoFont.appFont(18, .bold))
                    .foregroundStyle(playerButtonText)
                    .lineLimit(1)
                    .contextMenu {
                        Button("复制歌名") {
                            copyCurrentSongTitle()
                        }
                    }
                Text(song?.artists ?? "")
                    .font(CoFont.appFont(13, .medium))
                    .foregroundStyle(playerButtonSecondaryText)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture { openArtistHome() }
            }
            .frame(maxWidth: size + 56)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleLyrics()
        }
    }

    @ViewBuilder
    private var lyricPlayerBackgroundLayer: some View {
        if let image = CoImageFileCache.image(at: lyricBackgroundImagePath) {
            GeometryReader { proxy in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width + 96, height: proxy.size.height + 96)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .blur(radius: CGFloat(lyricBackgroundBlur))
                    .overlay(Color.black.opacity(colorScheme == .dark ? 0.48 : 0.34))
                    .clipped()
            }
            .ignoresSafeArea()
        } else {
            CoverBlurBackground(url: displayCoverURL, scheme: colorScheme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 顶栏（收起 / 状态 / 红心 / 队列）

    @ViewBuilder
    private var headerBar: some View {
        HStack(spacing: 14) {
            Button {
                CoHaptics.tap()
                closePlayer()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(playerButtonText)
                    .frame(width: 38, height: 38)
                    .background {
                        playerButtonSurface(size: 38)
                    }
                    .clipShape(Circle())
            }
            .buttonStyle(GlassPressButtonStyle())
            .modifier(Layoutable(part: .topBack, enabled: layoutMode, data: $layoutData))

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text(LocalizedStringKey(player.isBuffering ? "加载中…" : (player.isPlaying ? "正在播放" : "已暂停")))
                    .font(CoFont.appFont(12, .semibold))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                Text(song?.album ?? "Co")
                    .font(CoFont.appFont(10))
                    .foregroundStyle(palette.secondary.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(minWidth: 118, maxWidth: 190)
            .modifier(Layoutable(part: .topTitle, enabled: layoutMode, data: $layoutData))

            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button {
                    CoHaptics.tap()
                    if let song {
                        toggleLocalFavorite(song)
                    }
                } label: {
                    FavoriteHeartView(mark: favoriteMark(for: song), size: 15, inactiveColor: playerButtonText)
                        .frame(width: 38, height: 38)
                        .background {
                            playerButtonSurface(size: 38, active: localLibrary.containsSong(song))
                        }
                        .clipShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
                .modifier(Layoutable(part: .topFavorite, enabled: false, data: $layoutData))

                Menu {
                    Button("定时关闭") { showSleepTimer = true }
                    Button("添加到本地歌单") { showAddToLocalPlaylist = true }
                    Button("播放器设置") { openPlayerSettings() }
                    Button("歌词偏移") { showLyricOffsetSheet = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(playerButtonText)
                        .frame(width: 38, height: 38)
                        .background {
                            playerButtonSurface(size: 38)
                        }
                        .clipShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 1)
    }

    private var playerMoreActionsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "speedometer")
                    .font(.system(size: 13, weight: .semibold))
                Text("倍速播放")
                    .font(CoFont.appFont(13, .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(palette.text)

            HStack(spacing: 6) {
                ForEach(rateOptions, id: \.self) { option in
                    Button {
                        player.setRate(option)
                        CoHaptics.select()
                    } label: {
                        Text(String(format: "%.2gx", option))
                            .font(CoFont.appFont(10, .semibold))
                            .foregroundStyle(abs(player.rate - option) < 0.01 ? Color.white : palette.text)
                            .frame(width: 36, height: 28)
                            .background {
                                Capsule().fill(abs(player.rate - option) < 0.01 ? controlAccent : Color.white.opacity(0.08))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().overlay(Color.white.opacity(0.12))

            moreActionRow("定时关闭", systemName: player.sleepTimerRemaining > 0 ? "moon.zzz.fill" : "moon.zzz") {
                showMoreActions = false
                showSleepTimer = true
            }
            moreActionRow("添加到本地歌单", systemName: "text.badge.plus") {
                showMoreActions = false
                showAddToLocalPlaylist = true
            }
            if customCovers.hasCover(for: song) {
                moreActionRow("恢复默认封面", systemName: "arrow.uturn.backward") {
                    showMoreActions = false
                    customCovers.removeCover(for: song)
                    Task { await extractCoverPalette() }
                    ToastCenter.shared.show("已恢复默认封面")
                }
            }
            moreActionRow("播放器设置", systemName: "slider.horizontal.3") {
                showMoreActions = false
                openPlayerSettings()
            }
            moreActionRow("软件音量", systemName: "speaker.wave.2.fill") {
                showMoreActions = false
                showSoftwareVolume = true
            }
        }
        .padding(14)
        .frame(width: 292)
        .background {
            CoGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .coCardShadow(radius: 14, y: 8)
    }


    private func moreActionRow(_ title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            CoHaptics.tap()
            withAnimation(.spring(response: 0.20, dampingFraction: 0.9)) {
                action()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 20)
                Text(LocalizedStringKey(title))
                    .font(CoFont.appFont(13, .semibold))
                Spacer()
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Capsule().fill(Color.white.opacity(0.07)))
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.98))
    }

    // MARK: - 中间内容区（专辑 / 歌词 两模式独立视图，自动布局居中）

    @ViewBuilder
    private func content(geo: GeometryProxy) -> some View {
        ZStack {
            if song == nil {
                placeholderView
            } else if layoutRenderingStyle == .vinyl || layoutRenderingStyle == .record {
                if showVinylQueue {
                    vinylQueuePanel
                        .transition(.opacity)
                } else if layoutRenderingShowLyrics {
                    vinylLyricsPanel(geo: geo)
                        .transition(.opacity)
                } else {
                    vinylAlbumPanel(geo: geo)
                        .transition(.opacity)
                }
            } else if layoutRenderingShowLyrics {
                lyricsPanel(geo: geo)
                    .transition(.opacity)
            } else {
                albumPanel(geo: geo)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.22), value: layoutRenderingShowLyrics)
        .animation(.easeInOut(duration: 0.22), value: showVinylQueue)
    }

    private var vinylQueuePanel: some View {
        VStack(spacing: 12) {
            vinylCompactHeader
                .padding(.horizontal, 18)
            AppleMusicCompactQueueContent()
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 4)
    }

    /// 封面尺寸：固定算法，与布局时序无关
    private func coverSize(in geo: GeometryProxy) -> CGFloat {
        min(280, min(geo.size.width * 0.60, geo.size.height * 0.44))
    }

    /// 专辑模式：封面居中 + 歌名/歌手 + 轻点提示（VStack 自动居中）
    @ViewBuilder
    private func albumPanel(geo: GeometryProxy) -> some View {
        switch layoutRenderingStyle {
        case .appleMusic:
            appleMusicAlbumPanel(geo: geo)
        case .vinyl, .record, .folia:
            vinylAlbumPanel(geo: geo)
        }
    }

    private func vinylAlbumPanel(geo: GeometryProxy) -> some View {
        let size = min(304, min(geo.size.width * 0.72, geo.size.height * 0.48))
        return VStack(spacing: 12) {
            vinylCompactHeader
                .padding(.horizontal, 18)
                .padding(.top, 0)

            Spacer(minLength: 0)

            VinylTurntableView(
                coverURL: displayCoverURL,
                isPlaying: playerVisualsActive,
                trackId: song?.id,
                size: size,
                playsCoverVideoAudio: true,
                onTap: { toggleLyrics() },
                onNextTrack: { player.next() },
                onPreviousTrack: { player.previous() }
            )
            .modifier(Layoutable(
                part: .vinylCover,
                enabled: layoutMode && !layoutEditorUsesIPadLandscape,
                data: $vinylLayoutData,
                defaultEntry: VinylPlayerLayoutStore.defaultEntry(for: .vinylCover)
            ))

            Spacer(minLength: 0)
        }
        .padding(.bottom, deckInset + geo.safeAreaInsets.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard value.translation.height < -54,
                          abs(value.translation.height) > abs(value.translation.width) else { return }
                    CoHaptics.medium()
                    showComments = true
                }
        )
    }

    private var vinylCompactHeader: some View {
        HStack(spacing: 12) {
            Button {
                toggleLyrics()
            } label: {
                CoverImage(url: displayCoverURL, size: 48, cornerRadius: 12)
                    .shadow(color: .black.opacity(0.26), radius: 9, y: 4)
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.94))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(song?.name ?? "未在播放")
                        .font(CoFont.appFont(15, .semibold))
                        .foregroundStyle(albumTitleForeground)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .contextMenu {
                            Button("复制歌名") { copyCurrentSongTitle() }
                        }
                    if showSongVIPBadge, song?.isVIP == true {
                        Text("VIP")
                            .font(CoFont.appFont(8, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Color.coThemeRed))
                    }
                }
                Text(subtitle)
                    .font(CoFont.appFont(12, .medium))
                    .foregroundStyle(albumArtistForeground)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentShape(Rectangle())
                    .onTapGesture { openArtistHome() }
            }
            .modifier(Layoutable(
                part: .vinylTitle,
                enabled: layoutMode && !layoutEditorUsesIPadLandscape,
                data: $vinylLayoutData,
                defaultEntry: VinylPlayerLayoutStore.defaultEntry(for: .vinylTitle)
            ))

            Spacer(minLength: 0)

            Button {
                CoHaptics.tap()
                guard let song else { return }
                toggleLocalFavorite(song)
            } label: {
                FavoriteHeartView(mark: favoriteMark(for: song), size: 17, inactiveColor: albumTitleColor.opacity(0.78))
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("定时关闭") { showSleepTimer = true }
                Button("添加到本地歌单") { showAddToLocalPlaylist = true }
                customCoverActions
                Button("播放器设置") { openPlayerSettings() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(albumTitleForeground.opacity(0.82))
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func vinylLyricsPanel(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // iPad 竖屏歌词页与黑胶播放器页复用同一顶部栏，避免两个页面的点击热区和排版漂移。
            (UIDevice.current.userInterfaceIdiom == .pad ? AnyView(vinylCompactHeader) : AnyView(vinylLyricsHeader))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .modifier(Layoutable(
                    part: .vinylLyricsHeader,
                    enabled: layoutMode && !layoutEditorUsesIPadLandscape,
                    data: $vinylLayoutData,
                    defaultEntry: VinylPlayerLayoutStore.defaultEntry(for: .vinylLyricsHeader)
                ))
                .zIndex(3)

            Spacer(minLength: 0)

            Group {
                if lyrics.isEmpty {
                    vinylEmptyLyricsView
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: 34) {
                                Color.clear.frame(height: max(vinylLyricsLineSlotHeight * CGFloat(VinylLayoutDefaults.lyricTopRows), vinylLyricsViewportHeight * 0.18))
                                ForEach(lyrics.indices, id: \.self) { index in
                                    vinylLyricLine(lyrics[index], index: index, isFocused: vinylCurrentVisualIndex == index, proxy: proxy)
                                        .id(index)
                                        .background {
                                            GeometryReader { rowGeometry in
                                                Color.clear.preference(
                                                    key: LyricCenterPreferenceKey.self,
                                                    value: [index: rowGeometry.frame(in: .named("vinylLyricsViewport")).midY]
                                                )
                                            }
                                        }
                                }
                                Color.clear.frame(height: max(vinylLyricsLineSlotHeight * CGFloat(VinylLayoutDefaults.lyricBottomRows), vinylLyricsViewportHeight * 0.18))
                            }
                            .padding(.horizontal, 28)
                        }
                        .coordinateSpace(name: "vinylLyricsViewport")
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
                                    .onAppear { vinylLyricsViewportHeight = viewport.size.height }
                                    .onChange(of: viewport.size.height) { vinylLyricsViewportHeight = $0 }
                            }
                        }
                        .onPreferenceChange(LyricCenterPreferenceKey.self) { centers in
                            vinylUpdateFocusedLyric(from: centers)
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 4)
                                .onChanged { _ in
                                    vinylIsDraggingLyrics = true
                                    vinylLyricsResumeTask?.cancel()
                                }
                                .onEnded { _ in
                                    vinylScheduleLyricsResume(proxy: proxy)
                                }
                        )
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                                vinylScrollToCurrentLyric(proxy: proxy, animated: false)
                            }
                        }
                        .onChange(of: vinylCurrentLyricIndex) { _ in
                            guard !vinylIsDraggingLyrics else { return }
                            vinylScrollToCurrentLyric(proxy: proxy, animated: true)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: vinylLyricsViewportHeightLimit(in: geo))
            .modifier(Layoutable(
                part: .vinylLyricsText,
                enabled: layoutMode && !layoutEditorUsesIPadLandscape,
                data: $vinylLayoutData,
                defaultEntry: VinylPlayerLayoutStore.defaultEntry(for: .vinylLyricsText)
            ))
            .zIndex(1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear {
            vinylLyricsResumeTask?.cancel()
            vinylLyricTapTask?.cancel()
        }
    }

    private var vinylLyricsHeader: some View {
        HStack(spacing: 12) {
            Button {
                CoHaptics.tap()
                toggleLyrics()
            } label: {
                CoverImage(url: displayCoverURL, size: 48, cornerRadius: 10)
                    .shadow(color: .black.opacity(0.26), radius: 9, y: 4)
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.94))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(song?.name ?? "未在播放")
                        .font(CoFont.appFont(15, .semibold))
                        .foregroundStyle(albumTitleForeground)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .contextMenu {
                            Button("复制歌名") { copyCurrentSongTitle() }
                        }
                    if showSongVIPBadge, song?.isVIP == true {
                        Text("VIP")
                            .font(CoFont.appFont(8, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Color.coThemeRed))
                    }
                }
                Text(subtitle)
                    .font(CoFont.appFont(12, .medium))
                    .foregroundStyle(albumArtistForeground)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentShape(Rectangle())
                    .onTapGesture { openArtistHome() }
            }

            Spacer(minLength: 0)

            Button {
                CoHaptics.tap()
                guard let song else { return }
                toggleLocalFavorite(song)
            } label: {
                FavoriteHeartView(mark: favoriteMark(for: song), size: 17, inactiveColor: albumTitleColor.opacity(0.78))
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("定时关闭") { showSleepTimer = true }
                Button("添加到本地歌单") { showAddToLocalPlaylist = true }
                customCoverActions
                Button("播放器设置") { openPlayerSettings() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(albumTitleForeground.opacity(0.82))
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: 420)
    }

    private var vinylEmptyLyricsView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "quote.bubble")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(albumArtistForeground.opacity(0.5))
            Text("暂无歌词")
                .font(CoFont.appFont(15, .semibold))
                .foregroundStyle(albumTitleForeground.opacity(0.9))
            Text("点击封面区域返回歌曲页面")
                .font(CoFont.appFont(12))
                .foregroundStyle(albumArtistForeground.opacity(0.56))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            CoHaptics.tap()
            toggleLyrics()
        }
    }

    private func vinylLyricLine(_ line: LyricLine, index: Int, isFocused: Bool, proxy: ScrollViewProxy) -> some View {
        let isSelected = vinylSelectedLyricIndex == index || (vinylIsDraggingLyrics && isFocused)
        let visualFocus = isFocused || isSelected
        let isActive = vinylCurrentLyricIndex == index
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(line.text.isEmpty ? " " : line.text)
                    .font(CoFont.appFont(visualFocus ? 27 : 23, visualFocus ? .bold : .semibold))
                    .foregroundStyle(albumTitleForeground)
                    .opacity(visualFocus ? 1 : 0.36)
                    .fixedSize(horizontal: false, vertical: true)
                if isSelected {
                    Spacer(minLength: 8)
                    Text(coTimeString(line.time))
                        .font(CoFont.appFont(11, .semibold, .default))
                        .foregroundStyle(albumArtistForeground.opacity(0.82))
                    Button {
                        vinylLyricTapTask?.cancel()
                        playVinylLyric(line, index: index, proxy: proxy)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(albumTitleColor)
                            .frame(width: 24, height: 24)
                            .background(albumTitleColor.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if visualFocus, let translation = line.translation, !translation.isEmpty {
                Text(translation)
                    .font(CoFont.appFont(15, .medium))
                    .foregroundStyle(albumArtistForeground.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .scaleEffect(visualFocus ? 1.06 : 0.84, anchor: .leading)
        .blur(radius: visualFocus ? 0 : 0.7)
        .onTapGesture {
            scheduleVinylLyricSelection(index)
        }
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    vinylLyricTapTask?.cancel()
                    playVinylLyric(line, index: index, proxy: proxy)
                }
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: visualFocus)
    }

    private func scheduleVinylLyricSelection(_ index: Int) {
        vinylLyricTapTask?.cancel()
        vinylLyricTapTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                vinylSelectedLyricIndex = index
            }
            CoHaptics.tap()
        }
    }

    private func playVinylLyric(_ line: LyricLine, index: Int, proxy: ScrollViewProxy) {
        vinylSelectedLyricIndex = index
        vinylLyricsResumeTask?.cancel()
        vinylIsDraggingLyrics = false
        vinylFocusedLyricIndex = nil
        CoHaptics.tap()
        seekToLyric(line)
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.3)) {
            proxy.scrollTo(index, anchor: vinylLyricsFocusAnchor)
        }
    }

    private var vinylCurrentLyricIndex: Int? {
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

    private var vinylCurrentVisualIndex: Int? {
        vinylIsDraggingLyrics ? (vinylFocusedLyricIndex ?? vinylCurrentLyricIndex) : vinylCurrentLyricIndex
    }

    private var vinylLyricsLineSlotHeight: CGFloat {
        max(56, CGFloat(lyricFontSize) * 1.9 + CGFloat(lyricLineSpacing))
    }

    private var vinylLyricsFocusAnchor: UnitPoint {
        let total = CGFloat(max(VinylLayoutDefaults.lyricTopRows + VinylLayoutDefaults.lyricBottomRows, 1))
        let y = min(max(CGFloat(VinylLayoutDefaults.lyricTopRows) / total, 0.18), 0.82)
        return UnitPoint(x: 0.5, y: y)
    }

    private func vinylLyricsViewportHeightLimit(in geo: GeometryProxy) -> CGFloat {
        let desired = CGFloat(VinylLayoutDefaults.lyricTopRows + VinylLayoutDefaults.lyricBottomRows + 1) * vinylLyricsLineSlotHeight
        let available = max(220, geo.size.height - 100)
        return min(max(220, desired), available)
    }

    private func vinylUpdateFocusedLyric(from centers: [Int: CGFloat]) {
        guard vinylIsDraggingLyrics, vinylLyricsViewportHeight > 0, !centers.isEmpty else { return }
        let focusY = vinylLyricsViewportHeight * vinylLyricsFocusAnchor.y
        let nextIndex = centers.min { abs($0.value - focusY) < abs($1.value - focusY) }?.key
        vinylFocusedLyricIndex = nextIndex
        vinylSelectedLyricIndex = nextIndex
    }

    private func vinylScrollToCurrentLyric(proxy: ScrollViewProxy, animated: Bool) {
        guard let index = vinylCurrentLyricIndex else { return }
        let action = { proxy.scrollTo(index, anchor: vinylLyricsFocusAnchor) }
        if animated {
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.38)) { action() }
        } else {
            action()
        }
    }

    private func vinylScheduleLyricsResume(proxy: ScrollViewProxy) {
        vinylLyricsResumeTask?.cancel()
        let target = vinylFocusedLyricIndex ?? vinylCurrentLyricIndex
        if let target {
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.34)) {
                proxy.scrollTo(target, anchor: vinylLyricsFocusAnchor)
            }
        }
        vinylLyricsResumeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            vinylIsDraggingLyrics = false
            vinylFocusedLyricIndex = nil
            vinylLyricsResumeTask = nil
        }
    }


    private func appleMusicAlbumPanel(geo: GeometryProxy) -> some View {
        let size = coverSize(in: geo)
        let coverRadius: CGFloat = circularCover ? size / 2 : min(24, size * 0.08)
        return VStack(spacing: 12) {
            Spacer(minLength: 0)

            Button {
                toggleLyrics()
            } label: {
                ZStack {
                    // 静态装饰层（光晕 + 托盘）：不再呼吸/浮动（用户要求飘动效果暂停），封面本体静止
                    ZStack {
                            // 主色光晕（呼吸）
                            Circle()
                                .fill(palette.accent.opacity(0.24))
                                .frame(width: size * 1.38, height: size * 1.38)
                                .blur(radius: 46)
                                .scaleEffect(1.0)
                            // 次色光晕（反向呼吸，增加层次）
                            Circle()
                                .fill(palette.secondary.opacity(0.15))
                                .frame(width: size * 1.10, height: size * 1.10)
                                .blur(radius: 40)
                                .scaleEffect(1.0)
                            // 液态玻璃托盘（圆形模式用圆形托盘）
                            if circularCover {
                                CoGlass(shape: Circle())
                                    .frame(width: size * 1.10, height: size * 1.10)
                                    .shadow(color: .black.opacity(0.28), radius: 26, y: 12)
                                    .offset(y: 0)
                            } else {
                                CoGlass(shape: RoundedRectangle(cornerRadius: min(30, size * 0.10), style: .continuous))
                                    .frame(width: size * 1.10, height: size * 1.10)
                                    .shadow(color: .black.opacity(0.28), radius: 26, y: 12)
                                    .offset(y: 0)
                            }
                        }
                    .allowsHitTesting(false)

                    // 封面（静态）
                    CoverImage(
                        url: displayCoverURL,
                        size: size,
                        cornerRadius: coverRadius,
                        emptyHint: player.isBuffering ? "等待开始播放…" : nil,
                        playsCoverVideoAudio: true
                    )
                        .matchedGeometryEffect(id: "playerCover", in: coverNS)
                        .id(song?.identityKey ?? "empty-cover")
                        .modifier(CoverSpin(enabled: circularCover && circularCoverSpin, isPlaying: playerVisualsActive))
                        .overlay {
                            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
                        }
                        .overlay {
                            // 顶部玻璃反光
                            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.28), .white.opacity(0.03), .clear],
                                        startPoint: .top, endPoint: .center
                                    )
                                )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                        .shadow(color: .black.opacity(0.38), radius: 24, y: 12)
                        .scaleEffect(coverSwitchPulse ? 0.94 : 1)
                        .blur(radius: coverSwitchPulse ? 2 : 0)
                        .rotation3DEffect(.degrees(Double(coverDrag.height / -18)), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
                        .rotation3DEffect(.degrees(Double(coverDrag.width / 18)), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
                        .offset(x: coverDrag.width * 0.05, y: coverDrag.height * 0.05)
                        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: coverDrag)
                        .animation(.easeOut(duration: 0.24), value: coverSwitchPulse)
                }
                .frame(width: size * 1.10, height: size * 1.10)
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            guard swipeSwitchSong else { return }
                            coverDrag = value.translation
                            let x = value.translation.width
                            if abs(x) > abs(value.translation.height) {
                                swipeOffset = x
                            }
                        }
                        .onEnded { value in
                            handleSwipeEnd(horizontal: value.translation.width)
                        }
                )
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.96))
            .modifier(Layoutable(part: .cover, enabled: layoutMode, data: $layoutData))

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text(song?.name ?? "未在播放")
                        .font(CoFont.appFont(22, .bold))
                        .foregroundStyle(albumTitleForeground)
                        .lineLimit(2)
                        .minimumScaleFactor(0.55)
                        .multilineTextAlignment(.center)
                        .contextMenu {
                            Button("复制歌名") {
                                copyCurrentSongTitle()
                            }
                        }
                        .shadow(color: albumGlow(albumTitleColor, strong: true), radius: albumTextGlow ? 10 : 0, y: 2)
                    if showSongVIPBadge, song?.isVIP == true {
                        Text("VIP")
                            .font(CoFont.appFont(9, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.coThemeRed))
                            .shadow(color: palette.accent.opacity(0.45), radius: 6)
                    }
                }
                .shadow(color: albumTextGlow ? palette.accent.opacity(0.30) : .clear, radius: albumTextGlow ? 10 : 0)
                Text(subtitle)
                    .font(CoFont.appFont(14, .medium))
                    .foregroundStyle(albumArtistForeground)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .shadow(color: albumGlow(albumArtistColor), radius: albumTextGlow ? 7 : 0, y: 1)
                    .contentShape(Rectangle())
                    .onTapGesture { openArtistHome() }
            }
            .padding(.horizontal, 36)
            .modifier(Layoutable(part: .title, enabled: layoutMode, data: $layoutData))


            // 封面下歌词阅览（固定高度预留，歌词加载后布局不跳动）
            lyricPreviewBox
                .modifier(Layoutable(part: .previewLyric, enabled: layoutMode, data: $layoutData))

            Spacer(minLength: 0)
        }
        .padding(.bottom, deckInset + geo.safeAreaInsets.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 左右滑动切歌：左滑下一首、右滑上一首，仅响应横向手势。
        // 使用 .gesture 与封面点击互斥：拖动时不会误触点击封面。
        .offset(x: swipeOffset)
        .opacity(CGFloat(1) - min(abs(swipeOffset) / CGFloat(260), CGFloat(0.35)))
        .gesture(
            DragGesture(minimumDistance: 15)
                .onChanged { value in
                    guard swipeSwitchSong else { return }
                    coverDrag = value.translation
                    let x = value.translation.width
                    if abs(x) > abs(value.translation.height) {
                        swipeOffset = x
                    }
                }
                .onEnded { value in
                    handleSwipeEnd(horizontal: value.translation.width)
                }
        )
    }

    /// 封面下歌词阅览：最多 5 行，跟随当前播放行自动滚动预览
    private var lyricPreviewBox: some View {
        let rows = lyricPreviewRows
        return VStack(spacing: 3) {
            if rows.isEmpty {
                Text("暂无歌词，点击封面查看完整歌词")
                    .font(CoFont.appFont(12))
                    .foregroundStyle(albumPreviewDimForeground)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 6) {
                        Text(item.isCurrent ? "●" : "·")
                            .font(CoFont.appFont(8))
                            .foregroundStyle(item.isCurrent ? albumPreviewLyricColor : albumPreviewDimColor.opacity(0.5))
                        Text(item.text)
                            .font(CoFont.appFont(12, item.isCurrent ? .semibold : .regular))
                            .foregroundStyle(item.isCurrent ? albumPreviewForeground : albumPreviewDimForeground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .shadow(color: albumGlow(item.isCurrent ? albumPreviewLyricColor : albumPreviewDimColor), radius: albumTextGlow && item.isCurrent ? 8 : 0, y: 1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 5 * 18 + 4 * 3)
        .padding(.horizontal, 40)
        .contentShape(Rectangle())
        .onTapGesture { toggleLyrics() }
    }

    /// 歌词预览行数据：当前行前后各取几行，最多 5 行
    private struct LyricPreviewRow {
        let text: String
        let isCurrent: Bool
    }

    /// 当前歌词行索引（二分查找，与歌词面板一致）
    private var previewCurrentIndex: Int? {
        guard !lyrics.isEmpty else { return nil }
        var low = 0
        var high = lyrics.count - 1
        var answer: Int?
        while low <= high {
            let mid = (low + high) / 2
            if lyrics[mid].time <= LyricTiming.effectiveProgress(clock.progress, userOffset: lyricOffset) {
                answer = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return answer
    }

    private var lyricPreviewRows: [LyricPreviewRow] {
        guard !lyrics.isEmpty else { return [] }
        var rows: [LyricPreviewRow] = []
        if let idx = previewCurrentIndex {
            let start = max(0, idx - 2)
            for i in start..<min(lyrics.count, start + 5) {
                let text = lyrics[i].text
                rows.append(LyricPreviewRow(text: text.isEmpty ? " " : text, isCurrent: i == idx))
            }
        } else {
            for i in 0..<min(5, lyrics.count) {
                let text = lyrics[i].text
                rows.append(LyricPreviewRow(text: text.isEmpty ? " " : text, isCurrent: i == 0))
            }
        }
        return rows
    }


    /// 歌词模式：左上小封面 + 歌名信息条 + 居中歌词（自动布局，歌词可滚动到底部透过底栏玻璃）
    @ViewBuilder
    private func lyricsPanel(geo: GeometryProxy) -> some View {
        ZStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                Button {
                    toggleLyrics()
                } label: {
                    CoverImage(url: displayCoverURL, size: 48, cornerRadius: circularCover ? 24 : 12)
                        .matchedGeometryEffect(id: "playerCover", in: coverNS)
                        .modifier(CoverSpin(enabled: circularCover && circularCoverSpin, isPlaying: playerVisualsActive))
                        .overlay {
                            RoundedRectangle(cornerRadius: circularCover ? 24 : 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                        }
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.9))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(song?.name ?? "")
                            .font(CoFont.appFont(14, .semibold))
                            .foregroundStyle(palette.text)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if showSongVIPBadge, song?.isVIP == true {
                            Text("VIP")
                                .font(CoFont.appFont(8, .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(Color.coThemeRed))
                        }
                    }
                    HStack(spacing: 8) {
                        Text(song?.artists ?? "")
                            .font(CoFont.appFont(12))
                            .foregroundStyle(palette.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .contentShape(Rectangle())
                            .onTapGesture { openArtistHome() }
                        Text(coTimeString(clock.progress))
                            .font(CoFont.appFont(11, .medium))
                            .foregroundStyle(palette.secondary.opacity(0.78))
                            .monospacedDigit()
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 0)
            .padding(.bottom, 0)

            // 歌词视口截止到底栏上方：当前行在可见区居中（26 版风格，无渐隐遮挡）
            Group {
                if lyrics.isEmpty {
                    emptyLyricsView
                } else {
                    LyricsSection(
                        lyrics: lyrics,
                        accent: lyricCurrentColor,
                        secondary: lyricDimColor,
                        gradientStart: lyricGradStart,
                        gradientEnd: lyricGradEnd,
                        baseFontSize: CGFloat(lyricFontSize) * CGFloat(lyricScale),
                        lineSpacing: CGFloat(lyricLineSpacing),
                        glowRadius: lyricGlowRadius,
                        showTranslation: false,
                        alignment: lyricAlign,
                        offsetX: CGFloat(lyricOffsetX),
                        anchor: lyricAnchor,
                        glowColorOverride: lyricGlowColor,
                        blurStart: CGFloat(lyricBlurStart),
                        blurAmount: CGFloat(lyricBlurAmount),
                        tilt: CGFloat(lyricTilt),
                        tiltY: CGFloat(lyricTiltY),
                        lyricOffset: CGFloat(lyricOffset)
                    ) { line in
                        CoHaptics.tap()
                        seekToLyric(line)
                    }
                }
            }
            .padding(.bottom, deckInset + geo.safeAreaInsets.bottom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id("lyricsPanel-\(song?.identityKey ?? "none")")
    }

    // MARK: - 空态兜底（歌曲数据为空时不出现空白页）

    private var placeholderView: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(palette.secondary)
            Text("暂无播放内容")
                .font(CoFont.appFont(16, .medium))
                .foregroundStyle(palette.text)
            Text("返回选择一首歌曲即可开始播放")
                .font(CoFont.appFont(13))
                .foregroundStyle(palette.secondary)
            Button {
                CoHaptics.tap()
                closePlayer()
            } label: {
                Text("返回")
                    .font(CoFont.appFont(14, .semibold))
                    .foregroundStyle(palette.text)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 10)
                    .background {
                                                CoGlass(shape: Capsule())
                    }
            }
            .buttonStyle(GlassPressButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 空歌词兜底

    private var emptyLyricsView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)
            VStack(spacing: 10) {
                Image(systemName: "quote.bubble")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(palette.secondary.opacity(0.7))
                Text("暂无歌词")
                    .font(CoFont.appFont(14, .medium))
                    .foregroundStyle(palette.text)
                Text("点击左上角封面返回专辑视图")
                    .font(CoFont.appFont(11))
                    .foregroundStyle(palette.secondary.opacity(0.8))
            }
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 底部控制栏（旧式悬浮布局：进度 / 主控制）

    private var deckInset: CGFloat { 102 }


    @ViewBuilder
    private func controlDeck(bottomInset: CGFloat, appliesPortraitLayout: Bool = true) -> some View {
        VStack(spacing: 0) {
            if layoutRenderingStyle == .vinyl || layoutRenderingStyle == .record {
                vinylProgress
                    .modifier(Layoutable(
                        part: .progress,
                        enabled: layoutMode && !layoutEditorUsesIPadLandscape,
                        data: $vinylLayoutData,
                        defaultEntry: VinylPlayerLayoutStore.defaultEntry(for: .progress),
                        appliesTransform: appliesPortraitLayout
                    ))
                    .modifier(IPadLandscapeLayoutable(
                        part: .progress,
                        style: layoutRenderingStyle,
                        enabled: layoutMode && layoutEditorUsesIPadLandscape,
                        data: $iPadLandscapeLayoutData,
                        appliesTransform: !appliesPortraitLayout
                    ))

                vinylControlRow(appliesPortraitLayout: appliesPortraitLayout)
                    .modifier(Layoutable(
                        part: .controls,
                        enabled: layoutMode && !layoutEditorUsesIPadLandscape,
                        data: $vinylLayoutData,
                        defaultEntry: VinylPlayerLayoutStore.defaultEntry(for: .controls),
                        appliesTransform: appliesPortraitLayout
                    ))
                    .modifier(IPadLandscapeLayoutable(
                        part: .controls,
                        style: layoutRenderingStyle,
                        enabled: layoutMode && layoutEditorUsesIPadLandscape,
                        data: $iPadLandscapeLayoutData,
                        appliesTransform: !appliesPortraitLayout
                    ))
            } else {
                progressBlock(
                    styleOverride: playerButtonStyle == .appleMusic ? 0 : nil,
                    accentOverride: playerButtonStyle == .appleMusic ? .white.opacity(0.92) : nil
                )
                .modifier(Layoutable(
                    part: .progress,
                    enabled: layoutMode && !layoutEditorUsesIPadLandscape,
                    data: $layoutData,
                    appliesTransform: appliesPortraitLayout
                ))
                .modifier(IPadLandscapeLayoutable(
                    part: .progress,
                    style: layoutRenderingStyle,
                    enabled: layoutMode && layoutEditorUsesIPadLandscape,
                    data: $iPadLandscapeLayoutData,
                    appliesTransform: !appliesPortraitLayout
                ))

                deckRow(appliesPortraitLayout: appliesPortraitLayout)
                    .modifier(Layoutable(
                        part: .controls,
                        enabled: layoutMode && !layoutEditorUsesIPadLandscape,
                        data: $layoutData,
                        appliesTransform: appliesPortraitLayout
                    ))
                    .modifier(IPadLandscapeLayoutable(
                        part: .controls,
                        style: layoutRenderingStyle,
                        enabled: layoutMode && layoutEditorUsesIPadLandscape,
                        data: $iPadLandscapeLayoutData,
                        appliesTransform: !appliesPortraitLayout
                    ))
            }
        }
        .padding(.horizontal, playerButtonStyle == .appleMusic ? 24 : 32)
        .padding(.top, 10)
        .padding(.bottom, max(12, bottomInset + 4))
        .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 720 : .infinity)
        .frame(maxWidth: .infinity)
    }

    /// 黑胶样式控制行：左侧循环/上一首，中间播放，右侧下一首/播放列表。
    private func vinylControlRow(appliesPortraitLayout: Bool = true) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                vinylSideControl(
                    icon: player.playMode.icon,
                    active: player.playMode == .shuffle,
                    part: .loop,
                    appliesPortraitLayout: appliesPortraitLayout
                ) {
                    player.togglePlayMode()
                }
                vinylTransportControl(icon: "backward.fill", size: 25, part: .previous, appliesPortraitLayout: appliesPortraitLayout) {
                    player.previous()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                CoHaptics.tap()
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 36, weight: .bold))
                    .frame(width: 72, height: 64)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 76)
            .modifier(Layoutable(
                part: .playPause,
                enabled: layoutMode && !layoutEditorUsesIPadLandscape,
                data: $vinylLayoutData,
                defaultEntry: VinylPlayerLayoutStore.defaultEntry(for: .playPause),
                appliesTransform: appliesPortraitLayout
            ))

            HStack(spacing: 6) {
                vinylTransportControl(icon: "forward.fill", size: 25, part: .next, appliesPortraitLayout: appliesPortraitLayout) {
                    player.next()
                }
                vinylSideControl(
                    icon: "list.bullet",
                    active: showVinylQueue,
                    part: .queue,
                    appliesPortraitLayout: appliesPortraitLayout
                ) {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showVinylQueue.toggle()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 64)
    }

    private func vinylSideControl(
        icon: String,
        active: Bool = false,
        part: PlayerLayoutPart,
        appliesPortraitLayout: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            CoHaptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    active
                        ? Color.coAmber
                        : .white.opacity(0.86)
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(Layoutable(
            part: part,
            enabled: layoutMode && !layoutEditorUsesIPadLandscape,
            data: $vinylLayoutData,
            defaultEntry: VinylPlayerLayoutStore.defaultEntry(for: part),
            appliesTransform: appliesPortraitLayout
        ))
    }

    private func vinylTransportControl(
        icon: String,
        size: CGFloat,
        part: PlayerLayoutPart,
        appliesPortraitLayout: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            CoHaptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 58)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(Layoutable(
            part: part,
            enabled: layoutMode && !layoutEditorUsesIPadLandscape,
            data: $vinylLayoutData,
            defaultEntry: VinylPlayerLayoutStore.defaultEntry(for: part),
            appliesTransform: appliesPortraitLayout
        ))
    }

    private var vinylProgress: some View {
        VinylScrubber()
    }

    private var subtitle: String {
        guard let song else { return "" }
        let parts = [song.artists, song.album].filter { !$0.isEmpty }
        return parts.isEmpty ? "未知歌曲" : parts.joined(separator: " · ")
    }

    // MARK: - 进度区块（可点按 / 拖动的进度条 + 当前时间 / 总时长 + ±15 秒）

    @ViewBuilder
    private func progressBlock(styleOverride: Int? = nil, accentOverride: Color? = nil) -> some View {
        let isAppleMusicStyle = playerButtonStyle == .appleMusic
        let trackColor: Color = isAppleMusicStyle ? .white.opacity(0.18) : palette.secondary.opacity(0.26)
        let timeColor: Color = isAppleMusicStyle ? .white.opacity(0.58) : palette.secondary
        return VStack(spacing: 1) {
            SeekBar(accent: accentOverride ?? progressAccent, track: trackColor, style: styleOverride ?? progressBarStyle)
            HStack(spacing: 6) {
                if !isAppleMusicStyle {
                    seekPillButton("gobackward.15") { player.seekBy(-15) }
                }
                Text(coTimeString(clock.progress))
                    .font(CoFont.appFont(10, .regular, .default))
                    .foregroundStyle(timeColor)
                    .frame(minWidth: 34, alignment: .leading)
                Spacer(minLength: 0)
                Text(coTimeString(clock.duration))
                    .font(CoFont.appFont(10, .regular, .default))
                    .foregroundStyle(timeColor)
                    .frame(minWidth: 34, alignment: .trailing)
                if !isAppleMusicStyle {
                    seekPillButton("goforward.15") { player.seekBy(15) }
                }
            }
        }
    }

    private func seekPillButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            CoHaptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.secondary)
                .frame(width: 30, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressButtonStyle())
    }

    // MARK: - 合并控制行（循环 / 上一曲 / 播放暂停 / 下一曲 / 播放列表 平行排列，播放键居中）

    private func deckRow(appliesPortraitLayout: Bool = true) -> some View {
        Group {
            if layoutRenderingStyle == .appleMusic {
                appleMusicDeckRow(appliesPortraitLayout: appliesPortraitLayout)
            } else {
                legacyDeckRow(appliesPortraitLayout: appliesPortraitLayout)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
    }

    private func legacyDeckRow(appliesPortraitLayout: Bool = true) -> some View {
        ZStack {
            // 两侧对称：循环模式 / 播放列表
            HStack {
                modeButton(appliesPortraitLayout: appliesPortraitLayout)
                Spacer(minLength: 0)
                queueButton(appliesPortraitLayout: appliesPortraitLayout)
            }
            .padding(.horizontal, 8)
            // 中间主控制组：上一曲 / 播放暂停 / 下一曲 真正居中
            HStack(spacing: 16) {
                deckButton(icon: "backward.fill", expand: false, part: .previous, appliesPortraitLayout: appliesPortraitLayout) {
                    CoHaptics.tap()
                    player.previous()
                }
                playButton(appliesPortraitLayout: appliesPortraitLayout)
                deckButton(icon: "forward.fill", expand: false, part: .next, appliesPortraitLayout: appliesPortraitLayout) {
                    CoHaptics.tap()
                    player.next()
                }
            }
        }
    }

    private func appleMusicDeckRow(appliesPortraitLayout: Bool = true) -> some View {
        ZStack {
            HStack {
                modeButton(appliesPortraitLayout: appliesPortraitLayout)
                Spacer(minLength: 0)
                queueButton(appliesPortraitLayout: appliesPortraitLayout)
            }
            HStack(spacing: 26) {
                Button {
                    CoHaptics.tap()
                    player.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(playerButtonText)
                        .frame(width: 46, height: 46)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .modifier(Layoutable(
                    part: .previous,
                    enabled: layoutMode && !layoutEditorUsesIPadLandscape,
                    data: $layoutData,
                    appliesTransform: appliesPortraitLayout
                ))

                Button {
                    CoHaptics.tap()
                    player.togglePlayPause()
                } label: {
                    PlayPauseMorphIcon(isPlaying: player.isPlaying, size: 22)
                        .foregroundStyle(playerButtonStyle == .appleMusic ? Color.white : Color.black)
                        .frame(width: 46, height: 46)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .modifier(Layoutable(
                    part: .playPause,
                    enabled: layoutMode && !layoutEditorUsesIPadLandscape,
                    data: $layoutData,
                    appliesTransform: appliesPortraitLayout
                ))

                Button {
                    CoHaptics.tap()
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(playerButtonText)
                        .frame(width: 46, height: 46)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .modifier(Layoutable(
                    part: .next,
                    enabled: layoutMode && !layoutEditorUsesIPadLandscape,
                    data: $layoutData,
                    appliesTransform: appliesPortraitLayout
                ))
            }
        }
    }

    private var secondaryPlayerButtonSize: CGFloat {
        playerButtonStyle == .appleMusic ? 42 : 30
    }

    private var deckPlayerButtonSize: CGFloat {
        playerButtonStyle == .appleMusic ? 46 : 34
    }

    private var primaryPlayerButtonSize: CGFloat {
        playerButtonStyle == .appleMusic ? 62 : 56
    }

    @ViewBuilder
    private func playerButtonSurface(size: CGFloat, active: Bool = false, primary: Bool = false, appleLiquid: Bool = false) -> some View {
        switch playerButtonStyle {
        case .glass:
            ZStack {
                CoGlass(shape: Circle())
                if primary {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [controlAccent.opacity(0.62), controlAccentSoft.opacity(0.56)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                Circle()
                    .strokeBorder(
                        active || primary ? controlAccent.opacity(0.52) : .white.opacity(0.22),
                        lineWidth: primary ? 1.1 : 0.8
                    )
            }
            .frame(width: size, height: size)
        case .appleMusic:
            if appleLiquid {
                GlassEffectContainer {
                    Circle()
                        .fill(.clear)
                        .glassEffect(
                            primary ? .regular.tint(.white.opacity(0.96)) : .regular,
                            in: Circle()
                        )
                }
                .frame(width: size, height: size)
            } else {
                Color.clear
                    .frame(width: size, height: size)
            }
        }
    }

    /// 循环 / 随机播放按钮（随机模式高亮）
    private func modeButton(appliesPortraitLayout: Bool = true) -> some View {
        Button {
            CoHaptics.select()
            player.togglePlayMode()
        } label: {
            Image(systemName: player.playMode.icon)
                .font(.system(size: playerButtonStyle == .appleMusic ? 17 : 12, weight: .semibold))
                .foregroundStyle(player.playMode == .shuffle ? controlAccent : playerButtonSecondaryText)
                .frame(width: secondaryPlayerButtonSize, height: secondaryPlayerButtonSize)
                .background {
                    playerButtonSurface(size: secondaryPlayerButtonSize, active: player.playMode == .shuffle)
                }
                .clipShape(Circle())
        }
        .buttonStyle(GlassPressButtonStyle())
        .modifier(Layoutable(
            part: .loop,
            enabled: layoutMode && !layoutEditorUsesIPadLandscape,
            data: $layoutData,
            appliesTransform: appliesPortraitLayout
        ))
    }

    /// 播放列表按钮
    private func queueButton(appliesPortraitLayout: Bool = true) -> some View {
        Button {
            CoHaptics.tap()
            showQueue = true
        } label: {
            Image(systemName: "list.bullet")
                .font(.system(size: playerButtonStyle == .appleMusic ? 17 : 12, weight: .semibold))
                .foregroundStyle(playerButtonSecondaryText)
                .frame(width: secondaryPlayerButtonSize, height: secondaryPlayerButtonSize)
                .background {
                    playerButtonSurface(size: secondaryPlayerButtonSize)
                }
                .clipShape(Circle())
        }
        .buttonStyle(GlassPressButtonStyle())
        .modifier(Layoutable(
            part: .queue,
            enabled: layoutMode && !layoutEditorUsesIPadLandscape,
            data: $layoutData,
            appliesTransform: appliesPortraitLayout
        ))
    }

    private func deckButton(
        icon: String,
        accent: Bool = false,
        expand: Bool = true,
        part: PlayerLayoutPart? = nil,
        appliesPortraitLayout: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            CoHaptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: playerButtonStyle == .appleMusic ? 19 : 17, weight: .medium))
                .foregroundStyle(accent ? controlAccent : playerButtonText)
                .frame(width: deckPlayerButtonSize, height: deckPlayerButtonSize)
                .background {
                    if playerButtonStyle != .appleMusic {
                        playerButtonSurface(size: deckPlayerButtonSize, active: accent, appleLiquid: true)
                    }
                }
                .clipShape(Circle())
        }
        .buttonStyle(GlassPressButtonStyle())
        .frame(maxWidth: expand ? .infinity : nil)
        .modifier(Layoutable(
            part: part ?? .controls,
            enabled: layoutMode && part != nil && !layoutEditorUsesIPadLandscape,
            data: $layoutData,
            appliesTransform: appliesPortraitLayout
        ))
    }

    private func playButton(appliesPortraitLayout: Bool = true) -> some View {
        Button {
            CoHaptics.tap()
            player.togglePlayPause()
        } label: {
            PlayPauseMorphIcon(isPlaying: player.isPlaying, size: 22)
                .foregroundStyle(layoutRenderingStyle == .appleMusic ? Color.black : playerButtonText)
                .frame(width: primaryPlayerButtonSize, height: primaryPlayerButtonSize)
                .background {
                    if playerButtonStyle != .appleMusic {
                        playerButtonSurface(size: primaryPlayerButtonSize, primary: true, appleLiquid: true)
                    }
                }
                .clipShape(Circle())
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.9))
        .modifier(Layoutable(
            part: .playPause,
            enabled: layoutMode && !layoutEditorUsesIPadLandscape,
            data: $layoutData,
            appliesTransform: appliesPortraitLayout
        ))
    }


    // MARK: - 播放器自定义布局工具栏（x / y / z + 恢复默认）


    /// 各组件 X 滑杆范围
    private var layoutXRange: ClosedRange<CGFloat> {
        switch layoutPart {
        case .lyric:
            return -80...80
        case .topBack, .topTitle, .topFavorite, .cover, .title, .previewLyric:
            return -180...180
        default:
            return -140...140
        }
    }

    /// 各组件 Y 滑杆范围
    private var layoutYRange: ClosedRange<CGFloat> {
        switch layoutPart {
        case .lyric: return -80...80
        case .topBack, .topTitle, .topFavorite: return -80...160
        case .cover, .title, .previewLyric:
            return -220...220
        case .grabber: return -120...120
        default: return -300...300
        }
    }


    /// 经典与黑胶样式共用的完整播放器预览，使用实际播放器视口的宽高比例。
    private var playerLayoutPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("布局预览")
                    .font(CoFont.appFont(12, .semibold))
                    .foregroundStyle(palette.text)
                Spacer()
                Text(layoutEditorStyle.title)
                    .font(CoFont.appFont(11, .medium))
                    .foregroundStyle(Color.coAmber)
            }

            GeometryReader { geometry in
                let canvasSize = playerPreviewCanvasSize
                let availableWidth = max(1, geometry.size.width - 16)
                let availableHeight = max(1, geometry.size.height - 16)
                let scale = min(availableWidth / canvasSize.width, availableHeight / canvasSize.height) * 0.96

                ZStack {
                    GeometryReader { previewGeometry in
                        ZStack {
                            background
                                .ignoresSafeArea()

                            if layoutRenderingStyle == .record {
                                RecordPlayerView(
                                    song: song,
                                    lyrics: lyrics,
                                    layoutData: vinylLayoutData,
                                    initialShowsLyrics: layoutRenderingShowLyrics,
                                    isFavorite: song.map { localLibrary.containsSong($0) } ?? false,
                                    onFavorite: {},
                                    onComments: {},
                                    onSettings: {},
                                    visualsActive: false
                                )
                                .id("record-layout-preview-\(layoutRenderingShowLyrics)")
                                .environmentObject(player)
                                .environmentObject(clock)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if layoutRenderingStyle == .vinyl {
                                content(geo: previewGeometry)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                controlDeck(bottomInset: previewGeometry.safeAreaInsets.bottom)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            } else {
                                VStack(spacing: 0) {
                                    headerBar
                                    content(geo: previewGeometry)
                                }
                                .foregroundStyle(palette.text)
                                controlDeck(bottomInset: previewGeometry.safeAreaInsets.bottom)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            }
                        }
                        .frame(width: canvasSize.width, height: canvasSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    }
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .scaleEffect(scale)
                .frame(width: canvasSize.width * scale, height: canvasSize.height * scale, alignment: .center)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            .aspectRatio(previewDeviceAspect, contentMode: .fit)
            .overlay(alignment: .top) {
                if layoutPreviewDevice == .iPhone {
                    Image("iPhonePreviewShell")
                        .resizable()
                        .scaledToFit()
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: previewDeviceMaxWidth)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(10)
        .background(Color.black.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 低系统使用完整播放器视口缩小预览，避免 iPad 预览比例与实际播放页不一致。
    private var appleMusicLayoutPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("布局预览")
                    .font(CoFont.appFont(12, .semibold))
                    .foregroundStyle(palette.text)
                Spacer()
                Text(layoutEditorStyle.title)
                    .font(CoFont.appFont(11, .medium))
                    .foregroundStyle(Color.coAmber)
            }

            GeometryReader { geometry in
                let canvasSize = appleMusicPreviewCanvasSize
                let availableWidth = max(1, geometry.size.width - 16)
                let availableHeight = max(1, geometry.size.height - 16)
                let scale = min(
                    availableWidth / canvasSize.width,
                    availableHeight / canvasSize.height
                ) * 0.96

                ZStack {
                    ReferencePlaybackView(
                        song: song,
                        lyrics: lyrics,
                        showLyrics: $layoutPreviewShowLyrics,
                        showQueue: $layoutPreviewShowQueue,
                        onFavorite: {
                            guard let song else { return }
                            toggleLocalFavorite(song)
                        },
                        onComments: {
                            if song != nil { ToastCenter.shared.show("预览中暂不支持评论") }
                        },
                        onSleepTimer: {
                            showSleepTimer = true
                        },
                        onAddToLocalPlaylist: {
                            showAddToLocalPlaylist = true
                        },
                        onPlayerSettings: {
                            openPlayerSettings()
                        },
                        onArtist: {
                            openArtistHome()
                        }
                    )
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .scaleEffect(scale)
                    .frame(
                        width: canvasSize.width * scale,
                        height: canvasSize.height * scale,
                        alignment: .center
                    )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            .aspectRatio(previewDeviceAspect, contentMode: .fit)
            .overlay(alignment: .top) {
                if layoutPreviewDevice == .iPhone {
                    Image("iPhonePreviewShell")
                        .resizable()
                        .scaledToFit()
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: previewDeviceMaxWidth)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(10)
        .background(Color.black.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var appleMusicPreviewCanvasSize: CGSize {
        playerPreviewCanvasSize
    }

    private var playerPreviewCanvasSize: CGSize {
        if layoutPreviewDevice == .iPad {
            if layoutEditorUsesIPadLandscape && UIDevice.current.userInterfaceIdiom == .pad {
                return CGSize(width: 844, height: 390)
            }
            return CGSize(width: 768, height: 1024)
        }
        if layoutPreviewDevice == .iPhone {
            return CGSize(width: 390, height: 844)
        }
        let viewport = playerViewportSize
        if viewport.width > 1, viewport.height > 1 {
            if layoutMode,
               UIDevice.current.userInterfaceIdiom == .pad,
               !layoutEditorUsesIPadLandscape {
                return CGSize(width: min(viewport.width, viewport.height), height: max(viewport.width, viewport.height))
            }
            return viewport
        }
        let fallback = UIScreen.main.bounds.size
        return CGSize(width: max(fallback.width, 320), height: max(fallback.height, 568))
    }

    private var previewDeviceAspect: CGFloat {
        switch layoutPreviewDevice {
        case .iPhone:
            return 1419.0 / 2796.0
        case .iPad:
            return layoutEditorUsesIPadLandscape ? 844.0 / 390.0 : 768.0 / 1024.0
        }
    }

    private var previewDeviceMaxWidth: CGFloat {
        switch layoutPreviewDevice {
        case .iPhone:
            return 220
        case .iPad:
            return layoutEditorUsesIPadLandscape ? 460 : 340
        }
    }

    private var iOS26LayoutPreviewEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Text("自定义布局")
                        .font(CoFont.appFont(20, .bold))
                        .foregroundStyle(palette.text)

                    Spacer(minLength: 0)

                    Button("完成") {
                        CoHaptics.select()
                        layoutMode = false
                    }
                    .font(CoFont.appFont(14, .semibold))
                    .foregroundStyle(Color.coAmber)
                }

                layoutEditorStylePicker

                // Folia 舞台不进自定义布局：它的排版本身就是效果，拖来拖去会把效果拆散；
                // 模式与配色在 Folia 设置里调，这里只留一个入口让用户切回别的风格。
                if layoutEditorStyle == .folia {
                    Text("Folia 舞台不支持自定义布局，模式与配色在 Folia 设置里调。")
                        .font(CoFont.appFont(14, .regular))
                        .foregroundStyle(palette.text.opacity(0.7))
                        .padding(.vertical, 24)
                } else {

                if UIDevice.current.userInterfaceIdiom == .pad {
                    Picker("预览方向", selection: $layoutEditorUsesIPadLandscape) {
                        Text("竖屏").tag(false)
                        Text("横屏").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Group {
                    if layoutEditorUsesIPadLandscape && UIDevice.current.userInterfaceIdiom == .pad {
                        iPadLandscapeLayoutPreview
                    } else if layoutEditorStyle == .appleMusic {
                        appleMusicLayoutPreview
                    } else {
                        playerLayoutPreview
                    }
                }

                Picker("预览页面", selection: $layoutPreviewShowLyrics) {
                    Text("封面").tag(false)
                    Text("歌词").tag(true)
                }
                .pickerStyle(.segmented)

                Toggle("隐藏封面歌词", isOn: $hideCoverLyrics)
                    .font(CoFont.appFont(15, .medium))
                    .foregroundStyle(palette.text)
                    .tint(Color.coAmber)
                Text("只影响封面页的歌词预览，完整歌词页不受影响")
                    .font(CoFont.appFont(12, .regular))
                    .foregroundStyle(palette.text.opacity(0.6))

                layoutEditorPartPicker
                layoutEditorSliders
                layoutEditorStyleDebugControls

                HStack(spacing: 18) {
                    Button {
                        resetUnifiedLayoutPart()
                        CoHaptics.success()
                    } label: {
                        Label("恢复当前", systemImage: "arrow.counterclockwise")
                    }
                    .foregroundStyle(Color.coAmber)
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    Button {
                        resetUnifiedLayoutStyle()
                        CoHaptics.success()
                    } label: {
                        Label("恢复此样式", systemImage: "arrow.counterclockwise.circle")
                    }
                    .foregroundStyle(Color.coAmber)
                    .buttonStyle(.plain)
                }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .background { GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil) }
    }

    private var layoutEditorStylePicker: some View {
        HStack(spacing: 8) {
            ForEach(CoCoverPlayerStyle.availableCases) { style in
                let selected = layoutEditorStyle == style
                Button {
                    layoutEditorStyleRaw = style.rawValue
                    selectInitialLayoutPart(for: style)
                    CoHaptics.select()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: style.icon)
                            .font(.system(size: 17, weight: .semibold))
                        Text(LocalizedStringKey(style.title))
                            .font(CoFont.appFont(12, .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selected ? Color.white : Color.coLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        selected ? Color.coAmber : Color.primary.opacity(0.055),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var layoutPreviewDevice: PlayerPreviewDevice {
        UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
    }

    @ViewBuilder
    private var layoutEditorPartPicker: some View {
        if layoutEditorUsesIPadLandscape && UIDevice.current.userInterfaceIdiom == .pad {
            layoutPartChips(IPadLandscapeLayoutPart.allCases.map { ($0.rawValue, $0) }) { part in
                iPadLandscapeLayoutPart = part
            } selected: { iPadLandscapeLayoutPart == $0 }
        } else {
            switch layoutEditorStyle {
            case .appleMusic:
                layoutPartChips(AppleMusicLayoutPart.allCases.map { ($0.rawValue, $0) }) { part in
                    appleLayoutPart = part
                } selected: { appleLayoutPart == $0 }
        case .folia:
            Text("Folia 舞台不支持自定义布局，模式与配色在 Folia 设置里调。")
                .font(CoFont.appFont(14, .regular))
                .foregroundStyle(palette.text.opacity(0.7))
                .padding(.vertical, 12)
        case .vinyl, .record:
            layoutPartChips(PlayerLayoutPart.vinylEditableCases.map { (layoutPartTitle($0), $0) }) { part in
                    layoutPart = part
                    layoutPartRaw = part.rawValue
                } selected: { layoutPart == $0 }
            }
        }
    }

    private func layoutPartTitle(_ part: PlayerLayoutPart) -> String {
        guard layoutEditorStyle == .record else { return part.rawValue }
        switch part {
        case .vinylCover: return "唱片"
        case .vinylTitle: return "歌名歌手"
        case .vinylLyricsHeader: return "歌词顶部"
        case .vinylLyricsText: return "歌词内容"
        case .progress: return "进度条"
        case .controls: return "控制行"
        case .loop: return "播放模式"
        case .previous: return "上一首"
        case .playPause: return "播放暂停"
        case .next: return "下一首"
        case .queue: return "播放列表"
        default: return part.rawValue
        }
    }

    private func layoutPartChips<T: Identifiable>(
        _ parts: [(String, T)],
        onSelect: @escaping (T) -> Void,
        selected: @escaping (T) -> Bool
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(parts.enumerated()), id: \.offset) { item in
                    let title = item.element.0
                    let part = item.element.1
                    Button {
                        onSelect(part)
                        CoHaptics.select()
                    } label: {
                        Text(LocalizedStringKey(title))
                            .font(CoFont.appFont(12, .semibold))
                            .foregroundStyle(selected(part) ? Color.white : Color.coLabel)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background(
                                selected(part) ? Color.coAmber : Color.primary.opacity(0.055),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var layoutEditorSliders: some View {
        VStack(spacing: 8) {
            layoutSlider("X", value: unifiedLayoutEntryBinding.x, range: unifiedLayoutXRange)
            layoutSlider("Y", value: unifiedLayoutEntryBinding.y, range: unifiedLayoutYRange)
            layoutSlider("大小", value: unifiedLayoutEntryBinding.scale, range: 0.3...1.5, step: 0.05, format: "%.2f")
            layoutSlider("旋转", value: unifiedLayoutEntryBinding.rotation, range: -180...180, step: 1)
            layoutSlider("透明度", value: unifiedLayoutEntryBinding.opacity, range: 0...1, step: 0.05, format: "%.2f")
        }
        .padding(12)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var unifiedLayoutEntryBinding: Binding<PlayerLayoutEntry> {
        Binding(
            get: {
                if layoutEditorUsesIPadLandscape && UIDevice.current.userInterfaceIdiom == .pad {
                    return IPadLandscapeLayoutStore.entry(
                        for: iPadLandscapeLayoutPart,
                        style: layoutEditorStyle,
                        in: iPadLandscapeLayoutData
                    )
                }
                switch layoutEditorStyle {
                case .appleMusic:
                    return appleLayout.entry(for: appleLayoutPart)
                case .folia: return VinylPlayerLayoutStore.defaultEntry(for: layoutPart)
                case .vinyl, .record:
                    return vinylLayoutData[layoutPart.rawValue]
                        ?? VinylPlayerLayoutStore.defaultEntry(for: layoutPart)
                }
            },
            set: { value in
                if layoutEditorUsesIPadLandscape && UIDevice.current.userInterfaceIdiom == .pad {
                    var styleData = iPadLandscapeLayoutData[layoutEditorStyle.rawValue] ?? [:]
                    styleData[iPadLandscapeLayoutPart.rawValue] = value
                    iPadLandscapeLayoutData[layoutEditorStyle.rawValue] = styleData
                    return
                }
                switch layoutEditorStyle {
                case .appleMusic:
                    appleLayout.set(value, for: appleLayoutPart)
                case .folia: break
                case .vinyl, .record:
                    vinylLayoutData[layoutPart.rawValue] = value
                }
            }
        )
    }

    private var unifiedLayoutXRange: ClosedRange<CGFloat> {
        if layoutEditorUsesIPadLandscape && UIDevice.current.userInterfaceIdiom == .pad { return -300...300 }
        if layoutEditorStyle == .appleMusic { return -240...240 }
        return layoutXRange
    }

    private var unifiedLayoutYRange: ClosedRange<CGFloat> {
        if layoutEditorUsesIPadLandscape && UIDevice.current.userInterfaceIdiom == .pad { return -240...240 }
        if layoutEditorStyle == .appleMusic { return -300...300 }
        return layoutYRange
    }

    private func selectInitialLayoutPart(for style: CoCoverPlayerStyle) {
        switch style {
        case .appleMusic:
            appleLayoutPart = .cover
        case .folia: break
        case .vinyl, .record:
            layoutPart = .vinylCover
            layoutPartRaw = layoutPart.rawValue
        }
    }

    private func resetUnifiedLayoutPart() {
        if layoutEditorUsesIPadLandscape && UIDevice.current.userInterfaceIdiom == .pad {
            var styleData = iPadLandscapeLayoutData[layoutEditorStyle.rawValue] ?? [:]
            styleData.removeValue(forKey: iPadLandscapeLayoutPart.rawValue)
            iPadLandscapeLayoutData[layoutEditorStyle.rawValue] = styleData
            return
        }
        switch layoutEditorStyle {
        case .appleMusic:
            appleLayout.reset(appleLayoutPart)
        case .folia: break
        case .vinyl, .record:
            vinylLayoutData.removeValue(forKey: layoutPart.rawValue)
        }
    }

    private func resetUnifiedLayoutStyle() {
        if layoutEditorUsesIPadLandscape && UIDevice.current.userInterfaceIdiom == .pad {
            iPadLandscapeLayoutData[layoutEditorStyle.rawValue] = nil
            return
        }
        switch layoutEditorStyle {
        case .appleMusic:
            appleLayout.resetAll()
        case .folia: break
        case .vinyl, .record:
            vinylLayoutData = [:]
        }
    }

    private var iPadLandscapeLayoutPreview: some View {
        GeometryReader { geometry in
            let canvasSize = CGSize(width: 844, height: 390)
            let scale = min((geometry.size.width - 16) / canvasSize.width, (geometry.size.height - 16) / canvasSize.height) * 0.96
            ZStack {
                if layoutEditorStyle == .record {
                    RecordPlayerView(
                        song: song,
                        lyrics: lyrics,
                        layoutData: vinylLayoutData,
                        initialShowsLyrics: layoutRenderingShowLyrics,
                        isFavorite: song.map { localLibrary.containsSong($0) } ?? false,
                        onFavorite: {},
                        onComments: {},
                        onSettings: {},
                        visualsActive: false
                    )
                    .id("record-ipad-layout-preview-\(layoutRenderingShowLyrics)")
                    .environmentObject(player)
                    .environmentObject(clock)
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .scaleEffect(max(0.01, scale))
                    .frame(width: canvasSize.width * scale, height: canvasSize.height * scale)
                } else {
                    iPadLandscapeLyricsView
                        .frame(width: canvasSize.width, height: canvasSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .scaleEffect(max(0.01, scale))
                        .frame(width: canvasSize.width * scale, height: canvasSize.height * scale)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .aspectRatio(CGFloat(844) / CGFloat(390), contentMode: .fit)
        .frame(maxWidth: 460)
    }



    private var applePrimaryColorBinding: Binding<Color> {
        Binding(
            get: {
                if applePrimaryHex.hasPrefix("#"), let color = Color(hex: applePrimaryHex) {
                    return color
                }
                return .white
            },
            set: { applePrimaryHex = "#" + UIColor($0).hexString }
        )
    }

    private var appleSecondaryColorBinding: Binding<Color> {
        Binding(
            get: {
                if appleSecondaryHex.hasPrefix("#"), let color = Color(hex: appleSecondaryHex) {
                    return color
                }
                return Color.coComment
            },
            set: { appleSecondaryHex = "#" + UIColor($0).hexString }
        )
    }

    private var appleAccentColorBinding: Binding<Color> {
        Binding(
            get: {
                if appleAccentHex.hasPrefix("#"), let color = Color(hex: appleAccentHex) {
                    return color
                }
                return Color.coAppleMusicAccentFallback
            },
            set: { appleAccentHex = "#" + UIColor($0).hexString }
        )
    }

    private var appleVolumeColorBinding: Binding<Color> {
        Binding(
            get: {
                if appleVolumeHex.hasPrefix("#"), let color = Color(hex: appleVolumeHex) {
                    return color
                }
                return applePrimaryColorBinding.wrappedValue
            },
            set: { appleVolumeHex = "#" + UIColor($0).hexString }
        )
    }

    private var albumTitleColorBinding: Binding<Color> {
        Binding(
            get: {
                if albumTitleColorHex.hasPrefix("#"), let color = Color(hex: albumTitleColorHex) {
                    return color
                }
                return palette.text
            },
            set: { albumTitleColorHex = "#" + UIColor($0).hexString }
        )
    }

    private var albumArtistColorBinding: Binding<Color> {
        Binding(
            get: {
                if albumArtistColorHex.hasPrefix("#"), let color = Color(hex: albumArtistColorHex) {
                    return color
                }
                return palette.secondary
            },
            set: { albumArtistColorHex = "#" + UIColor($0).hexString }
        )
    }

    private var albumPreviewLyricColorBinding: Binding<Color> {
        Binding(
            get: {
                if albumPreviewLyricColorHex.hasPrefix("#"), let color = Color(hex: albumPreviewLyricColorHex) {
                    return color
                }
                return palette.text
            },
            set: { albumPreviewLyricColorHex = "#" + UIColor($0).hexString }
        )
    }

    private var albumPreviewDimColorBinding: Binding<Color> {
        Binding(
            get: {
                if albumPreviewDimColorHex.hasPrefix("#"), let color = Color(hex: albumPreviewDimColorHex) {
                    return color
                }
                return palette.secondary
            },
            set: { albumPreviewDimColorHex = "#" + UIColor($0).hexString }
        )
    }




    private var appleMusicAppearanceControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apple Music 外观")
                .font(CoFont.appFont(12, .semibold))
                .foregroundStyle(Color.coLabel)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("显示音量条", isOn: $appleShowVolume)
                .font(CoFont.appFont(12))
                .tint(Color.coAmber)
            Toggle("同步主页壁纸", isOn: $appleSyncWallpaper)
                .font(CoFont.appFont(12))
                .tint(Color.coAmber)
            if appleSyncWallpaper {
                HStack(spacing: 8) {
                    Text("壁纸模糊")
                        .font(CoFont.appFont(12))
                        .foregroundStyle(palette.secondary)
                        .frame(width: 58, alignment: .leading)
                    Slider(value: $appleWallpaperBlur, in: 0...32, step: 1)
                        .tint(Color.coAmber)
                    Text("\(Int(appleWallpaperBlur))")
                        .font(CoFont.appFont(11, .semibold, .default))
                        .foregroundStyle(Color.coAmber)
                        .frame(width: 28, alignment: .trailing)
                }
            }
            ColorPicker("主图标与当前歌词", selection: applePrimaryColorBinding, supportsOpacity: false)
                .font(CoFont.appFont(12))
            ColorPicker("次级文字与时间", selection: appleSecondaryColorBinding, supportsOpacity: false)
                .font(CoFont.appFont(12))
            ColorPicker("高亮颜色", selection: appleAccentColorBinding, supportsOpacity: false)
                .font(CoFont.appFont(12))
            ColorPicker("音量条颜色", selection: appleVolumeColorBinding, supportsOpacity: false)
                .font(CoFont.appFont(12))
            Divider().opacity(0.35)
            Text("封面页文字颜色")
                .font(CoFont.appFont(12, .semibold))
                .foregroundStyle(Color.coLabel)
            ColorPicker("歌名颜色", selection: albumTitleColorBinding, supportsOpacity: false)
                .font(CoFont.appFont(12))
            ColorPicker("歌手颜色", selection: albumArtistColorBinding, supportsOpacity: false)
                .font(CoFont.appFont(12))
            ColorPicker("预览歌词颜色", selection: albumPreviewLyricColorBinding, supportsOpacity: false)
                .font(CoFont.appFont(12))
            ColorPicker("预览未播放颜色", selection: albumPreviewDimColorBinding, supportsOpacity: false)
                .font(CoFont.appFont(12))
            Toggle("文字渐变", isOn: $albumTextGradient)
                .font(CoFont.appFont(12))
                .tint(Color.coAmber)
            Toggle("文字高光", isOn: $albumTextGlow)
                .font(CoFont.appFont(12))
                .tint(Color.coAmber)
            if albumTextGlow {
                HStack {
                    Text("高光强度")
                        .font(CoFont.appFont(12))
                        .foregroundStyle(palette.secondary)
                    Slider(value: $albumTextGlowIntensity, in: 0.2...2.0, step: 0.05)
                        .tint(Color.coAmber)
                    Text("\(Int((albumTextGlowIntensity * 100).rounded()))%")
                        .font(CoFont.appFont(11, .semibold, .default))
                        .foregroundStyle(Color.coAmber)
                        .frame(width: 42, alignment: .trailing)
                }
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var layoutEditorStyleDebugControls: some View {
        switch layoutEditorStyle {
        case .folia: EmptyView()
        case .vinyl, .record:
            vinylStyleDebugControls
        case .appleMusic:
            appleMusicAppearanceControls
        }
    }

    private var vinylStyleDebugControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(layoutEditorStyle == .record ? "唱片模式调试" : "黑胶样式调试")
                .font(CoFont.appFont(13, .bold))
                .foregroundStyle(palette.text)
            layoutDebugToggle("左右滑动切歌", isOn: $swipeSwitchSong,
                              caption: "左滑下一首，右滑上一首")
        }
        .padding(12)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }


    private func layoutDebugToggle(_ title: String, isOn: Binding<Bool>, caption: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(LocalizedStringKey(title), isOn: isOn)
                .font(CoFont.appFont(13))
                .tint(Color.coAmber)
            if let caption {
                Text(LocalizedStringKey(caption))
                    .font(CoFont.appFont(11))
                    .foregroundStyle(palette.secondary)
            }
        }
    }




    private func layoutSlider(_ title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, step: CGFloat = 1, format: String = "%.0f") -> some View {
        HStack(spacing: 10) {
            Text(LocalizedStringKey(title))
                .font(CoFont.appFont(12, .medium))
                .foregroundStyle(palette.secondary)
                .frame(width: 56, alignment: .leading)
            layoutValueSlider(value: value, range: range, step: step)
            Text(String(format: format, value.wrappedValue))
                .font(CoFont.appFont(11, .regular, .default))
                .foregroundStyle(palette.secondary)
                .frame(width: 34, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func layoutValueSlider(value: Binding<CGFloat>, range: ClosedRange<CGFloat>, step: CGFloat) -> some View {
        Slider(value: value, in: range, step: step)
            .tint(Color.coAmber)
            .transaction { transaction in transaction.animation = nil }
    }

    // MARK: - 分享


    // MARK: - 下载

    /// 分享面板关闭后清理临时下载文件（不占用户存储）
    // MARK: - 动作

    /// 全部歌手名（多歌手歌曲点击时弹出选择，避免只打开第一位）
    private var artistNames: [String] {
        guard let artists = song?.artists else { return [] }
        let separators = [" / ", "/", "、", ",", "，", " & ", " &", "& ", " feat. ", " Feat. ", " ft. ", " Ft. "]
        let normalized = separators.reduce(artists) { value, separator in
            value.replacingOccurrences(of: separator, with: "|")
        }
        return normalized
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).description }
            .filter { !$0.isEmpty }
    }

    /// 首位歌手名（用于跳转歌手主页）
    private var primaryArtistName: String {
        artistNames.first ?? ""
    }

    private func openArtistHome() {
        guard !primaryArtistName.isEmpty else { return }
        CoHaptics.tap()
        if artistNames.count > 1 {
            showArtistPicker = true
        } else {
            pickedArtistName = primaryArtistName
            showArtistHome = true
        }
    }

    private func copyCurrentSongTitle() {
        guard let title = song?.name.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return }
        UIPasteboard.general.string = title
        CoHaptics.success()
        ToastCenter.shared.show("歌名已复制")
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
                    Task { await extractCoverPalette() }
                    ToastCenter.shared.show("已恢复默认封面")
                }
            }
        }
    }

    private func prepareLayoutEditor() {
        layoutEditorStyleRaw = coverPlayerStyle.rawValue
        selectInitialLayoutPart(for: coverPlayerStyle)
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let isLandscape = playerViewportSize.width > playerViewportSize.height
        layoutEditorUsesIPadLandscape = isPad && isLandscape
        layoutPreviewShowLyrics = false
    }

    private func toggleLyrics() {
        CoHaptics.tap()
        withAnimation(.easeInOut(duration: 0.22)) {
            showLyrics.toggle()
        }
    }

    private func seekToLyric(_ line: LyricLine) {
        guard song?.identityKey == player.currentSong?.identityKey else { return }
        player.seekPrecisely(to: LyricTiming.seekTime(for: line, userOffset: lyricOffset))
    }

    private func closePlayer() {
        isPresented = false
    }

    /// 左右切歌：松手后旧封面沿手势方向飞出，新封面从对侧滑入（左滑下一首，右滑上一首）。
    private func handleSwipeEnd(horizontal: CGFloat) {
        guard swipeSwitchSong else { return }
        let x = horizontal
        if x < -70 {
            CoHaptics.tap()
            coverDrag = .zero
            flySwipe(direction: -1)
        } else if x > 70 {
            CoHaptics.tap()
            coverDrag = .zero
            flySwipe(direction: 1)
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                swipeOffset = 0
                coverDrag = .zero
            }
        }
    }

    private func flySwipe(direction: CGFloat) {
        let flyOut: CGFloat = direction * 560
        let flyIn: CGFloat = -direction * 560
        // 1) 当前封面继续向滑动方向飞出
        withAnimation(.easeIn(duration: 0.17)) { swipeOffset = flyOut }
        // 2) 飞出后立即切歌，并把新封面放到对侧屏幕外，再滑回中央
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) {
            // 动画期间开关被关闭：面板直接复位，避免卡在屏幕外
            guard swipeSwitchSong else {
                withAnimation(.easeOut(duration: 0.2)) {
                    swipeOffset = 0
                    coverDrag = .zero
                }
                return
            }
            if direction < 0 { player.next() } else { player.previous() }
            swipeOffset = flyIn
            // 等下一帧先渲染出新封面在屏幕外的位置，再动画滑回中央（否则动画会从旧位置开始，方向不对）
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.26)) { swipeOffset = 0 }
            }
        }
    }

    private func loadLyrics() async {
        guard let song else { return }
        let identity = song.identityKey
        func apply(_ parsed: [LyricLine]) {
            guard self.song?.identityKey == identity, !parsed.isEmpty else { return }
            self.lyrics = parsed
        }

        let cacheKey: String = "kugou:\(song.kugouHash ?? song.identityKey)"
        if let cached = LyricsCache.shared.value(for: cacheKey) {
            apply(LyricParser.parse(
                cached.lyric,
                translationRaw: cached.translation,
                wordRaw: cached.wordTiming,
                wordFormat: cached.wordFormat
            ))
        }

        if song.source == .kugou, let hash = song.kugouHash {
            let payload = await KugouMusicAPI.shared.lyricPayload(
                hash: hash,
                duration: song.duration,
                keyword: "\(song.name) \(song.artists)"
            )
            apply(LyricParser.parse(payload.lrc, wordRaw: payload.krc, wordFormat: .kugouKRC))
            LyricsCache.shared.save(lyric: payload.lrc, translation: nil, wordTiming: payload.krc, wordFormat: .kugouKRC, for: cacheKey)
        }
    }

    private func extractCoverPalette() async {
        guard let url = displayCoverURL else { return }
        do {
            let image: UIImage?
            if url.isFileURL {
                image = CustomCoverMedia.previewImage(at: url)
            } else {
                let response = try await URLSession.shared.data(from: url)
                image = UIImage(data: response.0)
            }
            guard let image,
                  let dominant = PaletteExtractor.dominantColor(in: image) else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                dominantColor = dominant
            }
        } catch {
            // 提取失败：静默保持回退色
        }
    }

}

/// 黑胶页专用的白色极简进度条：非拖动时隐藏滑块，拖动时才显示。
private struct VinylScrubber: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    @State private var isDragging = false
    @State private var dragProgress = 0.0

    private var currentProgress: Double {
        isDragging ? dragProgress : clock.progress
    }

    private var fraction: Double {
        guard clock.duration > 0 else { return 0 }
        return min(max(currentProgress / clock.duration, 0), 1)
    }

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.25))
                        .frame(height: 4)
                    Capsule()
                        .fill(.white)
                        .frame(width: max(4, width * fraction), height: 4)
                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? 13 : 9, height: isDragging ? 13 : 9)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .offset(x: width * fraction - (isDragging ? 6.5 : 4.5))
                        .opacity(isDragging ? 1 : 0)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard clock.duration > 0 else { return }
                            isDragging = true
                            dragProgress = min(max(value.location.x / width, 0), 1) * clock.duration
                        }
                        .onEnded { _ in
                            player.seek(to: dragProgress)
                            isDragging = false
                        }
                )
            }
            .frame(height: 14)

            HStack {
                Text(coTimeString(currentProgress))
                Spacer(minLength: 0)
                Text(coTimeString(clock.duration))
            }
            .font(CoFont.appFont(10, .regular, .default))
            .foregroundStyle(.white.opacity(0.55))
            .monospacedDigit()
        }
    }
}

// MARK: - 自定义进度条（点击 / 拖动均可跳转，配色跟随封面主色）

struct SeekBar: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    let accent: Color
    let track: Color
    /// 进度条样式：0 流光 / 1 辉光 / 2 极光 / 3 波浪
    var style: Int = 0

    @State private var scrubbing = false
    @State private var scrubValue: Double = 0
    /// 流光样式：光点游动相位（0→1 往返）
    @State private var flowPhase: CGFloat = 0
    @State private var lastPreviewSecond: Int?

    private var progress: Double {
        scrubbing ? scrubValue : clock.progress
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let total = max(clock.duration, 1)
            let ratio = min(max(progress / total, 0), 1)
            let thumbX = min(max(width * ratio, 10), max(width - 10, 10))

            ZStack(alignment: .leading) {
                // 轨道与已播放段（按样式）
                switch style {
                case 1:
                    // 辉光：全宽渐变底轨 + 明亮已播放段 + 底部柔光
                    Capsule()
                        .fill(
                            LinearGradient(colors: [accent.opacity(0.28), track.opacity(0.5), accent.opacity(0.18)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(height: 7)
                    Capsule()
                        .fill(
                            LinearGradient(colors: [.white.opacity(0.9), accent],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: thumbX, height: 7)
                        .shadow(color: accent.opacity(0.65), radius: 5, y: 1)
                    Capsule()
                        .fill(.white.opacity(0.85))
                        .frame(width: max(3, thumbX - 4), height: 2)
                        .offset(y: -2)
                        .clipShape(Capsule())
                case 2:
                    // 极光：发丝细线 + 极光渐变 + 大号光晕滑块
                    Capsule()
                        .fill(track.opacity(0.6))
                        .frame(height: 2.5)
                    Capsule()
                        .fill(
                            LinearGradient(colors: [accent, .white.opacity(0.85), accent.opacity(0.6)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: thumbX, height: 2.5)
                        .shadow(color: accent.opacity(0.7), radius: 4)
                    Circle()
                        .fill(.white.opacity(0.16))
                        .frame(width: 30, height: 30)
                        .overlay {
                            Circle()
                                .fill(
                                    LinearGradient(colors: [.white, accent.opacity(0.85)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 18, height: 18)
                                .overlay {
                                    Circle().strokeBorder(.white.opacity(0.95), lineWidth: 1)
                                }
                        }
                        .shadow(color: accent.opacity(0.85), radius: scrubbing ? 9 : 6)
                        .scaleEffect(scrubbing ? 1.15 : 1)
                        .offset(x: thumbX - 15)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: scrubbing)
                case 3:
                    // 波浪：正弦波形，已播放段高亮发光
                    WaveBar(ratio: ratio, accent: accent, track: track, width: width, isPlaying: player.isPlaying)
                default:
                    // 流光：清透轨道 + 渐变已播放段 + 顶部高光 + 游动光点
                    Capsule()
                        .fill(track.opacity(0.55))
                        .frame(height: 5)
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .frame(height: 5)
                        .overlay {
                            Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                        }
                    Capsule()
                        .fill(
                            LinearGradient(colors: [accent, accent.opacity(0.6), .white.opacity(0.85)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: thumbX, height: 5)
                        .shadow(color: accent.opacity(0.45), radius: 4, y: 1)
                        .overlay(alignment: .top) {
                            LinearGradient(colors: [.white.opacity(0.55), .clear],
                                           startPoint: .top, endPoint: .bottom)
                                .frame(height: 2.5)
                                .clipShape(Capsule())
                        }
                    if player.isPlaying {
                        // 游动光点仅在播放中运行，暂停后不保留 repeatForever 动画。
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.35))
                                .blur(radius: 4)
                                .frame(width: 14, height: 14)
                            Circle()
                                .fill(.white.opacity(0.95))
                                .frame(width: 5, height: 5)
                                .shadow(color: .white.opacity(0.7), radius: 2)
                        }
                        .offset(x: max(2, thumbX - 5) * flowPhase)
                        .animation(.linear(duration: 2.4).repeatForever(autoreverses: true), value: flowPhase)
                    }
                }

                // 滑块（流光/辉光/波浪用发光圆点；极光自带大滑块）
                if style != 2 {
                    Circle()
                        .fill(.white)
                        .frame(width: scrubbing ? 22 : 14, height: scrubbing ? 22 : 14)
                        .overlay {
                            Circle().strokeBorder(.white.opacity(0.95), lineWidth: 0.8)
                        }
                        .shadow(color: accent.opacity(0.7), radius: scrubbing ? 10 : 3.5, y: scrubbing ? 3 : 1)
                        .offset(x: thumbX - (scrubbing ? 11 : 7))
                        .animation(.spring(response: 0.24, dampingFraction: 0.76), value: scrubbing)
                }

                if scrubbing {
                    Text(coTimeString(scrubValue))
                        .font(CoFont.appFont(11, .semibold, .default))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background {
                            Capsule()
                                .fill(.black.opacity(0.48))
                                .overlay {
                                    Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.7)
                                }
                        }
                        .shadow(color: accent.opacity(0.35), radius: 10, y: 4)
                        .offset(x: min(max(thumbX - 31, 0), max(width - 62, 0)), y: -25)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .frame(width: width, height: 42)
            .onAppear {
                if player.isPlaying, flowPhase == 0 { flowPhase = 1 }
            }
            .onChange(of: player.isPlaying) { playing in
                flowPhase = playing ? 1 : 0
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !scrubbing {
                            CoHaptics.medium()
                        }
                        scrubbing = true
                        let raw = min(max(value.location.x / width, 0), 1) * total
                        let snapped = raw.rounded()
                        scrubValue = snapped
                        let previewSecond = Int(snapped)
                        if previewSecond != lastPreviewSecond, previewSecond % 15 == 0 {
                            CoHaptics.select()
                        }
                        lastPreviewSecond = previewSecond
                    }
                    .onEnded { _ in
                        CoHaptics.tap()
                        player.seek(to: scrubValue)
                        scrubbing = false
                        lastPreviewSecond = nil
                    }
            )
        }
        .frame(height: 42)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: scrubbing)
    }
}


// MARK: - 波浪进度条（正弦波形：已播放段高亮，波面缓慢流动）

private struct WaveShape: Shape {
    var phase: CGFloat = 0
    var amplitude: CGFloat = 3.2

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = rect.midY
        let freq: CGFloat = 2.4
        path.move(to: CGPoint(x: 0, y: mid))
        var x: CGFloat = 0
        while x <= rect.width {
            let y = mid + sin(x / rect.width * .pi * 2 * freq + phase * .pi * 2) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += 2
        }
        return path
    }
}

private struct WaveBar: View {
    let ratio: Double
    let accent: Color
    let track: Color
    let width: CGFloat
    let isPlaying: Bool

    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack(alignment: .leading) {
            // 辉光底层光晕（已播放段模糊扩散，辉光渐变氛围）
            WaveShape(phase: phase)
                .stroke(accent.opacity(0.5), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .blur(radius: 8)
                .frame(width: width, height: 16)
                .frame(width: max(0, width * CGFloat(ratio)), alignment: .leading)
                .clipped()
            // 未播放波形（暗色渐变轨道）
            WaveShape(phase: phase)
                .stroke(
                    LinearGradient(colors: [accent.opacity(0.25), track.opacity(0.45), accent.opacity(0.15)],
                                   startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
                )
                .frame(width: width, height: 16)
            // 已播放波形（辉光渐变高亮：白→主色→淡，双阴影辉光）
            WaveShape(phase: phase)
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.95), accent, accent.opacity(0.6)],
                                   startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 3.6, lineCap: .round)
                )
                .shadow(color: accent.opacity(0.8), radius: 6, y: 1)
                .shadow(color: accent.opacity(0.45), radius: 14)
                .frame(width: width, height: 16)
                .frame(width: max(0, width * CGFloat(ratio)), alignment: .leading)
                .clipped()
        }
        .frame(height: 20)
        .onAppear {
            if isPlaying, phase == 0 { phase = 1 }
        }
        .onChange(of: isPlaying) { playing in
            phase = playing ? 1 : 0
        }
        .animation(isPlaying ? .linear(duration: 3).repeatForever(autoreverses: false) : .default, value: phase)
    }
}

private struct LyricCenterPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - 歌词（居中显示 + 逐行高亮 + 自动滚动 + 点击跳转）

struct LyricsSection: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    let lyrics: [LyricLine]
    let accent: Color
    let secondary: Color
    var gradientStart: Color? = nil
    var gradientEnd: Color? = nil
    var baseFontSize: CGFloat = 17
    var lineSpacing: CGFloat = 24
    var glowRadius: CGFloat = 9
    /// 显示歌词翻译（当前行下方小字）
    var showTranslation: Bool = false
    /// 歌词对齐样式（居中 / 居左）
    var alignment: HorizontalAlignment = .center
    /// 歌词水平偏移
    var offsetX: CGFloat = 0
    /// 当前行在视口中的垂直锚点
    var anchor: UnitPoint = .center
    /// 自定义发光颜色（nil 时跟随当前行颜色 / 封面取色）
    var glowColorOverride: Color? = nil
    /// 歌词模糊控制：距当前行几行后开始模糊 + 模糊强度（0 = 完全关闭模糊）
    var blurStart: CGFloat = 1
    var blurAmount: CGFloat = 1.1
    /// 歌词 3D 倾斜角度（绕 X 轴，顶部向后倒，0 = 关闭）
    var tilt: CGFloat = 0
    /// 歌词左右倾斜角度（绕 Y 轴，负值向左、正值向右，0 = 关闭）
    var tiltY: CGFloat = 0
    /// 歌词进度偏移（秒）：正数提前、负数延后
    var lyricOffset: CGFloat = 0
    let onTapLine: (LyricLine) -> Void

    /// 长按歌词进入多选复制模式（可多选 / 全选复制）
    @State private var selectionMode = false
    @State private var selected: Set<Int> = []
    /// 用户手动滚动时暂停自动跟随，停手后延迟恢复。
    @State private var isUserScrolling = false
    @GestureState private var lyricDragActive = false
    @State private var resumeScrollTask: Task<Void, Never>?
    /// 歌词手动滚动时，以视口中心最近的一行作为视觉焦点。
    @State private var focusedIndex: Int?
    /// 单击选中的歌词；双击或右侧按钮才执行跳转。
    @State private var selectedLyricIndex: Int?
    @State private var lyricTapTask: Task<Void, Never>?
    @State private var viewportHeight: CGFloat = 0

    /// 二分查找当前行（歌词按时间升序），避免逐行扫描降低 CPU
    private var currentIndex: Int? {
        guard !lyrics.isEmpty else { return nil }
        var low = 0
        var high = lyrics.count - 1
        var answer: Int?
        while low <= high {
            let mid = (low + high) / 2
            if lyrics[mid].time <= LyricTiming.effectiveProgress(clock.progress, userOffset: Double(lyricOffset)) {
                answer = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return answer
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: lineSpacing) {
                    ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                        lyricRow(index: index, line: line, proxy: proxy)
                            .background {
                                GeometryReader { rowGeometry in
                                    Color.clear.preference(
                                        key: LyricCenterPreferenceKey.self,
                                        value: [index: rowGeometry.frame(in: .named("coLyricsViewport")).midY]
                                    )
                                }
                            }
                            .contentShape(Rectangle())
                            .overlay(alignment: .topTrailing) {
                                if selectionMode {
                                    Image(systemName: selected.contains(index) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(selected.contains(index) ? accent : secondary.opacity(0.55))
                                        .padding(.trailing, 10)
                                        .padding(.top, 2)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .onTapGesture {
                                if selectionMode {
                                    withAnimation(.easeInOut(duration: 0.2)) { toggleSelect(index) }
                                } else {
                                    scheduleLyricSelection(index, proxy: proxy)
                                }
                            }
                            .simultaneousGesture(
                                TapGesture(count: 2)
                                    .onEnded {
                                        guard !selectionMode else { return }
                                        lyricTapTask?.cancel()
                                        playLyric(index: index, line: line, proxy: proxy)
                                    }
                            )
                            .onLongPressGesture(minimumDuration: 0.35) {
                                lyricTapTask?.cancel()
                                resumeScrollTask?.cancel()
                                isUserScrolling = false
                                selectedLyricIndex = nil
                                CoHaptics.medium()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if !selectionMode {
                                        selectionMode = true
                                        selected = [index]
                                    } else {
                                        toggleSelect(index)
                                    }
                                }
                            }
                            .id(index)
                    }
                }
                .padding(.top, 210)
                .padding(.bottom, 210)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .offset(x: offsetX)
            .coordinateSpace(name: "coLyricsViewport")
            .coScrollIndicatorsHidden()
            .rotation3DEffect(.degrees(Double(tilt)), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.5)
            .rotation3DEffect(.degrees(Double(tiltY)), axis: (x: 0, y: 1, z: 0), anchor: .center, perspective: 0.5)
            // 上下渐隐遮罩：歌词接近顶部或底部时自然淡出。
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.10),
                        .init(color: .black, location: 0.90),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(alignment: .top) {
                if selectionMode {
                    selectionBar
                        .padding(.top, 4)
                        .contentShape(Rectangle())
                        .allowsHitTesting(true)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay {
                GeometryReader { viewportGeometry in
                    Color.clear
                        .onAppear { viewportHeight = viewportGeometry.size.height }
                        .onChange(of: viewportGeometry.size.height) { newHeight in
                            viewportHeight = newHeight
                        }
                }
            }
            .onPreferenceChange(LyricCenterPreferenceKey.self) { positions in
                guard viewportHeight > 0, !positions.isEmpty else { return }
                let centerY = viewportHeight / 2
                let nextFocusedIndex = positions.min {
                    abs($0.value - centerY) < abs($1.value - centerY)
                }?.key
                focusedIndex = nextFocusedIndex
                if isUserScrolling {
                    selectedLyricIndex = nextFocusedIndex
                    if !lyricDragActive { scheduleLyricResume(proxy) }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 4)
                    .updating($lyricDragActive) { _, active, _ in active = true }
                    .onChanged { _ in
                        guard !selectionMode else { return }
                        lyricTapTask?.cancel()
                        isUserScrolling = true
                        resumeScrollTask?.cancel()
                    }
                    .onEnded { _ in
                        resumeScrollTask?.cancel()
                        let selectedIndex = focusedIndex
                        if let selectedIndex {
                            selectedLyricIndex = selectedIndex
                            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.38)) {
                                proxy.scrollTo(selectedIndex, anchor: .center)
                            }
                        }
                        if !selectionMode { scheduleLyricResume(proxy) }
                    }
            )
            .onAppear {
                // 延迟到布局稳定后再定位当前行，避免从封面页调整进度后切回歌词错位
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    scrollToCurrent(proxy)
                }
            }
            .onChange(of: lyricDragActive) { active in
                if !active, isUserScrolling, !selectionMode { scheduleLyricResume(proxy) }
            }
            .onChange(of: lyrics.first?.id) { _ in
                lyricTapTask?.cancel()
                resumeScrollTask?.cancel()
                isUserScrolling = false
                selectedLyricIndex = nil
                focusedIndex = nil
                scrollToCurrent(proxy)
            }
            .onChange(of: currentIndex) { newIndex in
                guard let newIndex, !isUserScrolling else { return }
                selectedLyricIndex = nil
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newIndex, anchor: anchor)
                }
            }
            .onChange(of: player.seekRevision) { _ in
                // 滑动进度条是明确的“跟随播放”指令：正在浏览歌词也要立刻跟回来，别等 3 秒回落。
                resumeScrollTask?.cancel()
                isUserScrolling = false
                selectedLyricIndex = nil
                focusedIndex = nil
                guard let newIndex = currentIndex else { return }
                DispatchQueue.main.async {
                    withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.3)) {
                        proxy.scrollTo(newIndex, anchor: anchor)
                    }
                }
            }
            .onDisappear {
                lyricTapTask?.cancel()
                resumeScrollTask?.cancel()
                isUserScrolling = false
                selectedLyricIndex = nil
                focusedIndex = nil
            }
        }
    }

    /// Apple Music 风格渐隐：当前行最大最亮，已播放行与未播放行按距离逐层变暗变淡
    private func lyricRow(index: Int, line: LyricLine, proxy: ScrollViewProxy) -> some View {
        let playbackIndex = currentIndex ?? 0
        // 手动滚动时，以视口中心行为清晰度焦点；颜色和渐变仍只跟随实际播放行。
        // 这样拖动歌词不会暂停播放，也不会让整页歌词一起变糊。
        let visualIndex = isUserScrolling ? (focusedIndex ?? currentIndex) : (selectedLyricIndex ?? currentIndex)
        let isCurrent = currentIndex != nil && index == playbackIndex
        let isFocused = index == visualIndex
        let isPlayed = (currentIndex ?? -1) >= 0 && index < playbackIndex
        let distance = abs(index - (visualIndex ?? playbackIndex))
        let opacity: Double = isFocused
            ? 1.0
            : (isPlayed ? 0.28 : 0.62) - Double(min(distance, 4)) * 0.05
        let size = isFocused ? baseFontSize + 4 : baseFontSize - CGFloat(min(distance, 2)) * 1.5
        // 歌词行模糊：当前行与邻近行保持清晰，距离越远才越柔和（避免只剩一行清晰显得突兀）
        // 模糊起始距离与强度由用户控制（0 强度 = 完全关闭模糊）
        let blurRadius: CGFloat = isFocused ? 0 : min(CGFloat(max(distance - Int(blurStart), 0)) * blurAmount, 7.0)

        // 当前行用渐变（封面色或自定义），光晕跟随渐变起始色
        let lineStyle: AnyShapeStyle
        if isCurrent, let gradientStart, let gradientEnd {
            lineStyle = AnyShapeStyle(LinearGradient(colors: [gradientStart, gradientEnd], startPoint: .top, endPoint: .bottom))
        } else {
            lineStyle = AnyShapeStyle(isCurrent ? accent : secondary)
        }
        let glowColor = glowColorOverride ?? (gradientStart ?? accent)

        let lineFont: Font = CoFont.appFont(size)
        // 翻译行只展示在当前视觉焦点行下方。
        let translationText = (isCurrent && showTranslation) ? line.translation : nil

        return VStack(alignment: alignment == .leading ? .leading : .center, spacing: 3) {
            Text(line.text.isEmpty ? " " : line.text)
                .font(lineFont)
                .foregroundStyle(lineStyle)
                .opacity(max(opacity, 0.15))
                // 双层光晕：内层亮、外层宽，发光更明显
                .shadow(
                    color: isCurrent ? glowColor.opacity(glowRadius > 0 ? 0.9 : 0) : .clear,
                    radius: isCurrent ? glowRadius * 0.45 : 0
                )
                .shadow(
                    color: isCurrent ? glowColor.opacity(glowRadius > 0 ? 0.55 : 0) : .clear,
                    radius: isCurrent ? glowRadius : 0
                )
                .blur(radius: blurRadius)
                .scaleEffect(isFocused ? 1.05 : 1, anchor: .leading)
                .multilineTextAlignment(alignment == .leading ? .leading : .center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            if let translationText, !translationText.isEmpty {
                Text(translationText)
                    .font(CoFont.appFont(size * 0.68, .regular))
                    .foregroundStyle(secondary.opacity(isCurrent ? 0.9 : 0.45))
                    .multilineTextAlignment(alignment == .leading ? .leading : .center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .blur(radius: blurRadius * 0.5)
                    .opacity(max(opacity, 0.2))
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
        .padding(.horizontal, alignment == .leading ? 40 : 36)
        .overlay(alignment: .trailing) {
            if selectedLyricIndex == index || (isUserScrolling && isFocused) {
                HStack(spacing: 6) {
                    Text(coTimeString(line.time))
                        .font(CoFont.appFont(11, .semibold, .default))
                        .foregroundStyle(secondary.opacity(0.82))
                    Button {
                        lyricTapTask?.cancel()
                        playLyric(index: index, line: line, proxy: proxy)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(accent)
                            .frame(width: 24, height: 24)
                            .background(accent.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, alignment == .leading ? 34 : 28)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: visualIndex)
    }

    private func scheduleLyricResume(_ proxy: ScrollViewProxy) {
        resumeScrollTask?.cancel()
        resumeScrollTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 3_000_000_000) }
            catch { return }
            guard !Task.isCancelled, !lyricDragActive, !selectionMode else { return }
            lyricTapTask?.cancel()
            isUserScrolling = false
            selectedLyricIndex = nil
            focusedIndex = nil
            withAnimation(.easeInOut(duration: 0.3)) { scrollToCurrent(proxy) }
        }
    }

    private func scheduleLyricSelection(_ index: Int, proxy: ScrollViewProxy) {
        lyricTapTask?.cancel()
        lyricTapTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                selectedLyricIndex = index
                isUserScrolling = true
            }
            scheduleLyricResume(proxy)
            CoHaptics.tap()
        }
    }

    private func playLyric(index: Int, line: LyricLine, proxy: ScrollViewProxy) {
        selectedLyricIndex = nil
        resumeScrollTask?.cancel()
        isUserScrolling = false
        focusedIndex = nil
        CoHaptics.tap()
        onTapLine(line)
        DispatchQueue.main.async {
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.3)) {
                proxy.scrollTo(index, anchor: anchor)
            }
        }
    }

    private func toggleSelect(_ index: Int) {
        if selected.contains(index) {
            selected.remove(index)
        } else {
            selected.insert(index)
        }
    }

    private func copySelected() {
        let text = selected.sorted()
            .compactMap { idx -> String? in
                lyrics.indices.contains(idx) ? lyrics[idx].text : nil
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        guard !text.isEmpty else { return }
        UIPasteboard.general.string = text
        CoHaptics.success()
        withAnimation(.easeInOut(duration: 0.2)) {
            selectionMode = false
            selected = []
        }
    }

    private var selectionBar: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { selected = Set(lyrics.indices) }
            } label: {
                Text("全选")
                    .font(CoFont.appFont(13, .medium))
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
            Button {
                copySelected()
            } label: {
                Text(selected.isEmpty ? "复制" : "复制 (\(selected.count))")
                    .font(CoFont.appFont(13, .semibold))
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectionMode = false
                    selected = []
                }
            } label: {
                Text("取消")
                    .font(CoFont.appFont(13))
                    .foregroundStyle(secondary)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.8)
                }
        }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        guard let currentIndex else { return }
        proxy.scrollTo(currentIndex, anchor: anchor)
    }
}

// MARK: - 歌词渐变预设（一键组合：渐变起止色 + 发光强度）

struct LyricPreset {
    let name: String
    let start: String
    let end: String
    let glow: Int

    static let all: [LyricPreset] = [
        LyricPreset(name: "晨曦金", start: "#FFD08A", end: "#FF7A3D", glow: 2),
        LyricPreset(name: "冰蓝极光", start: "#8FD8FF", end: "#5B6BFF", glow: 2),
        LyricPreset(name: "霓虹紫", start: "#E8A2FF", end: "#8A2BE2", glow: 3),
        LyricPreset(name: "草莓奶昔", start: "#FF9AB5", end: "#FF5E8A", glow: 1),
        LyricPreset(name: "鎏金夜曲", start: "#F5D98B", end: "#C9A227", glow: 2),
        LyricPreset(name: "薄荷气泡", start: "#A8F0D4", end: "#2BC48D", glow: 2),
    ]
}

// MARK: - 播放器设置（更多菜单 → 播放器设置：全局播放行为与播放器风格入口）

struct PlayerSettingsSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    private let onDismiss: (() -> Void)?
    @Binding private var layoutMode: Bool
    @AppStorage("co.lyricBackground.image") private var lyricBackgroundImagePath = ""
    @AppStorage("co.coverPlayerStyle") private var coverPlayerStyleRaw = CoCoverPlayerStyle.appleMusic.rawValue
    @Environment(\.dismiss) private var dismiss
    @AppStorage("co.playerSettings.coverExpanded") private var coverExpanded = true
    @State private var showLyricBackgroundPicker = false

    init(layoutMode: Binding<Bool>, onDismiss: (() -> Void)? = nil) {
        self._layoutMode = layoutMode
        self.onDismiss = onDismiss
    }

    private var selectedCoverPlayerStyle: CoCoverPlayerStyle {
        CoCoverPlayerStyle.resolved(rawValue: coverPlayerStyleRaw)
    }





    private var coverPlayerStyleSelector: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("播放器风格")
                .font(CoFont.appFont(13, .semibold))
                .foregroundStyle(Color.coLabel)
            ForEach(CoCoverPlayerStyle.availableCases) { style in
                let selected = selectedCoverPlayerStyle == style
                Button {
                    coverPlayerStyleRaw = style.rawValue
                    CoHaptics.select()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: style.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selected ? .white : Color.coAmber)
                            .frame(width: 32, height: 32)
                            .background(selected ? Color.coAmber : Color.coAmber.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(style.title))
                                .font(CoFont.appFont(13, .semibold))
                                .foregroundStyle(Color.coLabel)
                            Text(LocalizedStringKey(style.subtitle))
                                .font(CoFont.appFont(11))
                                .foregroundStyle(Color.coComment)
                                .lineLimit(1)
                        }
                        Spacer()
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.coAmber)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(
                        selected ? Color.coAmber.opacity(0.12) : Color.primary.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(selected ? Color.coAmber.opacity(0.42) : Color.coComment.opacity(0.10), lineWidth: 0.8)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }



    var body: some View {
        let _ = theme.accent
        CoNavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    NavigationLink {
                        FoliaSettingsView()
                    } label: {
                        HStack {
                            Label("Folia 歌词与液态设置", systemImage: "sparkles")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(CoFont.appFont(14, .semibold))
                        .padding(14)
                        .background { CoGlass(shape: RoundedRectangle(cornerRadius: 14)) }
                    }
                    .buttonStyle(.plain)
                    layoutCard
                    coverCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
            }
            .navigationTitle("播放器设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        if let onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showLyricBackgroundPicker) {
            WallpaperPhotoPicker { data in
                if let path = LyricBackgroundStore.save(data) {
                    lyricBackgroundImagePath = path
                    CoHaptics.success()
                    ToastCenter.shared.show("歌词背景已应用")
                } else {
                    ToastCenter.shared.show("歌词背景保存失败")
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            if let path = LyricBackgroundStore.restoreFromBackup(), lyricBackgroundImagePath != path {
                lyricBackgroundImagePath = path
            }
        }
    }

    // MARK: - 设置卡片（液态玻璃圆角分组，紧凑排版）

    /// 设置卡片容器：液态玻璃圆角卡片
    private func settingCard<Content: View>(_ title: String, isExpanded: Binding<Bool>? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            if let isExpanded {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.06)) {
                        isExpanded.wrappedValue.toggle()
                    }
                    CoHaptics.select()
                } label: {
                    HStack(spacing: 10) {
                        Text(LocalizedStringKey(title))
                            .font(CoFont.appFont(13, .bold))
                            .foregroundStyle(Color.coLabel)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.coComment)
                            .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
                            .frame(width: 24, height: 24)
                    }
                    .frame(minHeight: 38)
                    .contentShape(Rectangle())
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.98))

                if isExpanded.wrappedValue {
                    content()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                        ))
                }
            } else {
                Text(LocalizedStringKey(title))
                    .font(CoFont.appFont(14, .bold))
                    .foregroundStyle(Color.coLabel)
                content()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                PlayerSettingsLiquidGlass(shape: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
    }


    /// 布局卡片：播放器自定义布局 / 指示线 / 歌词对齐
    private var layoutCard: some View {
        settingCard("自定义布局") {
            Button {
                layoutMode = true
                CoHaptics.select()
                if let onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                    Text("打开播放器布局编辑器")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .font(CoFont.appFont(13, .semibold))
                .foregroundStyle(Color.coLabel)
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.98))
        }
    }

    /// 封面卡片：播放器风格选择
    private var coverCard: some View {
        settingCard("封面", isExpanded: $coverExpanded) {
            coverPlayerStyleSelector
            Button {
                showLyricBackgroundPicker = true
                CoHaptics.select()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                    Text(lyricBackgroundImagePath.isEmpty ? "选择歌词背景图" : "更换歌词背景图")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .font(CoFont.appFont(13, .semibold))
                .foregroundStyle(Color.coLabel)
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.98))
        }
    }
}

private struct PlayerSettingsLiquidGlass<S: Shape>: View {
    let shape: S

    var body: some View {
        CoGlass(shape: shape)
    }

}

// MARK: - 下载文件分享（Identifiable 包装，供 sheet(item:) 使用）

struct ShareFileItem: Identifiable {
    let id = UUID()
    let url: URL
}


// MARK: - 原生系统分享面板（UIActivityViewController 封装，直接调系统自带分享）

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // iPad 弹出需要 popover 锚点，否则会崩溃
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 圆形封面旋转（播放中匀速旋转，暂停即停）
struct CoverSpin: ViewModifier {
    let enabled: Bool
    let isPlaying: Bool
    var degreesPerSecond: Double = 15

    @State private var pausedAngle = 0.0
    @State private var startedAt: Date?
    @State private var renderedAngle = 0.0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(enabled ? renderedAngle : 0))
            .onAppear { updateAnimation() }
            .onChange(of: isPlaying) { _ in updateAnimation() }
            .onChange(of: enabled) { _ in updateAnimation() }
    }

    private func updateAnimation() {
        guard enabled else {
            stop(at: Date())
            pausedAngle = 0
            setRenderedAngle(0)
            return
        }
        if isPlaying {
            start(at: Date())
        } else {
            stop(at: Date())
        }
    }

    private func start(at date: Date) {
        guard startedAt == nil else { return }
        let angle = normalized(pausedAngle)
        setRenderedAngle(angle)
        startedAt = date
        withAnimation(.linear(duration: 360 / max(degreesPerSecond, 1)).repeatForever(autoreverses: false)) {
            renderedAngle = angle + 360
        }
    }

    private func stop(at date: Date) {
        guard let startedAt else { return }
        pausedAngle = normalized(pausedAngle + date.timeIntervalSince(startedAt) * degreesPerSecond)
        self.startedAt = nil
        setRenderedAngle(pausedAngle)
    }

    private func setRenderedAngle(_ angle: Double) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            renderedAngle = angle
        }
    }

    private func normalized(_ angle: Double) -> Double {
        let remainder = angle.truncatingRemainder(dividingBy: 360)
        return remainder >= 0 ? remainder : remainder + 360
    }
}

/// Apple Music 播放页的最小版评论：只读，不臃肿。
/// 一个入口（播放页底部评论键）、一页只读列表，不做发评论、点赞、回复、
/// 分页、排序。只拉第 1 页：有热门就只显示热门，热门为空才显示普通评论，
/// 两边都空才显示“暂无评论”——不编造任何一条。
private struct CoHotCommentsSheet: View {
    let song: Song
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [SongComment] = []
    @State private var isHot = true
    @State private var isLoading = true
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isHot ? "热门评论" : "评论")
                        .font(.system(size: 18, weight: .bold))
                    Text(song.name)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            if isLoading {
                Spacer()
                ProgressView("正在加载评论…")
                Spacer()
            } else if let errorText {
                Spacer()
                Text(errorText)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            } else if comments.isEmpty {
                Spacer()
                Text("暂无评论")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(comments) { comment in
                    HStack(alignment: .top, spacing: 12) {
                        AsyncImage(url: comment.avatarURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.primary.opacity(0.12))
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(comment.nickname.isEmpty ? "酷狗用户" : comment.nickname)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                                Text(comment.time, style: .date)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if comment.likedCount > 0 {
                                    Label("\(comment.likedCount)", systemImage: "heart")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(comment.content)
                                .font(.system(size: 14))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .task(id: song.identityKey) {
            isLoading = true
            errorText = nil
            do {
                let page = try await KugouMusicAPI.shared.comments(
                    mixSongID: song.kugouAlbumAudioId ?? "",
                    hash: song.kugouHash,
                    page: 1,
                    limit: 30,
                    songName: song.name,
                    artist: song.artists
                )
                if !page.hotComments.isEmpty {
                    comments = page.hotComments
                    isHot = true
                } else {
                    comments = page.comments
                    isHot = false
                }
            } catch {
                errorText = "评论加载失败，稍后再试"
            }
            isLoading = false
        }
    }
}
