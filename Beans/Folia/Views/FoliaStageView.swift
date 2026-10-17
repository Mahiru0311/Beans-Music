import SwiftUI

// Beans owns the audio and queue. This shell replaces only the visible lyric surface.
struct FoliaStageView: View {
    let song: Song?
    let lyrics: [LyricLine]
    let onBack: () -> Void
    let onSettings: () -> Void
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    @AppStorage(FoliaPreferences.daylightKey) private var daylight = false
    @AppStorage(FoliaPreferences.modeKey) private var modeRaw = FoliaVisualizerMode.still.rawValue
    @State private var document = FoliaLyricDocument(trackIdentity: "empty", lines: [])

    var body: some View {
        ZStack {
            (daylight ? Color.white : Color.black).ignoresSafeArea()
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
        switch FoliaPreferences.availableMode(rawValue: modeRaw) {
        case .classic:
            FoliaClassicRenderer(document: document, clock: clock)
        case .still:
            FoliaStillRenderer(document: document, clock: clock)
        default:
            Text("此歌词模式尚未移植，请在设置中选择可用模式。")
                .multilineTextAlignment(.center).padding(32)
        }
    }

    private func refreshDocument() {
        document = FoliaBeansLyricBridge.document(trackIdentity: song?.identityKey ?? "empty", lyrics: lyrics,
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
                Button { player.togglePlayMode() } label: { Image(systemName: player.playMode.icon).frame(width: 44, height: 44) }
            }.font(.title3)
        }
        .padding(12).background { BeansGlass(shape: RoundedRectangle(cornerRadius: 24)) }
    }
}
