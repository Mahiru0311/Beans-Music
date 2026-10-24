import SwiftUI

// Beans owns the audio and queue. This shell replaces only the visible lyric surface.
// 2026-10-25 重构：背景不再是纯黑/纯白，改成封面毛玻璃取色（与播放页同款 CoverBlurBackground，
// 切歌时后台一次性模糊、无实时模糊开销）；效果只留 8 个全部有渲染器的，不再有待移植空壳。
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

    /// 播放页同款取法：自定义封面优先，否则用歌曲封面；无封面时毛玻璃层为空，只剩底色。
    private var displayCoverURL: URL? { customCovers.url(for: song) ?? song?.coverURL }

    var body: some View {
        ZStack {
            (daylight ? Color.white : Color.black).ignoresSafeArea()
            CoverBlurBackground(url: displayCoverURL, scheme: daylight ? .light : .dark)
                .ignoresSafeArea()
            // 统一罩一层，保证歌词在任何封面上都可读；日间浅罩、夜间深罩。
            Color.black.opacity(daylight ? 0.10 : 0.35).ignoresSafeArea()
                .allowsHitTesting(false)
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
                FoliaStageTransport(player: player, clock: clock)
                    .padding(.horizontal, 24).padding(.bottom, 12)
            }
        }
        .foregroundStyle(daylight ? Color.black : Color.white)
        .onAppear(perform: refreshDocument)
        .onChange(of: lyrics) { _, _ in refreshDocument() }
        .onChange(of: song?.identityKey) { _, _ in refreshDocument() }
        .onChange(of: clock.duration) { _, _ in refreshDocument() }
    }

    @ViewBuilder private var lyricSurface: some View {
        switch currentMode {
        case .classic:
            FoliaClassicRenderer(document: document, clock: clock)
        case .still:
            FoliaStillRenderer(document: document, clock: clock)
        case .sonnet, .tempera, .cadenza, .partita, .fume, .diorama:
            FoliaLineEffectView(document: document, clock: clock, mode: currentMode)
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
            })
            HStack(spacing: 36) {
                Button { player.previous() } label: { Image(systemName: "backward.fill").frame(width: 44, height: 44) }
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").frame(width: 44, height: 44)
                }
                Button { player.next() } label: { Image(systemName: "forward.fill").frame(width: 44, height: 44) }
            }.font(.title3)
        }
        .padding(12).background { CoGlass(shape: RoundedRectangle(cornerRadius: 24)) }
    }
}

// Folia 新效果（2026-10-25 重构）：商籁、凝彩、心象、云阶、浮名、镜台共用同一套行级舞台——
// 同一份歌词文档、同一个当前行计算（句间停顿保持上一句，与静止一致）、同一组字号/颜色设置；
// 每个效果只是给上一句/当前句/下一句加不同的对齐、位移、缩放、色块或倒影，
// 没有常驻动画，行切换时才动一次，省电。翻译不显示：歌词数据里 translation 本就是空的。
struct FoliaLineEffectView: View {
    let document: FoliaLyricDocument
    @ObservedObject var clock: PlaybackClock
    let mode: FoliaVisualizerMode

    @State private var effectiveIndex = 0
    @AppStorage(FoliaPreferences.fontScaleKey) private var fontScale = 1.0
    @AppStorage(FoliaPreferences.primaryColorKey) private var primaryHex = "#FFFFFF"
    @AppStorage(FoliaPreferences.accentColorKey) private var accentHex = "#A5B4FC"
    @AppStorage(FoliaPreferences.showTextKey) private var showText = true
    @AppStorage(LyricTiming.userOffsetKey) private var userOffset = 0.0

    private var activeIndex: Int {
        FoliaTimeline.activeIndex(lines: document.lines, time: LyricTiming.effectiveProgress(clock.progress, userOffset: userOffset))
    }

    var body: some View {
        ZStack {
            if showText {
                VStack(spacing: 32) {
                    row(offset: -1)
                    row(offset: 0)
                    row(offset: 1)
                }
                .frame(maxWidth: 896).padding(.horizontal, 48).padding(.bottom, 64)
                .allowsHitTesting(false)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: effectiveIndex)
            }
        }
        .onAppear { effectiveIndex = max(0, activeIndex) }
        .onChange(of: activeIndex) { _, index in updateIndex(index) }
        .onChange(of: document) { _, _ in updateIndex(activeIndex) }
    }

    @ViewBuilder
    private func row(offset: Int) -> some View {
        let index = effectiveIndex + offset
        if document.lines.indices.contains(index) {
            let line = document.lines[index]
            if line.fullText.isEmpty {
                Color.clear.frame(height: 80)
            } else {
                effectRow(line: line, offset: offset, current: offset == 0)
                    .id(line.id)
            }
        } else {
            Color.clear.frame(height: 80)
        }
    }

    @ViewBuilder
    private func effectRow(line: FoliaLine, offset: Int, current: Bool) -> some View {
        switch mode {
        case .sonnet:
            // 商籁：像诗页一样左对齐衬线排版，换行时整句从下方滑上来。
            baseText(line: line, current: current)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .tempera:
            // 凝彩：当前句落在实色块上（取用户设的逐词高亮色），字色按色块明暗反白或反黑。
            if current {
                baseText(line: line, current: true)
                    .foregroundStyle(accentIsLight ? Color.black : Color.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color(hex: accentHex) ?? .accentColor,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            } else {
                baseText(line: line, current: false).opacity(0.3)
                    .transition(.opacity)
            }
        case .cadenza:
            // 心象：当前句放大加高亮色辉光、微微倾斜，像一句自由华彩。
            baseText(line: line, current: current)
                .scaleEffect(current ? 1.12 : 0.95)
                .rotationEffect(.degrees(current ? -2 : 0))
                .shadow(color: current ? (Color(hex: accentHex) ?? .accentColor).opacity(0.8) : .clear,
                        radius: current ? 14 : 0, y: 4)
                .opacity(current ? 1 : 0.3)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        case .partita:
            // 云阶：三句像台阶一样向右拾级而上。
            baseText(line: line, current: current)
                .offset(x: CGFloat(offset) * 36)
                .opacity(current ? 1 : 0.3)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        case .fume:
            // 浮名：上一句向上飘散变淡，当前句从下方浮现，像烟。
            baseText(line: line, current: current)
                .offset(y: offset == -1 ? -24 : (offset == 1 ? 12 : 0))
                .opacity(current ? 1 : (offset == -1 ? 0.12 : 0.45))
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .diorama:
            // 镜台：当前句下方带一面渐隐的倒影，像镜面舞台。
            if current {
                VStack(spacing: 4) {
                    baseText(line: line, current: true)
                    baseText(line: line, current: true)
                        .scaleEffect(x: 1, y: -1).opacity(0.22)
                        .mask(LinearGradient(colors: [.black, .clear],
                                             startPoint: .top, endPoint: .bottom))
                }
                .transition(.opacity)
            } else {
                baseText(line: line, current: false).opacity(0.3)
                    .transition(.opacity)
            }
        default:
            baseText(line: line, current: current).opacity(current ? 1 : 0.3)
        }
    }

    private func baseText(line: FoliaLine, current: Bool) -> some View {
        Text(line.fullText)
            .font(.system(size: (current ? 40 : 30) * fontScale,
                          weight: current ? .bold : .semibold,
                          design: mode == .sonnet ? .serif : .default))
            .tracking(0.8)
            .foregroundStyle(Color(hex: primaryHex) ?? .white)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 2)
            .multilineTextAlignment(mode == .sonnet ? .leading : .center)
            .frame(maxWidth: .infinity, alignment: mode == .sonnet ? .leading : .center)
    }

    /// 高亮色偏亮时当前句用黑字，否则用白字，保证色块上的字可读。
    private var accentIsLight: Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(Color(hex: accentHex) ?? .white)
            .getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return false }
        return 0.299 * red + 0.587 * green + 0.114 * blue > 0.6
    }

    private func updateIndex(_ active: Int) {
        effectiveIndex = FoliaTimeline.stillIndex(previous: effectiveIndex, activeIndex: active, lineCount: document.lines.count)
    }
}
