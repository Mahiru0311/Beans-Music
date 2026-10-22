import ActivityKit
import Foundation

/// Co Live Activity 属性（与 2.0.3 的 BeansNowPlayingAttributes 同构，只改名，不带网易云/QQ）。
/// 刻意保持最小：只含歌名/歌手/播放态，不含封面图片、不含进度。
/// 原因：封面大图塞进 Activity 状态会超限、且扩展进程读不到主 App 的图片缓存；
/// 封面由系统 Now Playing（MPNowPlayingInfoCenter）负责，见 PlayerManager.updateNowPlaying；
/// 进度每秒更新会触 ActivityKit 限频且费电，进度由系统 Now Playing 与锁屏媒体控制负责。
@available(iOS 16.1, *)
struct CocoNowPlayingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let isPlaying: Bool
    }

    let songKey: String
    let title: String
    let artist: String
}
