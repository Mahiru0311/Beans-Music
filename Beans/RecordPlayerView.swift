import SwiftUI
import UIKit

// Adapted under LGPL-3.0. See THIRD_PARTY_NOTICES.md.
struct RecordPlayerView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var customCovers = CustomSongCoverStore.shared

    let song: Song?
    let lyrics: [LyricLine]
    @Binding var isPresented: Bool
    let layoutData: [String: PlayerLayoutEntry]
    let initialShowsLyrics: Bool
    let isFavorite: Bool
    let favoriteMark: FavoriteMark
    let onFavorite: () -> Void
    let onComments: () -> Void
    let onSettings: () -> Void
    let onArtist: () -> Void
    let onSleepTimer: () -> Void
    let onAddToLocalPlaylist: () -> Void
    let visualsActive: Bool

    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var showSoftwareVolume = false
    @State private var showLyricOffsetSheet = false
    @AppStorage("co.audioQuality") private var playbackQualityRaw = CoAudioQuality.hires.rawValue
    @AppStorage(LyricTiming.userOffsetKey) private var lyricOffset = 0.0

    init(
        song: Song?,
        lyrics: [LyricLine],
        isPresented: Binding<Bool>,
        layoutData: [String: PlayerLayoutEntry] = [:],
        initialShowsLyrics: Bool = false,
        isFavorite: Bool = false,
        favoriteMark: FavoriteMark = .none,
        onFavorite: @escaping () -> Void,
        onComments: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onArtist: @escaping () -> Void = {},
        onSleepTimer: @escaping () -> Void = {},
        onAddToLocalPlaylist: @escaping () -> Void = {},
        visualsActive: Bool = true
    ) {
        self.song = song
        self.lyrics = lyrics
        self._isPresented = isPresented
        self.layoutData = layoutData
        self.initialShowsLyrics = initialShowsLyrics
        self.isFavorite = isFavorite
        self.favoriteMark = favoriteMark
        self.onFavorite = onFavorite
        self.onComments = onComments
        self.onSettings = onSettings
        self.onArtist = onArtist
        self.onSleepTimer = onSleepTimer
        self.onAddToLocalPlaylist = onAddToLocalPlaylist
        self.visualsActive = visualsActive
        self._showLyrics = State(initialValue: initialShowsLyrics)
    }

    private var displayCoverURL: URL? {
        customCovers.url(for: song) ?? song?.coverURL
    }

    var body: some View {
        GeometryReader { geometry in
            let surface = ZStack {
                backdrop
                if isPhoneLandscape(size: geometry.size) {
                    landscapeLayout(size: geometry.size)
                } else if isIPadPortrait(size: geometry.size) || geometry.size.width < 720 {
                    compactLayout(size: geometry.size)
                } else {
                    regularLayout(size: geometry.size)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())

            // iOS 26+ owns the full-screen interactive dismissal. Keeping a
            // second gesture here made this style disappear instantly.
            surface
        }
        .animation(.easeInOut(duration: 0.22), value: showLyrics)
        .sheet(isPresented: $showSoftwareVolume) {
            CoSoftwareVolumeSheetHost()
                .environmentObject(player)
        }
        .sheet(isPresented: $showLyricOffsetSheet) {
            CoLyricOffsetSheet()
        }
        .overlay(alignment: .top) {
            recordHeader
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .zIndex(10)
        }
    }

    private var backdrop: some View {
        ZStack {
            if false {
            } else {
                CoverBlurBackground(url: displayCoverURL, scheme: colorScheme, animationsEnabled: visualsActive)
                RadialGradient(
                    colors: [.white.opacity(0.12), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 700
                )
                LinearGradient(
                    colors: [.clear, .black.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func compactLayout(size: CGSize) -> some View {
        if isIPadPortrait(size: size) {
            portraitIPadLayout(size: size)
        } else {
            let artworkDimension = max(150, min(size.width - 72, size.height * 0.43, 310))
            VStack(spacing: 16) {
                Spacer().frame(height: 34)
                if showQueue {
                    recordQueuePage
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                } else if showLyrics {
                    lyricsColumn
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                } else {
                    turntable(size: artworkDimension)
                        .modifier(recordLayout(.vinylCover))
                        .frame(maxWidth: .infinity)
                    trackMetadata
                        .modifier(recordLayout(.vinylTitle))
                    RecordModeMiniLyrics(lyrics: lyrics) {
                        withAnimation(.easeInOut(duration: 0.22)) { showLyrics = true }
                    }
                    // Keep the lyric preview's footprint stable while the next
                    // song's lyrics are being resolved, so the scrubber never jumps.
                    .frame(maxWidth: .infinity)
                    .frame(height: 84)
                }
                RecordModeScrubber()
                    .padding(.horizontal, 20)
                    .modifier(recordLayout(.progress))
                controls
                    .padding(.bottom, 20)
                    .modifier(recordLayout(.controls))
            }
            .padding(.horizontal, 16)
        }
    }

    private func portraitIPadLayout(size: CGSize) -> some View {
        let artworkDimension = min(
            390,
            max(280, size.width * 0.54),
            max(280, size.height * 0.42)
        )

        return VStack(spacing: 12) {
            Spacer(minLength: 18)

            if showQueue {
                recordQueuePage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            } else if showLyrics {
                lyricsColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            } else {
                turntable(size: artworkDimension)
                    .modifier(recordLayout(.vinylCover))
                    .frame(maxWidth: .infinity)
                trackMetadata
                    .modifier(recordLayout(.vinylTitle))
                RecordModeMiniLyrics(lyrics: lyrics) {
                    withAnimation(.easeInOut(duration: 0.22)) { showLyrics = true }
                }
                .frame(maxWidth: 620)
                .frame(height: 84)
            }

            RecordModeScrubber()
                .frame(maxWidth: 700)
                .padding(.horizontal, 24)
                .modifier(recordLayout(.progress))
            controls
                .frame(maxWidth: 760)
                .modifier(recordLayout(.controls))
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 42)
        .padding(.vertical, 12)
    }

    private func landscapeLayout(size: CGSize) -> some View {
        let artworkDimension = min(190, max(120, size.height - 175))
        return VStack(spacing: 6) {
            HStack(spacing: 18) {
                if showQueue {
                    recordQueuePage
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                } else if showLyrics {
                    lyricsColumn
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 7) {
                        turntable(size: artworkDimension)
                            .modifier(recordLayout(.vinylCover))
                        trackMetadata
                            .modifier(recordLayout(.vinylTitle))
                    }
                    .frame(maxWidth: .infinity)
                    lyricsColumn
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
            VStack(spacing: 4) {
                RecordModeScrubber()
                    .padding(.horizontal, 24)
                    .modifier(recordLayout(.progress))
                transportControls
                    .frame(maxWidth: 360)
            }
            .padding(.bottom, 6)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }

    private func regularLayout(size: CGSize) -> some View {
        let artworkDimension = max(180, min(330, size.width * 0.30, size.height - 300))
        return Group {
            if showQueue {
                regularQueueLayout(size: size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    VStack(spacing: 22) {
                        Spacer()
                        turntable(size: artworkDimension)
                            .modifier(recordLayout(.vinylCover))
                        trackMetadata
                            .modifier(recordLayout(.vinylTitle))
                        VStack(spacing: 14) {
                            RecordModeScrubber()
                                .frame(maxWidth: 380)
                                .modifier(recordLayout(.progress))
                            controls
                                .modifier(recordLayout(.controls))
                        }
                        Spacer()
                    }
                    .padding(.trailing, 30)
                    .frame(maxWidth: .infinity)
                    lyricsColumn
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 48)
        .padding(.vertical, size.height < 500 ? 24 : 40)
    }

    private func regularQueueLayout(size: CGSize) -> some View {
        let artworkDimension = min(
            290,
            max(190, size.width * 0.24),
            max(190, size.height - 260)
        )

        return HStack(spacing: 30) {
            VStack(spacing: 13) {
                Spacer(minLength: 0)
                turntable(size: artworkDimension)
                    .modifier(recordLayout(.vinylCover))
                trackMetadata
                    .modifier(recordLayout(.vinylTitle))
                RecordModeScrubber()
                    .frame(maxWidth: 430)
                    .modifier(recordLayout(.progress))
                HStack(spacing: 10) {
                    transportControls
                        .frame(maxWidth: 270)
                    circleButton(icon: "list.bullet", size: 17) {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showQueue = false
                        }
                    }
                }
                .frame(maxWidth: 330)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: size.width * 0.44, maxHeight: .infinity)

            AppleMusicCompactQueueContent()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 8)
    }

    private func turntable(size: CGFloat, allowsLyrics: Bool = true) -> some View {
        RecordModeTurntableView(
            coverURL: displayCoverURL,
            isPlaying: visualsActive && player.isPlaying,
            trackId: song?.id,
            size: size,
            onTap: {
                guard allowsLyrics else { return }
                if showQueue { showQueue = false }
                withAnimation(.easeInOut(duration: 0.22)) { showLyrics = true }
            },
            onNextTrack: { player.next() },
            onPreviousTrack: { player.previous() }
        )
    }

    private var trackMetadata: some View {
        VStack(spacing: 5) {
            Text(song?.name ?? "")
                .font(CoFont.appFont(21, .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .contextMenu {
                    Button("复制歌名") {
                        copySongTitle()
                    }
                }
            Text(song.map { "\($0.artists) — \($0.album)" } ?? "")
                .font(CoFont.appFont(13.5))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
                .contentShape(Rectangle())
                .onTapGesture(perform: onArtist)
            Text("来源：\(sourceName)")
                .font(CoFont.appFont(11))
                .foregroundStyle(.white.opacity(0.5))
            HStack(spacing: 8) {
                Menu {
                    CoAudioQualityMenu()
                        .environmentObject(player)
                } label: {
                    Label("音质：\(CoAudioQuality(rawValue: playbackQualityRaw)?.displayName ?? CoAudioQuality.hires.displayName)", systemImage: "waveform")
                        .font(CoFont.appFont(12, .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(.white.opacity(0.12), in: Capsule())
                }
                metadataButton(title: "评论", icon: "text.bubble", action: onComments)
            }
        }
        .frame(maxWidth: 400)
    }

    private func metadataButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(CoFont.appFont(12, .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(RecordModePressButtonStyle())
    }

    private var sourceName: String {
        // 酷狗专版：只留酷狗文案，无歌时仍显示“未知”。
        guard song != nil else { return "未知" }
        return "酷狗"
    }

    private var controls: some View {
        HStack(spacing: 0) {
            circleButton(icon: player.playMode.icon, size: 14, tint: player.playMode == .sequential ? nil : .red) {
                player.togglePlayMode()
            }
            .frame(maxWidth: .infinity)
            circleButton(icon: "backward.fill", size: 16) { player.previous() }
                .frame(maxWidth: .infinity)
            playPauseButton
                .frame(maxWidth: .infinity)
            circleButton(icon: "forward.fill", size: 16) { player.next() }
                .frame(maxWidth: .infinity)
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showQueue.toggle()
                    if showQueue {
                        showLyrics = false
                    }
                }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(RecordModePressButtonStyle())
                .frame(maxWidth: .infinity)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 0) {
            transportButton(icon: "backward.fill", size: 25) { player.previous() }
            transportButton(icon: player.isPlaying ? "pause.fill" : "play.fill", size: 36) {
                player.togglePlayPause()
            }
            transportButton(icon: "forward.fill", size: 25) { player.next() }
        }
        .foregroundStyle(.white)
    }

    private func transportButton(icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: size == 36 ? 64 : 58)
        }
        .buttonStyle(RecordModePressButtonStyle())
    }

    private var playPauseButton: some View {
        Button {
            player.togglePlayPause()
        } label: {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 58, height: 58)
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.black.opacity(0.85))
            }
        }
        .buttonStyle(RecordModePressButtonStyle())
    }

    private func circleButton(
        icon: String,
        size: CGFloat,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(tint ?? .white.opacity(0.8))
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.1), in: Circle())
        }
        .buttonStyle(RecordModePressButtonStyle())
    }

    private var recordQueuePage: some View {
        VStack(spacing: 12) {
            HStack(spacing: 11) {
                CoverImage(url: displayCoverURL, size: 46, cornerRadius: 10)
                    .shadow(color: .black.opacity(0.26), radius: 9, y: 4)
                VStack(alignment: .leading, spacing: 3) {
                    Text(song?.name ?? "未在播放")
                        .font(CoFont.appFont(16, .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .contextMenu {
                            Button("复制歌名") {
                                copySongTitle()
                            }
                        }
                    Text(song?.artists ?? "")
                        .font(CoFont.appFont(12, .medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onArtist)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onFavorite) {
                    FavoriteHeartView(mark: favoriteMark.isLiked ? favoriteMark : (isFavorite ? .local : .none), size: 17)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(RecordModePressButtonStyle())
            }
            .frame(maxWidth: 520)
            AppleMusicCompactQueueContent()
        }
        .padding(.horizontal, 8)
    }

    private var lyricsColumn: some View {
        AppleMusicLyricsSection(
            lyrics: lyrics,
            primary: .white,
            secondary: .white.opacity(0.58),
            lyricOffset: CGFloat(lyricOffset)
        ) { line in
            player.seekPrecisely(to: LyricTiming.seekTime(for: line, userOffset: lyricOffset))
        }
        .padding(.horizontal, 8)
        .modifier(recordLayout(.vinylLyricsText))
    }

    private var recordHeader: some View {
        HStack {
            Spacer()
            if showLyrics {
                Button {
                    CoHaptics.tap()
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showLyrics = false
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(RecordModePressButtonStyle())
                .accessibilityLabel("返回唱片")
            }
            Menu {
                if showLyrics || showQueue {
                    Button("返回唱片") {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showLyrics = false
                            showQueue = false
                        }
                    }
                }
                Button("定时关闭", action: onSleepTimer)
                Button("添加到本地歌单", action: onAddToLocalPlaylist)
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
                Button("播放器设置", action: onSettings)
                Button("歌词偏移") {
                    showLyricOffsetSheet = true
                }
                Button("软件音量") {
                    showSoftwareVolume = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(RecordModePressButtonStyle())
            .accessibilityLabel("更多设置")

        }
    }

    private func isPhoneLandscape(size: CGSize) -> Bool {
        UIDevice.current.userInterfaceIdiom == .phone && size.width > size.height
    }

    private func isIPadPortrait(size: CGSize) -> Bool {
        UIDevice.current.userInterfaceIdiom == .pad && size.height >= size.width
    }

    private func recordLayout(_ part: PlayerLayoutPart) -> some ViewModifier {
        RecordModeLayoutTransform(
            entry: layoutData[part.rawValue] ?? VinylPlayerLayoutStore.defaultEntry(for: part)
        )
    }

    private func copySongTitle() {
        guard let title = song?.name.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return }
        UIPasteboard.general.string = title
        CoHaptics.success()
        ToastCenter.shared.show("歌名已复制")
    }

}

/// 共用播放音质切换（系统弹窗式）：Menu 里直接列 4 档，点开就是
/// 系统展开的小弹窗，上下滑动选档、当前档带勾，选完立即重播生效。
/// 不再进整页选择表——原先那张整页表已删。实际档位能确认时首行
/// 灰字显示“实际：X”，拿不到时不显示、不编档位（只看勾选的偏好）。
struct CoAudioQualityMenu: View {
    @EnvironmentObject private var player: PlayerManager
    @ObservedObject private var equalizer = CoEqualizer.shared
    @AppStorage("co.audioQuality") private var selectedRaw = CoAudioQuality.hires.rawValue

    static func normalized(_ quality: CoAudioQuality) -> CoAudioQuality {
        switch quality {
        case .higher: return .exhigh
        case .master: return .hires
        default: return quality
        }
    }

    static func displayName(forKey key: String) -> String? {
        switch key {
        case "hires": return "Hi-Res"
        case "lossless": return "无损"
        case "exhigh": return "极高"
        case "standard": return "标准"
        default: return nil
        }
    }

    private var tiers: [(quality: CoAudioQuality, note: String)] {
        [(.standard, "128"), (.exhigh, "320"), (.lossless, "FLAC"), (.hires, "Hi-Res")]
    }

    private var selectedTier: CoAudioQuality {
        Self.normalized(CoAudioQuality(rawValue: selectedRaw) ?? .hires)
    }

    var body: some View {
        if let key = player.actualAudioQualityKey, let name = Self.displayName(forKey: key) {
            Button("实际：\(name)") {}.disabled(true)
        }
        ForEach(tiers, id: \.quality) { tier in
            Button {
                selectedRaw = tier.quality.rawValue
                player.retryCurrent()
            } label: {
                HStack {
                    Text(tier.quality.displayName)
                    Text(tier.note)
                    if selectedTier == tier.quality {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
        Divider()
        Button {
            let wasProcessing = equalizer.isEnabled || equalizer.surroundEnabled || equalizer.headphoneBoostEnabled || equalizer.vocalBoostEnabled || equalizer.widenEnabled
            equalizer.setSurroundEnabled(!equalizer.surroundEnabled)
            // EQ 关着时本就没有 tap 在跑：只靠重挂 audioMix 未必立即生效，
            // 断点续播重挂一次，3D 立刻可听；EQ 开着时 tap 已在跑、改动即时生效，不用重播。
            if !wasProcessing, equalizer.surroundEnabled {
                player.retryCurrent()
            }
        } label: {
            HStack {
                Text("3D环绕")
                if equalizer.surroundEnabled {
                    Image(systemName: "checkmark")
                }
            }
        }
        Button {
            let wasProcessing = equalizer.isEnabled || equalizer.surroundEnabled || equalizer.headphoneBoostEnabled || equalizer.vocalBoostEnabled || equalizer.widenEnabled
            equalizer.setHeadphoneBoostEnabled(!equalizer.headphoneBoostEnabled)
            // 与 3D 开关同理：之前没 tap 在跑时断点续播重挂一次，立刻可听。
            if !wasProcessing, equalizer.headphoneBoostEnabled {
                player.retryCurrent()
            }
        } label: {
            HStack {
                Text("耳机增强")
                if equalizer.headphoneBoostEnabled {
                    Image(systemName: "checkmark")
                }
            }
        }
        Button {
            let wasProcessing = equalizer.isEnabled || equalizer.surroundEnabled || equalizer.headphoneBoostEnabled || equalizer.vocalBoostEnabled || equalizer.widenEnabled
            equalizer.setVocalBoostEnabled(!equalizer.vocalBoostEnabled)
            if !wasProcessing, equalizer.vocalBoostEnabled {
                player.retryCurrent()
            }
        } label: {
            HStack {
                Text("人声清晰")
                if equalizer.vocalBoostEnabled {
                    Image(systemName: "checkmark")
                }
            }
        }
        Button {
            let wasProcessing = equalizer.isEnabled || equalizer.surroundEnabled || equalizer.headphoneBoostEnabled || equalizer.vocalBoostEnabled || equalizer.widenEnabled
            equalizer.setWidenEnabled(!equalizer.widenEnabled)
            if !wasProcessing, equalizer.widenEnabled {
                player.retryCurrent()
            }
        } label: {
            HStack {
                Text("声场加宽")
                if equalizer.widenEnabled {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}

private struct RecordModeLayoutTransform: ViewModifier {
    let entry: PlayerLayoutEntry

    func body(content: Content) -> some View {
        content
            .scaleEffect(entry.scale)
            .rotationEffect(.degrees(entry.rotation))
            .opacity(entry.opacity)
            .offset(x: entry.x, y: entry.y)
    }
}

struct RecordModePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct RecordModeMiniLyrics: View {
    @EnvironmentObject private var clock: PlaybackClock

    let lyrics: [LyricLine]
    let onOpen: () -> Void

    private var lines: (previous: LyricLine?, current: LyricLine?, next: LyricLine?) {
        guard !lyrics.isEmpty else { return (nil, nil, nil) }
        let index = lyrics.lastIndex(where: { $0.time <= clock.progress })
        guard let index else { return (nil, nil, lyrics.first) }
        return (
            index > 0 ? lyrics[index - 1] : nil,
            lyrics[index],
            index + 1 < lyrics.count ? lyrics[index + 1] : nil
        )
    }

    var body: some View {
        let visible = lines
        Group {
            if visible.current != nil || visible.next != nil {
                VStack(spacing: 12) {
                    line(visible.previous, emphasized: false)
                    line(visible.current, emphasized: true)
                    line(visible.next, emphasized: false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpen)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: visible.current?.id)
            } else {
                Color.clear
            }
        }
        .frame(height: 84)
    }

    private func line(_ line: LyricLine?, emphasized: Bool) -> some View {
        Text(line?.text.isEmpty == false ? line!.text : " ")
            .font(CoFont.appFont(emphasized ? 17 : 14, emphasized ? .bold : .medium))
            .foregroundStyle(.white.opacity(emphasized ? 1 : 0.45))
            .lineLimit(1)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
            .id(line?.id)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

private struct RecordModeScrubber: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    @State private var isDragging = false
    @State private var dragProgress = 0.0

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let duration = max(clock.duration, player.currentSong?.duration ?? 0)
                let value = isDragging ? dragProgress : clock.progress
                let fraction = duration > 0 ? min(max(value / duration, 0), 1) : 0

                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25)).frame(height: 4)
                    Capsule().fill(.white).frame(width: max(4, width * fraction), height: 4)
                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? 13 : 9, height: isDragging ? 13 : 9)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .offset(x: max(0, min(width - (isDragging ? 13 : 9), width * fraction - (isDragging ? 6.5 : 4.5))))
                        .opacity(isDragging ? 1 : 0)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard duration > 0 else { return }
                            isDragging = true
                            dragProgress = min(max(value.location.x / max(width, 1), 0), 1) * duration
                        }
                        .onEnded { _ in
                            player.seek(to: dragProgress)
                            isDragging = false
                        }
                )
            }
            .frame(height: 14)
            HStack {
                Text(coTimeString(isDragging ? dragProgress : clock.progress))
                Spacer()
                Text(coTimeString(max(clock.duration, player.currentSong?.duration ?? 0)))
            }
            .font(CoFont.appFont(10.5, .regular, .default))
            .foregroundStyle(.white.opacity(0.55))
        }
    }
}

private struct RecordModeTurntableView: View {
    let coverURL: URL?
    let isPlaying: Bool
    let trackId: Int?
    let size: CGFloat
    var playsCoverVideoAudio = true
    var onTap: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var isTransitioningTrack = false

    var body: some View {
        let armHeight = size * 0.68
        ZStack(alignment: .top) {
            // The disc is rendered once and rotated by its backing CALayer.
            // Updating the whole SwiftUI tree every frame made the rings,
            // gradients and cover view participate in every animation tick.
            SmoothRecordDiscView(
                coverURL: coverURL,
                isPlaying: isPlaying && !isDragging && !reduceMotion,
                size: size,
                playsCoverVideoAudio: playsCoverVideoAudio
            )
            .offset(x: dragOffset)
            .padding(.top, armHeight * 0.36)
            .contentShape(Circle())
            .gesture(swipeGesture)
            .onTapGesture { onTap?() }
            .zIndex(1)

            RecordModeTonearmView(
                isPlaying: isPlaying && !isDragging && !isTransitioningTrack,
                height: armHeight,
                reduceMotion: reduceMotion
            )
            .offset(x: size * 0.12, y: -armHeight * 0.08)
            .allowsHitTesting(false)
            .zIndex(2)
        }
        .frame(width: size + 48, height: size + armHeight * 0.38, alignment: .top)
        .onChange(of: trackId) { _ in
            isTransitioningTrack = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 320_000_000)
                isTransitioningTrack = false
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 0.6 else { return }
                isDragging = true
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let translation = value.translation.width
                let predicted = value.predictedEndTranslation.width
                if translation < -45 || predicted < -100 {
                    switchTrack(offset: -size * 1.25, callback: onNextTrack)
                } else if translation > 45 || predicted > 100 {
                    switchTrack(offset: size * 1.25, callback: onPreviousTrack)
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                        dragOffset = 0
                        isDragging = false
                    }
                }
            }
    }

    private func switchTrack(offset: CGFloat, callback: (() -> Void)?) {
        let slideOutDuration = 0.20
        let slideInDuration = 0.22

        // Finish moving the old track off-screen before replacing its song and
        // cover. This keeps the expensive artwork/lyrics update out of the
        // visible part of the swipe and avoids a mid-gesture hitch.
        withAnimation(.easeOut(duration: slideOutDuration)) {
            dragOffset = offset
            isDragging = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + slideOutDuration) {
            callback?()
            dragOffset = -offset
            withAnimation(.easeOut(duration: slideInDuration)) {
                dragOffset = 0
            }
        }
    }
}

/// A hosted static disc whose rotation is a compositing-only layer animation.
/// This follows the same principle as Moumusic's smooth playing indicator:
/// animation frames do not invalidate the surrounding SwiftUI layout tree.
private struct SmoothRecordDiscView: UIViewRepresentable {
    let coverURL: URL?
    let isPlaying: Bool
    let size: CGFloat
    let playsCoverVideoAudio: Bool

    func makeUIView(context: Context) -> SmoothRecordDiscUIView {
        SmoothRecordDiscUIView()
    }

    func updateUIView(_ uiView: SmoothRecordDiscUIView, context: Context) {
        uiView.update(
            coverURL: coverURL,
            isPlaying: isPlaying,
            size: size,
            playsCoverVideoAudio: playsCoverVideoAudio
        )
    }

    static func dismantleUIView(_ uiView: SmoothRecordDiscUIView, coordinator: ()) {
        uiView.stopRotation()
    }
}

private final class SmoothRecordDiscUIView: UIView {
    private var hostController: UIHostingController<AnyView>?
    private var rotationIsRunning = false
    private var currentAngle: CGFloat = 0
    private var renderedCoverURL: URL?
    private var renderedSize: CGFloat = -1
    private var renderedPlaysCoverVideoAudio = false
    private var renderedIsPlaying = false
    private let rotationKey = "co.recordDiscRotation"

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(coverURL: URL?, isPlaying: Bool, size: CGFloat, playsCoverVideoAudio: Bool) {
        let visualChanged = hostController == nil
            || renderedCoverURL != coverURL
            || renderedSize != size
            || renderedPlaysCoverVideoAudio != playsCoverVideoAudio
        if visualChanged {
            let root = AnyView(
                RecordModeDiscView(
                    coverURL: coverURL,
                    size: size,
                    playsCoverVideoAudio: playsCoverVideoAudio
                )
            )
            if let hostController {
                hostController.rootView = root
            } else {
                let controller = UIHostingController(rootView: root)
                controller.view.backgroundColor = .clear
                controller.view.isOpaque = false
                controller.view.isUserInteractionEnabled = false
                hostController = controller
                addSubview(controller.view)
            }
            renderedCoverURL = coverURL
            renderedSize = size
            renderedPlaysCoverVideoAudio = playsCoverVideoAudio
        }
        if visualChanged {
            setNeedsLayout()
        }
        guard renderedIsPlaying != isPlaying else { return }
        renderedIsPlaying = isPlaying
        if isPlaying {
            startRotation()
        } else {
            stopRotation()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hostController?.view.frame = bounds
    }

    func stopRotation() {
        guard rotationIsRunning else { return }
        syncAngleFromPresentation()
        layer.removeAnimation(forKey: rotationKey)
        layer.setValue(currentAngle, forKeyPath: "transform.rotation.z")
        rotationIsRunning = false
    }

    private func startRotation() {
        guard !rotationIsRunning else { return }
        syncAngleFromPresentation()
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = currentAngle
        animation.toValue = currentAngle + 2 * .pi
        animation.duration = 360.0 / 24.0
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: rotationKey)
        rotationIsRunning = true
    }

    private func syncAngleFromPresentation() {
        guard let presentation = layer.presentation(),
              let value = presentation.value(forKeyPath: "transform.rotation.z") as? NSNumber else { return }
        currentAngle = CGFloat(value.doubleValue)
    }
}

private struct RecordModeDiscView: View {
    let coverURL: URL?
    let size: CGFloat
    var playsCoverVideoAudio = false

    var body: some View {
        let labelSize = size * 0.64
        let spindleSize = max(7, size * 0.032)
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.42))
                .frame(width: size + 8, height: size + 8)
                .blur(radius: max(8, size * 0.045))
                .offset(y: size * 0.04)
            Circle()
                .fill(RadialGradient(
                    colors: [Color(white: 0.16), Color(white: 0.08), Color(white: 0.025)],
                    center: .center,
                    startRadius: size * 0.08,
                    endRadius: size * 0.52
                ))
                .frame(width: size, height: size)
                .overlay {
                    Circle().stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.28), .white.opacity(0.04), .black.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
                }
            Circle()
                .fill(AngularGradient(
                    gradient: Gradient(colors: [
                        .white.opacity(0.04), .white.opacity(0.16), .black.opacity(0.16),
                        .white.opacity(0.11), .black.opacity(0.12), .white.opacity(0.05)
                    ]),
                    center: .center
                ))
                .frame(width: size - 4, height: size - 4)
                .opacity(0.9)
            ForEach(0..<18, id: \.self) { index in
                let factor = 0.68 + (Double(index) / 17) * 0.29
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(index % 4 == 0 ? 0.14 : 0.06),
                                .black.opacity(0.42),
                                .white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: index % 4 == 0 ? 0.8 : 0.45
                    )
                    .frame(width: size * factor, height: size * factor)
            }
            Circle()
                .fill(AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.00),
                        .init(color: .white.opacity(0.22), location: 0.15),
                        .init(color: .clear, location: 0.28),
                        .init(color: .clear, location: 0.52),
                        .init(color: .white.opacity(0.14), location: 0.66),
                        .init(color: .clear, location: 0.82),
                        .init(color: .clear, location: 1.00)
                    ]),
                    center: .center,
                    angle: .degrees(35)
                ))
                .frame(width: size - 2, height: size - 2)
                .blendMode(.screen)
                .allowsHitTesting(false)
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(white: 0.18), Color(white: 0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: labelSize + 6, height: labelSize + 6)
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                Group {
                    if coverURL != nil {
                        CoverImage(
                            url: coverURL,
                            size: labelSize,
                            cornerRadius: labelSize / 2,
                            emptyHint: nil,
                            playsCoverVideoAudio: playsCoverVideoAudio
                        )
                    } else {
                        ZStack {
                            LinearGradient(
                                colors: [Color(white: 0.22), Color(white: 0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Image(systemName: "music.note")
                                .font(.system(size: labelSize * 0.35, weight: .light))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                }
                .frame(width: labelSize, height: labelSize)
                .clipShape(Circle())
                .overlay { Circle().strokeBorder(.black.opacity(0.45), lineWidth: 1.5) }
                Circle()
                    .stroke(.white.opacity(0.26), lineWidth: 0.8)
                    .frame(width: labelSize * 0.86, height: labelSize * 0.86)
                Circle()
                    .fill(LinearGradient(
                        colors: [.white.opacity(0.95), .white.opacity(0.45), .black.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: spindleSize * 2.4, height: spindleSize * 2.4)
                Circle()
                    .fill(Color(white: 0.04))
                    .frame(width: spindleSize, height: spindleSize)
            }
        }
        .frame(width: size + 8, height: size + 8)
    }
}

private struct RecordModeTonearmView: View {
    let isPlaying: Bool
    let height: CGFloat
    let reduceMotion: Bool

    var body: some View {
        let width = height * 0.58
        let pivotSize = width * 0.46
        ZStack(alignment: .top) {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(white: 0.9), Color(white: 0.28), Color(white: 0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: pivotSize, height: pivotSize)
                .overlay {
                    Circle()
                        .fill(Color(white: 0.12))
                        .padding(pivotSize * 0.19)
                }
                .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
                .zIndex(2)
            RecordModeTonearmPath()
                .stroke(Color.black.opacity(0.36), lineWidth: max(5, width * 0.09))
                .blur(radius: 2)
                .offset(x: 2, y: 3)
            RecordModeTonearmPath()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.96), .white.opacity(0.52), .white.opacity(0.90), .white.opacity(0.38)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: max(3.5, width * 0.058),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .rotationEffect(
                    .degrees(isPlaying ? 0 : -32),
                    anchor: UnitPoint(x: 0.5, y: pivotSize * 0.5 / height)
                )
                .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.74), value: isPlaying)
                .zIndex(1)
        }
        .frame(width: width, height: height, alignment: .top)
    }
}

private struct RecordModeTonearmPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.width * 0.5, y: 0)
        let first = CGPoint(x: rect.width * 0.58, y: rect.height * 0.28)
        let second = CGPoint(x: rect.width * 0.42, y: rect.height * 0.55)
        let end = CGPoint(x: rect.width * 0.31, y: rect.height * 0.74)
        path.move(to: start)
        path.addCurve(
            to: first,
            control1: CGPoint(x: rect.width * 0.52, y: rect.height * 0.1),
            control2: CGPoint(x: rect.width * 0.58, y: rect.height * 0.2)
        )
        path.addCurve(
            to: second,
            control1: CGPoint(x: rect.width * 0.58, y: rect.height * 0.38),
            control2: CGPoint(x: rect.width * 0.45, y: rect.height * 0.48)
        )
        path.addCurve(
            to: end,
            control1: CGPoint(x: rect.width * 0.38, y: rect.height * 0.62),
            control2: CGPoint(x: rect.width * 0.33, y: rect.height * 0.70)
        )
        return path
    }
}

