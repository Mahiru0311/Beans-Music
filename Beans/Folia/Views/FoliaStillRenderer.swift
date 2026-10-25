import SwiftUI

// Still: three rows, gentle fade+rise on line change — the calmest of the five effects,
// no glow or scale. (Earlier it was fully frozen; the bold rewrite gives it motion too.)
struct FoliaStillRenderer: View {
    let document: FoliaLyricDocument
    @ObservedObject var clock: PlaybackClock
    @State private var effectiveIndex = 0
    @AppStorage(FoliaPreferences.fontScaleKey) private var fontScale = 1.0
    @AppStorage(FoliaPreferences.subtitleScaleKey) private var subtitleScale = 1.0
    @AppStorage(FoliaPreferences.translationKey) private var showTranslation = true
    @AppStorage(FoliaPreferences.primaryColorKey) private var primaryHex = "#FFFFFF"
    @AppStorage(FoliaPreferences.secondaryColorKey) private var secondaryHex = "#FFFFFF"
    @AppStorage(FoliaPreferences.daylightKey) private var daylight = false
    @AppStorage(FoliaPreferences.showTextKey) private var showText = true
    @AppStorage(LyricTiming.userOffsetKey) private var userOffset = 0.0

    private var activeIndex: Int {
        FoliaTimeline.activeIndex(lines: document.lines, time: LyricTiming.effectiveProgress(clock.progress, userOffset: userOffset))
    }

    var body: some View {
        ZStack {
            RadialGradient(colors: [.clear, .black], center: .center, startRadius: 0, endRadius: 550)
                .opacity(daylight ? 0.3 : 0.65).ignoresSafeArea().allowsHitTesting(false)
            if showText {
                VStack(spacing: 32) {
                    row(offset: -1)
                    row(offset: 0)
                    row(offset: 1)
                }
                .frame(maxWidth: 896).padding(.horizontal, 48).padding(.bottom, 64)
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.5), value: effectiveIndex)
            }
        }
        .onAppear { effectiveIndex = max(0, activeIndex) }
        .onChange(of: activeIndex) { _, index in updateIndex(index) }
        .onChange(of: document) { _, _ in updateIndex(activeIndex) }
        .onChange(of: clock.progress) { _, _ in updateIndex(activeIndex) }
    }

    @ViewBuilder
    private func row(offset: Int) -> some View {
        let index = effectiveIndex + offset
        if document.lines.indices.contains(index) {
            let line = document.lines[index]
            let current = offset == 0
            VStack(spacing: current ? 12 : 8) {
                if !line.fullText.isEmpty {
                    Text(line.fullText)
                        .font(.system(size: (current ? 40 : 30) * fontScale, weight: current ? .bold : .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Color(hex: primaryHex) ?? .white)
                        .opacity(current ? 1 : 0.3)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 2)
                }
                if showTranslation, let translation = line.translation, !translation.isEmpty {
                    Text(translation)
                        .font(.system(size: (current ? 24 : 20) * fontScale * subtitleScale,
                                      weight: current ? .medium : .regular))
                        .foregroundStyle(Color(hex: secondaryHex) ?? .white)
                        .opacity(current ? 0.8 : 0.3)
                }
            }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
                .id(line.id)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            Color.clear.frame(height: 80)
        }
    }

    private func updateIndex(_ active: Int) {
        if active != -1 { effectiveIndex = active; return }
        // 间隙里显示“当前时间之前刚唱完的那行”，而不是滑动前留下的旧行。
        // 正常播放时两者是同一行；滑动进间隙后，旧的 held 行会是错的。
        let now = LyricTiming.effectiveProgress(clock.progress, userOffset: userOffset)
        if let recent = FoliaTimeline.recentCompleted(lines: document.lines, activeIndex: active, time: now),
           let idx = document.lines.firstIndex(where: { $0.id == recent.id }) {
            effectiveIndex = idx
        } else {
            effectiveIndex = 0
        }
    }
}
