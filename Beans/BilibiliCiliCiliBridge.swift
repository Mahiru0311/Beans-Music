import Combine
import SwiftUI
import CiliCiliKit

@MainActor
final class BilibiliCiliCiliBridge {
    static let shared = BilibiliCiliCiliBridge()
    private var subscriptions = Set<AnyCancellable>()
    private weak var player: PlayerManager?
    private var listenQueueTask: Task<Void, Never>?
    private var listenQueueRevision = 0
    private var listenSongKey: String?
    private var listenPlaybackRevision: Int?
    private var expectedQueueKeys: [String] = []

    func configure(player: PlayerManager) {
        self.player = player
        guard subscriptions.isEmpty else { return }
        let runtime = CiliCiliRuntime.shared
        runtime.onPlaybackActivation = { [weak self] in
            self?.invalidateListenQueue()
            self?.player?.pauseForBilibiliVideo()
        }
        runtime.onVideoListenModeChange = { [weak self] request, enabled, resumeAt, shouldResume in
            self?.handleVideoListenModeChange(
                request: request,
                enabled: enabled,
                resumeAt: resumeAt,
                shouldResume: shouldResume
            )
        }
        runtime.onVideoListenPlaybackSnapshot = { [weak self] request in
            guard let player = self?.player,
                  player.currentSong?.identityKey == BilibiliListenQueue.song(request).identityKey else { return nil }
            return CiliCiliListenPlaybackSnapshot(time: player.currentPlaybackTime(), isPlaying: player.isPlaying)
        }
        runtime.onVideoListenQueueChange = { [weak self] request in self?.updateListenQueue(request) }
        runtime.onSessionChange = { cookie, name, id, avatar in
            try BilibiliAuth.shared.acceptCiliCiliSession(cookie: cookie, name: name, id: id, avatar: avatar)
        }
        synchronizeAccount()
        runtime.$isVideoDetailActive.removeDuplicates().sink { active in
            if active { BilibiliPresentationState.shared.enterVideo("cilicili-module") }
            else { BilibiliPresentationState.shared.leaveVideo("cilicili-module") }
        }.store(in: &subscriptions)
        runtime.$isLiveRoomActive.removeDuplicates().sink { active in
            if active { BilibiliPresentationState.shared.enterLive("cilicili-live") }
            else { BilibiliPresentationState.shared.leaveLive("cilicili-live") }
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: .beansBilibiliLoginDidUpdate).sink { [weak self] _ in
            self?.synchronizeAccount()
        }.store(in: &subscriptions)
        player.$isPlaying.removeDuplicates().filter { $0 }.sink { _ in
            runtime.stopPlaybackForMusic()
        }.store(in: &subscriptions)
    }

    private func handleVideoListenModeChange(
        request: CiliCiliVideoListenRequest,
        enabled: Bool,
        resumeAt: TimeInterval,
        shouldResume: Bool
    ) {
        invalidateListenQueue()
        guard let player else { return }
        guard enabled else {
            player.pauseForBilibiliVideo()
            return
        }

        let song = BilibiliListenQueue.song(request)
        let queue = BilibiliListenQueue.songs(for: request)
        player.playBilibiliAudio(song, context: queue, resumeAt: resumeAt, shouldResume: shouldResume)
        listenSongKey = song.identityKey
        listenPlaybackRevision = player.queueContextRevision
        expectedQueueKeys = player.queue.map(\.identityKey)
        // A supplied entry list is authoritative. Do not replace its order with author page 1.
        guard shouldResume, !request.preservesQueueOrder, request.queue.count <= 1 else { return }
        let revision = listenQueueRevision
        let playbackRevision = player.queueContextRevision

        // Beans 的播放器按钮不经过 CiliCili 的详情页控件。把当前上下文的
        // 下一批视频补进同一个 Beans 队列，才能让“下一首”继续按 UP 主/相关推荐
        // 前进，而不是因为外部播放器队列只有一首而停住。
        let api = BilibiliAPI.shared
        listenQueueTask = Task { @MainActor [weak self, weak player] in
            do {
                let candidates: [BilibiliFeedVideo]
                if let ownerID = request.ownerID, ownerID > 0 {
                    let owner = Artist(id: String(ownerID), name: request.artist, coverURL: nil, source: .bilibili)
                    candidates = try await api.upVideos(owner, page: 1).items
                } else {
                    candidates = try await api.relatedVideos(aid: String(request.aid ?? 0))
                }
                let additions = candidates.compactMap { item -> Song? in
                    let bvid = item.song.bilibiliID?.split(separator: ":").first.map(String.init)
                    guard bvid != request.bvid else { return nil }
                    return item.song
                }
                // A late author response must not contaminate a newer music/video queue.
                guard !Task.isCancelled, let self, let player,
                      revision == self.listenQueueRevision,
                      playbackRevision == player.queueContextRevision,
                      player.currentSong?.identityKey == song.identityKey,
                      player.queue.map(\.identityKey) == [song.identityKey] else { return }
                player.append(songs: additions)
                self.expectedQueueKeys = player.queue.map(\.identityKey)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, self?.listenQueueRevision == revision else { return }
                BeansLogger.shared.log("听视频队列预加载失败：\(error.localizedDescription)", level: .debug)
            }
        }
    }

    private func invalidateListenQueue() {
        listenQueueRevision += 1
        listenQueueTask?.cancel()
        listenQueueTask = nil
        listenSongKey = nil
        listenPlaybackRevision = nil
        expectedQueueKeys = []
    }

    private func updateListenQueue(_ request: CiliCiliVideoListenRequest) {
        let song = BilibiliListenQueue.song(request)
        guard let player, listenSongKey == song.identityKey,
              listenPlaybackRevision == player.queueContextRevision,
              player.currentSong?.identityKey == song.identityKey,
              player.queue.map(\.identityKey) == expectedQueueKeys else { return }
        let queue = BilibiliListenQueue.songs(for: request)
        guard queue.count > 1 else { return }
        player.updateBilibiliAudioContext(queue, currentSongKey: song.identityKey)
        expectedQueueKeys = player.queue.map(\.identityKey)
        listenQueueTask?.cancel()
        listenQueueTask = nil
    }

    private func synchronizeAccount() {
        let auth = BilibiliAuth.shared
        CiliCiliRuntime.shared.synchronizeLegacySession(
            cookie: auth.cookieHeader, name: auth.nickname, userID: auth.accountID,
            avatar: auth.avatarURL?.absoluteString
        )
    }
}

extension BilibiliNativeRoute {
    var ciliCiliRoute: CiliCiliRoute? {
        switch self {
        case .video(let song):
            let parts = (song.bilibiliID ?? "").split(separator: ":", maxSplits: 1)
            return .video(bvid: parts.first.map(String.init) ?? "", title: song.name,
                          cover: song.coverURL?.absoluteString, cid: parts.count > 1 ? Int(parts[1]) : nil)
        case .up(let artist):
            return .uploader(mid: Int(artist.id) ?? 0, name: artist.name, avatar: artist.coverURL?.absoluteString)
        case .live(let room): return .live(roomID: Int(room.id) ?? 0)
        case .collection(let item):
            return .collection(id: Int(item.number) ?? 0, isSeries: item.kind == .series,
                               ownerID: Int(item.ownerID) ?? 0, ownerName: item.ownerName, title: item.title)
        case .account: return .account
        case .playlist: return nil
        }
    }
}
