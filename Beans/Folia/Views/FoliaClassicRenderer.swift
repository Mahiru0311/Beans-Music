import SwiftUI

// Independent native Classic draft; it does not reuse Still under another mode name.
struct FoliaClassicRenderer: View {
    let document: FoliaLyricDocument
    @ObservedObject var clock: PlaybackClock
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(FoliaPreferences.fontScaleKey) private var fontScale = 1.0
    @AppStorage(FoliaPreferences.subtitleScaleKey) private var subtitleScale = 1.0
    @AppStorage(FoliaPreferences.translationKey) private var showTranslation = true
    @AppStorage(FoliaPreferences.primaryColorKey) private var primaryHex = "#FFFFFF"
    @AppStorage(FoliaPreferences.secondaryColorKey) private var secondaryHex = "#FFFFFF"
    @AppStorage(FoliaPreferences.accentColorKey) private var accentHex = "#A5B4FC"
    @AppStorage(FoliaPreferences.showTextKey) private var showText = true
    @AppStorage(FoliaPreferences.classicIntensityKey) private var intensityRaw = "normal"
    @AppStorage(FoliaPreferences.classicRotationKey) private var rotationEnabled = true
    @AppStorage(FoliaPreferences.classicBreathingKey) private var breathing = 1.0
    @AppStorage(FoliaPreferences.classicLegacyLayoutKey) private var legacy = false
    @AppStorage(FoliaPreferences.classicSpacingKey) private var spacing = 0.7
    @AppStorage(LyricTiming.userOffsetKey) private var userOffset = 0.0

    private var intensity: FoliaClassicIntensity { FoliaClassicIntensity(rawValue: intensityRaw) ?? .normal }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !player.isPlaying || player.isBuffering || !showText)) { _ in
            stage(time: LyricTiming.effectiveProgress(player.currentPlaybackTime(), userOffset: userOffset))
        }
        .allowsHitTesting(false)
    }

    private func stage(time: Double) -> some View {
        let activeIndex = FoliaTimeline.activeIndex(lines: document.lines, time: time)
        let activeLine = document.lines.indices.contains(activeIndex) ? document.lines[activeIndex] : nil
        return GeometryReader { viewport in
            let size = max(36, min(72, Double(viewport.size.width) * 0.06)) * fontScale
            VStack(spacing: 24) {
                Spacer(minLength: 56)
                FoliaClassicBreathing(intensity: intensity, multiplier: breathing,
                                      disabled: reduceMotion || !showText || activeLine == nil) {
                    ZStack {
                        if showText, let line = activeLine {
                            lineView(line, fontSize: size, time: time)
                                .id(line.id)
                                .transition(reduceMotion ? .opacity : .asymmetric(
                                    insertion: .modifier(active: FoliaClassicLineTransition(scale: 0.9, blur: 10, opacity: 0),
                                                         identity: FoliaClassicLineTransition(scale: 1, blur: 0, opacity: 1)),
                                    removal: .modifier(active: FoliaClassicLineTransition(scale: 1.1, blur: 20, opacity: 0),
                                                       identity: FoliaClassicLineTransition(scale: 1, blur: 0, opacity: 1))))
                        } else if showText {
                            Text("等待音乐")
                                .font(.system(size: max(24, min(36, viewport.size.width * 0.035)) * fontScale))
                                .foregroundStyle(Color(hex: secondaryHex) ?? .white).opacity(0.5)
                        }
                    }
                    .frame(maxWidth: 1152, minHeight: min(300, viewport.size.height * 0.5))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: activeLine?.id)
                }
                Spacer(minLength: 16)
                if showText { subtitle(time: time, activeIndex: activeIndex, activeLine: activeLine).font(.system(size: 20 * fontScale * subtitleScale)) }
                // Leave room for the shared Beans transport; it owns seeking and audio.
                Spacer().frame(height: 140)
            }
            .padding(.horizontal, 32).frame(width: viewport.size.width, height: viewport.size.height)
        }
    }

    @ViewBuilder private func lineView(_ line: FoliaLine, fontSize: Double, time: Double) -> some View {
        if line.words.isEmpty {
            // LRC has no word timestamps: keep it readable without fabricated karaoke timing.
            Text(line.fullText).font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(Color(hex: primaryHex) ?? .white).multilineTextAlignment(.center)
        } else {
            let interlude = line.fullText == "......"
            let geometry = line.words.indices.map {
                FoliaClassicMotion.geometry(seed: line.startTime, index: $0, intensity: intensity,
                                            rotationEnabled: rotationEnabled, interlude: interlude)
            }
            FoliaClassicLayout(geometries: geometry, fontSize: fontSize, intensity: intensity,
                               spacing: spacing, legacy: legacy, interlude: interlude,
                               justification: FoliaClassicMotion.justification(seed: line.startTime, intensity: intensity, interlude: interlude),
                               alignment: FoliaClassicMotion.alignment(seed: line.startTime, intensity: intensity)) {
                ForEach(Array(line.words.enumerated()), id: \.element.id) { index, word in
                    FoliaClassicWordView(word: word, time: time, state: FoliaClassicMotion.state(word: word, time: time),
                                         geometry: geometry[index], intensity: intensity, fontSize: fontSize,
                                         base: Color(hex: primaryHex) ?? .white, accent: Color(hex: accentHex) ?? .indigo,
                                         rotationEnabled: rotationEnabled, reduceMotion: reduceMotion)
                }
            }
        }
    }

    @ViewBuilder private func subtitle(time: Double, activeIndex: Int, activeLine: FoliaLine?) -> some View {
        let completed = FoliaTimeline.recentCompleted(lines: document.lines, activeIndex: activeIndex, time: time)
        let candidate = [activeLine, completed].compactMap { $0 }.first {
            FoliaClassicMotion.hasReadableText($0.translation)
        }
        let translation = showTranslation ? candidate?.translation : nil
        VStack(spacing: 8) {
            if FoliaClassicMotion.hasReadableText(translation), let translation {
                Text(translation).multilineTextAlignment(.center)
            } else {
                ForEach(FoliaTimeline.upcomingLines(lines: document.lines, activeIndex: activeIndex)) { line in
                    Text(line.fullText).font(.system(size: 16 * fontScale * subtitleScale))
                        .multilineTextAlignment(.center).blur(radius: reduceMotion ? 0 : 2)
                }
            }
        }
        .foregroundStyle(Color(hex: secondaryHex) ?? .white).opacity(0.6)
        .padding(12).frame(maxWidth: 896)
        .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct FoliaClassicLineTransition: ViewModifier {
    let scale: Double
    let blur: Double
    let opacity: Double
    func body(content: Content) -> some View { content.scaleEffect(scale).blur(radius: blur).opacity(opacity) }
}

private struct FoliaClassicBreathing<Content: View>: View {
    let intensity: FoliaClassicIntensity
    let multiplier: Double
    let disabled: Bool
    let content: Content
    @State private var epoch = Date()

    init(intensity: FoliaClassicIntensity, multiplier: Double, disabled: Bool, @ViewBuilder content: () -> Content) {
        self.intensity = intensity
        self.multiplier = multiplier
        self.disabled = disabled
        self.content = content()
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: disabled || multiplier <= 0)) { context in
            let motion = FoliaClassicMotion.breathing(elapsed: context.date.timeIntervalSince(epoch), intensity: intensity,
                                                     multiplier: disabled ? 0 : multiplier)
            content.offset(y: motion.y).scaleEffect(motion.scale)
        }
    }
}
