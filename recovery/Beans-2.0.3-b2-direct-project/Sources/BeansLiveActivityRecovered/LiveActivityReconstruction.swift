import Foundation

// ActivityKit is available only when this source is built for an Apple target.
// Keeping the import and conformance conditional lets the evidence project be
// parsed on Windows while retaining the framework relationship recovered from
// the appex metadata.
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif

// Direct field reconstruction of BeansLiveActivity.appex from Beans 2.0.3 build 2.
/// Original type: BeansLiveActivity; kind: struct; descriptor: 0x8224; fields: 0.
/// The appex retains `BeansLiveActivity: SwiftUI.Widget` conformance and an
/// `@main` entry. Its body symbols prove ActivityConfiguration, a lock-screen
/// HStack/VStack view, and Dynamic Island regions. The source below preserves
/// that structure; system-image names are explicitly marked inferred because
/// the string argument is not retained in the field/symbol metadata.
#if canImport(ActivityKit) && canImport(WidgetKit) && canImport(SwiftUI)
@available(iOS 16.1, macOS 13.0, *)
@main
public struct BeansLiveActivity_2_0_3: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: BeansNowPlayingAttributes_2_0_3.self) { context in
            BeansNowPlayingLockScreenView_2_0_3(context: context)
                .activityBackgroundTint(Color.black.opacity(0.82))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BeansNowPlayingIcon_2_0_3(isPlaying: context.state.isPlaying)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.title).lineLimit(1)
                        Text(context.attributes.artist).lineLimit(1).font(.caption)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.lyric).lineLimit(1)
                }
            } compactLeading: {
                BeansNowPlayingIcon_2_0_3(isPlaying: context.state.isPlaying)
            } compactTrailing: {
                Text(context.state.lyric).lineLimit(1)
            } minimal: {
                BeansNowPlayingIcon_2_0_3(isPlaying: context.state.isPlaying)
            }
        }
    }
}

@available(iOS 16.1, macOS 13.0, *)
private struct BeansNowPlayingLockScreenView_2_0_3: View {
    let context: ActivityViewContext<BeansNowPlayingAttributes_2_0_3>

    var body: some View {
        HStack(spacing: 10) {
            BeansNowPlayingIcon_2_0_3(isPlaying: context.state.isPlaying)
                .frame(width: 34, height: 34)
                .background(Color.black, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.title).lineLimit(1)
                Text(context.attributes.artist).lineLimit(1).font(.caption)
                Text(context.state.lyric).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

@available(iOS 16.1, macOS 13.0, *)
private struct BeansNowPlayingIcon_2_0_3: View {
    let isPlaying: Bool

    var body: some View {
        // The binary proves Image(systemName:), Color, Circle, and the
        // foreground-style path. The exact literal system-image argument is
        // not retained, so these conventional names remain an inference.
        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.white)
    }
}
#else
public struct BeansLiveActivity_2_0_3 {}
#endif

/// Original type: BeansNowPlayingAttributes; kind: struct; descriptor: 0x8268; fields: 3.
public struct BeansNowPlayingAttributes_2_0_3: Codable, Hashable, Sendable {
    /// Original nested type: BeansNowPlayingAttributes.ContentState.
    /// The binary emits the nested nominal as `ContentState` and records the
    /// two stored fields as `Sb` (Bool) and `SS` (String).
    public struct ContentState: Codable, Hashable, Sendable {
        public var isPlaying: Bool = false
        public var lyric: String = ""

        public init(isPlaying: Bool = false, lyric: String = "") {
            self.isPlaying = isPlaying
            self.lyric = lyric
        }
    }

    public var songKey: String = ""
    public var title: String = ""
    public var artist: String = ""

    public init(songKey: String = "", title: String = "", artist: String = "") {
        self.songKey = songKey
        self.title = title
        self.artist = artist
    }
}

#if canImport(ActivityKit)
extension BeansNowPlayingAttributes_2_0_3: ActivityAttributes {}
#endif

/// Original type: CodingKeys; kind: enum; descriptor: 0x828c; fields: 3.
// CodingKeys is a synthesized CodingKeys enum; its cases are preserved in the evidence JSON.

/// Original type: CodingKeys; kind: enum; descriptor: 0x82b0; fields: 2.
// CodingKeys is a synthesized CodingKeys enum; its cases are preserved in the evidence JSON.

/// Original type: ContentState; kind: struct; descriptor: 0x82cc; fields: 2.
/// Compatibility spelling for the nested nominal recovered above. A typealias
/// preserves source usability without inventing a second nominal type that is
/// absent from the appex metadata.
public typealias ContentState_2_0_3 = BeansNowPlayingAttributes_2_0_3.ContentState
