import Foundation
import AVFoundation

extension PlayerManager_2_0_3 {
    /// 0x10037ff28. Read uptime only when a new listening segment starts.
    public func beginListeningSegment(uptime: () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        guard listeningSegmentStartedUptime == nil else { return }
        listeningSegmentStartedUptime = uptime()
    }

    /// 0x10037f99c. End an active segment and flush its accumulated duration.
    /// No active segment means no flush, even if a pending amount already exists.
    public func endListeningSegment(uptime: () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        guard let started = listeningSegmentStartedUptime else { return }
        let elapsed = uptime() - started
        if elapsed > 0 { pendingListeningDuration = elapsed + pendingListeningDuration }
        listeningSegmentStartedUptime = nil
        flushListeningDuration(uptime: uptime)
    }

    /// 0x10037cf18. State/storage behavior; Combine publication remains separate.
    public func flushListeningDuration(uptime: () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        guard pendingListeningDuration > 0 else { return }
        _listeningDuration = pendingListeningDuration + _listeningDuration
        pendingListeningDuration = 0
        let persisted = _listeningDuration >= 0 ? _listeningDuration : 0
        defaults.set(persisted, forKey: "beans.playback.listeningDuration.v1")
        lastListeningPublishUptime = uptime()
    }

    /// 0x10037fa4c. Keep the legacy progress/song baselines separate from uptime.
    public func resetListeningProgressBaseline() {
        lastListeningProgress = nil
        lastListeningSongKey = nil
    }

    /// 0x1003921fc. The explicit status and clock closure are test seams.
    /// Original callers pass an AVPlayer; elapsed samples use system uptime.
    public func updateListeningDuration(
        timeControlStatus: AVPlayer.TimeControlStatus,
        uptime: () -> Double = { ProcessInfo.processInfo.systemUptime }
    ) {
        guard _isPlaying, timeControlStatus == .playing else {
            endListeningSegment(uptime: uptime)
            resetListeningProgressBaseline()
            return
        }
        beginListeningSegment(uptime: uptime)
        if let started = listeningSegmentStartedUptime {
            let now = uptime()
            let elapsed = now - started
            if elapsed > 0 {
                pendingListeningDuration = elapsed + pendingListeningDuration
                listeningSegmentStartedUptime = now
            }
        }
        if uptime() - lastListeningPublishUptime >= 15 {
            flushListeningDuration(uptime: uptime)
        }
    }
}
