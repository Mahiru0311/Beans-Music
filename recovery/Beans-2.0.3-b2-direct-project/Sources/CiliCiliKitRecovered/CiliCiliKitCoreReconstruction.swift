import Foundation
import Combine
#if canImport(SwiftUI)
import SwiftUI
#endif

// Focused CiliCiliKit reconstruction from the exact embedded 2.0.3 build 2 binary.
// Stored names and field counts are direct reflection evidence; unresolved payloads are Any.

/// Direct nominal evidence for the diagnostics dependency retained by
/// AccountMessageService. Its event element substitution remains symbolic,
/// while the counter is an exact `Si` (`Int`) field.
public final class AccountMessageDiagnosticsStore_2_0_3 {
    public var _events: Any = ()
    public var maximumEventCount: Int = 0
}

/// Direct nominal evidence for the dependency retained by AppDependencies.
/// Its URL and service payload substitutions are not decoded uniquely, while
/// the URLSession field is an exact `So12NSURLSessionC` match.
public final class AccountMessageService_2_0_3 {
    public var apiBaseURL: Any = ()
    public var messageBaseURL: Any = ()
    public var privateMessageBaseURL: Any = ()
    public var sessionStore: Any = ()
    public var api: Any = ()
    public var session: URLSession = .shared
    public var diagnostics: AccountMessageDiagnosticsStore_2_0_3 = AccountMessageDiagnosticsStore_2_0_3()
}

/// Direct nominal evidence for AppDependencies.playbackNetworkRefreshCoordinator.
/// The two stored payload substitutions remain unresolved in the IPA.
public final class PlaybackNetworkRefreshCoordinator_2_0_3 {
    public var stabilizationDelay: Any = ()
    public var debouncer: Any = ()
}

/// Original nominal name: AppDependencies; kind: class; field count: 13.
/// The class descriptor and field names are direct framework metadata. Fields
/// whose private dependency types do not survive the IPA remain opaque.
public final class AppDependencies_2_0_3 {
    public var sessionStore: Any = ()
    public var libraryStore: Any = ()
    public var homeRecommendDiagnosticsStore: Any = ()
    public var api: Any = ()
    public var accountMessageService: AccountMessageService_2_0_3 = AccountMessageService_2_0_3()
    public var sponsorBlockService: Any = ()
    public var networkMetricsRecorder: Any = ()
    public var sessionCancellables: Set<AnyCancellable> = []
    public var hasScheduledStartupWork: Bool = false
    public var hasCompletedStartupMaintenance: Bool = false
    /// Decoded relative typeref: `ScTyy...GSg` -> `Task<Void, Never>?`.
    public var startupWarmupTask: Task<Void, Never>? = nil
    /// Decoded relative typeref: `ScTyy...GSg` -> `Task<Void, Never>?`.
    public var startupMaintenanceTask: Task<Void, Never>? = nil
    public var playbackNetworkRefreshCoordinator: PlaybackNetworkRefreshCoordinator_2_0_3 = PlaybackNetworkRefreshCoordinator_2_0_3()
}

/// Original nominal name: CiliCiliRuntime; kind: class; descriptor: 0xc1b980; field count: 26.
public final class CiliCiliRuntime_2_0_3 {
    public static let shared = CiliCiliRuntime_2_0_3()
    public init() {}
    /// Original field: dependencies; direct field symbol: `AppDependencies`.
    public var dependencies: AppDependencies_2_0_3 = AppDependencies_2_0_3()
    /// Original field: _accentColor; encoding: <unresolved>; flags: 0x2.
    public var _accentColor: Any = ()
    /// Original field: _backdropRevision; encoding: <unresolved>; flags: 0x2.
    public var _backdropRevision: Any = ()
    /// Original field: _isDetailActive; encoding: <unresolved>; flags: 0x2.
    public var _isDetailActive: Any = ()
    /// Original field: _isVideoDetailActive; encoding: <unresolved>; flags: 0x2.
    public var _isVideoDetailActive: Any = ()
    /// Original field: _isLiveRoomActive; encoding: <unresolved>; flags: 0x2.
    public var _isLiveRoomActive: Any = ()
    /// Original field: _isSearchActive; encoding: <unresolved>; flags: 0x2.
    public var _isSearchActive: Any = ()
    /// Original field: _isDynamicActive; encoding: <unresolved>; flags: 0x2.
    public var _isDynamicActive: Any = ()
    /// Original field: _isAccountActive; encoding: <unresolved>; flags: 0x2.
    public var _isAccountActive: Any = ()
    /// Original field: _isHostMiniPlayerVisible; encoding: <unresolved>; flags: 0x2.
    public var _isHostMiniPlayerVisible: Any = ()
    /// Original field: _integrationError; encoding: <unresolved>; flags: 0x2.
    public var _integrationError: Any = ()
    /// Original field: onPlaybackActivation; encoding: yycSg; flags: 0x2.
    /// Direct field-offset symbol: `(() -> ())?`.
    public var onPlaybackActivation: (() -> Void)? = nil
    /// Original field: playbackAllowed; encoding: Sbyc; flags: 0x2.
    /// Direct field-offset symbol: `() -> Swift.Bool`.
    public var playbackAllowed: () -> Bool = { true }
    /// Original field: onVideoListenModeChange; encoding: <unresolved>; flags: 0x2.
    /// Direct field-offset symbol: `((CiliCiliVideoListenRequest, Bool, Double, Bool) -> ())?`.
    public var onVideoListenModeChange: ((CiliCiliVideoListenRequest_2_0_3, Bool, Double, Bool) -> Void)? = nil
    /// Original field: downloadVideo; encoding: <unresolved>; flags: 0x2.
    /// Direct field-offset symbol:
    /// `downloadVideo10Foundation3URLVAA0aaE13ListenRequestV_SitYaKYCcSgvpWvd`.
    /// It fixes the callback as an optional async-throwing closure receiving a
    /// URL, a video-listen request, and an Int.
    public var downloadVideo: ((URL, CiliCiliVideoListenRequest_2_0_3, Int) async throws -> Void)? = nil
    /// Original field: onSessionChange; encoding: ySS_S3SSgtKcSg; flags: 0x2.
    /// Direct field-offset symbol: `((String, String, String, String?) throws -> ())?`.
    public var onSessionChange: ((String, String, String, String?) throws -> Void)? = nil
    /// Original field: backdropViewProvider; encoding: <unresolved>; flags: 0x2.
    /// The retained public setter fixes its source shape as
    /// `@MainActor @Sendable () -> SwiftUI.AnyView`.
#if canImport(SwiftUI)
    public var backdropViewProvider: (@MainActor @Sendable () -> SwiftUI.AnyView)? = nil
#else
    public var backdropViewProvider: Any = ()
#endif
    /// Original field: navigationOwners; direct field symbol: `Set<Foundation.UUID>`.
    /// Direct field symbols resolve each owner set to `Set<Foundation.UUID>`.
    public var navigationOwners: Set<UUID> = []
    /// Original field: videoDetailOwners; direct typeref: `Set<Foundation.UUID>`.
    public var videoDetailOwners: Set<UUID> = []
    /// Original field: liveRoomOwners; direct typeref: `Set<Foundation.UUID>`.
    public var liveRoomOwners: Set<UUID> = []
    /// Original field: dynamicOwners; direct typeref: `Set<Foundation.UUID>`.
    public var dynamicOwners: Set<UUID> = []
    /// Original field: accountOwners; direct typeref: `Set<Foundation.UUID>`.
    public var accountOwners: Set<UUID> = []
    /// Direct field symbol: `Set<Combine.AnyCancellable>`.
    public var subscriptions: Set<AnyCancellable> = []
    /// Original field: lastExportedIdentity; encoding: SS; flags: 0x2.
    public var lastExportedIdentity: String = ""
    /// Original field: pendingLegacySession; encoding: SS6cookie_SS4nameSS2idSSSg6avatartSg; flags: 0x2.
    /// Direct metadata encoding: `(cookie:String, name:String, id:String, avatar:String?)?`.
    public var pendingLegacySession: (cookie: String, name: String, id: String, avatar: String?)? = nil
    /// Direct initializer symbol encodes this storage as
    /// `CiliCiliListenSource?` (`...ListenSourceVSgvpfi`).
    public var listenSource: CiliCiliListenSource_2_0_3? = nil
}

/// Direct field metadata for the public request type retained in the embedded
/// framework. The retained accessor spelling is
/// `audioURL10Foundation0G0VSgv`. Within this same binary, the identical
/// `Foundation0G0V` substitution is used by the demangled
/// `Foundation.URLComponents.url -> Foundation.URL` accessor, so the field is
/// recovered as `Foundation.URL?` without using another release.
public struct CiliCiliVideoListenRequest_2_0_3 {
    public var bvid: String
    public var aid: Int?
    public var cid: Int?
    public var title: String
    public var coverURL: String?
    public var duration: Double
    public var artist: String
    public var ownerID: Int?
    public var audioURL: URL?

    public init(bvid: String, aid: Int? = nil, cid: Int? = nil, title: String,
                coverURL: String? = nil, duration: Double, artist: String,
                ownerID: Int? = nil, audioURL: URL? = nil) {
        self.bvid = bvid; self.aid = aid; self.cid = cid; self.title = title
        self.coverURL = coverURL; self.duration = duration; self.artist = artist
        self.ownerID = ownerID; self.audioURL = audioURL
    }
}

/// Direct field names and recovered typerefs for the return type. The identity,
/// item array, and async loader shape are retained; no other payload is added.
public struct CiliCiliListenSource_2_0_3 {
    /// Direct Ghidra field accessor symbol: `CiliCiliListenSource.id: Foundation.UUID`.
    public var id: UUID
    /// Relative typeref decodes this field as `Array<CiliCiliVideoListenRequest>`.
    public var items: [CiliCiliVideoListenRequest_2_0_3]
    /// Direct field symbol: `loadMore: ([CiliCiliVideoListenRequest]) async -> Void` optional.
    public var loadMore: (([CiliCiliVideoListenRequest_2_0_3]) async -> Void)?

    public init(id: UUID = UUID(), items: [CiliCiliVideoListenRequest_2_0_3] = [], loadMore: (([CiliCiliVideoListenRequest_2_0_3]) async -> Void)? = nil) {
        self.id = id; self.items = items; self.loadMore = loadMore
    }
}

// Public method signatures are direct symbol evidence. Bodies below are
// intentionally minimal where the framework implementation is not recoverable
// from the available symbol/field metadata; they keep the reconstructed API
// callable without pretending that a no-op is the original behavior.
public extension CiliCiliRuntime_2_0_3 {
    /// Direct getter symbols return `Swift.Bool`; backing published storage is
    /// retained as an opaque field because its wrapper typeref is stripped.
    var isVideoDetailActive: Bool { (_isVideoDetailActive as? Bool) ?? false }
    var isLiveRoomActive: Bool { (_isLiveRoomActive as? Bool) ?? false }

    /// The direct getter calls a runtime state helper and returns its low bit;
    /// the helper's state storage is not represented in this focused scaffold.
    static var hasActivePlayback: Bool { false }

    func listenSource(for request: CiliCiliVideoListenRequest_2_0_3) -> CiliCiliListenSource_2_0_3 {
        // The recovered ARM64 body unwraps the optional storage, walks its
        // request array, and compares the first two words of each request
        // before returning the existing source.  In the recovered nine-field
        // layout those two words are the Swift String storage for `bvid`
        // (pointer and count); the following `aid` field is not read by this
        // identity path.  Display and playback fields are likewise not used.
        if let listenSource,
           listenSource.items.contains(where: { $0.bvid == request.bvid }) {
            return listenSource
        }

        // The no-match branch allocates a fresh source and copies the request
        // into its item array before returning it.  Keeping the request here is
        // important: callers use the returned source as the initial queue
        // snapshot, rather than receiving an empty placeholder.
        let created = CiliCiliListenSource_2_0_3(items: [request])
        listenSource = created
        return created
    }

    /// Direct symbol/ABI recovered; the async cache worker is not in the
    /// public symbol slice, so the scaffold leaves its values at zero.
    func resourceCacheUsage() async -> (disk: Int, memory: Int) { (0, 0) }

    /// Direct body allocates an async task and switches to a private worker;
    /// that worker is kept as an unresolved state-machine boundary.
    func clearResourceCaches() async {}

    /// The direct body enters the runtime/player state machine; the callee
    /// implementation is outside the recovered symbol slice, so no callback
    /// invocation is invented here.
    func stopPlaybackForMusic() {}

    func setHostMiniPlayerVisible(_ visible: Bool) {
        _isHostMiniPlayerVisible = visible
    }

    func synchronizeLegacySession(cookie: String, name: String, userID: String, avatar: String?) {
        pendingLegacySession = (cookie: cookie, name: name, id: userID, avatar: avatar)
        // The direct body enters CiliCili's private session store and updates
        // `lastExportedIdentity`; no callback dispatch is claimed here because
        // its private dependency object is outside the recovered field slice.
    }

#if canImport(SwiftUI)
    func setBeansAccentColor(_ color: SwiftUI.Color) {
        _accentColor = color
    }

    func setBackdropViewProvider(_ provider: @escaping @MainActor @Sendable () -> SwiftUI.AnyView) {
        backdropViewProvider = provider
    }
#endif
}

/// Original nominal name: AVPlayerHLSBridgeEngine; kind: class; descriptor: 0xc160d8; field count: 70.
public final class AVPlayerHLSBridgeEngine_2_0_3 {
    /// Original field: player; encoding: So8AVPlayerC; flags: 0x2.
    public var player: Any = ()
    /// Original field: viewModel; encoding: <unresolved>; flags: 0x2.
    public var viewModel: Any = ()
    /// Original field: itemEndObserver; encoding: ypSg (`Any?`); flags: 0x2.
    public var itemEndObserver: Any? = nil
    /// Original field: itemFailedObserver; encoding: ypSg (`Any?`); flags: 0x2.
    public var itemFailedObserver: Any? = nil
    /// Original field: itemStalledObserver; encoding: ypSg (`Any?`); flags: 0x2.
    public var itemStalledObserver: Any? = nil
    /// Original field: itemAccessLogObserver; encoding: ypSg (`Any?`); flags: 0x2.
    public var itemAccessLogObserver: Any? = nil
    /// Original field: itemReadinessTimeoutTask; encoding: <unresolved>; flags: 0x2.
    /// Decoded relative typeref: `ScTyy...GSg` -> `Task<Void, Never>?`.
    public var itemReadinessTimeoutTask: Task<Void, Never>? = nil
    /// Original field: firstFrameWatchdogTask; encoding: <unresolved>; flags: 0x2.
    /// Decoded relative typeref: `ScTyy...GSg` -> `Task<Void, Never>?`.
    public var firstFrameWatchdogTask: Task<Void, Never>? = nil
    /// Original field: firstFrameWatchdogGeneration; encoding: Si; flags: 0x2.
    public var firstFrameWatchdogGeneration: Int = 0
    /// Original field: playerObservers; encoding: <unresolved>; flags: 0x2.
    public var playerObservers: Any = ()
    /// Original field: itemObservers; encoding: <unresolved>; flags: 0x2.
    public var itemObservers: Any = ()
    /// Original field: layerReadyForDisplayObserver; encoding: <unresolved>; flags: 0x2.
    public var layerReadyForDisplayObserver: Any = ()
    /// Original field: controllerReadyForDisplayObserver; encoding: <unresolved>; flags: 0x2.
    public var controllerReadyForDisplayObserver: Any = ()
    /// Original field: periodicTimeObserver; encoding: ypSg (`Any?`); flags: 0x0.
    public var periodicTimeObserver: Any? = nil
    /// Original field: videoFrameContext; encoding: So9CIContextC; flags: 0x2.
    public var videoFrameContext: Any = ()
    /// Original field: surfaceView; encoding: So6UIViewCSgXw; flags: 0x2.
    public var surfaceView: Any = ()
    /// Original field: playerLayer; encoding: So13AVPlayerLayerCSg; flags: 0x2.
    public var playerLayer: Any = ()
    /// Original field: playerViewController; encoding: So22AVPlayerViewControllerCSgXw; flags: 0x0.
    public var playerViewController: Any = ()
    /// Original field: nativeDolbyVideoOverlay; encoding: <unresolved>; flags: 0x2.
    public var nativeDolbyVideoOverlay: Any = ()
    /// Original field: nativeDolbyVideoSyncTask; encoding: <unresolved>; flags: 0x2.
    /// Decoded relative typeref: `ScTyy...GSg` -> `Task<Void, Never>?`.
    public var nativeDolbyVideoSyncTask: Task<Void, Never>? = nil
    /// Original field: lastDisplayDynamicRangePolicySummary; encoding: SSSg; flags: 0x2.
    public var lastDisplayDynamicRangePolicySummary: String? = nil
    /// Original field: playerItem; encoding: So12AVPlayerItemCSg; flags: 0x2.
    public var playerItem: Any = ()
    /// Original field: videoOutput; encoding: So23AVPlayerItemVideoOutputCSg; flags: 0x2.
    public var videoOutput: Any = ()
    /// Original field: lastVideoFrameImage; encoding: So7UIImageCSg; flags: 0x2.
    public var lastVideoFrameImage: Any = ()
    /// Original field: recoveryFrameCacheTask; encoding: <unresolved>; flags: 0x2.
    /// Decoded relative typeref: `ScTyy...GSg` -> `Task<Void, Never>?`.
    public var recoveryFrameCacheTask: Task<Void, Never>? = nil
    /// Original field: source; encoding: <unresolved>; flags: 0x2.
    public var source: Any = ()
    /// Original field: hlsBridge; encoding: <unresolved>; flags: 0x2.
    public var hlsBridge: Any = ()
    /// Original field: liveHLSProxy; encoding: <unresolved>; flags: 0x2.
    public var liveHLSProxy: Any = ()
    /// Original field: mediaTimeOffset; encoding: Sd; flags: 0x2.
    public var mediaTimeOffset: Double = 0
    /// Original field: retainedAssets; encoding: SaySo7AVAssetCG; flags: 0x2.
    public var retainedAssets: Any = ()
    /// Original field: currentRate; encoding: Sf; flags: 0x2.
    public var currentRate: Float = 0
    /// Original field: wantsPlayback; encoding: Sb; flags: 0x2.
    public var wantsPlayback: Bool = false
    /// Original field: didReportFirstFrame; encoding: Sb; flags: 0x2.
    public var didReportFirstFrame: Bool = false
    /// Original field: lastPlaybackState; encoding: <unresolved>; flags: 0x2.
    public var lastPlaybackState: Any = ()
    /// Original field: videoGravity; encoding: <unresolved>; flags: 0x2.
    public var videoGravity: Any = ()
    /// Original field: isDirectLiveHLS; encoding: Sb; flags: 0x2.
    public var isDirectLiveHLS: Bool = false
    /// Original field: didSeekDirectLiveHLS; encoding: Sb; flags: 0x2.
    public var didSeekDirectLiveHLS: Bool = false
    /// Original field: isPerformingSeek; encoding: Sb; flags: 0x2.
    public var isPerformingSeek: Bool = false
    /// Original field: seekGeneration; encoding: Si; flags: 0x2.
    public var seekGeneration: Int = 0
    /// Original field: isSeekProtectionActive; encoding: Sb; flags: 0x2.
    public var isSeekProtectionActive: Bool = false
    /// Original field: lastSeekFinishedAt; encoding: SdSg; flags: 0x2.
    public var lastSeekFinishedAt: Double? = nil
    /// Original field: seekProtectionReleaseTask; encoding: <unresolved>; flags: 0x2.
    /// Decoded relative typeref: `ScTyy...GSg` -> `Task<Void, Never>?`.
    public var seekProtectionReleaseTask: Task<Void, Never>? = nil
    /// Original field: seekProtectionTargetTime; encoding: SdSg; flags: 0x2.
    public var seekProtectionTargetTime: Double? = nil
    /// Original field: seekProtectionAppliedAt; encoding: SdSg; flags: 0x2.
    public var seekProtectionAppliedAt: Double? = nil
    /// Original field: seekWarmupTask; encoding: <unresolved>; flags: 0x2.
    /// Decoded relative typeref: `ScTyy...GSg` -> `Task<Void, Never>?`.
    public var seekWarmupTask: Task<Void, Never>? = nil
    /// Original field: seekWarmupGeneration; encoding: Si; flags: 0x2.
    public var seekWarmupGeneration: Int = 0
    /// Original field: automaticallyWaitsBeforeSeekProtection; encoding: SbSg (`Bool?`); flags: 0x2.
    public var automaticallyWaitsBeforeSeekProtection: Bool? = nil
    /// Original field: terminalStallTask; encoding: <unresolved>; flags: 0x2.
    /// Decoded relative typeref: `ScTyy...GSg` -> `Task<Void, Never>?`.
    public var terminalStallTask: Task<Void, Never>? = nil
    /// Original field: terminalStallGeneration; encoding: Si; flags: 0x2.
    public var terminalStallGeneration: Int = 0
    /// Original field: isStartupFastStartActive; encoding: Sb; flags: 0x2.
    public var isStartupFastStartActive: Bool = false
    /// Original field: manualPreferredPeakBitRate; encoding: SdSg; flags: 0x2.
    public var manualPreferredPeakBitRate: Double? = nil
    /// Original field: lastRecordedAccessLogStallCount; encoding: Si; flags: 0x2.
    public var lastRecordedAccessLogStallCount: Int = 0
    /// Original field: lastPlaybackFailureReason; encoding: <unresolved>; flags: 0x2.
    public var lastPlaybackFailureReason: Any = ()
    /// Original field: playbackGeneration; encoding: Si; flags: 0x2.
    public var playbackGeneration: Int = 0
    /// Original field: playbackFailureRecoveryAttempts; encoding: SDySSSiG; flags: 0x2.
    public var playbackFailureRecoveryAttempts: [String: Int] = [:]
    /// Original field: isPlaybackFailureRecoveryInProgress; encoding: Sb; flags: 0x2.
    public var isPlaybackFailureRecoveryInProgress: Bool = false
    /// Original field: isStopped; encoding: Sb; flags: 0x2.
    public var isStopped: Bool = false
    /// Original field: targetVolume; encoding: Sf; flags: 0x2.
    public var targetVolume: Float = 0
    /// Original field: targetMuted; encoding: Sb; flags: 0x2.
    public var targetMuted: Bool = false
    /// Original field: isTemporaryAudioSuppressed; encoding: Sb; flags: 0x2.
    public var isTemporaryAudioSuppressed: Bool = false
    /// Original field: isPictureInPictureEnabled; encoding: Sb; flags: 0x2.
    public var isPictureInPictureEnabled: Bool = false
    /// Original field: contentOverlay; encoding: <unresolved>; flags: 0x2.
    public var contentOverlay: Any = ()
    /// Original field: contentOverlayHostingController; encoding: <unresolved>; flags: 0x2.
    public var contentOverlayHostingController: Any = ()
    /// Original field: contentOverlayContainerView; encoding: So6UIViewCSgXw; flags: 0x2.
    public var contentOverlayContainerView: Any = ()
    /// Original field: pendingSurfaceDetachTask; encoding: <unresolved>; flags: 0x2.
    /// Decoded relative typeref: `ScTyy...GSg` -> `Task<Void, Never>?`.
    public var pendingSurfaceDetachTask: Task<Void, Never>? = nil
    /// Original field: shouldPrerollPausedRecoveryAfterSeek; encoding: Sb; flags: 0x2.
    public var shouldPrerollPausedRecoveryAfterSeek: Bool = false
    /// Original field: onPlaybackStateChange; encoding: <unresolved>; flags: 0x2.
    public var onPlaybackStateChange: Any = ()
    /// Original field: onPlaybackIntentChange; encoding: ySbYbScMYccSg; flags: 0x2.
    public var onPlaybackIntentChange: Any = ()
    /// Original field: onLoadingProgressChange; encoding: ySdYbScMYccSg; flags: 0x2.
    public var onLoadingProgressChange: Any = ()
    /// Original field: onFirstFrame; encoding: ySdYbScMYccSg; flags: 0xffeb5ef2.
    public var onFirstFrame: Any = ()
}

/// Original nominal name: LocalHLSBridge; kind: struct; descriptor: 0xc1699c; field count: 10.
public struct LocalHLSBridge_2_0_3 {
    /// Original field: masterPlaylistURL; encoding: <unresolved>; flags: 0x0.
    public var masterPlaylistURL: Any = ()
    /// Original field: mediaTimeOffset; encoding: Sd; flags: 0x0.
    public var mediaTimeOffset: Double = 0
    /// Original field: videoClockDelay; encoding: Sd; flags: 0x0.
    public var videoClockDelay: Double = 0
    /// Original field: videoVariantCount; encoding: Si; flags: 0x0.
    public var videoVariantCount: Int = 0
    /// Original field: videoVariantQualities; encoding: SaySiG; flags: 0x0.
    public var videoVariantQualities: [Int] = []
    /// Original field: videoVariantDetails; encoding: SaySSG; flags: 0x0.
    public var videoVariantDetails: [String] = []
    /// Original field: routePlanCacheState; encoding: SS; flags: 0x0.
    public var routePlanCacheState: String = ""
    /// Original field: serverCacheState; encoding: SS; flags: 0x0.
    public var serverCacheState: String = ""
    /// Original field: seekPlanner; encoding: <unresolved>; flags: 0x0.
    public var seekPlanner: Any = ()
    /// Original field: server; encoding: <unresolved>; flags: 0xffeb5ab2.
    public var server: Any = ()
}

/// Original nominal name: HLSRendition; kind: struct; descriptor: 0xc16898; field count: 19.
public struct HLSRendition_2_0_3 {
    /// Original field: sourceURL; encoding: <unresolved>; flags: 0x0.
    public var sourceURL: Any = ()
    /// Original field: fallbackSourceURLs; encoding: <unresolved>; flags: 0x0.
    public var fallbackSourceURLs: Any = ()
    /// Original field: mediaType; encoding: <unresolved>; flags: 0x0.
    public var mediaType: Any = ()
    /// Original field: quality; encoding: SiSg; flags: 0x0.
    public var quality: Int? = nil
    /// Original field: initialization; encoding: <unresolved>; flags: 0x0.
    public var initialization: Any = ()
    /// Original field: initializationData; encoding: <unresolved>; flags: 0x0.
    public var initializationData: Any = ()
    /// Original field: references; encoding: <unresolved>; flags: 0x0.
    public var references: Any = ()
    /// Original field: targetDuration; encoding: Sd; flags: 0x0.
    public var targetDuration: Double = 0
    /// Original field: bandwidth; encoding: Si; flags: 0x0.
    public var bandwidth: Int = 0
    /// Original field: codec; encoding: SS; flags: 0x0.
    public var codec: String = ""
    /// Original field: mediaTimeOffset; encoding: Sd; flags: 0x0.
    public var mediaTimeOffset: Double = 0
    /// Original field: baseMediaDecodeTimeOffsetTicks; encoding: <unresolved>; flags: 0x0.
    public var baseMediaDecodeTimeOffsetTicks: Any = ()
    /// Original field: dynamicRange; encoding: <unresolved>; flags: 0x0.
    public var dynamicRange: Any = ()
    /// Original field: dolbyVisionConfiguration; encoding: <unresolved>; flags: 0x0.
    public var dolbyVisionConfiguration: Any = ()
    /// Original field: dolbyVisionRenderingPolicy; encoding: <unresolved>; flags: 0x0.
    public var dolbyVisionRenderingPolicy: Any = ()
    /// Original field: videoColorInformation; encoding: <unresolved>; flags: 0x0.
    public var videoColorInformation: Any = ()
    /// Original field: hlsBaseLayerCodec; encoding: SSSg; flags: 0x0.
    public var hlsBaseLayerCodec: String? = nil
    /// Original field: dimensions; encoding: <unresolved>; flags: 0x0.
    public var dimensions: Any = ()
    /// Original field: frameRate; encoding: SdSg; flags: 0xffeb5b2a.
    public var frameRate: Double? = nil
}

/// Original nominal name: HomeViewModel; kind: class; descriptor: 0xc21b30; field count: 22.
public final class HomeViewModel_2_0_3 {
    /// Original field: _videos; encoding: <unresolved>; flags: 0x2.
    public var _videos: Any = ()
    /// Original field: videoCells; encoding: <unresolved>; flags: 0x2.
    public var videoCells: Any = ()
    /// Original field: _lastSeenMarkerIndex; encoding: <unresolved>; flags: 0x2.
    public var _lastSeenMarkerIndex: Any = ()
    /// Original field: _state; encoding: <unresolved>; flags: 0x2.
    public var _state: Any = ()
    /// Original field: _mode; encoding: <unresolved>; flags: 0x2.
    public var _mode: Any = ()
    /// Original field: _channel; encoding: <unresolved>; flags: 0x2.
    public var _channel: Any = ()
    /// Original field: _isRefreshing; encoding: <unresolved>; flags: 0x2.
    public var _isRefreshing: Any = ()
    /// Original field: _isUserRefreshing; encoding: <unresolved>; flags: 0x0.
    public var _isUserRefreshing: Any = ()
    /// Original field: libraryStore; encoding: <unresolved>; flags: 0x0.
    public var libraryStore: Any = ()
    /// Original field: sessionStore; encoding: <unresolved>; flags: 0x2.
    public var sessionStore: Any = ()
    /// Original field: requestRevision; encoding: Si; flags: 0x2.
    public var requestRevision: Int = 0
    /// Original field: lastUserRefreshDate; encoding: <unresolved>; flags: 0x2.
    public var lastUserRefreshDate: Any = ()
    /// Original field: modeSwitchRefreshPending; encoding: Sb; flags: 0x2.
    public var modeSwitchRefreshPending: Bool = false
    /// Original field: retainedRecommendVideos; encoding: <unresolved>; flags: 0x2.
    public var retainedRecommendVideos: Any = ()
    /// Original field: retainedRecommendLastSeenMarkerIndex; encoding: SiSg; flags: 0x2.
    public var retainedRecommendLastSeenMarkerIndex: Int? = nil
    /// Original field: recommendContextCancellable; encoding: <unresolved>; flags: 0x0.
    public var recommendContextCancellable: Any = ()
    /// Original field: pageCoordinator; encoding: <unresolved>; flags: 0x2.
    public var pageCoordinator: Any = ()
    /// Original field: snapshotCoordinator; encoding: <unresolved>; flags: 0x0.
    public var snapshotCoordinator: Any = ()
    /// Original field: mediaPreloadCoordinator; encoding: <unresolved>; flags: 0x0.
    public var mediaPreloadCoordinator: Any = ()
    /// Original field: exposureRecorder; encoding: <unresolved>; flags: 0x2.
    public var exposureRecorder: Any = ()
    /// Original field: cellStore; encoding: <unresolved>; flags: 0x2.
    public var cellStore: Any = ()
    /// Original field: recommendMetadataHydrationTasks; encoding: <unresolved>; flags: 0xffefccba.
    public var recommendMetadataHydrationTasks: Any = ()
}

/// Original nominal name: VideoDetailViewModel; kind: class; descriptor: 0xc32c60; field count: 78.
public final class VideoDetailViewModel_2_0_3 {
    /// Original field: _detail; encoding: <unresolved>; flags: 0x2.
    public var _detail: Any = ()
    /// Original field: _onlineViewerCount; encoding: <unresolved>; flags: 0x2.
    public var _onlineViewerCount: Any = ()
    /// Original field: _playVariants; encoding: <unresolved>; flags: 0x2.
    public var _playVariants: Any = ()
    /// Original field: _selectedPlayVariant; encoding: <unresolved>; flags: 0x0.
    public var _selectedPlayVariant: Any = ()
    /// Original field: renderStores; encoding: <unresolved>; flags: 0x2.
    public var renderStores: Any = ()
    /// Original field: detailPresentationState; encoding: <unresolved>; flags: 0x2.
    public var detailPresentationState: Any = ()
    /// Original field: relatedStateStorage; encoding: <unresolved>; flags: 0x2.
    public var relatedStateStorage: Any = ()
    /// Original field: commentListState; encoding: <unresolved>; flags: 0x2.
    public var commentListState: Any = ()
    /// Original field: _selectedCID; encoding: <unresolved>; flags: 0x2.
    public var _selectedCID: Any = ()
    /// Original field: _state; encoding: <unresolved>; flags: 0x2.
    public var _state: Any = ()
    /// Original field: _playURLState; encoding: <unresolved>; flags: 0x2.
    public var _playURLState: Any = ()
    /// Original field: _isSwitchingPlayQuality; encoding: <unresolved>; flags: 0x2.
    public var _isSwitchingPlayQuality: Any = ()
    /// Original field: _pendingPlayVariantID; encoding: <unresolved>; flags: 0x2.
    public var _pendingPlayVariantID: Any = ()
    /// Original field: _playbackContentMode; encoding: <unresolved>; flags: 0x2.
    public var _playbackContentMode: Any = ()
    /// Original field: _isSwitchingVideoListenMode; encoding: <unresolved>; flags: 0x2.
    public var _isSwitchingVideoListenMode: Any = ()
    /// Original field: _videoListenAudioVariants; encoding: <unresolved>; flags: 0x2.
    public var _videoListenAudioVariants: Any = ()
    /// Original field: _selectedVideoListenAudioPreferenceKey; encoding: <unresolved>; flags: 0x2.
    public var _selectedVideoListenAudioPreferenceKey: Any = ()
    /// Original field: automaticVideoListenAudioVariantID; encoding: SSSg; flags: 0x2.
    public var automaticVideoListenAudioVariantID: String? = nil
    /// Original field: failedVideoListenAudioVariantIDs; encoding: ShySSG; flags: 0x2.
    public var failedVideoListenAudioVariantIDs: Set<String> = []
    /// Original field: pendingVideoListenPlaybackIntent; encoding: SbSg (`Bool?`); flags: 0x2.
    public var pendingVideoListenPlaybackIntent: Bool? = nil
    /// Original field: _videoListenPgcSeasonInfo; encoding: <unresolved>; flags: 0x2.
    public var _videoListenPgcSeasonInfo: Any = ()
    /// Original field: videoListenPgcSeasonID; encoding: SiSg; flags: 0x2.
    public var videoListenPgcSeasonID: Int? = nil
    /// Original field: _videoListenQueueSession; encoding: <unresolved>; flags: 0x2.
    public var _videoListenQueueSession: Any = ()
    /// Original field: videoListenQueueTask; encoding: <unresolved>; flags: 0x2.
    /// Decoded relative typeref: `ScTyy...GSg` -> `Task<Void, Never>?`.
    public var videoListenQueueTask: Task<Void, Never>? = nil
    /// Original field: videoListenQueueTaskGeneration; encoding: Si; flags: 0x2.
    public var videoListenQueueTaskGeneration: Int = 0
    /// Original field: videoListenContentSwitchTask; encoding: <unresolved>; flags: 0x2.
    /// Decoded relative typeref: `ScTyy...GSg` -> `Task<Void, Never>?`.
    public var videoListenContentSwitchTask: Task<Void, Never>? = nil
    /// Original field: _videoListenSleepTimerOption; encoding: <unresolved>; flags: 0x2.
    public var _videoListenSleepTimerOption: Any = ()
    /// Original field: _videoListenSleepTimerDeadline; encoding: <unresolved>; flags: 0x2.
    public var _videoListenSleepTimerDeadline: Any = ()
    /// Original field: videoListenSleepTimerTask; encoding: <unresolved>; flags: 0x0.
    /// Decoded relative typeref: `ScTyy...GSg` -> `Task<Void, Never>?`.
    public var videoListenSleepTimerTask: Task<Void, Never>? = nil
    /// Original field: videoListenPlaybackSessionStore; encoding: <unresolved>; flags: 0x2.
    public var videoListenPlaybackSessionStore: Any = ()
    /// Original field: pendingVideoListenPlaybackSessionState; encoding: <unresolved>; flags: 0x2.
    public var pendingVideoListenPlaybackSessionState: Any = ()
    /// Original field: _interactionState; encoding: <unresolved>; flags: 0x2.
    public var _interactionState: Any = ()
    /// Original field: _interactionMessage; encoding: <unresolved>; flags: 0x2.
    public var _interactionMessage: Any = ()
    /// Original field: _isMutatingInteraction; encoding: <unresolved>; flags: 0x2.
    public var _isMutatingInteraction: Any = ()
    /// Original field: interactionMutationState; encoding: <unresolved>; flags: 0x2.
    public var interactionMutationState: Any = ()
    /// Original field: interactionMutationRevision; encoding: Si; flags: 0x2.
    public var interactionMutationRevision: Int = 0
    /// Original field: _favoriteFolders; encoding: <unresolved>; flags: 0x2.
    public var _favoriteFolders: Any = ()
    /// Original field: _favoriteFolderState; encoding: <unresolved>; flags: 0x2.
    public var _favoriteFolderState: Any = ()
    /// Original field: _stablePlayerViewModel; encoding: <unresolved>; flags: 0x2.
    public var _stablePlayerViewModel: Any = ()
    /// Original field: _playbackFallbackMessage; encoding: <unresolved>; flags: 0x2.
    public var _playbackFallbackMessage: Any = ()
    /// Original field: _danmakuItems; encoding: <unresolved>; flags: 0x2.
    public var _danmakuItems: Any = ()
    /// Original field: _danmakuItemsRevision; encoding: <unresolved>; flags: 0x2.
    public var _danmakuItemsRevision: Any = ()
    /// Original field: _danmakuState; encoding: <unresolved>; flags: 0x2.
    public var _danmakuState: Any = ()
    /// Original field: _isDanmakuEnabled; encoding: <unresolved>; flags: 0x2.
    public var _isDanmakuEnabled: Any = ()
    /// Original field: _danmakuSettings; encoding: <unresolved>; flags: 0x2.
    public var _danmakuSettings: Any = ()
    /// Original field: _detailLoadElapsedMilliseconds; encoding: <unresolved>; flags: 0x2.
    public var _detailLoadElapsedMilliseconds: Any = ()
    /// Original field: _playURLElapsedMilliseconds; encoding: <unresolved>; flags: 0x2.
    public var _playURLElapsedMilliseconds: Any = ()
    /// Original field: _relatedElapsedMilliseconds; encoding: <unresolved>; flags: 0x2.
    public var _relatedElapsedMilliseconds: Any = ()
    /// Original field: _lastPlayURLSource; encoding: <unresolved>; flags: 0x2.
    public var _lastPlayURLSource: Any = ()
    /// Original field: currentPlayURLData; encoding: <unresolved>; flags: 0x2.
    public var currentPlayURLData: Any = ()
    /// Original field: _resumeDiagnostics; encoding: <unresolved>; flags: 0x2.
    public var _resumeDiagnostics: Any = ()
    /// Original field: commentThreadState; encoding: <unresolved>; flags: 0x0.
    public var commentThreadState: Any = ()
    /// Original field: serviceDependencies; encoding: <unresolved>; flags: 0x0.
    public var serviceDependencies: Any = ()
    /// Original field: playbackOptions; encoding: <unresolved>; flags: 0x2.
    public var playbackOptions: Any = ()
    /// Original field: coreTaskState; encoding: <unresolved>; flags: 0x2.
    public var coreTaskState: Any = ()
    /// Original field: relatedTaskState; encoding: <unresolved>; flags: 0x2.
    public var relatedTaskState: Any = ()
    /// Original field: playbackWarmupTaskState; encoding: <unresolved>; flags: 0x2.
    public var playbackWarmupTaskState: Any = ()
    /// Original field: lifecycleSubscriptionState; encoding: <unresolved>; flags: 0x2.
    public var lifecycleSubscriptionState: Any = ()
    /// Original field: sponsorBlockState; encoding: <unresolved>; flags: 0x2.
    public var sponsorBlockState: Any = ()
    /// Original field: danmakuLoadingState; encoding: <unresolved>; flags: 0x2.
    public var danmakuLoadingState: Any = ()
    /// Original field: stablePlayerState; encoding: <unresolved>; flags: 0x2.
    public var stablePlayerState: Any = ()
    /// Original field: playbackTransitionState; encoding: <unresolved>; flags: 0x2.
    public var playbackTransitionState: Any = ()
    /// Original field: playbackStartupWaitState; encoding: <unresolved>; flags: 0x2.
    public var playbackStartupWaitState: Any = ()
    /// Original field: playbackRecoveryState; encoding: <unresolved>; flags: 0x2.
    public var playbackRecoveryState: Any = ()
    /// Original field: renderStoreSyncState; encoding: <unresolved>; flags: 0x2.
    public var renderStoreSyncState: Any = ()
    /// Original field: navigationState; encoding: <unresolved>; flags: 0x2.
    public var navigationState: Any = ()
    /// Original field: playVariantSwitchToken; encoding: <unresolved>; flags: 0x2.
    public var playVariantSwitchToken: Any = ()
    /// Original field: pendingPlaybackHistoryResumeTime; encoding: SdSg; flags: 0x2.
    public var pendingPlaybackHistoryResumeTime: Double? = nil
    /// Original field: pendingPlaybackHistoryResumeCID; encoding: SiSg; flags: 0x2.
    public var pendingPlaybackHistoryResumeCID: Int? = nil
    /// Original field: didResolveCloudHistoryResume; encoding: Sb; flags: 0x2.
    public var didResolveCloudHistoryResume: Bool = false
    /// Original field: isAwaitingInitialManualPlayback; encoding: Sb; flags: 0x2.
    public var isAwaitingInitialManualPlayback: Bool = false
    /// Original field: isAwaitingRelatedVideoReturnPlayback; encoding: Sb; flags: 0x2.
    public var isAwaitingRelatedVideoReturnPlayback: Bool = false
    /// Original field: manuallySelectedPageCID; encoding: SiSg; flags: 0x2.
    public var manuallySelectedPageCID: Int? = nil
    /// Original field: uploaderInteractionLoadState; encoding: <unresolved>; flags: 0x2.
    public var uploaderInteractionLoadState: Any = ()
    /// Original field: lastUserSeekAt; encoding: <unresolved>; flags: 0x2.
    public var lastUserSeekAt: Any = ()
    /// Original field: loadTiming; encoding: <unresolved>; flags: 0x2.
    public var loadTiming: Any = ()
    /// Original field: cleanupStablePlaybackBeforeDeinit; encoding: yyYbcSg; flags: 0x0.
    public var cleanupStablePlaybackBeforeDeinit: Any = ()
    /// Original field: relatedLoadTimeoutNanoseconds; encoding: <unresolved>; flags: 0xfff93bda.
    public var relatedLoadTimeoutNanoseconds: Any = ()
}

/// Original nominal name: LiveDanmakuService; kind: class; descriptor: 0xc22a94; field count: 16.
public final class LiveDanmakuService_2_0_3 {
    /// Original field: roomID; encoding: Si; flags: 0x0.
    public var roomID: Int = 0
    /// Original field: api; encoding: <unresolved>; flags: 0x0.
    public var api: Any = ()
    /// Original field: session; encoding: So12NSURLSessionC; flags: 0x0.
    public var session: URLSession = .shared
    /// Original field: onItems; encoding: <unresolved>; flags: 0x0.
    public var onItems: Any = ()
    /// Original field: onDiagnostics; encoding: <unresolved>; flags: 0x0.
    public var onDiagnostics: Any = ()
    /// Original field: logger; encoding: <unresolved>; flags: 0x0.
    public var logger: Any = ()
    /// Original field: stateQueue; encoding: So17OS_dispatch_queueC; flags: 0x2.
    public var stateQueue: Any = ()
    /// Original field: task; encoding: So25NSURLSessionWebSocketTaskCSg; flags: 0x2.
    public var task: URLSessionWebSocketTask? = nil
    /// Original field: networkWebSocket; encoding: <unresolved>; flags: 0x2.
    public var networkWebSocket: Any = ()
    /// Original field: rawWebSocket; encoding: <unresolved>; flags: 0x2.
    public var rawWebSocket: Any = ()
    /// Original field: heartbeatTask; encoding: <unresolved>; flags: 0x2.
    /// Decoded relative typeref: `ScTyy...GSg` -> `Task<Void, Never>?`.
    public var heartbeatTask: Task<Void, Never>? = nil
    /// Original field: receiveTask; encoding: <unresolved>; flags: 0x2.
    /// Decoded relative typeref: `ScTyy...GSg` -> `Task<Void, Never>?`.
    public var receiveTask: Task<Void, Never>? = nil
    /// Original field: reconnectTask; encoding: <unresolved>; flags: 0x2.
    /// Decoded relative typeref: `ScTyy...GSg` -> `Task<Void, Never>?`.
    public var reconnectTask: Task<Void, Never>? = nil
    /// Original field: isStopped; encoding: Sb; flags: 0x2.
    public var isStopped: Bool = false
    /// Original field: reconnectAttempt; encoding: Si; flags: 0x0.
    public var reconnectAttempt: Int = 0
    /// Original field: startDate; encoding: <unresolved>; flags: 0xffefdb14.
    public var startDate: Any = ()
}

/// Original nominal name: SessionStore; kind: class; descriptor: 0xc2c288; field count: 25.
public final class SessionStore_2_0_3 {
    /// Original field: _sessdata; encoding: <unresolved>; flags: 0x2.
    public var _sessdata: Any = ()
    /// Original field: _accessKey; encoding: <unresolved>; flags: 0x2.
    public var _accessKey: Any = ()
    /// Original field: _loginCredentialKind; encoding: <unresolved>; flags: 0x2.
    public var _loginCredentialKind: Any = ()
    /// Original field: _user; encoding: <unresolved>; flags: 0x2.
    public var _user: Any = ()
    /// Original field: _playbackCredentialVersion; encoding: <unresolved>; flags: 0x2.
    public var _playbackCredentialVersion: Any = ()
    /// Original field: _playbackAccountCredentialVersion; encoding: <unresolved>; flags: 0x2.
    public var _playbackAccountCredentialVersion: Any = ()
    /// Original field: _dynamicFeedAccountCredentialVersion; encoding: <unresolved>; flags: 0x2.
    public var _dynamicFeedAccountCredentialVersion: Any = ()
    /// Original field: _interactionAccountCredentialVersion; encoding: <unresolved>; flags: 0x2.
    public var _interactionAccountCredentialVersion: Any = ()
    /// Original field: _historyAccountCredentialVersion; encoding: <unresolved>; flags: 0x2.
    public var _historyAccountCredentialVersion: Any = ()
    /// Original field: _accountConfigurationVersion; encoding: <unresolved>; flags: 0x2.
    public var _accountConfigurationVersion: Any = ()
    /// Original field: _accounts; encoding: <unresolved>; flags: 0x2.
    public var _accounts: Any = ()
    /// Original field: _mainAccountMID; encoding: <unresolved>; flags: 0x2.
    public var _mainAccountMID: Any = ()
    /// Original field: _playbackAccountMID; encoding: <unresolved>; flags: 0x2.
    public var _playbackAccountMID: Any = ()
    /// Original field: _dynamicFeedAccountMID; encoding: <unresolved>; flags: 0x2.
    public var _dynamicFeedAccountMID: Any = ()
    /// Original field: _interactionAccountMID; encoding: <unresolved>; flags: 0x2.
    public var _interactionAccountMID: Any = ()
    /// Original field: _historyAccountPolicy; encoding: <unresolved>; flags: 0x0.
    public var _historyAccountPolicy: Any = ()
    /// Original field: keychain; encoding: <unresolved>; flags: 0x0.
    public var keychain: Any = ()
    /// Original field: sessdataKey; encoding: SS; flags: 0x0.
    public var sessdataKey: String = ""
    /// Original field: accessKeyKey; encoding: SS; flags: 0x0.
    public var accessKeyKey: String = ""
    /// Original field: loginCookieHeaderKey; encoding: SS; flags: 0x0.
    public var loginCookieHeaderKey: String = ""
    /// Original field: loginCredentialKindKey; encoding: SS; flags: 0x0.
    public var loginCredentialKindKey: String = ""
    /// Original field: accountRegistryKey; encoding: SS; flags: 0x0.
    public var accountRegistryKey: String = ""
    /// Original field: buvidKey; encoding: SS; flags: 0x2.
    public var buvidKey: String = ""
    /// Original field: loginCookieHeader; encoding: SSSg; flags: 0x2.
    public var loginCookieHeader: String? = nil
    /// Original field: credentialsByMID; encoding: <unresolved>; flags: 0xfff1b49c.
    public var credentialsByMID: Any = ()
}

/// Original nominal name: PlayerSettings; kind: class; descriptor: 0xc28170; field count: 4.
public final class PlayerSettings_2_0_3 {
    /// Original field: _videoCodecPreference; encoding: <unresolved>; flags: 0x2.
    public var _videoCodecPreference: Any = ()
    /// Original field: _forceHardwareDecodeEnabled; encoding: <unresolved>; flags: 0x2.
    public var _forceHardwareDecodeEnabled: Any = ()
    /// Original field: _dolbyVisionRenderingPolicy; encoding: <unresolved>; flags: 0x0.
    public var _dolbyVisionRenderingPolicy: Any = ()
    /// Original field: userDefaults; encoding: So14NSUserDefaultsC; flags: 0xffef6c88.
    public var userDefaults: UserDefaults = .standard
}

/// Original nominal name: PlaybackSession; kind: class; descriptor: 0xc27c58; field count: 3.
public final class PlaybackSession_2_0_3 {
    /// Original field: _activePlayer; encoding: <unresolved>; flags: 0x2.
    public var _activePlayer: Any = ()
    /// Original field: _snapshot; encoding: <unresolved>; flags: 0x2.
    public var _snapshot: Any = ()
    /// Original field: stateCancellable; encoding: <unresolved>; flags: 0xfff25c4e.
    public var stateCancellable: Any = ()
}

/// Original nominal name: VideoPlayerState; kind: enum; descriptor: 0xc1d294; field count: 8.
public enum VideoPlayerState_2_0_3 {
    /// Original case: failed; encoding: SSSg; flags: 0x0.
    case failed(String?)
    /// Original case: idle; encoding: <unresolved>; flags: 0x0.
    case idle
    /// Original case: preparing; encoding: <unresolved>; flags: 0x0.
    case preparing
    /// Original case: ready; encoding: <unresolved>; flags: 0x0.
    case ready
    /// Original case: buffering; encoding: <unresolved>; flags: 0x0.
    case buffering
    /// Original case: playing; encoding: <unresolved>; flags: 0x0.
    case playing
    /// Original case: paused; encoding: <unresolved>; flags: 0x0.
    case paused
    /// Original case: ended; encoding: <unresolved>; flags: 0xffedc29a.
    case ended
}

/// Original nominal name: VideoPlayerProgress; kind: struct; descriptor: 0xc1d278; field count: 4.
public struct VideoPlayerProgress_2_0_3 {
    /// Original field: currentTime; encoding: Sd; flags: 0x0.
    public var currentTime: Double = 0
    /// Original field: duration; encoding: SdSg; flags: 0x0.
    public var duration: Double? = nil
    /// Original field: isPlaying; encoding: Sb; flags: 0x0.
    public var isPlaying: Bool = false
    /// Original field: bufferedRanges; encoding: <unresolved>; flags: 0xffedc26a.
    public var bufferedRanges: Any = ()
}
