import SwiftUI

// Beans owns the audio and queue. This shell replaces only the visible lyric surface.
// 2026-10-25 重构：背景不再是纯黑/纯白，改成封面毛玻璃取色（与播放页同款 CoverBlurBackground，
// 切歌时后台一次性模糊、无实时模糊开销）；效果只留 5 个（绘光、流光、云阶、浮名、静止），不再臃肿。
struct FoliaStageView: View {
    let song: Song?
    let lyrics: [LyricLine]
    let onBack: () -> Void
    let onSettings: () -> Void
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    @ObservedObject private var customCovers = CustomSongCoverStore.shared
    @AppStorage(FoliaPreferences.daylightKey) private var daylight = false
    @AppStorage(FoliaPreferences.modeKey) private var modeRaw = FoliaVisualizerMode.still.rawValue
    @State private var document = FoliaLyricDocument(trackIdentity: "empty", lines: [])
    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>?

    /// 沉浸式：点一下出现，3 秒不动自动藏起（只藏底部控制框，顶部栏一直在，退出路不断）。
    private func pokeControls() {
        showControls = true
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled { showControls = false }
        }
    }

    /// 播放页同款取法：自定义封面优先，否则用歌曲封面；无封面时毛玻璃层为空，只剩底色。
    private var displayCoverURL: URL? { customCovers.url(for: song) ?? song?.coverURL }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                landscapeBody(size: geo.size)
            } else {
                portraitBody
            }
        }
        .foregroundStyle(daylight ? Color.black : Color.white)
        .onAppear { refreshDocument(); pokeControls() }
        .onDisappear { hideControlsTask?.cancel() }
        .onChange(of: lyrics) { _, _ in refreshDocument() }
        .onChange(of: song?.identityKey) { _, _ in refreshDocument() }
        .onChange(of: clock.duration) { _, _ in refreshDocument() }
    }

    // 竖屏：原来的舞台（封面毛玻璃背景 + 歌词效果 + 顶部栏 + 底部控制框 3 秒自动藏）。
    private var portraitBody: some View {
        ZStack {
            (daylight ? Color.white : Color.black).ignoresSafeArea()
            CoverBlurBackground(url: displayCoverURL, scheme: daylight ? .light : .dark)
                .ignoresSafeArea()
            // 统一罩一层，保证歌词在任何封面上都可读；日间浅罩、夜间深罩。
            Color.black.opacity(daylight ? 0.10 : 0.35).ignoresSafeArea()
                .allowsHitTesting(false)
            // 点空白处唤出控制框（歌词层不吃触摸，点得透）。
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { pokeControls() }
            lyricSurface
            VStack {
                HStack {
                    Button(action: onBack) { Image(systemName: "chevron.down").frame(width: 44, height: 44) }
                    Spacer()
                    Text(song?.name ?? "Folia").font(.subheadline).lineLimit(1)
                    Spacer()
                    Button(action: onSettings) { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }
                }
                .padding(.horizontal, 16)
                Spacer()
                if showControls {
                    FoliaStageTransport(player: player, clock: clock, onInteract: pokeControls)
                        .padding(.horizontal, 24).padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.3), value: showControls)
        }
    }

    // 横屏：封面在左、其余在右。顶部只剩两颗键，歌名歌手移到右栏顶部，
    // 右栏从上到下是歌名歌手、歌词效果、控制框（同样 3 秒自动藏）。
    private func landscapeBody(size: CGSize) -> some View {
        let artworkSize = min(size.height - 96, size.width * 0.42)
        return ZStack {
            (daylight ? Color.white : Color.black).ignoresSafeArea()
            CoverBlurBackground(url: displayCoverURL, scheme: daylight ? .light : .dark)
                .ignoresSafeArea()
            Color.black.opacity(daylight ? 0.10 : 0.35).ignoresSafeArea()
                .allowsHitTesting(false)
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { pokeControls() }
            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) { Image(systemName: "chevron.down").frame(width: 44, height: 44) }
                    Spacer()
                    Button(action: onSettings) { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }
                }
                .padding(.horizontal, 16)
                HStack(spacing: 24) {
                    CoverImage(url: displayCoverURL, size: artworkSize, cornerRadius: 16)
                        .frame(width: artworkSize, height: artworkSize)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(song?.name ?? "Folia")
                            .font(.title3.bold()).lineLimit(1)
                        Text(song.map { $0.artists } ?? "")
                            .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        lyricSurface
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        if showControls {
                            FoliaStageTransport(player: player, clock: clock, onInteract: pokeControls)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .animation(.easeOut(duration: 0.3), value: showControls)
        }
    }

    @ViewBuilder private var lyricSurface: some View {
        switch currentMode {
        case .classic:
            FoliaClassicRenderer(document: document, clock: clock)
        case .still:
            FoliaStillRenderer(document: document, clock: clock)
        case .lumiere:
            FoliaLumiereView(document: document, clock: clock)
        case .partita:
            FoliaPartitaView(document: document, clock: clock)
        case .fume:
            FoliaFumeView(document: document, clock: clock)
        }
    }

    private var currentMode: FoliaVisualizerMode {
        FoliaPreferences.availableMode(rawValue: modeRaw)
    }

    private func refreshDocument() {
        document = FoliaCoLyricBridge.document(trackIdentity: song?.identityKey ?? "empty", lyrics: lyrics,
                                                 duration: clock.duration > 0 ? clock.duration : song?.duration ?? 0)
    }
}

private struct FoliaStageTransport: View {
    @ObservedObject var player: PlayerManager
    @ObservedObject var clock: PlaybackClock
    let onInteract: () -> Void
    @State private var dragging = false
    @State private var scrubTime = 0.0

    private var duration: Double { clock.duration.isFinite ? max(1, clock.duration) : 1 }
    private var progress: Double { clock.progress.isFinite ? min(duration, max(0, clock.progress)) : 0 }

    var body: some View {
        VStack(spacing: 8) {
            Slider(value: Binding(get: { dragging ? scrubTime : progress }, set: { scrubTime = $0 }),
                   in: 0...duration, onEditingChanged: { editing in
                if editing { scrubTime = progress }
                dragging = editing
                if !editing { player.seekPrecisely(to: scrubTime) }
                onInteract()
            })
            HStack(spacing: 36) {
                Button { player.previous(); onInteract() } label: { Image(systemName: "backward.fill").frame(width: 44, height: 44) }
                Button { player.togglePlayPause(); onInteract() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").frame(width: 44, height: 44)
                }
                Button { player.next(); onInteract() } label: { Image(systemName: "forward.fill").frame(width: 44, height: 44) }
            }.font(.title3)
        }
        .padding(12).background { CoGlass(shape: RoundedRectangle(cornerRadius: 24)) }
    }
}

