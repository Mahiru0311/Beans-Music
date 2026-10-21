import Foundation

extension MiniPlayerLyricLine_2_0_3 {
    /// 0x100320884: rightmost timestamp <= clamped progress plus stored offset.
    /// The caller supplies ascending lyric times; the original does not sort here.
    public func displayedText(progress: Double, lyricOffset: Double = 0) -> String {
        let shifted = progress + lyricOffset
        // FCSEL GE also maps an unordered (NaN) sum to zero.
        let time = shifted >= 0 ? shifted : 0
        var lower = 0
        var upper = lyrics.count - 1
        var selected: String?
        while lower <= upper {
            let middle = (lower + upper) / 2
            if lyrics[middle].time <= time {
                selected = lyrics[middle].text
                lower = middle + 1
            } else {
                upper = middle - 1
            }
        }
        return selected ?? artist
    }
}
