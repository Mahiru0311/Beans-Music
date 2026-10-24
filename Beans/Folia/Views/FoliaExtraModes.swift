import SwiftUI

// Folia 效果（2026-10-25 精简后）：只留绘光、云阶、浮名三个行级效果，
// 外加流光、静止两个独立渲染器（在 FoliaClassicRenderer / FoliaStillRenderer 里）。
// 其余 11 个效果与横屏锁已删，舞台回到竖屏，不再臃肿；舞台外壳（封面毛玻璃、沉浸隐藏）未动。

// MARK: - 共用小工具

/// 确定性伪随机：同一序号永远得到同一组参数，画面不抖（原版同款 sin(seed)*10000 思路）。
private func foliaHash(_ index: Int, _ salt: Int) -> Double {
    let value = sin(Double(index * 127 + salt * 311) * 0.7) * 43758.5453
    return value - floor(value)
}

private func foliaContainsCJK(_ text: String) -> Bool {
    text.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
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

// MARK: - 浮名

// 浮名：主句巨大居中、前后句以虚影叠在身后（单独成层，不进三行 VStack；长句溢出边界是设计本身）。
// 原行级舞台里的 fumeStage，原样搬成独立视图。
struct FoliaFumeView: View {
    let document: FoliaLyricDocument
    @ObservedObject var clock: PlaybackClock

    @State private var effectiveIndex = 0
    @AppStorage(FoliaPreferences.fontScaleKey) private var fontScale = 1.0
    @AppStorage(FoliaPreferences.primaryColorKey) private var primaryHex = "#FFFFFF"
    @AppStorage(FoliaPreferences.showTextKey) private var showText = true
    @AppStorage(LyricTiming.userOffsetKey) private var userOffset = 0.0

    private var activeIndex: Int { foliaActiveIndex(document: document, clock: clock, userOffset: userOffset) }

    var body: some View {
        ZStack {
            if showText {
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
        .frame(maxWidth: 896).padding(.horizontal, 48).padding(.bottom, 64)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.5, dampingFraction: 0.68), value: effectiveIndex)
        .onAppear { effectiveIndex = max(0, activeIndex) }
        .onChange(of: activeIndex) { _, index in updateIndex(index) }
        .onChange(of: document) { _, _ in updateIndex(activeIndex) }
    }

    private func updateIndex(_ active: Int) {
        effectiveIndex = FoliaTimeline.stillIndex(previous: effectiveIndex, activeIndex: active, lineCount: document.lines.count)
    }
}
