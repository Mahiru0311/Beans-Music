import ActivityKit
import Foundation

/// 不再请求 Co 自己的实时活动。
///
/// 根因（2026-10-24 用户实测：播放时出现两个灵动岛）：
/// 播放时 iOS 本来就会因为 MPNowPlayingInfoCenter + 音频会话自动给一个
/// “正在播放”的灵动岛/锁屏（歌名、封面、控制都在），而 Co 又用 ActivityKit
/// 额外请求了一个只显示歌名/歌手的实时活动，两者在灵动岛里并排出现。
/// 系统那一路不能也不应关（关了锁屏、控制中心、耳机控制全没了），所以
/// 正确修法是停掉 Co 这一路，只留系统正在播放。
///
/// update() 因此只做一件事：把旧版本已发出的活动清掉，永不新发。
/// 扩展目标 BeansLiveActivity 本身不动（删目标要改工程配置，收益为零），
/// 没有活动请求时它永远不会被系统拉起。
@MainActor
final class BeansNowPlayingLiveActivity {
    static let shared = BeansNowPlayingLiveActivity()
    private var staleCleanupDone = false

    func update(song: Song?, isPlaying: Bool) {
        // 只在第一次调用时清一次旧活动；之后不再碰 ActivityKit，
        // 也就不会再产生第二个灵动岛。
        guard !staleCleanupDone else { return }
        staleCleanupDone = true
        Task {
            for activity in Activity<BeansNowPlayingAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
