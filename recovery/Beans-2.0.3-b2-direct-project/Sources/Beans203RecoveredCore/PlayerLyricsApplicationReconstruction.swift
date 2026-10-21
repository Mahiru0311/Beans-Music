import Foundation

extension PlayerManager_2_0_3 {
    /// 0x100375e68: return nil for a negative or out-of-bounds queue index.
    public var currentSong: Song_2_0_3? {
        guard _currentIndex >= 0, _currentIndex < _queue.count else { return nil }
        return _queue[_currentIndex]
    }
}

/// Extracted state-mutation policy from PlayerView (descriptor 0x7c89bc),
/// 0x10040cca4. API shape and returned Bool are reconstruction seams.
/// The original diagnostics and SwiftUI state wrapper remain separate work.
public enum PlayerLyricsApplication_2_0_3 {
    @discardableResult
    public static func apply(
        _ parsed: [LyricLine_2_0_3], requestedSongKey: String,
        currentSong: Song_2_0_3?, to displayed: inout [LyricLine_2_0_3]
    ) -> Bool {
        guard let currentSong, currentSong.playbackKey == requestedSongKey, !parsed.isEmpty else {
            return false
        }
        displayed = parsed
        return true
    }
}
