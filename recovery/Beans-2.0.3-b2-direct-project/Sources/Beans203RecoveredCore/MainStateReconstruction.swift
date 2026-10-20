import Foundation
import AVFoundation
import Combine

// Additional main-program state reconstruction from Beans 2.0.3 build 2 field metadata only.
// Unknown generic/closure/framework payloads remain Any.

/// Original type: QishuiAPI; kind: class; descriptor: 0x7c987c; fields: 9.
public final class QishuiAPI_2_0_3 {
    /// Original field: session; encoding: So12NSURLSessionC; flags: 0x0.
    public var session: URLSession = .shared
    /// Original field: songSearchCache; encoding: <unresolved>; flags: 0x0.
    public var songSearchCache: NSCache<NSString, QishuiCacheBox_2_0_3<[Song_2_0_3]>> = NSCache()
    /// Original field: playlistSearchCache; encoding: <unresolved>; flags: 0x0.
    public var playlistSearchCache: NSCache<NSString, QishuiCacheBox_2_0_3<[Playlist_2_0_3]>> = NSCache()
    /// Original field: recommendationCache; encoding: <unresolved>; flags: 0x0.
    public var recommendationCache: NSCache<NSString, QishuiCacheBox_2_0_3<[Playlist_2_0_3]>> = NSCache()
    /// Original field: playlistDetailsCache; encoding: <unresolved>; flags: 0x0.
    public var playlistDetailsCache: NSCache<NSString, QishuiCacheBox_2_0_3<QishuiPlaylistDetails_2_0_3>> = NSCache()
    /// Original field: songSearchTTL; encoding: Sd; flags: 0x0.
    public var songSearchTTL: Double = 300
    /// Original field: playlistSearchTTL; encoding: Sd; flags: 0x0.
    public var playlistSearchTTL: Double = 300
    /// Original field: recommendationTTL; encoding: Sd; flags: 0x0.
    public var recommendationTTL: Double = 1800
    /// Original field: playlistDetailsTTL; encoding: Sd; flags: 0xfff4e4a0.
    public var playlistDetailsTTL: Double = 1800

    // Reconstruction-only dependency seams; these are not claimed as IPA fields.
    let recoveryDefaults: UserDefaults
    let recoveryVersion: String?

    /// Initialization recovered from 0x10056a5d0 (session and cache settings).
    public init(session: URLSession? = nil, defaults: UserDefaults = .standard, version: String? = nil) {
        recoveryDefaults = defaults
        recoveryVersion = version
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 30
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
        songSearchCache.countLimit = 40
        playlistSearchCache.countLimit = 40
        recommendationCache.countLimit = 8
        playlistDetailsCache.countLimit = 24
    }
}

/// Original type: AuthStore; kind: class; descriptor: 0x7c358c; fields: 5.
public final class AuthStore_2_0_3 {
    /// Original field: _user; encoding: <unresolved>; flags: 0x2.
    public var _user: Any = ()
    /// Original field: _isLoggedIn; encoding: <unresolved>; flags: 0x2.
    public var _isLoggedIn: Any = ()
    /// Original field: _playlists; encoding: <unresolved>; flags: 0x0.
    public var _playlists: Any = ()
    /// Original field: defaults; encoding: So14NSUserDefaultsC; flags: 0x0.
    public var defaults: UserDefaults = .standard
    /// Original field: userKey; encoding: SS; flags: 0xffd5f1a6.
    public var userKey: String = ""
}

/// Original type: BeansCacheManager; kind: class; descriptor: 0x7c3674; fields: 3.
public final class BeansCacheManager_2_0_3 {
    /// `Published<[BeansCacheUsage]>` is decoded from `_usage`
    /// (`ySayBeansCacheUsageGG`).
    @Published public var usage: [BeansCacheUsage_2_0_3] = []
    /// `Published<Bool>` is decoded from `_working` (`ySbG`).
    @Published public var working: Bool = false
    /// `Published<String?>` is decoded from `_message` (`ySSSgG`).
    @Published public var message: String? = nil

    public init() {}
}

/// Original type: BeansDiagnostics; kind: class; descriptor: 0x7c3808; fields: 13.
public final class BeansDiagnostics_2_0_3 {
    /// The three underscore fields are `Published` backing storage in the
    /// binary (`ySSG`, `yDate?G`, and `ySbG`).
    @Published public var lastRoute: String = ""
    @Published public var lastSnapshotDate: Date? = nil
    @Published public var enabled: Bool = false
    /// Original field: lock; encoding: So6NSLockC; flags: 0x2.
    public var lock: NSLock = NSLock()
    /// Original field: recordingEnabled; encoding: Sb; flags: 0x2.
    public var recordingEnabled: Bool = false
    /// Original field: values; encoding: SDyS2SG; flags: 0x2.
    public var values: [String: String] = [:]
    /// Original field: started; encoding: Sb; flags: 0x2.
    public var started: Bool = false
    /// Original field: timer; encoding: So24OS_dispatch_source_timer_pSg; flags: 0x0.
    public var timer: DispatchSourceTimer? = nil
    /// Original field: monitorQueue; encoding: So17OS_dispatch_queueC; flags: 0x2.
    public var monitorQueue: DispatchQueue = DispatchQueue(label: "Beans203Recovered.Diagnostics")
    /// Original field: pendingBeat; encoding: SdSg; flags: 0x2.
    public var pendingBeat: Double? = nil
    /// Original field: reportedHang; encoding: Sb; flags: 0x2.
    public var reportedHang: Bool = false
    /// Original field: foreground; encoding: Sb; flags: 0x2.
    public var foreground: Bool = false
    /// Original field: observers; encoding: SaySo8NSObject_pG; flags: 0xffd64d74.
    public var observers: [NSObjectProtocol] = []

    public init() {}
}

/// Original nominal: BeansResourceSnapshot; descriptor: 0x7c3cb8; fields: 4.
public struct BeansResourceSnapshot_2_0_3 {
    /// The IPA keeps this symbolic integer unresolved; it is retained as Any
    /// rather than choosing signedness from the field name alone.
    public var memoryBytes: Any
    public var cpuPercent: Double
    public var sampledAt: Date
    public var available: Bool
    public init(memoryBytes: Any = 0, cpuPercent: Double = 0,
                sampledAt: Date = Date(), available: Bool = false) {
        self.memoryBytes = memoryBytes; self.cpuPercent = cpuPercent
        self.sampledAt = sampledAt; self.available = available
    }
}

/// Original nominal: BeansLogLevel; descriptor: 0x7c3d50; fields: 5.
public enum BeansLogLevel_2_0_3: CaseIterable, Hashable, Sendable {
    case debug, info, warn, error, fatal
}

/// Original nominal: BeansLogEntry; descriptor: 0x7c3ce0; fields: 14.
public struct BeansLogEntry_2_0_3 {
    public var id: UUID
    public var date: Date
    public var level: BeansLogLevel_2_0_3
    public var message: String
    public var module: String
    public var file: String
    public var function: String
    public var sourceLine: Int
    /// The typeref is retained symbolically in the IPA; no signedness guess.
    public var threadID: Any
    public var isMainThread: Bool
    public var device: String
    public var resources: BeansResourceSnapshot_2_0_3
    public var context: [String: String]
    public init(id: UUID = UUID(), date: Date = Date(), level: BeansLogLevel_2_0_3 = .debug,
                message: String = "", module: String = "", file: String = "",
                function: String = "", sourceLine: Int = 0, threadID: Any = 0,
                isMainThread: Bool = false, device: String = "",
                resources: BeansResourceSnapshot_2_0_3 = BeansResourceSnapshot_2_0_3(),
                context: [String: String] = [:]) {
        self.id = id; self.date = date; self.level = level; self.message = message
        self.module = module; self.file = file; self.function = function
        self.sourceLine = sourceLine; self.threadID = threadID
        self.isMainThread = isMainThread; self.device = device
        self.resources = resources; self.context = context
    }
}

/// Original type: BeansLogger; kind: class; descriptor: 0x7c3c28; fields: 20.
public final class BeansLogger_2_0_3 {
    /// `Published<[BeansLogEntry]>` is decoded from `_entries`.
    @Published public var entries: [BeansLogEntry_2_0_3] = []
    /// Original field: queue; encoding: So17OS_dispatch_queueC; flags: 0x0.
    public var queue: DispatchQueue = DispatchQueue(label: "Beans203Recovered.Logger")
    /// Original field: queueKey; encoding: <unresolved>; flags: 0x0.
    public var queueKey: Any = ()
    /// The same IPA symbolic target is resolved as Foundation.URL elsewhere.
    public var root: URL = URL(fileURLWithPath: "/")
    /// Original field: maxFileBytes; encoding: Si; flags: 0x0.
    public var maxFileBytes: Int = 0
    /// Original field: maxTotalBytes; encoding: Si; flags: 0x0.
    public var maxTotalBytes: Int = 0
    /// Original field: consoleEnabled; encoding: Sb; flags: 0x0.
    public var consoleEnabled: Bool = false
    /// Original field: console; encoding: unresolved.
    public var console: Any = ()
    /// Original field: stateLock; encoding: So6NSLockC; flags: 0x2.
    public var stateLock: NSLock = NSLock()
    /// Original fields: snapshot/recent; decoded type `[BeansLogEntry]`.
    public var snapshot: [BeansLogEntry_2_0_3] = []
    public var recent: [BeansLogEntry_2_0_3] = []
    /// Original field: viewers; encoding: Si; flags: 0x2.
    public var viewers: Int = 0
    /// Original field: publicationPending; encoding: Sb; flags: 0x2.
    public var publicationPending: Bool = false
    /// Original field: handle; encoding: So12NSFileHandleCSg; flags: 0x2.
    public var handle: FileHandle? = nil
    /// Original field: activeDay; encoding: SS; flags: 0x2.
    public var activeDay: String = ""
    /// Original field: activeBytes; encoding: Si; flags: 0x2.
    public var activeBytes: Int = 0
    /// URL/Date symbolic targets are resolved by the same Foundation records.
    public var activeURL: URL? = nil
    public var lastPrune: Date? = nil
    public var lastContextWrite: Date? = nil
    /// Original field: device; encoding: SS; flags: 0xffd687ac.
    public var device: String = ""

    public init() {}
}

/// Original nominal: BiquadState; descriptor: 0x7c3a10; fields: 2.
public struct BiquadState_2_0_3: Sendable, Hashable {
    public var z1: Float
    public var z2: Float
    public init(z1: Float = 0, z2: Float = 0) {
        self.z1 = z1; self.z2 = z2
    }
}

/// Original nominal: BiquadCoefficients; descriptor: 0x7c3a34; fields: 6.
public struct BiquadCoefficients_2_0_3: Sendable, Hashable {
    public var b0: Float
    public var b1: Float
    public var b2: Float
    public var a1: Float
    public var a2: Float
    public init(b0: Float = 0, b1: Float = 0, b2: Float = 0,
                a1: Float = 0, a2: Float = 0) {
        self.b0 = b0; self.b1 = b1; self.b2 = b2
        self.a1 = a1; self.a2 = a2
    }
}

/// Original nominal: BeansEqualizerCustomPreset; descriptor: 0x7c3a50; fields: 4.
public struct BeansEqualizerCustomPreset_2_0_3: Sendable, Hashable {
    public var id: String
    public var name: String
    public var gains: [Double]
    public var preampGain: Double
    public init(id: String = "", name: String = "", gains: [Double] = [], preampGain: Double = 0) {
        self.id = id; self.name = name; self.gains = gains; self.preampGain = preampGain
    }
}

/// Original nominal: BeansEqualizerPreset; descriptor: 0x7c3a6c; fields: 8.
public enum BeansEqualizerPreset_2_0_3: CaseIterable, Hashable, Sendable {
    case flat, bass, vocal, pop, rock, classical, jazz, electronic
}

/// Original type: BeansEqualizer; kind: class; descriptor: 0x7c39c0; fields: 16.
public final class BeansEqualizer_2_0_3 {
    /// Published backing fields decoded as `Bool`, `[Double]`, preset,
    /// optional String, and Double respectively.
    @Published public var isEnabled: Bool = false
    @Published public var bandGains: [Double] = []
    @Published public var selectedPreset: BeansEqualizerPreset_2_0_3 = .flat
    @Published public var selectedCustomPresetName: String? = nil
    @Published public var preampGain: Double = 0
    public var customPresets: [BeansEqualizerCustomPreset_2_0_3] = []
    /// Original field: defaults; encoding: So14NSUserDefaultsC; flags: 0x0.
    public var defaults: UserDefaults = .standard
    /// Original field: configurationLock; encoding: So6NSLockC; flags: 0x2.
    public var configurationLock: NSLock = NSLock()
    /// Original field: processingEnabled; encoding: Sb; flags: 0x2.
    public var processingEnabled: Bool = false
    /// Original field: processingGains; encoding: SaySdG; flags: 0x2.
    public var processingGains: [Double] = []
    /// Original field: processingPreampLinear; encoding: Sf; flags: 0x2.
    public var processingPreampLinear: Float = 0
    /// Original field: processingFormatIsFloat32; encoding: Sb; flags: 0x2.
    public var processingFormatIsFloat32: Bool = false
    /// Original field: sampleRate; encoding: Sd; flags: 0x2.
    public var sampleRate: Double = 0
    /// Original field: coefficients; decoded type: `[BiquadCoefficients]`.
    public var coefficients: [BiquadCoefficients_2_0_3] = []
    /// Original field: filterStates; decoded type: `[BiquadState]`.
    public var filterStates: [BiquadState_2_0_3] = []
    /// Original field: pendingPersistWorkItem; encoding: <unresolved>; flags: 0xffd6857a.
    public var pendingPersistWorkItem: Any = ()

    public init() {}
}

/// Original type: CustomSongCoverStore; kind: class; descriptor: 0x7c5abc; fields: 5.
public final class CustomSongCoverStore_2_0_3 {
    /// Original field: _revision; encoding: <unresolved>; flags: 0x0.
    public var _revision: Any = ()
    /// Original field: legacyDefaultsKey; encoding: SS; flags: 0x0.
    public var legacyDefaultsKey: String = ""
    /// Original field: defaultsKey; encoding: SS; flags: 0x0.
    public var defaultsKey: String = ""
    /// Original field: directory; encoding: <unresolved>; flags: 0x2.
    public var directory: Any = ()
    /// Original field: entries; encoding: <unresolved>; flags: 0xffd79158.
    public var entries: Any = ()
}

/// Original type: RemoteControlStore; kind: class; descriptor: 0x7ca108; fields: 5.
public final class RemoteControlStore_2_0_3 {
    /// Original field: configURL; encoding: <unresolved>; flags: 0x0.
    public var configURL: Any = ()
    /// Original field: appliedKeysKey; encoding: SS; flags: 0x0.
    public var appliedKeysKey: String = ""
    /// Original field: originalPrefix; encoding: SS; flags: 0x2.
    public var originalPrefix: String = ""
    /// Original field: isLoading; encoding: Sb; flags: 0x2.
    public var isLoading: Bool = false
    /// Original field: lastRefresh; encoding: <unresolved>; flags: 0xfff784da.
    public var lastRefresh: Any = ()
}

/// Original type: IPADownloader; kind: class; descriptor: 0x7c6c80; fields: 7.
public final class IPADownloader_2_0_3 {
    /// Original field: _state; encoding: <unresolved>; flags: 0x2.
    public var _state: Any = ()
    /// Original field: _progress; encoding: <unresolved>; flags: 0x2.
    public var _progress: Any = ()
    /// Original field: _isDownloading; encoding: <unresolved>; flags: 0x2.
    public var _isDownloading: Any = ()
    /// Original field: session; encoding: So12NSURLSessionCSg; flags: 0x2.
    public var session: URLSession? = nil
    /// Original field: task; encoding: So24NSURLSessionDownloadTaskCSg; flags: 0x2.
    public var task: URLSessionDownloadTask? = nil
    /// Original field: continuation; encoding: <unresolved>; flags: 0x2.
    public var continuation: Any = ()
    /// Original field: destination; encoding: <unresolved>; flags: 0xffdc8470.
    public var destination: Any = ()
}

/// Original type: SongFileDownloadTransfer; kind: class; descriptor: 0x7c65f4; fields: 7.
public final class SongFileDownloadTransfer_2_0_3 {
    /// Original field: onProgress; encoding: ySdSgScMYcc; flags: 0x0.
    public var onProgress: Any = ()
    /// Original field: lock; encoding: So6NSLockC; flags: 0x2.
    public var lock: NSLock = NSLock()
    /// Original field: continuation; encoding: <unresolved>; flags: 0x2.
    public var continuation: Any = ()
    /// Original field: session; encoding: So12NSURLSessionCSg; flags: 0x2.
    public var session: URLSession? = nil
    /// Original field: downloadTask; encoding: So24NSURLSessionDownloadTaskCSg; flags: 0x2.
    public var downloadTask: URLSessionDownloadTask? = nil
    /// Original field: cancellationRequested; encoding: Sb; flags: 0x2.
    public var cancellationRequested: Bool = false
    /// Original field: lastProgressUpdate; the IPA-relative typeref resolves
    /// to `Foundation.Date` (the same target as `savedAt` fields).
    public var lastProgressUpdate: Date = Date()
}

/// Original type: PlayerManager; kind: class; descriptor: 0x7c8814; fields: 109.
public final class PlayerManager_2_0_3 {
    /// Original field: _queue; encoding: <unresolved>; flags: 0x2.
    public var _queue: [Song_2_0_3] = []
    /// Original field: _currentIndex; encoding: <unresolved>; flags: 0x2.
    public var _currentIndex: Int = 0
    /// Original field: _isPlaying; encoding: <unresolved>; flags: 0x2.
    public var _isPlaying: Bool = false
    /// Original field: _isBuffering; encoding: <unresolved>; flags: 0x2.
    public var _isBuffering: Bool = false
    /// Original field: _loadFailed; encoding: <unresolved>; flags: 0x2.
    public var _loadFailed: Bool = false
    /// Original field: loadGeneration; encoding: Si; flags: 0x0.
    public var loadGeneration: Int = 0
    /// Original field: clock; encoding: <unresolved>; flags: 0x2.
    public var clock: PlaybackClock_2_0_3 = PlaybackClock_2_0_3()
    /// Original field: progress; encoding: Sd; flags: 0x2.
    public var progress: Double = 0
    /// Original field: duration; encoding: Sd; flags: 0x2.
    public var duration: Double = 0
    /// Original field: _playMode; encoding: <unresolved>; flags: 0x2.
    public var _playMode: PlayMode_2_0_3 = .sequential
    /// Original field: _rate; encoding: <unresolved>; flags: 0x2.
    public var _rate: Double = 1
    /// Original field: _softwareVolume; encoding: <unresolved>; flags: 0x2.
    public var _softwareVolume: Double = 1
    /// Original field: _sleepTimerEndsAt; encoding: <unresolved>; flags: 0x2.
    public var _sleepTimerEndsAt: Date? = nil
    /// Original field: _sleepTimerRemaining; encoding: <unresolved>; flags: 0x2.
    public var _sleepTimerRemaining: Int = 0
    /// Original field: _stopAfterCurrentSong; encoding: <unresolved>; flags: 0x2.
    public var _stopAfterCurrentSong: Bool = false
    /// Original field: _history; encoding: <unresolved>; flags: 0x2.
    public var _history: [Song_2_0_3] = []
    /// Original field: _playCounts; encoding: <unresolved>; flags: 0x2.
    public var _playCounts: [String: Int] = [:]
    /// Original field: _listeningDuration; encoding: <unresolved>; flags: 0x2.
    public var _listeningDuration: Double = 0
    /// Original field: _seekRevision; encoding: <unresolved>; flags: 0x2.
    public var _seekRevision: Int = 0
    /// Original field: lyricProgress; encoding: Sd; flags: 0x2.
    public var lyricProgress: Double = 0
    /// Original field: player; encoding: So8AVPlayerCSg; flags: 0x2.
    public var player: AVPlayer? = nil
    /// Original field: timeObserver; encoding: ypSg (`Any?`); flags: 0x2.
    public var timeObserver: Any? = nil
    /// Original field: endObserver; encoding: So8NSObject_pSg; flags: 0x2.
    public var endObserver: NSObjectProtocol? = nil
    /// Original field: failureObserver; encoding: So8NSObject_pSg; flags: 0x2.
    public var failureObserver: NSObjectProtocol? = nil
    /// Original field: itemStatusObserver; encoding: <unresolved>; flags: 0x2.
    public var itemStatusObserver: Any = ()
    /// Original field: timeControlStatusObserver; encoding: <unresolved>; flags: 0x2.
    public var timeControlStatusObserver: Any = ()
    /// Original field: equalizerSettingsObserver; encoding: So8NSObject_pSg; flags: 0x2.
    public var equalizerSettingsObserver: NSObjectProtocol? = nil
    /// Original field: backendBlockObserver; encoding: So8NSObject_pSg; flags: 0x2.
    public var backendBlockObserver: NSObjectProtocol? = nil
    /// Original field: customCoverObserver; encoding: So8NSObject_pSg; flags: 0x2.
    public var customCoverObserver: NSObjectProtocol? = nil
    /// Original field: lockScreenArtworkObserver; encoding: So8NSObject_pSg; flags: 0x2.
    public var lockScreenArtworkObserver: NSObjectProtocol? = nil
    /// Original field: $__lazy_storage_$_lockScreenArtwork; encoding: <unresolved>; flags: 0x2.
    public var field_30____lazy_storage___lockScreenArtwork: Any = ()
    /// Original field: listeningStatsObserver; encoding: So8NSObject_pSg; flags: 0x2.
    public var listeningStatsObserver: NSObjectProtocol? = nil
    /// Original field: playbackConfirmed; encoding: Sb; flags: 0x2.
    public var playbackConfirmed: Bool = false
    /// Original field: pendingThirdPartyVIPNotice; encoding: <unresolved>; flags: 0x2.
    public var pendingThirdPartyVIPNotice: ThirdPartyVIPNotice_2_0_3? = nil
    /// Original field: sessionConfigured; encoding: Sb; flags: 0x2.
    public var sessionConfigured: Bool = false
    /// Original field: systemPlaybackPrepared; encoding: Sb; flags: 0x2.
    public var systemPlaybackPrepared: Bool = false
    /// Original field: routeObserverInstalled; encoding: Sb; flags: 0x2.
    public var routeObserverInstalled: Bool = false
    /// Original field: interruptionObserverInstalled; encoding: Sb; flags: 0x2.
    public var interruptionObserverInstalled: Bool = false
    /// Original field: secondaryAudioHintObserverInstalled; encoding: Sb; flags: 0x2.
    public var secondaryAudioHintObserverInstalled: Bool = false
    /// Original field: mediaServicesObserverInstalled; encoding: Sb; flags: 0x2.
    public var mediaServicesObserverInstalled: Bool = false
    /// Original field: applicationAudioObserverInstalled; encoding: Sb; flags: 0x2.
    public var applicationAudioObserverInstalled: Bool = false
    /// Original field: applicationIsInBackground; encoding: Sb; flags: 0x2.
    public var applicationIsInBackground: Bool = false
    /// Original field: remoteCommandsInstalled; encoding: Sb; flags: 0x2.
    public var remoteCommandsInstalled: Bool = false
    /// Original field: playOrder; encoding: SaySiG; flags: 0x2.
    public var playOrder: [Int] = []
    /// Original field: orderPosition; encoding: Si; flags: 0x2.
    public var orderPosition: Int = 0
    /// Original field: sleepTimer; encoding: So7NSTimerCSg; flags: 0x2.
    public var sleepTimer: Timer? = nil
    /// Original field: lastCountedSongID; encoding: SSSg; flags: 0x2.
    public var lastCountedSongID: String? = nil
    /// Original field: wasPlayingBeforeInterruption; encoding: Sb; flags: 0x2.
    public var wasPlayingBeforeInterruption: Bool = false
    /// Original field: interruptionInProgress; encoding: Sb; flags: 0x2.
    public var interruptionInProgress: Bool = false
    /// Original field: interruptionResumeWorkItem; encoding: <unresolved>; flags: 0x2.
    public var interruptionResumeWorkItem: Any = ()
    /// Original field: audioRecoveryWorkItem; encoding: <unresolved>; flags: 0x2.
    public var audioRecoveryWorkItem: Any = ()
    /// Original field: audioSessionWatchdogTimer; encoding: So7NSTimerCSg; flags: 0x2.
    public var audioSessionWatchdogTimer: Timer? = nil
    /// Original field: shouldResumeAfterAudioLoss; encoding: Sb; flags: 0x2.
    public var shouldResumeAfterAudioLoss: Bool = false
    /// Original field: audioLossInProgress; encoding: Sb; flags: 0x2.
    public var audioLossInProgress: Bool = false
    /// Original field: lastNowPlayingRefreshUptime; encoding: Sd; flags: 0x2.
    public var lastNowPlayingRefreshUptime: Double = 0
    /// Original field: lastPublishedProgress; encoding: Sd; flags: 0x2.
    public var lastPublishedProgress: Double = 0
    /// Original field: seekState; encoding: <unresolved>; flags: 0x2.
    public var seekState: PlaybackSeekState_2_0_3 = PlaybackSeekState_2_0_3()
    /// Original field: lastPersistedProgress; encoding: Sd; flags: 0x2.
    public var lastPersistedProgress: Double = 0
    /// Original field: lastListeningProgress; encoding: SdSg; flags: 0x2.
    public var lastListeningProgress: Double? = nil
    /// Original field: lastListeningSongKey; encoding: SSSg; flags: 0x2.
    public var lastListeningSongKey: String? = nil
    /// Original field: pendingListeningDuration; encoding: Sd; flags: 0x2.
    public var pendingListeningDuration: Double = 0
    /// Original field: listeningSegmentStartedUptime; encoding: SdSg; flags: 0x2.
    public var listeningSegmentStartedUptime: Double? = nil
    /// Original field: lastListeningPublishUptime; encoding: Sd; flags: 0x0.
    public var lastListeningPublishUptime: Double = 0
    /// Original field: playbackPersistenceQueue; encoding: So17OS_dispatch_queueC; flags: 0x2.
    public var playbackPersistenceQueue: DispatchQueue = DispatchQueue(label: "Beans203Recovered.PlayerPersistence")
    /// Original field: lastNowPlayingArtworkKey; encoding: SSSg; flags: 0x2.
    public var lastNowPlayingArtworkKey: String? = nil
    /// Original field: nowPlayingArtworkImage; encoding: So7UIImageCSg; flags: 0x2.
    public var nowPlayingArtworkImage: Any = ()
    /// Original field: nowPlayingArtworkRequests; encoding: <unresolved>; flags: 0x2.
    public var nowPlayingArtworkRequests: Any = ()
    /// Original field: audioLoadSpan; encoding: <unresolved>; flags: 0x2.
    public var audioLoadSpan: Any = ()
    /// Original field: audioDiagnosticTask; encoding: <unresolved>; flags: 0x2.
    public var audioDiagnosticTask: Any = ()
    /// Original field: audioResolutionTask; encoding: <unresolved>; flags: 0x2.
    public var audioResolutionTask: Any = ()
    /// Original field: preparationTimeoutWorkItem; encoding: <unresolved>; flags: 0x2.
    public var preparationTimeoutWorkItem: Any = ()
    /// Original field: preparationFailure; encoding: yycSg; flags: 0x2.
    public var preparationFailure: (() -> Void)? = nil
    /// Original field: nowPlayingSongKey; encoding: SSSg; flags: 0x2.
    public var nowPlayingSongKey: String? = nil
    /// Original field: nowPlayingInfo; encoding: SDySSypG (`[String: Any]`); flags: 0x2.
    public var nowPlayingInfo: [String: Any] = [:]
    /// Original field: kugouStandardFallbackSongKey; encoding: SSSg; flags: 0x2.
    public var kugouStandardFallbackSongKey: String? = nil
    /// Original field: thirdPartyRetryExcludedHostsBySong; encoding: SDySSShySSGG; flags: 0x2.
    public var thirdPartyRetryExcludedHostsBySong: [String: Set<String>] = [:]
    /// Original field: attemptedThirdPartyQualitiesBySong; encoding: SDySSShySSGG; flags: 0x2.
    public var attemptedThirdPartyQualitiesBySong: [String: Set<String>] = [:]
    /// Original field: activeThirdPartyQuality; encoding: <unresolved>; flags: 0x2.
    public var activeThirdPartyQuality: ThirdPartyAudioQuality_2_0_3? = nil
    /// Original field: attemptedQQOfficialBRsBySong; encoding: SDySSShySSGG; flags: 0x2.
    public var attemptedQQOfficialBRsBySong: [String: Set<String>] = [:]
    /// Original field: activeQQOfficialBR; encoding: SSSg; flags: 0x2.
    public var activeQQOfficialBR: String? = nil
    /// Original field: bilibiliPlaybackAlternatives; encoding: <unresolved>; flags: 0x2.
    public var bilibiliPlaybackAlternatives: [URL] = []
    /// Original field: bilibiliRetryScheduled; encoding: Sb; flags: 0x2.
    public var bilibiliRetryScheduled: Bool = false
    /// Original field: bilibiliQueueLoader; encoding: yycSg; flags: 0x2.
    public var bilibiliQueueLoader: (() -> Void)? = nil
    /// Original field: bilibiliQueueID; encoding: <unresolved>; flags: 0x2.
    public var bilibiliQueueID: UUID? = nil
    /// Original field: playbackRecoveryInFlightSongKey; encoding: SSSg; flags: 0x2.
    public var playbackRecoveryInFlightSongKey: String? = nil
    /// Original field: finalizedFailureSongKey; encoding: SSSg; flags: 0x2.
    public var finalizedFailureSongKey: String? = nil
    /// Original field: failureAutoSkipWorkItem; encoding: <unresolved>; flags: 0x2.
    public var failureAutoSkipWorkItem: Any = ()
    /// Original field: qqThirdPartyFallbackSongKey; encoding: SSSg; flags: 0x2.
    public var qqThirdPartyFallbackSongKey: String? = nil
    /// Original field: playbackConfirmationWorkItem; encoding: <unresolved>; flags: 0x2.
    public var playbackConfirmationWorkItem: Any = ()
    /// Original field: playbackStallWorkItem; encoding: <unresolved>; flags: 0x2.
    public var playbackStallWorkItem: Any = ()
    /// Original field: thirdPartyPrefetchTask; encoding: <unresolved>; flags: 0x2.
    public var thirdPartyPrefetchTask: Any = ()
    /// Original field: lyricLiveActivityStorage; encoding: ypSg (`Any?`); flags: 0x2.
    public var lyricLiveActivityStorage: Any? = nil
    /// Original field: lyricLiveActivityStateStorage; encoding: ypSg (`Any?`); flags: 0x2.
    public var lyricLiveActivityStateStorage: Any? = nil
    /// Original field: lyricLiveActivitySongKey; encoding: SSSg; flags: 0x0.
    public var lyricLiveActivitySongKey: String? = nil
    /// Original field: historyKey; encoding: SS; flags: 0x0.
    public var historyKey: String = ""
    /// Original field: countsKey; encoding: SS; flags: 0x0.
    public var countsKey: String = ""
    /// Original field: playbackStateKey; encoding: SS; flags: 0x0.
    public var playbackStateKey: String = ""
    /// Original field: audioMixKey; encoding: SS; flags: 0x0.
    public var audioMixKey: String = ""
    /// Original field: nowPlayingEnabledKey; encoding: SS; flags: 0x0.
    public var nowPlayingEnabledKey: String = ""
    /// Original field: playModeKey; encoding: SS; flags: 0x0.
    public var playModeKey: String = ""
    /// Original field: softwareVolumeKey; encoding: SS; flags: 0x0.
    public var softwareVolumeKey: String = ""
    /// Original field: autoSkipOnFailureKey; encoding: SS; flags: 0x0.
    public var autoSkipOnFailureKey: String = ""
    /// Original field: autoResumeLastPlaybackKey; encoding: SS; flags: 0x0.
    public var autoResumeLastPlaybackKey: String = ""
    /// Original field: thirdPartyVIPNoticeKey; encoding: SS; flags: 0x0.
    public var thirdPartyVIPNoticeKey: String = ""
    /// Original field: defaults; encoding: So14NSUserDefaultsC; flags: 0x2.
    public var defaults: UserDefaults = .standard
    /// Original field: didAttemptAutoResume; encoding: Sb; flags: 0x2.
    public var didAttemptAutoResume: Bool = false
    /// Original field: crossPlatformFallbackOriginKey; encoding: SSSg; flags: 0x2.
    public var crossPlatformFallbackOriginKey: String? = nil
    /// Original field: crossPlatformFallbackTriedSources; encoding: ShySSG; flags: 0x2.
    public var crossPlatformFallbackTriedSources: Set<String> = []
    /// Original field: crossPlatformFallbackInFlightSongKey; encoding: SSSg; flags: 0xffe01ea4.
    public var crossPlatformFallbackInFlightSongKey: String? = nil
}
