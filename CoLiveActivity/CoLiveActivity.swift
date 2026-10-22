import ActivityKit
import SwiftUI
import WidgetKit

/// Co Live Activity 扩展视图：锁屏大卡片 + 灵动岛（紧凑/展开/最小）。
/// 风格：红白简洁 iOS 风格——锁屏卡片白底黑字、红色播放指示；灵动岛系统为深色底，故用白字。
/// 刻意不含自定义播放/切歌按钮：Live Activity 按钮需 AppIntent 且扩展进程无法直接调用主 App 的
/// PlayerManager，系统 Now Playing 的长按展开控制（播放/暂停/切歌/进度）已由
/// MPRemoteCommandCenter 提供，见 PlayerManager.setupRemoteCommands。
/// 点灵动岛/锁屏卡片回到 Co 应用是系统默认行为。
@main
struct CoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CocoNowPlayingAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: context.state.isPlaying ? "music.note" : "pause.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.red, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                    Text(context.attributes.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                Image(systemName: context.state.isPlaying ? "waveform" : "pause")
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .activityBackgroundTint(.white)
            .activitySystemActionForegroundColor(.red)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isPlaying ? "music.note" : "pause.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.title)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        Text(context.attributes.artist)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.isPlaying ? "waveform" : "pause")
                        .foregroundStyle(.white.opacity(0.8))
                }
            } compactLeading: {
                Image(systemName: "music.note")
                    .foregroundStyle(.white)
            } compactTrailing: {
                Image(systemName: context.state.isPlaying ? "waveform" : "pause")
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "music.note")
                    .foregroundStyle(.white)
            }
        }
    }
}
