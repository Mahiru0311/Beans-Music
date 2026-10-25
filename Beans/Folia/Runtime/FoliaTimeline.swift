import Foundation

// Ports shared helpers from Folia's visualizer/runtime.ts; gaps stay distinct from active lines.
enum FoliaTimeline {
    static func activeIndex(lines: [FoliaLine], time: Double) -> Int {
        guard time.isFinite else { return -1 }
        return lines.firstIndex { time >= $0.startTime && time <= $0.endTime } ?? -1
    }

    static func recentCompleted(lines: [FoliaLine], activeIndex: Int, time: Double) -> FoliaLine? {
        guard activeIndex == -1 else { return nil }
        return lines.last { time > $0.endTime }
    }

    static func upcomingLines(lines: [FoliaLine], activeIndex: Int, count: Int = 2) -> [FoliaLine] {
        guard lines.indices.contains(activeIndex), count > 0 else { return [] }
        return Array(lines.dropFirst(activeIndex + 1).prefix(count))
    }


    // Still holds its displayed center line during silent gaps, as the source renderer does.
    static func stillIndex(previous: Int, activeIndex: Int, lineCount: Int) -> Int {
        if activeIndex != -1 { return activeIndex }
        return previous >= lineCount ? 0 : previous
    }
}
