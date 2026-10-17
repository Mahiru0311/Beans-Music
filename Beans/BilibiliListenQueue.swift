import Foundation
import CiliCiliKit

enum BilibiliListenQueue {
    static func song(_ request: CiliCiliVideoListenRequest) -> Song {
        let bvid = request.bvid.trimmingCharacters(in: .whitespacesAndNewlines)
        let cid = request.cid.flatMap { $0 > 0 ? $0 : nil }
        return Song(id: request.aid ?? 0, name: request.title,
                    artists: request.artist.isEmpty ? "哔哩哔哩" : request.artist,
                    album: "哔哩哔哩视频", coverURL: request.coverURL.flatMap(URL.init(string:)),
                    duration: request.duration.isFinite ? max(0, request.duration) : 0,
                    source: .bilibili, bilibiliID: cid.map { bvid + ":" + String($0) } ?? bvid)
    }

    static func songs(for current: CiliCiliVideoListenRequest) -> [Song] {
        var result: [Song] = []
        var seen = Set<String>()
        let currentSong = song(current)
        let currentBVID = current.bvid.trimmingCharacters(in: .whitespacesAndNewlines)
        var replacedUnresolvedCurrent = false
        for item in current.queue {
            let bvid = item.bvid.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !bvid.isEmpty else { continue }
            let representsCurrent = bvid == currentBVID && (item.cid == current.cid || item.cid == nil || (current.cid == nil && !replacedUnresolvedCurrent))
            if representsCurrent { replacedUnresolvedCurrent = true }
            let candidate = representsCurrent ? currentSong : song(item)
            if seen.insert(candidate.identityKey).inserted { result.append(candidate) }
        }
        if !seen.contains(currentSong.identityKey) { result.insert(currentSong, at: 0) }
        return result
    }
}
