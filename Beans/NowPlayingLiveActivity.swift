import ActivityKit
import Foundation

/// Updates the existing Beans widget extension without requesting an activity on every progress tick.
@MainActor
final class BeansNowPlayingLiveActivity {
    static let shared = BeansNowPlayingLiveActivity()
    private var activity: Activity<BeansNowPlayingAttributes>?
    private var lastState: BeansNowPlayingAttributes.ContentState?
    private var requestedSongKey: String?
    private var requestedState: BeansNowPlayingAttributes.ContentState?
    private var revision = 0

    func update(song: Song?, isPlaying: Bool) {
        let newState = BeansNowPlayingAttributes.ContentState(isPlaying: isPlaying)
        let authorizationEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        let authorizedSong = authorizationEnabled ? song : nil
        guard requestedSongKey != authorizedSong?.identityKey || requestedState != newState else { return }
        requestedSongKey = authorizedSong?.identityKey; requestedState = newState
        revision += 1
        let revision = revision
        Task {
            guard revision == self.revision else { return }
            guard let song = authorizedSong else {
                if let activity { await activity.end(nil, dismissalPolicy: .immediate) }
                guard revision == self.revision else { return }
                self.activity = nil; lastState = nil
                return
            }
            let state = BeansNowPlayingAttributes.ContentState(isPlaying: isPlaying)
            if activity?.attributes.songKey != song.identityKey {
                if let activity { await activity.end(nil, dismissalPolicy: .immediate) }
                guard revision == self.revision else { return }
                let attributes = BeansNowPlayingAttributes(songKey: song.identityKey, title: song.name, artist: song.artists)
                do {
                    activity = try Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil), pushType: nil)
                    lastState = state
                } catch {
                    // A failed request must not permanently suppress a later retry.
                    activity = nil
                    requestedSongKey = nil; requestedState = nil
                }
            } else if state != lastState, let activity {
                await activity.update(ActivityContent(state: state, staleDate: nil))
                if revision == self.revision { lastState = state }
            }
        }
    }
}
