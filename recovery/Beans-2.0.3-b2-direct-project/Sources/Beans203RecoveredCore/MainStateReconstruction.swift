import Foundation
import Combine

// Additional main-program state reconstruction from Beans 2.0.3 build 2 field metadata only.
// Unknown generic/closure/framework payloads remain Any.

/// Original type: QishuiAPI; kind: class; descriptor: 0x7c987c; fields: 9.
public final class QishuiAPI_2_0_3 {
    /// Original field: session; encoding: So12NSURLSessionC; flags: 0x0.
    public var session: URLSession = .shared
    /// Original field: songSearchCache; encoding: <unresolved>; flags: 0x0.
    public var songSearchCache: Any = ()
    /// Original field: playlistSearchCache; encoding: <unresolved>; flags: 0x0.
    public var playlistSearchCache: Any = ()
    /// Original field: recommendationCache; encoding: <unresolved>; flags: 0x0.
    public var recommendationCache: Any = ()
    /// Original field: playlistDetailsCache; encoding: <unresolved>; flags: 0x0.
    public var playlistDetailsCache: Any = ()
    /// Original field: songSearchTTL; encoding: Sd; flags: 0x0.
    public var songSearchTTL: Double = 0
    /// Original field: playlistSearchTTL; encoding: Sd; flags: 0x0.
    public var playlistSearchTTL: Double = 0
    /// Original field: recommendationTTL; encoding: Sd; flags: 0x0.
    public var recommendationTTL: Double = 0
    /// Original field: playlistDetailsTTL; encoding: Sd; flags: 0xfff4e4a0.
    public var playlistDetailsTTL: Double = 0
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

/// Original type: BeansLogger; kind: class; descriptor: 0x7c3c28; fields: 20.
public final class BeansLogger_2_0_3 {
    /// Original field: _entries; encoding: <unresolved>; flags: 0x0.
    public var _entries: Any = ()
    /// Original field: queue; encoding: So17OS_dispatch_queueC; flags: 0x0.
    public var queue: Any = ()
    /// Original field: queueKey; encoding: <unresolved>; flags: 0x0.
    public var queueKey: Any = ()
    /// Original field: root; encoding: <unresolved>; flags: 0x0.
    public var root: Any = ()
    /// Original field: maxFileBytes; encoding: Si; flags: 0x0.
    public var maxFileBytes: Int = 0
    /// Original field: maxTotalBytes; encoding: Si; flags: 0x0.
    public var maxTotalBytes: Int = 0
    /// Original field: consoleEnabled; encoding: Sb; flags: 0x0.
    public var consoleEnabled: Bool = false
    /// Original field: console; encoding: <unresolved>; flags: 0x0.
    public var console: Any = ()
    /// Original field: stateLock; encoding: So6NSLockC; flags: 0x2.
    public var stateLock: NSLock = NSLock()
    /// Original field: snapshot; encoding: <unresolved>; flags: 0x2.
    public var snapshot: Any = ()
    /// Original field: recent; encoding: <unresolved>; flags: 0x2.
    public var recent: Any = ()
    /// Original field: viewers; encoding: Si; flags: 0x2.
    public var viewers: Int = 0
    /// Original field: publicationPending; encoding: Sb; flags: 0x2.
    public var publicationPending: Bool = false
    /// Original field: handle; encoding: So12NSFileHandleCSg; flags: 0x2.
    public var handle: Any = ()
    /// Original field: activeDay; encoding: SS; flags: 0x2.
    public var activeDay: String = ""
    /// Original field: activeBytes; encoding: Si; flags: 0x2.
    public var activeBytes: Int = 0
    /// Original field: activeURL; encoding: <unresolved>; flags: 0x2.
    public var activeURL: Any = ()
    /// Original field: lastPrune; encoding: <unresolved>; flags: 0x2.
    public var lastPrune: Any = ()
    /// Original field: lastContextWrite; encoding: <unresolved>; flags: 0x0.
    public var lastContextWrite: Any = ()
    /// Original field: device; encoding: SS; flags: 0xffd687ac.
    public var device: String = ""
}

/// Original type: BeansEqualizer; kind: class; descriptor: 0x7c39c0; fields: 16.
public final class BeansEqualizer_2_0_3 {
    /// Original field: _isEnabled; encoding: <unresolved>; flags: 0x2.
    public var _isEnabled: Any = ()
    /// Original field: _bandGains; encoding: <unresolved>; flags: 0x2.
    public var _bandGains: Any = ()
    /// Original field: _selectedPreset; encoding: <unresolved>; flags: 0x2.
    public var _selectedPreset: Any = ()
    /// Original field: _selectedCustomPresetName; encoding: <unresolved>; flags: 0x2.
    public var _selectedCustomPresetName: Any = ()
    /// Original field: _preampGain; encoding: <unresolved>; flags: 0x2.
    public var _preampGain: Any = ()
    /// Original field: _customPresets; encoding: <unresolved>; flags: 0x0.
    public var _customPresets: Any = ()
    /// Original field: defaults; encoding: So14NSUserDefaultsC; flags: 0x0.
    public var defaults: UserDefaults = .standard
    /// Original field: configurationLock; encoding: So6NSLockC; flags: 0x2.
    public var configurationLock: NSLock = NSLock()
    /// Original field: processingEnabled; encoding: Sb; flags: 0x2.
    public var processingEnabled: Bool = false
    /// Original field: processingGains; encoding: SaySdG; flags: 0x2.
    public var processingGains: Any = ()
    /// Original field: processingPreampLinear; encoding: Sf; flags: 0x2.
    public var processingPreampLinear: Float = 0
    /// Original field: processingFormatIsFloat32; encoding: Sb; flags: 0x2.
    public var processingFormatIsFloat32: Bool = false
    /// Original field: sampleRate; encoding: Sd; flags: 0x2.
    public var sampleRate: Double = 0
    /// Original field: coefficients; encoding: <unresolved>; flags: 0x2.
    public var coefficients: Any = ()
    /// Original field: filterStates; encoding: <unresolved>; flags: 0x2.
    public var filterStates: Any = ()
    /// Original field: pendingPersistWorkItem; encoding: <unresolved>; flags: 0xffd6857a.
    public var pendingPersistWorkItem: Any = ()
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
    public var _queue: Any = ()
    /// Original field: _currentIndex; encoding: <unresolved>; flags: 0x2.
    public var _currentIndex: Any = ()
    /// Original field: _isPlaying; encoding: <unresolved>; flags: 0x2.
    public var _isPlaying: Any = ()
    /// Original field: _isBuffering; encoding: <unresolved>; flags: 0x2.
    public var _isBuffering: Any = ()
    /// Original field: _loadFailed; encoding: <unresolved>; flags: 0x2.
    public var _loadFailed: Any = ()
    /// Original field: loadGeneration; encoding: Si; flags: 0x0.
    public var loadGeneration: Int = 0
    /// Original field: clock; encoding: <unresolved>; flags: 0x2.
    public var clock: Any = ()
    /// Original field: progress; encoding: Sd; flags: 0x2.
    public var progress: Double = 0
    /// Original field: duration; encoding: Sd; flags: 0x2.
    public var duration: Double = 0
    /// Original field: _playMode; encoding: <unresolved>; flags: 0x2.
    public var _playMode: Any = ()
    /// Original field: _rate; encoding: <unresolved>; flags: 0x2.
    public var _rate: Any = ()
    /// Original field: _softwareVolume; encoding: <unresolved>; flags: 0x2.
    public var _softwareVolume: Any = ()
    /// Original field: _sleepTimerEndsAt; encoding: <unresolved>; flags: 0x2.
    public var _sleepTimerEndsAt: Any = ()
    /// Original field: _sleepTimerRemaining; encoding: <unresolved>; flags: 0x2.
    public var _sleepTimerRemaining: Any = ()
    /// Original field: _stopAfterCurrentSong; encoding: <unresolved>; flags: 0x2.
    public var _stopAfterCurrentSong: Any = ()
    /// Original field: _history; encoding: <unresolved>; flags: 0x2.
    public var _history: Any = ()
    /// Original field: _playCounts; encoding: <unresolved>; flags: 0x2.
    public var _playCounts: Any = ()
    /// Original field: _listeningDuration; encoding: <unresolved>; flags: 0x2.
    public var _listeningDuration: Any = ()
    /// Original field: _seekRevision; encoding: <unresolved>; flags: 0x2.
    public var _seekRevision: Any = ()
    /// Original field: lyricProgress; encoding: Sd; flags: 0x2.
    public var lyricProgress: Double = 0
    /// Original field: player; encoding: So8AVPlayerCSg; flags: 0x2.
    public var player: Any = ()
    /// Original field: timeObserver; encoding: ypSg (`Any?`); flags: 0x2.
    public var timeObserver: Any? = nil
    /// Original field: endObserver; encoding: So8NSObject_pSg; flags: 0x2.
    public var endObserver: Any = ()
    /// Original field: failureObserver; encoding: So8NSObject_pSg; flags: 0x2.
    public var failureObserver: Any = ()
    /// Original field: itemStatusObserver; encoding: <unresolved>; flags: 0x2.
    public var itemStatusObserver: Any = ()
    /// Original field: timeControlStatusObserver; encoding: <unresolved>; flags: 0x2.
    public var timeControlStatusObserver: Any = ()
    /// Original field: equalizerSettingsObserver; encoding: So8NSObject_pSg; flags: 0x2.
    public var equalizerSettingsObserver: Any = ()
    /// Original field: backendBlockObserver; encoding: So8NSObject_pSg; flags: 0x2.
    public var backendBlockObserver: Any = ()
    /// Original field: customCoverObserver; encoding: So8NSObject_pSg; flags: 0x2.
    public var customCoverObserver: Any = ()
    /// Original field: lockScreenArtworkObserver; encoding: So8NSObject_pSg; flags: 0x2.
    public var lockScreenArtworkObserver: Any = ()
    /// Original field: $__lazy_storage_$_lockScreenArtwork; encoding: <unresolved>; flags: 0x2.
    public var field_30____lazy_storage___lockScreenArtwork: Any = ()
    /// Original field: listeningStatsObserver; encoding: So8NSObject_pSg; flags: 0x2.
    public var listeningStatsObserver: Any = ()
    /// Original field: playbackConfirmed; encoding: Sb; flags: 0x2.
    public var playbackConfirmed: Bool = false
    /// Original field: pendingThirdPartyVIPNotice; encoding: <unresolved>; flags: 0x2.
    public var pendingThirdPartyVIPNotice: Any = ()
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
    public var sleepTimer: Any = ()
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
    public var audioSessionWatchdogTimer: Any = ()
    /// Original field: shouldResumeAfterAudioLoss; encoding: Sb; flags: 0x2.
    public var shouldResumeAfterAudioLoss: Bool = false
    /// Original field: audioLossInProgress; encoding: Sb; flags: 0x2.
    public var audioLossInProgress: Bool = false
    /// Original field: lastNowPlayingRefreshUptime; encoding: Sd; flags: 0x2.
    public var lastNowPlayingRefreshUptime: Double = 0
    /// Original field: lastPublishedProgress; encoding: Sd; flags: 0x2.
    public var lastPublishedProgress: Double = 0
    /// Original field: seekState; encoding: <unresolved>; flags: 0x2.
    public var seekState: Any = ()
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
    public var playbackPersistenceQueue: Any = ()
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
    public var preparationFailure: Any = ()
    /// Original field: nowPlayingSongKey; encoding: SSSg; flags: 0x2.
    public var nowPlayingSongKey: String? = nil
    /// Original field: nowPlayingInfo; encoding: SDySSypG (`[String: Any]`); flags: 0x2.
    public var nowPlayingInfo: [String: Any] = [:]
    /// Original field: kugouStandardFallbackSongKey; encoding: SSSg; flags: 0x2.
    public var kugouStandardFallbackSongKey: String? = nil
    /// Original field: thirdPartyRetryExcludedHostsBySong; encoding: SDySSShySSGG; flags: 0x2.
    public var thirdPartyRetryExcludedHostsBySong: Any = ()
    /// Original field: attemptedThirdPartyQualitiesBySong; encoding: SDySSShySSGG; flags: 0x2.
    public var attemptedThirdPartyQualitiesBySong: Any = ()
    /// Original field: activeThirdPartyQuality; encoding: <unresolved>; flags: 0x2.
    public var activeThirdPartyQuality: Any = ()
    /// Original field: attemptedQQOfficialBRsBySong; encoding: SDySSShySSGG; flags: 0x2.
    public var attemptedQQOfficialBRsBySong: Any = ()
    /// Original field: activeQQOfficialBR; encoding: SSSg; flags: 0x2.
    public var activeQQOfficialBR: String? = nil
    /// Original field: bilibiliPlaybackAlternatives; encoding: <unresolved>; flags: 0x2.
    public var bilibiliPlaybackAlternatives: Any = ()
    /// Original field: bilibiliRetryScheduled; encoding: Sb; flags: 0x2.
    public var bilibiliRetryScheduled: Bool = false
    /// Original field: bilibiliQueueLoader; encoding: yycSg; flags: 0x2.
    public var bilibiliQueueLoader: Any = ()
    /// Original field: bilibiliQueueID; encoding: <unresolved>; flags: 0x2.
    public var bilibiliQueueID: Any = ()
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
