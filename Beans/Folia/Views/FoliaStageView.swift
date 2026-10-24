import SwiftUI
import UIKit

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
    @AppStorage(FoliaPreferences.fxKey) private var fxRaw = FoliaStageFX.none.rawValue
    @State private var document = FoliaLyricDocument(trackIdentity: "empty", lines: [])
    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var orientationObserver: NSObjectProtocol?

    /// 沉浸式：点一下出现，3 秒不动自动藏起（只藏底部控制框，顶部栏一直在，退出路不断）。
    private func pokeControls() {
        showControls = true
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled { showControls = false }
        }
    }

    /// 横屏锁：切进 Folia 自动转横屏，且在 Folia 里只能横屏。
    /// 公开接口只能“允许”横屏、不能强制转过去，所以这里用了 UIDevice 的转屏接口；
    /// 侧载包不受 App Store 审核影响。退出 Folia 时转回竖屏。
    private func lockLandscape() {
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()
        startOrientationWatch()
    }

    /// 在 Folia 里只要转回竖屏，就再弹回横屏（真正“只能横屏”）。
    private func startOrientationWatch() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { _ in
            if UIDevice.current.orientation.isPortrait {
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
                UIViewController.attemptRotationToDeviceOrientation()
            }
        }
    }

    private func stopOrientationWatch() {
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
            orientationObserver = nil
        }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    private func unlockToPortrait() {
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()
    }

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
            // 点空白处唤出控制框（歌词与特效层不吃触摸，点得透）。
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { pokeControls() }
            // 舞台特效层：封面之上、歌词之下。
            FoliaStageFXView(fx: FoliaStageFX(rawValue: fxRaw) ?? .none)
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
        .foregroundStyle(daylight ? Color.black : Color.white)
        .onAppear { refreshDocument(); pokeControls(); lockLandscape() }
        .onDisappear { hideControlsTask?.cancel(); stopOrientationWatch(); unlockToPortrait() }
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
        case .sonnet, .tempera, .cadenza, .fume, .diorama:
            FoliaLineEffectView(document: document, clock: clock, mode: currentMode)
        case .partita:
            FoliaPartitaView(document: document, clock: clock)
        case .lumiere:
            FoliaLumiereView(document: document, clock: clock)
        case .hanabi:
            FoliaHanabiView(document: document, clock: clock)
        case .tilt:
            FoliaTiltView(document: document, clock: clock)
        case .claddagh:
            FoliaCladdaghView(document: document, clock: clock)
        case .monet:
            FoliaMonetView(document: document, clock: clock, coverURL: displayCoverURL)
        case .pendolo:
            FoliaPendoloView(document: document, clock: clock)
        case .cappella:
            FoliaCappellaView(document: document, clock: clock)
        case .rise:
            FoliaRiseView(document: document, clock: clock)
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

    private var effectiveTime: Double {
        LyricTiming.effectiveProgress(clock.progress, userOffset: userOffset)
    }

    var body: some View {
        ZStack {
            if showText {
                Group {
                    if mode == .fume {
                        fumeStage
                    } else {
                        VStack(spacing: 32) {
                            row(offset: -1)
                            row(offset: 0)
                            row(offset: 1)
                        }
                    }
                }
                .frame(maxWidth: 896).padding(.horizontal, 48).padding(.bottom, 64)
                .allowsHitTesting(false)
                .animation(.spring(response: 0.5, dampingFraction: 0.68), value: effectiveIndex)
            }
        }
        .onAppear { effectiveIndex = max(0, activeIndex) }
        .onChange(of: activeIndex) { _, index in updateIndex(index) }
        .onChange(of: document) { _, _ in updateIndex(activeIndex) }
    }

    // 浮名：主句巨大居中、前后句以虚影叠在身后（不在三行 VStack 里排，单独成层）。
    @ViewBuilder
    private var fumeStage: some View {
        ZStack {
            if document.lines.indices.contains(effectiveIndex - 1) {
                let line = document.lines[effectiveIndex - 1]
                if !line.fullText.isEmpty {
                    Text(line.fullText)
                        .font(.system(size: 28 * fontScale, weight: .semibold))
                        .foregroundStyle(Color(hex: primaryHex) ?? .white)
                        .multilineTextAlignment(.center)
                        .opacity(0.12).scaleEffect(0.75).offset(y: -36)
                        .id(line.id).transition(.opacity)
                }
            }
            if document.lines.indices.contains(effectiveIndex + 1) {
                let line = document.lines[effectiveIndex + 1]
                if !line.fullText.isEmpty {
                    Text(line.fullText)
                        .font(.system(size: 28 * fontScale, weight: .semibold))
                        .foregroundStyle(Color(hex: primaryHex) ?? .white)
                        .multilineTextAlignment(.center)
                        .opacity(0.12).scaleEffect(0.75).offset(y: 36)
                        .id(line.id).transition(.opacity)
                }
            }
            if document.lines.indices.contains(effectiveIndex) {
                let line = document.lines[effectiveIndex]
                if line.fullText.isEmpty {
                    Color.clear.frame(height: 80)
                } else {
                    Text(line.fullText)
                        .font(.system(size: min(84, 44 * fontScale * 1.6), weight: .bold))
                        .foregroundStyle(Color(hex: primaryHex) ?? .white)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 2)
                        .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .id(line.id)
                        .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.92)))
                }
            } else {
                Color.clear.frame(height: 80)
            }
        }
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
        // 设计取自 Folia 开源项目（github.com/17iii/folia-0721）各模式的条目注释；
        // 浮名不在这里——它由 body 的 fumeStage 单独成层（巨字 + 身后虚影）。
        switch mode {
        case .sonnet:
            // 商籁：海报——当前句装在带角标的细边框里，换行时轻推一下；前后句在框外淡淡的。
            if current {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).stroke((Color(hex: primaryHex) ?? .white).opacity(0.8), lineWidth: 1)
                    baseText(line: line, current: true).padding(.horizontal, 24).padding(.vertical, 18)
                }
                .overlay(alignment: .topLeading) { CornerMark(color: Color(hex: accentHex) ?? .accentColor).padding(4) }
                .overlay(alignment: .topTrailing) { CornerMark(color: Color(hex: accentHex) ?? .accentColor).scaleEffect(x: -1).padding(4) }
                .overlay(alignment: .bottomLeading) { CornerMark(color: Color(hex: accentHex) ?? .accentColor).scaleEffect(y: -1).padding(4) }
                .overlay(alignment: .bottomTrailing) { CornerMark(color: Color(hex: accentHex) ?? .accentColor).scaleEffect(x: -1, y: -1).padding(4) }
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            } else {
                baseText(line: line, current: false).opacity(0.22).transition(.opacity)
            }
        case .tempera:
            // 凝彩：上下色块分割——当前句落在整幅实色带上，上下各压一条分割线，字色按色带明暗反白或反黑。
            if current {
                baseText(line: line, current: true)
                    .foregroundStyle(accentIsLight ? Color.black : Color.white)
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .background(Color(hex: accentHex) ?? .accentColor)
                    .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.6)).frame(height: 1) }
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.6)).frame(height: 1) }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else {
                baseText(line: line, current: false).opacity(0.22).transition(.opacity)
            }
        case .cadenza:
            // 心象：字符散落成云，焦点字（词）被光圈套住；前后句照常淡淡的。
            if current {
                FoliaCadenzaCloudView(line: line, time: effectiveTime,
                                      fontSize: 44 * fontScale,
                                      primary: Color(hex: primaryHex) ?? .white,
                                      accent: Color(hex: accentHex) ?? .accentColor)
                    .transition(.scale(scale: 0.75).combined(with: .opacity))
            } else {
                baseText(line: line, current: false).opacity(0.22).transition(.opacity)
            }
        case .diorama:
            // 镜台：不同景深上的方块——远景小而倾斜、近景大而正对。
            baseText(line: line, current: current)
                .scaleEffect(current ? 1.12 : (offset == -1 ? 0.72 : 0.85))
                .opacity(current ? 1 : (offset == -1 ? 0.22 : 0.3))
                .offset(y: offset == -1 ? -44 : (offset == 1 ? 44 : 0))
                .rotation3DEffect(.degrees(current ? 0 : (offset == -1 ? 25 : -18)),
                                  axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                .transition(.opacity)
        default:
            baseText(line: line, current: current).opacity(current ? 1 : 0.22)
        }
    }

    private func baseText(line: FoliaLine, current: Bool) -> some View {
        Text(line.fullText)
            .font(.system(size: (current ? 44 : 28) * fontScale,
                          weight: current ? .bold : .semibold,
                          design: mode == .sonnet ? .serif : .default))
            .tracking(0.8)
            .foregroundStyle(Color(hex: primaryHex) ?? .white)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
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

/// 海报角标：一个 L 形，四个角用镜像拼成一圈。
private struct CornerMark: View {
    let color: Color

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 14, y: 2))
            path.addLine(to: CGPoint(x: 2, y: 2))
            path.addLine(to: CGPoint(x: 2, y: 14))
        }
        .stroke(color, lineWidth: 2)
        .frame(width: 16, height: 16)
    }
}

/// 流式排布：子视图按行排，超宽自动换行（心象的字符云与花火的词块共用）。
struct FoliaFlowLayout: Layout {
    var spacing: CGFloat = 2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxRowWidth: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                maxRowWidth = max(maxRowWidth, x - spacing)
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing; rowHeight = max(rowHeight, size.height)
        }
        maxRowWidth = max(maxRowWidth, x > 0 ? x - spacing : 0)
        // 贴着内容宽（不超过提议宽），不撑满：群唱气泡与花火词块靠它贴着文本，不撑成满宽条。
        return CGSize(width: min(maxRowWidth, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; rowHeight = max(rowHeight, size.height)
        }
    }
}

/// 心象：字符散落成云，焦点字（词）被光圈套住。
/// 展示单元有词级时间用词，否则按字拆；抖动由序号定死，同一句永远同一个样子，不闪。
private struct FoliaCadenzaCloudView: View {
    let line: FoliaLine
    let time: Double
    let fontSize: CGFloat
    let primary: Color
    let accent: Color

    private var units: [(text: String, isFocus: Bool)] {
        if !line.words.isEmpty {
            var marked = line.words.map { word in
                (word.text, time >= word.startTime && time < word.endTime)
            }
            if !marked.contains(where: { $0.1 }) {
                let past = line.words.indices.filter { line.words[$0].startTime <= time }
                let focus = past.last ?? line.words.indices.first ?? 0
                if marked.indices.contains(focus) { marked[focus].1 = true }
            }
            return marked
        }
        let chars = Array(line.fullText)
        guard !chars.isEmpty else { return [] }
        let span = max(0.001, line.endTime - line.startTime)
        let progress = min(1, max(0, (time - line.startTime) / span))
        let focus = min(chars.count - 1, Int(progress * Double(chars.count)))
        return chars.enumerated().map { (String($0.element), $0.offset == focus) }
    }

    private var focusKey: Int { units.firstIndex(where: { $0.isFocus }) ?? -1 }

    private func jitter(_ index: Int, _ salt: Int) -> Double {
        let value = sin(Double(index * 127 + salt * 311) * 0.7) * 43758.5453
        return value - floor(value)
    }

    var body: some View {
        FoliaFlowLayout(spacing: 2) {
            ForEach(units.indices, id: \.self) { index in
                let unit = units[index]
                ZStack {
                    if unit.isFocus {
                        if unit.text.count == 1 {
                            Circle().stroke(accent, lineWidth: 2)
                                .frame(width: fontSize * 1.5, height: fontSize * 1.5)
                                .shadow(color: accent.opacity(0.8), radius: 12)
                        } else {
                            RoundedRectangle(cornerRadius: 8).stroke(accent, lineWidth: 2)
                                .padding(-6)
                                .shadow(color: accent.opacity(0.8), radius: 12)
                        }
                    }
                    Text(unit.text)
                        .font(.system(size: fontSize, weight: unit.isFocus ? .bold : .regular))
                        .foregroundStyle(unit.isFocus ? accent : primary.opacity(0.85))
                }
                .offset(x: (jitter(index, 1) - 0.5) * 48, y: (jitter(index, 2) - 0.5) * 32)
                .rotationEffect(.degrees((jitter(index, 3) - 0.5) * 24))
                .scaleEffect(0.9 + jitter(index, 4) * 0.25)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: focusKey)
    }
}

/// 涌现（QQ 音乐式）：只显示一行，下一行从当前行的底部升出来，旧行向上退场。
private struct FoliaRiseView: View {
    let document: FoliaLyricDocument
    @ObservedObject var clock: PlaybackClock

    @State private var effectiveIndex = 0
    @AppStorage(FoliaPreferences.fontScaleKey) private var fontScale = 1.0
    @AppStorage(FoliaPreferences.primaryColorKey) private var primaryHex = "#FFFFFF"
    @AppStorage(FoliaPreferences.showTextKey) private var showText = true
    @AppStorage(LyricTiming.userOffsetKey) private var userOffset = 0.0

    private var activeIndex: Int {
        FoliaTimeline.activeIndex(lines: document.lines, time: LyricTiming.effectiveProgress(clock.progress, userOffset: userOffset))
    }

    var body: some View {
        ZStack {
            if showText, document.lines.indices.contains(effectiveIndex) {
                let line = document.lines[effectiveIndex]
                if !line.fullText.isEmpty {
                    Text(line.fullText)
                        .font(.system(size: 44 * fontScale, weight: .bold))
                        .foregroundStyle(Color(hex: primaryHex) ?? .white)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 896).padding(.horizontal, 48).padding(.bottom, 64)
                        .allowsHitTesting(false)
                        .id(line.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: effectiveIndex)
                }
            }
        }
        .onAppear { effectiveIndex = max(0, activeIndex) }
        .onChange(of: activeIndex) { _, index in
            effectiveIndex = FoliaTimeline.stillIndex(previous: effectiveIndex, activeIndex: index, lineCount: document.lines.count)
        }
        .onChange(of: document) { _, _ in
            effectiveIndex = FoliaTimeline.stillIndex(previous: effectiveIndex, activeIndex: activeIndex, lineCount: document.lines.count)
        }
    }
}
