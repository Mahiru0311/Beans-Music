import ActivityKit
import Foundation

/// Co Live Activity 管理器：把 2.0.3 的 BeansNowPlayingLiveActivity 移植为酷狗单平台版。
/// 不依赖网易云/QQ/CiliCili，只接收 PlayerManager 传来的当前歌曲与播放态。
/// 调用方（PlayerManager）必须用 `if #available(iOS 16.2, *)` 包裹调用，
/// 因为主 App 的部署目标低于 16.2，ActivityKit 只在 iOS 16.2+ 可用。
@available(iOS 16.2, *)
@MainActor
final class CocoNowPlayingLiveActivity {
    static let shared = CocoNowPlayingLiveActivity()

    private var activity: Activity<CocoNowPlayingAttributes>?
    private var lastSongKey: String?
    private var lastState: CocoNowPlayingAttributes.ContentState?
    private var requestedSongKey: String?
    private var requestedState: CocoNowPlayingAttributes.ContentState?
    private var revision = 0

    private init() {}

    func update(song: Song?, isPlaying: Bool) {
        let newState = CocoNowPlayingAttributes.ContentState(isPlaying: isPlaying)
        let authorizedSong = ActivityAuthorizationInfo().areActivitiesEnabled ? song : nil
        guard requestedSongKey != authorizedSong?.identityKey || requestedState != newState else { return }
        requestedSongKey = authorizedSong?.identityKey
        requestedState = newState
        revision += 1
        let currentRevision = revision
        Task {
            guard currentRevision == self.revision else { return }
            guard let song = authorizedSong else {
                if let activity = self.activity {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
                guard currentRevision == self.revision else { return }
                self.activity = nil
                self.lastState = nil
                return
            }
            let state = CocoNowPlayingAttributes.ContentState(isPlaying: isPlaying)
            if activity?.attributes.songKey != song.identityKey {
                if let activity = self.activity {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
                guard currentRevision == self.revision else { return }
                let attributes = CocoNowPlayingAttributes(
                    songKey: song.identityKey,
                    title: song.name,
                    artist: song.artists
                )
                do {
                    self.activity = try Activity.request(
                        attributes: attributes,
                        content: ActivityContent(state: state, staleDate: nil),
                        pushType: nil
                    )
                    self.lastState = state
                } catch {
                    // 请求失败（如用户在设置里关了 Live Activity）不永久压制后续重试。
                    self.activity = nil
                    self.requestedSongKey = nil
                    self.requestedState = nil
                }
            } else if state != self.lastState, let activity = self.activity {
                await activity.update(ActivityContent(state: state, staleDate: nil))
                self.lastState = state
            }
        }
    }

    func end() {
        revision += 1
        requestedSongKey = nil
        requestedState = nil
        Task {
            if let activity = self.activity {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            self.activity = nil
            self.lastState = nil
        }
    }
}
