import SwiftUI
import UIKit

// Folia 新增模式（2026-10-25，folia-major 原版补齐）：绘光、花火、倾诉、回环、莫奈、时计、群唱，
// 外加云阶改分段式（原版是行内分 chunk，不是三行台阶）。
// 移植原则（深读报告第五节）：只搬歌词编排，不搬渲染器——跳过 Pixi/three、shot 预编译、MG 贴纸、
// 头像/表情资产、视频层、节拍时钟、鼓点分析、音频频谱、pretext 精确度量、逐帧直写；
// 节拍效果一律降级为行切换触发，光强/粒子量固定为 normal 档；全部共用行切换动一次、无常驻动画（省电）。
// 涌现（QQ 音乐式）不在原版里，仍在 FoliaStageView.swift 里单列。

// MARK: - 共用小工具

/// 确定性伪随机：同一序号永远得到同一组参数，画面不抖（原版同款 sin(seed)*10000 思路）。
private func foliaHash(_ index: Int, _ salt: Int) -> Double {
    let value = sin(Double(index * 127 + salt * 311) * 0.7) * 43758.5453
    return value - floor(value)
}

private func foliaContainsCJK(_ text: String) -> Bool {
    text.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
}

/// 扫字填充进度：按词/字时间插值（monet、pendolo 共用）。
/// 有词级时间用词，否则按字均分；返回 0–1。
private func foliaSweepProgress(line: FoliaLine, time: Double) -> Double {
    let units: [(start: Double, end: Double)]
    if line.words.isEmpty {
        let chars = Array(line.fullText)
        guard !chars.isEmpty else { return 0 }
        let span = max(0.001, line.endTime - line.startTime)
        let step = span / Double(chars.count)
        units = chars.enumerated().map { (line.startTime + Double($0.offset) * step,
                                          line.startTime + Double($0.offset + 1) * step) }
    } else {
        units = line.words.map { ($0.startTime, $0.endTime) }
    }
    if time <= units[0].start { return 0 }
    if time >= units[units.count - 1].end { return 1 }
    for (i, unit) in units.enumerated() where time < unit.end {
        let p = unit.end > unit.start ? (time - unit.start) / (unit.end - unit.start) : 1
        return (Double(i) + min(1, max(0, p))) / Double(units.count)
    }
    return 1
}

/// 扫字填充：一行字，底色淡、accent 色按进度从左向右扫过（monet、pendolo 共用）。
/// 宽度用 background + PreferenceKey 实测文本宽（不靠容器宽，短句也能扫准）。
private struct FoliaSweepText: View {
    let text: String
    let fontSize: CGFloat
    let weight: Font.Weight
    let base: Color
    let fill: Color
    let progress: Double
    @State private var textWidth: CGFloat = 0

    var body: some View {
        ZStack(alignment: .leading) {
            Text(text).font(.system(size: fontSize, weight: weight)).foregroundStyle(base)
                .background(GeometryReader { geo in
                    Color.clear.preference(key: FoliaTextWidthKey.self, value: geo.size.width)
                })
            Text(text).font(.system(size: fontSize, weight: weight)).foregroundStyle(fill)
                .mask(Rectangle().frame(width: textWidth * min(1, max(0, progress))))
        }
        .onPreferenceChange(FoliaTextWidthKey.self) { textWidth = $0 }
    }
}

private struct FoliaTextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// 行状态样板：各新模式共用同一套（当前行计算 + 间隙保持 + 行切换动一次）。
/// SwiftUI 没有视图继承，各模式仍各自写这几行，保持与 FoliaStageView.swift 里现有模式一致。
private func foliaActiveIndex(document: FoliaLyricDocument, clock: PlaybackClock, userOffset: Double) -> Int {
    FoliaTimeline.activeIndex(lines: document.lines,
                              time: LyricTiming.effectiveProgress(clock.progress, userOffset: userOffset))
}

// MARK: - 云阶（分段式重做）

// 云阶（原版）：把当前行切成 chunk 排进列，左右交替 stagger，背后一条引导斜线。
// 原版按字素数定列数、chunk 不均匀切、stagger 20–100；这里简化为按词/字数拆段
// （短行 1 段、中行 2 段、长行 3 段），段长种子化不均匀，stagger 20–100 交替，引导线 18° 下行。
// 只排当前行（前后行不进台阶）；跳过 CJK 语义分组、标点粘滞、预热缓存。
struct FoliaPartitaView: View {
    let document: FoliaLyricDocument
    @ObservedObject var clock: PlaybackClock

    @State private var effectiveIndex = 0
    @AppStorage(FoliaPreferences.fontScaleKey) private var fontScale = 1.0
    @AppStorage(FoliaPreferences.primaryColorKey) private var primaryHex = "#FFFFFF"
    @AppStorage(FoliaPreferences.accentColorKey) private var accentHex = "#A5B4FC"
    @AppStorage(FoliaPreferences.showTextKey) private var showText = true
    @AppStorage(LyricTiming.userOffsetKey) private var userOffset = 0.0

    private var activeIndex: Int { foliaActiveIndex(document: document, clock: clock, userOffset: userOffset) }

    private var currentLine: FoliaLine? {
        document.lines.indices.contains(effectiveIndex) ? document.lines[effectiveIndex] : nil
    }

    private var chunks: [String] {
        guard let line = currentLine, !line.fullText.isEmpty else { return [] }
        let units: [String] = line.words.isEmpty ? line.fullText.map(String.init) : line.words.map(\.text)
        guard !units.isEmpty else { return [] }
        let count = units.count <= 5 ? 1 : (units.count <= 12 ? 2 : 3)
        guard count > 1 else { return [line.fullText] }
        let separator = foliaContainsCJK(line.fullText) ? "" : " "
        var chunks: [String] = []
        var start = 0
        let avg = Double(units.count) / Double(count)
        for i in 0..<(count - 1) {
            let len = max(1, Int((avg * (0.7 + foliaHash(i, 9) * 0.6)).rounded()))
            let end = min(units.count - (count - 1 - i), start + len)
            chunks.append(units[start..<end].joined(separator: separator))
            start = end
        }
        chunks.append(units[start...].joined(separator: separator))
        return chunks
    }

    var body: some View {
        ZStack {
            if showText, let line = currentLine, !line.fullText.isEmpty {
                VStack(spacing: 16) {
                    ForEach(chunks.indices, id: \.self) { i in
                        Text(chunks[i])
                            .font(.system(size: 44 * fontScale, weight: .bold))
                            .foregroundStyle(Color(hex: primaryHex) ?? .white)
                            .shadow(color: .black.opacity(0.25), radius: 2, y: 2)
                            .multilineTextAlignment(.center)
                            .offset(x: (i % 2 == 0 ? -1 : 1) * (20 + foliaHash(i, 5) * 80))
                            .id("\(line.id)-\(i)")
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: 896).padding(.horizontal, 48).padding(.bottom, 64)
                .background {
                    Rectangle().fill((Color(hex: accentHex) ?? .accentColor).opacity(0.15))
                        .frame(width: 220, height: 1).rotationEffect(.degrees(18))
                }
                .allowsHitTesting(false)
                .animation(.spring(response: 0.5, dampingFraction: 0.68), value: effectiveIndex)
            }
        }
        .onAppear { effectiveIndex = max(0, activeIndex) }
        .onChange(of: activeIndex) { _, index in updateIndex(index) }
        .onChange(of: document) { _, _ in updateIndex(activeIndex) }
    }

    private func updateIndex(_ active: Int) {
        effectiveIndex = FoliaTimeline.stillIndex(previous: effectiveIndex, activeIndex: active, lineCount: document.lines.count)
    }
}

// MARK: - 绘光

// 绘光（原版）：自顶而下的光柱照亮一行字（舞台灯光导演）。
// 移植：顶部光柱（上窄下宽梯形 + 强调色渐变 + 模糊）+ 三行（前淡、当前亮带辉光、后淡）；
// 跳过 Pixi 光场 shader、星空/浮尘/线稿/散景七层、十字爆闪、主题图标；光强固定为 normal 档，不随音频起伏。
struct FoliaLumiereView: View {
    let document: FoliaLyricDocument
    @ObservedObject var clock: PlaybackClock

    @State private var effectiveIndex = 0
    @AppStorage(FoliaPreferences.fontScaleKey) private var fontScale = 1.0
    @AppStorage(FoliaPreferences.primaryColorKey) private var primaryHex = "#FFFFFF"
    @AppStorage(FoliaPreferences.accentColorKey) private var accentHex = "#A5B4FC"
    @AppStorage(FoliaPreferences.showTextKey) private var showText = true
    @AppStorage(LyricTiming.userOffsetKey) private var userOffset = 0.0

    private var activeIndex: Int { foliaActiveIndex(document: document, clock: clock, userOffset: userOffset) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if showText {
                    VStack {
                        Path { path in
                            let topW: CGFloat = 120, bottomW = min(geo.size.width * 0.7, 400)
                            let bottomY = geo.size.height * 0.5
                            path.move(to: CGPoint(x: geo.size.width / 2 - topW / 2, y: 0))
                            path.addLine(to: CGPoint(x: geo.size.width / 2 + topW / 2, y: 0))
                            path.addLine(to: CGPoint(x: geo.size.width / 2 + bottomW / 2, y: bottomY))
                            path.addLine(to: CGPoint(x: geo.size.width / 2 - bottomW / 2, y: bottomY))
                            path.closeSubpath()
                        }
                        .fill(LinearGradient(colors: [(Color(hex: accentHex) ?? .accentColor).opacity(0.3),
                                                       (Color(hex: accentHex) ?? .accentColor).opacity(0.05)],
                                             startPoint: .top, endPoint: .bottom))
                        .blur(radius: 20)
                        .frame(width: geo.size.width, height: geo.size.height * 0.5)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
                    VStack(spacing: 32) {
                        row(offset: -1)
                        row(offset: 0)
                        row(offset: 1)
                    }
                    .frame(maxWidth: 896).padding(.horizontal, 48).padding(.bottom, 64)
                    .allowsHitTesting(false)
                    .animation(.spring(response: 0.5, dampingFraction: 0.68), value: effectiveIndex)
                }
            }
        }
        .onAppear { effectiveIndex = max(0, activeIndex) }
        .onChange(of: activeIndex) { _, index in updateIndex(index) }
        .onChange(of: document) { _, _ in updateIndex(activeIndex) }
    }

    @ViewBuilder private func row(offset: Int) -> some View {
        let index = effectiveIndex + offset
        if document.lines.indices.contains(index) {
            let line = document.lines[index]
            if line.fullText.isEmpty {
                Color.clear.frame(height: 80)
            } else {
                Text(line.fullText)
                    .font(.system(size: (offset == 0 ? 44 : 28) * fontScale,
                                  weight: offset == 0 ? .bold : .semibold))
                    .foregroundStyle(Color(hex: primaryHex) ?? .white)
                    .shadow(color: offset == 0
                        ? (Color(hex: accentHex) ?? .accentColor).opacity(0.8)
                        : .black.opacity(0.25),
                            radius: offset == 0 ? 12 : 2, y: 2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .opacity(offset == 0 ? 1 : 0.22)
                    .id(line.id)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        } else {
            Color.clear.frame(height: 80)
        }
    }

    private func updateIndex(_ active: Int) {
        effectiveIndex = FoliaTimeline.stillIndex(previous: effectiveIndex, activeIndex: active, lineCount: document.lines.count)
    }
}

// MARK: - 花火

// 花火（原版）：一道升空尾迹，顶上开一朵花（烟花 PV 导演）。
// 移植：当前行词落在亮色块上弹出（scale + opacity）+ Canvas 烟花（行切换时放一发：火箭升空 → 顶上爆发星点）；
// 节拍降级为行切换触发；跳过 Pixi、段落 program、拼贴、辉光降采样链。
// 平时无烟花时不跑计时器（TimelineView 只在有粒子时挂上），省电。
struct FoliaHanabiView: View {
    let document: FoliaLyricDocument
    @ObservedObject var clock: PlaybackClock

    @State private var effectiveIndex = 0
    @State private var rockets: [Rocket] = []
    @State private var sparks: [Spark] = []
    @State private var lastDate = Date()
    @State private var stageSize = CGSize(width: 800, height: 390)
    @AppStorage(FoliaPreferences.fontScaleKey) private var fontScale = 1.0
    @AppStorage(FoliaPreferences.primaryColorKey) private var primaryHex = "#FFFFFF"
    @AppStorage(FoliaPreferences.accentColorKey) private var accentHex = "#A5B4FC"
    @AppStorage(FoliaPreferences.showTextKey) private var showText = true
    @AppStorage(LyricTiming.userOffsetKey) private var userOffset = 0.0

    private struct Rocket { var x, y, vy, burstY: Double }
    private struct Spark { var x, y, vx, vy, age, life, size: Double }

    private var activeIndex: Int { foliaActiveIndex(document: document, clock: clock, userOffset: userOffset) }

    private var currentLine: FoliaLine? {
        document.lines.indices.contains(effectiveIndex) ? document.lines[effectiveIndex] : nil
    }

    /// 当前行按词拆块（无词时间时整行一块）；词块之间用间距分开，不拼空格。
    private var wordBlocks: [String] {
        guard let line = currentLine, !line.fullText.isEmpty else { return [] }
        if line.words.isEmpty { return [line.fullText] }
        return line.words.map(\.text).filter { !$0.isEmpty }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if showText {
                    if !rockets.isEmpty || !sparks.isEmpty {
                        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                            Canvas { ctx, _ in drawFireworks(ctx: &ctx) }
                                .onChange(of: context.date) { _, date in
                                    let dt = min(0.1, max(0, date.timeIntervalSince(lastDate)))
                                    lastDate = date
                                    stepFireworks(dt: dt)
                                }
                        }
                        .allowsHitTesting(false)
                    }
                    VStack(spacing: 32) {
                        row(offset: -1)
                        currentBlocks
                        row(offset: 1)
                    }
                    .frame(maxWidth: 896).padding(.horizontal, 48).padding(.bottom, 64)
                    .allowsHitTesting(false)
                    .animation(.spring(response: 0.5, dampingFraction: 0.68), value: effectiveIndex)
                }
            }
            .onChange(of: geo.size) { _, size in stageSize = size }
        }
        .onAppear { effectiveIndex = max(0, activeIndex); lastDate = Date() }
        .onChange(of: activeIndex) { _, index in updateIndex(index); launchFirework() }
        .onChange(of: document) { _, _ in updateIndex(activeIndex) }
    }

    @ViewBuilder private var currentBlocks: some View {
        if let line = currentLine, !line.fullText.isEmpty {
            // 词块流式排布：长行自动换行，不溢出。
            FoliaFlowLayout(spacing: 8) {
                ForEach(wordBlocks.indices, id: \.self) { i in
                    Text(wordBlocks[i])
                        .font(.system(size: 44 * fontScale, weight: .bold))
                        .foregroundStyle(accentIsLight ? Color.black : Color.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color(hex: accentHex) ?? .accentColor, in: RoundedRectangle(cornerRadius: 8))
                        .id("\(line.id)-block-\(i)")
                }
            }
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        } else {
            Color.clear.frame(height: 80)
        }
    }

    @ViewBuilder private func row(offset: Int) -> some View {
        let index = effectiveIndex + offset
        if document.lines.indices.contains(index) {
            let line = document.lines[index]
            if line.fullText.isEmpty {
                Color.clear.frame(height: 80)
            } else {
                Text(line.fullText)
                    .font(.system(size: 28 * fontScale, weight: .semibold))
                    .foregroundStyle(Color(hex: primaryHex) ?? .white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .opacity(0.22)
                    .id(line.id)
                    .transition(.opacity)
            }
        } else {
            Color.clear.frame(height: 80)
        }
    }

    private var accentIsLight: Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(Color(hex: accentHex) ?? .white)
            .getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return false }
        return 0.299 * red + 0.587 * green + 0.114 * blue > 0.6
    }

    private func launchFirework() {
        let width = max(1, stageSize.width), height = max(1, stageSize.height)
        rockets.append(Rocket(x: Double.random(in: width * 0.2...width * 0.8), y: height,
                              vy: -420, burstY: Double.random(in: height * 0.15...height * 0.4)))
    }

    private func stepFireworks(dt: Double) {
        guard dt > 0 else { return }
        for i in rockets.indices { rockets[i].y += rockets[i].vy * dt }
        var burst: [Spark] = []
        rockets = rockets.filter { rocket in
            guard rocket.y > rocket.burstY else {
                for _ in 0..<14 {
                    let angle = Double.random(in: 0...(2 * Double.pi))
                    let speed = Double.random(in: 80...200)
                    burst.append(Spark(x: rocket.x, y: rocket.burstY,
                                       vx: cos(angle) * speed, vy: sin(angle) * speed,
                                       age: 0, life: Double.random(in: 0.8...1.2),
                                       size: Double.random(in: 2...4)))
                }
                return false
            }
            return true
        }
        sparks.append(contentsOf: burst)
        sparks = sparks.compactMap { spark in
            var spark = spark
            spark.age += dt
            guard spark.age < spark.life else { return nil }
            spark.vy += 300 * dt
            spark.x += spark.vx * dt
            spark.y += spark.vy * dt
            return spark
        }
    }

    private func drawFireworks(ctx: inout GraphicsContext) {
        for rocket in rockets {
            let circle = Path(ellipseIn: CGRect(x: rocket.x - 2, y: rocket.y - 2, width: 4, height: 4))
            ctx.fill(circle, with: .color(.white.opacity(0.9)))
        }
        for spark in sparks {
            let progress = spark.age / spark.life
            let circle = Path(ellipseIn: CGRect(x: spark.x - spark.size, y: spark.y - spark.size,
                                                width: spark.size * 2, height: spark.size * 2))
            ctx.fill(circle, with: .color(.white.opacity((1 - progress) * 0.9)))
        }
    }

    private func updateIndex(_ active: Int) {
        effectiveIndex = FoliaTimeline.stillIndex(previous: effectiveIndex, activeIndex: active, lineCount: document.lines.count)
    }
}

// MARK: - 倾诉

// 倾诉（原版）：把一行按概率拆成 1–4 个视觉行，两种排版：normal（水平常规）与 tilt（大号斜体、上下交错）。
// 移植：按字数对数 + 种子化拆段（阈值 0.45/1.05/1.7 → 1/2/3/4 段），tilt 概率 0.35；
// tilt 时字符上下交错偏移 + 斜体 + 大号；超宽整体缩（下限 normal 0.55 / tilt 0.5）。只排当前行。
// 跳过 pretext 精确换行（用字数估算拆段）。
struct FoliaTiltView: View {
    let document: FoliaLyricDocument
    @ObservedObject var clock: PlaybackClock

    @State private var effectiveIndex = 0
    @AppStorage(FoliaPreferences.fontScaleKey) private var fontScale = 1.0
    @AppStorage(FoliaPreferences.primaryColorKey) private var primaryHex = "#FFFFFF"
    @AppStorage(FoliaPreferences.showTextKey) private var showText = true
    @AppStorage(LyricTiming.userOffsetKey) private var userOffset = 0.0

    private var activeIndex: Int { foliaActiveIndex(document: document, clock: clock, userOffset: userOffset) }

    private var currentLine: FoliaLine? {
        document.lines.indices.contains(effectiveIndex) ? document.lines[effectiveIndex] : nil
    }

    /// 行种子（毫秒取整，同一行固定）：拆段数与 normal/tilt 都由它定。
    private var lineSeed: Int { Int((currentLine?.startTime ?? 0) * 1000) }

    private var segments: [String] {
        guard let line = currentLine, !line.fullText.isEmpty else { return [] }
        let chars = Array(line.fullText)
        let score = log(Double(chars.count) + 4) / log(24)
            * (0.7 + foliaHash(lineSeed, 7) * 0.6) * 0.75
        let count = score < 0.45 ? 1 : (score < 1.05 ? 2 : (score < 1.7 ? 3 : 4))
        guard count > 1 else { return [line.fullText] }
        var segments: [String] = []
        var start = 0
        let avg = Double(chars.count) / Double(count)
        for i in 0..<(count - 1) {
            let len = max(1, Int((avg * (0.85 + foliaHash(lineSeed + i, 3) * 0.3)).rounded()))
            let end = min(chars.count - (count - 1 - i), start + len)
            segments.append(String(chars[start..<end]))
            start = end
        }
        segments.append(String(chars[start...]))
        return segments
    }

    private var isTilt: Bool { foliaHash(lineSeed, 11) < 0.35 }

    var body: some View {
        ZStack {
            if showText, let line = currentLine, !line.fullText.isEmpty {
                VStack(spacing: 12) {
                    ForEach(segments.indices, id: \.self) { i in
                        if isTilt {
                            let chars = Array(segments[i])
                            HStack(spacing: 2) {
                                ForEach(chars.indices, id: \.self) { j in
                                    Text(String(chars[j]))
                                        .font(.system(size: 44 * 1.2 * fontScale, weight: .bold))
                                        .italic()
                                        .offset(y: j % 2 == 0 ? -8 : 8)
                                }
                            }
                            .foregroundStyle(Color(hex: primaryHex) ?? .white)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        } else {
                            Text(segments[i])
                                .font(.system(size: 44 * fontScale, weight: .bold))
                                .foregroundStyle(Color(hex: primaryHex) ?? .white)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                        }
                    }
                }
                .frame(maxWidth: 896).padding(.horizontal, 48).padding(.bottom, 64)
                .allowsHitTesting(false)
                .id(line.id)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.5, dampingFraction: 0.68), value: effectiveIndex)
            }
        }
        .onAppear { effectiveIndex = max(0, activeIndex) }
        .onChange(of: activeIndex) { _, index in updateIndex(index) }
        .onChange(of: document) { _, _ in updateIndex(activeIndex) }
    }

    private func updateIndex(_ active: Int) {
        effectiveIndex = FoliaTimeline.stillIndex(previous: effectiveIndex, activeIndex: active, lineCount: document.lines.count)
    }
}

// MARK: - 回环

// 回环（原版）：把一行歌词的每个字素投影到一条倾斜的 3D 椭圆轨道上，轨道随播放转动（弹簧驱动）。
// 移植：字素沿椭圆弧排布（角度 = 累计估算字宽/半径，跨度上限 4.25 弧度，旋转归一化 ±90° 保可读），
// 行切换时轨道转角弹簧推进 15°；上一行淡出。跳过 pretext 实测字素中心、逐帧直写、后行跟随比。
struct FoliaCladdaghView: View {
    let document: FoliaLyricDocument
    @ObservedObject var clock: PlaybackClock

    @State private var effectiveIndex = 0
    @State private var orbitRotation = 0.0
    @AppStorage(FoliaPreferences.fontScaleKey) private var fontScale = 1.0
    @AppStorage(FoliaPreferences.primaryColorKey) private var primaryHex = "#FFFFFF"
    @AppStorage(FoliaPreferences.showTextKey) private var showText = true
    @AppStorage(LyricTiming.userOffsetKey) private var userOffset = 0.0

    private var activeIndex: Int { foliaActiveIndex(document: document, clock: clock, userOffset: userOffset) }

    private var currentLine: FoliaLine? {
        document.lines.indices.contains(effectiveIndex) ? document.lines[effectiveIndex] : nil
    }

    private var previousLine: FoliaLine? {
        document.lines.indices.contains(effectiveIndex - 1) ? document.lines[effectiveIndex - 1] : nil
    }

    private func isCJK(_ character: Character) -> Bool {
        character.unicodeScalars.first.map { (0x4E00...0x9FFF).contains($0.value) } ?? false
    }

    /// 归一化到 ±90°（字不倒过来读）。
    private func normalizedRotation(_ degrees: Double) -> Double {
        let m = (degrees + 90).truncatingRemainder(dividingBy: 180)
        return (m < 0 ? m + 180 : m) - 90
    }

    /// 字素帧（预先算好，不在 ForEach 里改状态）：字、圆心坐标、切线旋转。
    private func graphemeFrames(line: FoliaLine, size: CGSize, fontSize: CGFloat,
                                orbitRotation: Double) -> [(char: String, x: CGFloat, y: CGFloat, rotation: Double)] {
        let chars = Array(line.fullText)
        let advances = chars.map { (isCJK($0) ? fontSize : fontSize * 0.5) + 0.22 * fontSize }
        let total = advances.reduce(0, +)
        let radiusX = size.width * 0.38
        let radiusY = size.height * 0.22
        let span = min(4.25, total / max(1, radiusX))
        let centerX = size.width / 2
        let centerY = size.height / 2
        let tilt = 45.0 * Double.pi / 180
        var frames: [(char: String, x: CGFloat, y: CGFloat, rotation: Double)] = []
        var cumulative = 0.0
        for (i, ch) in chars.enumerated() {
            let charCenter = cumulative + advances[i] / 2
            cumulative += advances[i]
            let angle = -Double.pi / 2 - span / 2 + charCenter / max(1, radiusX)
                + orbitRotation * Double.pi / 180
            let rawX = cos(angle) * radiusX
            let rawY = sin(angle) * radiusY
            let x = centerX + rawX * cos(tilt) - rawY * sin(tilt)
            let y = centerY + rawX * sin(tilt) + rawY * cos(tilt)
            let tangent = normalizedRotation((angle * 180 / Double.pi) + 90 + 45)
            frames.append((char: String(ch), x: x, y: y, rotation: tangent))
        }
        return frames
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if showText, let line = currentLine, !line.fullText.isEmpty {
                    let frames = graphemeFrames(line: line, size: geo.size,
                                                fontSize: 32 * fontScale, orbitRotation: orbitRotation)
                    ForEach(frames.indices, id: \.self) { i in
                        Text(frames[i].char)
                            .font(.system(size: 32 * fontScale, weight: .semibold))
                            .foregroundStyle(Color(hex: primaryHex) ?? .white)
                            .position(x: frames[i].x, y: frames[i].y)
                            .rotationEffect(.degrees(frames[i].rotation))
                    }
                    if let prev = previousLine, !prev.fullText.isEmpty {
                        Text(prev.fullText)
                            .font(.system(size: 28 * fontScale, weight: .semibold))
                            .foregroundStyle(Color(hex: primaryHex) ?? .white)
                            .opacity(0.3)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2 + 140)
                            .transition(.opacity)
                    }
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.68), value: effectiveIndex)
        }
        .allowsHitTesting(false)
        .onAppear { effectiveIndex = max(0, activeIndex) }
        .onChange(of: activeIndex) { _, index in updateIndex(index); orbitRotation += 15 }
        .onChange(of: document) { _, _ in updateIndex(activeIndex) }
    }

    private func updateIndex(_ active: Int) {
        effectiveIndex = FoliaTimeline.stillIndex(previous: effectiveIndex, activeIndex: active, lineCount: document.lines.count)
    }
}

// MARK: - 莫奈

// 莫奈（原版）：海报式左右分栏——左侧关键字栏（歌词轨道），右侧立绘。
// 移植：左侧歌词轨（5 行：前后各 2 行 + 当前行，按距离给 alpha/scale/blur，原版公式），
// 当前行扫字填充（按词/字时间插值宽度）；右侧封面立绘（歌曲封面，换歌交叉淡化）。
// 跳过立绘上传、音频可视化条、副字幕轨。横屏下左右分栏正合适。
struct FoliaMonetView: View {
    let document: FoliaLyricDocument
    @ObservedObject var clock: PlaybackClock
    let coverURL: URL?

    @State private var effectiveIndex = 0
    @AppStorage(FoliaPreferences.fontScaleKey) private var fontScale = 1.0
    @AppStorage(FoliaPreferences.primaryColorKey) private var primaryHex = "#FFFFFF"
    @AppStorage(FoliaPreferences.accentColorKey) private var accentHex = "#A5B4FC"
    @AppStorage(FoliaPreferences.showTextKey) private var showText = true
    @AppStorage(LyricTiming.userOffsetKey) private var userOffset = 0.0

    private var activeIndex: Int { foliaActiveIndex(document: document, clock: clock, userOffset: userOffset) }

    private var effectiveTime: Double {
        LyricTiming.effectiveProgress(clock.progress, userOffset: userOffset)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if showText {
                    HStack(spacing: 32) {
                        Spacer()
                        VStack(spacing: 18) {
                            ForEach([-2, -1, 0, 1, 2], id: \.self) { offset in
                                railRow(offset: offset, railWidth: geo.size.width * 0.5)
                            }
                        }
                        CoverImage(url: coverURL, size: min(geo.size.width * 0.32, 300), cornerRadius: 16)
                            .id(coverURL)
                            .transition(.opacity)
                            .animation(.easeOut(duration: 0.3), value: coverURL)
                        Spacer()
                    }
                    .padding(.horizontal, 48)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.68), value: effectiveIndex)
        }
        .allowsHitTesting(false)
        .onAppear { effectiveIndex = max(0, activeIndex) }
        .onChange(of: activeIndex) { _, index in updateIndex(index) }
        .onChange(of: document) { _, _ in updateIndex(activeIndex) }
    }

    @ViewBuilder private func railRow(offset: Int, railWidth: CGFloat) -> some View {
        let index = effectiveIndex + offset
        if document.lines.indices.contains(index) {
            let line = document.lines[index]
            if line.fullText.isEmpty {
                Color.clear.frame(height: 40)
            } else if offset == 0 {
                FoliaSweepText(text: line.fullText, fontSize: 36 * fontScale, weight: .bold,
                               base: (Color(hex: primaryHex) ?? .white).opacity(0.34),
                               fill: Color(hex: accentHex) ?? .accentColor,
                               progress: foliaSweepProgress(line: line, time: effectiveTime))
                    .frame(maxWidth: railWidth, alignment: .leading)
                    .id(line.id)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                let d = abs(offset)
                let waiting = offset > 0
                let alpha = waiting
                    ? max(0.36, 0.72 - Double(d - 1) * 0.18)
                    : max(0.28, 0.52 - Double(d - 1) * 0.12)
                let scale = waiting
                    ? max(0.68, 0.72 * pow(0.9, Double(d - 1)))
                    : 0.92
                let blur: CGFloat = waiting
                    ? (d == 1 ? 0.7 : 1.8 + Double(d - 2) * 0.8)
                    : 1.1 + Double(d - 1) * 0.7
                Text(line.fullText)
                    .font(.system(size: 28 * fontScale, weight: .semibold))
                    .foregroundStyle(Color(hex: primaryHex) ?? .white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: railWidth, alignment: .leading)
                    .opacity(alpha)
                    .scaleEffect(scale)
                    .blur(radius: blur)
                    .id(line.id)
                    .transition(.opacity)
            }
        } else {
            Color.clear.frame(height: 40)
        }
    }

    private func updateIndex(_ active: Int) {
        effectiveIndex = FoliaTimeline.stillIndex(previous: effectiveIndex, activeIndex: active, lineCount: document.lines.count)
    }
}

// MARK: - 时计

// 时计（原版）：左侧圆弧歌词 + 行切换棘轮步进 + 当前行扫字填充。
// 移植：歌词排在左圆弧上（圆心左边缘中点、半径比 0.42、圆弧角 100°，当前行在弧中、上下行沿弧排），
// 行切换时当前行弹簧步进（activeScale 1.25），当前行扫字填充；跳过 WebGL 齿轮、鼓点波纹（行切换步进已含敲击感）。
struct FoliaPendoloView: View {
    let document: FoliaLyricDocument
    @ObservedObject var clock: PlaybackClock

    @State private var effectiveIndex = 0
    @AppStorage(FoliaPreferences.fontScaleKey) private var fontScale = 1.0
    @AppStorage(FoliaPreferences.primaryColorKey) private var primaryHex = "#FFFFFF"
    @AppStorage(FoliaPreferences.accentColorKey) private var accentHex = "#A5B4FC"
    @AppStorage(FoliaPreferences.showTextKey) private var showText = true
    @AppStorage(LyricTiming.userOffsetKey) private var userOffset = 0.0

    private var activeIndex: Int { foliaActiveIndex(document: document, clock: clock, userOffset: userOffset) }

    private var effectiveTime: Double {
        LyricTiming.effectiveProgress(clock.progress, userOffset: userOffset)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if showText {
                    let radius = geo.size.height * 0.42
                    VStack(spacing: 20) {
                        ForEach([-2, -1, 0, 1, 2], id: \.self) { offset in
                            arcRow(offset: offset,
                                   xOffset: radius * (cos(Double(offset) * 25 * Double.pi / 180) - 1))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 80)
                    .animation(.spring(response: 0.5, dampingFraction: 0.68), value: effectiveIndex)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { effectiveIndex = max(0, activeIndex) }
        .onChange(of: activeIndex) { _, index in updateIndex(index) }
        .onChange(of: document) { _, _ in updateIndex(activeIndex) }
    }

    @ViewBuilder private func arcRow(offset: Int, xOffset: CGFloat) -> some View {
        let index = effectiveIndex + offset
        if document.lines.indices.contains(index) {
            let line = document.lines[index]
            if line.fullText.isEmpty {
                Color.clear.frame(height: 44)
            } else if offset == 0 {
                FoliaSweepText(text: line.fullText, fontSize: 36 * fontScale, weight: .bold,
                               base: (Color(hex: primaryHex) ?? .white).opacity(0.34),
                               fill: Color(hex: accentHex) ?? .accentColor,
                               progress: foliaSweepProgress(line: line, time: effectiveTime))
                    .scaleEffect(1.25)
                    .offset(x: xOffset)
                    .id(line.id)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Text(line.fullText)
                    .font(.system(size: 28 * fontScale, weight: .semibold))
                    .foregroundStyle(Color(hex: primaryHex) ?? .white)
                    .multilineTextAlignment(.leading)
                    .opacity(abs(offset) == 1 ? 0.6 : 0.3)
                    .offset(x: xOffset)
                    .id(line.id)
                    .transition(.opacity)
            }
        } else {
            Color.clear.frame(height: 44)
        }
    }

    private func updateIndex(_ active: Int) {
        effectiveIndex = FoliaTimeline.stillIndex(previous: effectiveIndex, activeIndex: active, lineCount: document.lines.count)
    }
}

// MARK: - 群唱

// 群唱（原版）：把歌词当成聊天记录，每行是一条消息，左右交替发。
// 移植：最近 5 行成聊天气泡（左右交替：序列 [左,右,左,右,右] + 0.18 翻转概率，种子化固定），
// 当前消息放大 1.12、字号 1.34 倍，逐字显现（220ms 淡入，按词/字时间）；已过消息缩放 0.92、透明度 0.82。
// 跳过头像系统（纯色圆点代替）、表情包、气泡度量缓存；内边距按手机屏缩小为 16×10（原版 web 是 22×17）。
private struct FoliaCharTime { var char: String; var time: Double }

private func foliaCharTimes(line: FoliaLine) -> [FoliaCharTime] {
    if !line.words.isEmpty {
        var result: [FoliaCharTime] = []
        for word in line.words {
            let chars = Array(word.text)
            guard !chars.isEmpty else { continue }
            let span = max(0.001, word.endTime - word.startTime)
            let step = span / Double(chars.count)
            for (i, ch) in chars.enumerated() {
                result.append(FoliaCharTime(char: String(ch), time: word.startTime + Double(i) * step))
            }
        }
        return result
    }
    let chars = Array(line.fullText)
    guard !chars.isEmpty else { return [] }
    let span = max(0.001, line.endTime - line.startTime)
    let step = span / Double(chars.count)
    return chars.enumerated().map { FoliaCharTime(char: String($0.element),
                                                  time: line.startTime + Double($0.offset) * step) }
}

/// 群唱当前消息的逐字显现：字按词/字时间淡入（220ms），长行自动换行（流式排布贴着文本宽，气泡不撑满）。
private struct FoliaCappellaCurrentText: View {
    let line: FoliaLine
    let time: Double
    let color: Color
    let fontScale: Double

    var body: some View {
        let units = foliaCharTimes(line: line)
        FoliaFlowLayout(spacing: 0) {
            ForEach(units.indices, id: \.self) { i in
                Text(units[i].char)
                    .font(.system(size: 28 * 1.34 * fontScale, weight: .bold))
                    .opacity(time >= units[i].time ? 1 : 0)
                    .animation(.easeOut(duration: 0.22), value: time)
            }
        }
        .foregroundStyle(color)
    }
}

struct FoliaCappellaView: View {
    let document: FoliaLyricDocument
    @ObservedObject var clock: PlaybackClock

    @State private var effectiveIndex = 0
    @AppStorage(FoliaPreferences.fontScaleKey) private var fontScale = 1.0
    @AppStorage(FoliaPreferences.primaryColorKey) private var primaryHex = "#FFFFFF"
    @AppStorage(FoliaPreferences.accentColorKey) private var accentHex = "#A5B4FC"
    @AppStorage(FoliaPreferences.showTextKey) private var showText = true
    @AppStorage(LyricTiming.userOffsetKey) private var userOffset = 0.0

    private var activeIndex: Int { foliaActiveIndex(document: document, clock: clock, userOffset: userOffset) }

    private var effectiveTime: Double {
        LyricTiming.effectiveProgress(clock.progress, userOffset: userOffset)
    }

    /// 发件方：序列 [左,右,左,右,右]（每 5 行强制一次右已含在序列里）+ 0.18 翻转概率，种子化固定。
    private func isRight(lineIndex: Int) -> Bool {
        let sequence = [false, true, false, true, true]
        var right = sequence[lineIndex % 5]
        if foliaHash(lineIndex, 21) < 0.18 { right.toggle() }
        return right
    }

    private var accentIsLight: Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(Color(hex: accentHex) ?? .white)
            .getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return false }
        return 0.299 * red + 0.587 * green + 0.114 * blue > 0.6
    }

    var body: some View {
        ZStack {
            if showText {
                VStack {
                    Spacer()
                    ForEach(Array((max(0, effectiveIndex - 4)...effectiveIndex)), id: \.self) { lineIndex in
                        bubbleRow(lineIndex: lineIndex)
                    }
                }
                .padding(.horizontal, 48).padding(.bottom, 64)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)
                .animation(.spring(response: 0.5, dampingFraction: 0.68), value: effectiveIndex)
            }
        }
        .onAppear { effectiveIndex = max(0, activeIndex) }
        .onChange(of: activeIndex) { _, index in updateIndex(index) }
        .onChange(of: document) { _, _ in updateIndex(activeIndex) }
    }

    @ViewBuilder private func bubbleRow(lineIndex: Int) -> some View {
        if document.lines.indices.contains(lineIndex) {
            let line = document.lines[lineIndex]
            if !line.fullText.isEmpty {
                let right = isRight(lineIndex: lineIndex)
                let current = lineIndex == effectiveIndex
                let bubbleColor: Color = right
                    ? (Color(hex: accentHex) ?? .accentColor)
                    : Color.white.opacity(0.15)
                let textColor: Color = right
                    ? (accentIsLight ? Color.black : Color.white)
                    : (Color(hex: primaryHex) ?? .white)
                let avatarColor: Color = right
                    ? (Color(hex: accentHex) ?? .accentColor)
                    : (Color(hex: primaryHex) ?? .white).opacity(0.5)
                HStack(spacing: 10) {
                    if !right {
                        Circle().fill(avatarColor).frame(width: 28, height: 28)
                    }
                    if right { Spacer(minLength: 0) }
                    Group {
                        if current {
                            FoliaCappellaCurrentText(line: line, time: effectiveTime,
                                                     color: textColor, fontScale: fontScale)
                        } else {
                            Text(line.fullText)
                                .font(.system(size: 28 * fontScale, weight: .semibold))
                                .foregroundStyle(textColor)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(bubbleColor, in: RoundedRectangle(cornerRadius: 18))
                    .frame(maxWidth: 560, alignment: right ? .trailing : .leading)
                    .scaleEffect(current ? 1.12 : 0.92)
                    .opacity(current ? 1 : 0.82)
                    if !right { Spacer(minLength: 0) }
                    if right {
                        Circle().fill(avatarColor).frame(width: 28, height: 28)
                    }
                }
                .id(line.id)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func updateIndex(_ active: Int) {
        effectiveIndex = FoliaTimeline.stillIndex(previous: effectiveIndex, activeIndex: active, lineCount: document.lines.count)
    }
}
