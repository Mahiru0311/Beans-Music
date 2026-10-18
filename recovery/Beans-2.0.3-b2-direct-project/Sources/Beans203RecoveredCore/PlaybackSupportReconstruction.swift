import Foundation

// Models reconstructed from Beans 2.0.3 build 2 IPA field metadata.

/// Original type: BeansProcessMetrics; kind: class; descriptor: 0x7c3c70; fields: 5.
public final class BeansProcessMetrics_2_0_3 {
    /// Original field: lock; encoding: `So6NSLockC`.
    public var lock: NSLock = NSLock()
    /// Original field: value; decoded type: `BeansResourceSnapshot`.
    public var value: BeansResourceSnapshot_2_0_3 = BeansResourceSnapshot_2_0_3()
    /// Original field: timer; encoding: `So24OS_dispatch_source_timer_pSg`.
    public var timer: DispatchSourceTimer? = nil
    /// Original fields: `previousCPU` and `previousUptime`; encoding: `SdSg`.
    public var previousCPU: Double? = nil
    public var previousUptime: Double? = nil

    public init() {}
}

/// Original nominal: BeansNowPlayingAttributes; descriptor: 0x7c3dc4; fields: 3.
/// The IPA also contains generated CodingKeys for all three fields.
public struct BeansNowPlayingAttributes_2_0_3: Codable, Hashable, Sendable {
    public var songKey: String
    public var title: String
    public var artist: String

    public init(songKey: String = "", title: String = "", artist: String = "") {
        self.songKey = songKey
        self.title = title
        self.artist = artist
    }
}

/// Original nominal: ContentState; descriptor: 0x7c3de0; fields: 2.
/// Generated CodingKeys in the IPA confirm Codable synthesis.
public struct BeansContentState_2_0_3: Codable, Hashable, Sendable {
    public var isPlaying: Bool
    public var lyric: String

    public init(isPlaying: Bool = false, lyric: String = "") {
        self.isPlaying = isPlaying
        self.lyric = lyric
    }
}
