import SwiftUI
import Beans203RecoveredCore

/// Focused MiniPlayerLyricLine view recovered from 0x100320884/0x100320a18.
/// The enclosing mini-player layout and controls are not represented by this view.
public struct MiniPlayerLyricLineView_2_0_3: View {
    @EnvironmentObject private var clock: PlaybackClock_2_0_3
    @AppStorage("beans.lyricOffset") private var lyricOffset: Double = 0
    private let lyrics: [LyricLine_2_0_3]
    private let artist: String
    private let isInline: Bool

    public init(lyrics: [LyricLine_2_0_3], artist: String, isInline: Bool = false) {
        self.lyrics = lyrics; self.artist = artist; self.isInline = isInline
    }

    public var body: some View {
        var model = MiniPlayerLyricLine_2_0_3()
        model.lyrics = lyrics
        model.artist = artist
        let text = model.displayedText(progress: clock.progress, lyricOffset: lyricOffset)
        return Text(text)
            .font(.system(size: isInline ? 8 : 10, weight: .regular, design: .default))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .animation(.easeInOut(duration: 0.25), value: text)
    }
}
