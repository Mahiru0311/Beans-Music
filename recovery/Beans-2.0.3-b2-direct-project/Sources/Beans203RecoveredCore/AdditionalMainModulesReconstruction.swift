import Foundation

// Additional direct field reconstruction generated from Beans 2.0.3 build 2 main-binary metadata only.
// Property bodies and unresolved generic/framework substitutions remain explicit Any.

/// Original nominal: ArtistHomeCache; kind: class; descriptor: 0x7c34b4; fields: 6.
public final class ArtistHomeCache_2_0_3 {
    /// Original field: defaults; encoding: So14NSUserDefaultsC; decoded typeref: So14NSUserDefaultsC; flags: 0x0.
    public var defaults: UserDefaults = .standard
    /// Original field: storageKey; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var storageKey: String = ""
    /// Original field: lock; encoding: So6NSLockC; decoded typeref: So6NSLockC; flags: 0x0.
    public var lock: NSLock = NSLock()
    /// Original field: persistenceQueue; encoding: So17OS_dispatch_queueC; decoded typeref: So17OS_dispatch_queueC; flags: 0x2.
    public var persistenceQueue: Any = ()
    /// Original field: entries; encoding: <unresolved>; decoded typeref: SDySSEntryG; flags: 0x0.
    public var entries: Any = ()
    /// Original field: ttl; encoding: Sd; decoded typeref: Sd; flags: 0xffd54fca.
    public var ttl: Double = 0
    public init() {}
}

/// Original nominal: ArtistHomeSheet; kind: struct; descriptor: 0x7c353c; fields: 20.
public struct ArtistHomeSheet_2_0_3 {
    /// Original field: _immersiveDetail; encoding: <unresolved>; decoded typeref: symbolic@0xb0a40cySbG; flags: 0x2.
    public var _immersiveDetail: Any = ()
    /// Original field: _theme; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb0908cG; flags: 0x2.
    public var _theme: Any = ()
    /// Original field: _player; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb091d4G; flags: 0x2.
    public var _player: Any = ()
    /// Original field: _dismiss; encoding: <unresolved>; decoded typeref: symbolic@0xb0a63cysymbolic@0xb0a85cG; flags: 0x0.
    public var _dismiss: Any = ()
    /// Original field: artistName; encoding: SS; decoded typeref: SS; flags: 0x2.
    public var artistName: String = ""
    /// Original field: artistSource; encoding: <unresolved>; decoded typeref: symbolic@0xb09084; flags: 0x2.
    public var artistSource: Any = ()
    /// Original field: artistID; encoding: SSSg; decoded typeref: SSSg; flags: 0x2.
    public var artistID: String? = nil
    /// Original field: embeddedInNavigation; encoding: Sb; decoded typeref: Sb; flags: 0x2.
    public var embeddedInNavigation: Bool = false
    /// Original field: __artist; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ysymbolic@0xb098a4SgG; flags: 0x2.
    public var __artist: Any = ()
    /// Original field: __hotSongs; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySaysymbolic@0xb09894GG; flags: 0x2.
    public var __hotSongs: Any = ()
    /// Original field: __albums; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySaysymbolic@0xb0989cGG; flags: 0x2.
    public var __albums: Any = ()
    /// Original field: __loading; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __loading: Any = ()
    /// Original field: __errorMessage; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySSSgG; flags: 0x2.
    public var __errorMessage: Any = ()
    /// Original field: __searchText; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySSG; flags: 0x2.
    public var __searchText: Any = ()
    /// Original field: __showBatchDownload; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __showBatchDownload: Any = ()
    /// Original field: __selectedAlbum; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ysymbolic@0xb0989cSgG; flags: 0x2.
    public var __selectedAlbum: Any = ()
    /// Original field: __loadTask; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4yScTyytsymbolic@0xb0d314GSgG; flags: 0x2.
    public var __loadTask: Any = ()
    /// Original field: _musicCollections; encoding: <unresolved>; decoded typeref: symbolic@0xb0aa0cysymbolic@0xb097acG; flags: 0x2.
    public var _musicCollections: Any = ()
    /// Original field: _downloadFeatureUnlocked; encoding: <unresolved>; decoded typeref: symbolic@0xb0a40cySbG; flags: 0x2.
    public var _downloadFeatureUnlocked: Any = ()
    /// Original field: _showSongVIPBadge; encoding: <unresolved>; decoded typeref: symbolic@0xb0a40cySbG; flags: 0xffe58afc.
    public var _showSongVIPBadge: Any = ()
    public init() {}
}

/// Original nominal: BeansCacheUsage; kind: struct; descriptor: 0x7c36bc; fields: 3.
public struct BeansCacheUsage_2_0_3 {
    /// The category enum and both size fields are direct field metadata.
    /// `symbolic@0xb0d2fc` is the same nominal used by `CMTime.value` and
    /// `CMTime.epoch`; it is retained as `Int64` rather than narrowed to Int.
    public var category: BeansCacheCategory_2_0_3
    public var diskBytes: Int64
    public var memoryBytes: Int64
    public init(category: BeansCacheCategory_2_0_3 = .images,
                diskBytes: Int64 = 0, memoryBytes: Int64 = 0) {
        self.category = category
        self.diskBytes = diskBytes
        self.memoryBytes = memoryBytes
    }
}

/// Original nominal: BeansCacheCategory; kind: enum; descriptor: 0x7c36d8; fields: 7.
public enum BeansCacheCategory_2_0_3: CaseIterable, Hashable, Sendable {
    /// Original field: images; encoding: <unresolved>; decoded typeref: <unresolved>; flags: 0x0.
    case images
    /// Original field: immersive; encoding: <unresolved>; decoded typeref: <unresolved>; flags: 0x0.
    case immersive
    /// Original field: metadata; encoding: <unresolved>; decoded typeref: <unresolved>; flags: 0x0.
    case metadata
    /// Original field: lyrics; encoding: <unresolved>; decoded typeref: <unresolved>; flags: 0x0.
    case lyrics
    /// Original field: network; encoding: <unresolved>; decoded typeref: <unresolved>; flags: 0x0.
    case network
    /// Original field: bilibili; encoding: <unresolved>; decoded typeref: <unresolved>; flags: 0x0.
    case bilibili
    /// Original field: logs; encoding: <unresolved>; decoded typeref: <unresolved>; flags: 0xffd63790.
    case logs
}

/// Original nominal: BeansCacheSettingsSection; kind: struct; descriptor: 0x7c36f4; fields: 4.
public struct BeansCacheSettingsSection_2_0_3 {
    /// Original field: _manager; encoding: <unresolved>; decoded typeref: symbolic@0xb0a66cyBeansCacheManagerG; flags: 0x2.
    public var _manager: Any = ()
    /// `State<Bool>` backing storage; the wrapped value is retained directly
    /// here because SwiftUI's property-wrapper payload is not source-visible.
    public var __expanded: Bool = false
    /// `State<[BeansCacheCategory]>` backing storage.
    public var __pending: [BeansCacheCategory_2_0_3] = []
    /// `State<Bool>` backing storage.
    public var __confirm: Bool = false
    public init() {}
}

/// Original nominal: BeansDiagnosticSpan; kind: class; descriptor: 0x7c3738; fields: 12.
public final class BeansDiagnosticSpan_2_0_3 {
    /// Original field: id; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var id: String = ""
    /// Original field: startedAt; encoding: <unresolved>; decoded typeref: symbolic@0xb0e184; flags: 0x0.
    public var startedAt: Date = Date()
    /// Original field: uptime; encoding: Sd; decoded typeref: Sd; flags: 0x0.
    public var uptime: Double = 0
    /// Original field: module; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var module: String = ""
    /// Original field: operation; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var operation: String = ""
    /// Original field: input; encoding: SDyS2SG; decoded typeref: SDyS2SG; flags: 0x0.
    public var input: [String: String] = [:]
    /// Original field: file; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var file: String = ""
    /// Original field: line; encoding: Si; decoded typeref: Si; flags: 0x0.
    public var line: Int = 0
    /// Original field: function; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var function: String = ""
    /// Original field: logger; encoding: <unresolved>; decoded typeref: symbolic@0xb08fec; flags: 0x0.
    public var logger: Any = ()
    /// Original field: lock; encoding: So6NSLockC; decoded typeref: So6NSLockC; flags: 0x2.
    public var lock: NSLock = NSLock()
    /// Original field: finished; encoding: Sb; decoded typeref: Sb; flags: 0xffd64c32.
    public var finished: Bool = false
    public init() {}
}

/// Original nominal: BeansDiagnosticPageModifier; kind: struct; descriptor: 0x7c37c4; fields: 4.
public struct BeansDiagnosticPageModifier_2_0_3 {
    /// Original field: name; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var name: String = ""
    /// Original field: sourceFile; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var sourceFile: String = ""
    /// Original field: sourceLine; encoding: Si; decoded typeref: Si; flags: 0x2.
    public var sourceLine: Int = 0
    /// Original field: __span; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4yBeansDiagnosticSpanSgG; flags: 0xffd64d80.
    public var __span: Any = ()
    public init() {}
}

/// Original nominal: BeansDiagnosticFile; kind: struct; descriptor: 0x7c3858; fields: 2.
public struct BeansDiagnosticFile_2_0_3 {
    /// Original field: url; encoding: <unresolved>; decoded typeref: symbolic@0xb0e014; flags: 0x0.
    public var url: Any = ()
    /// Original field: bytes; encoding: Si; decoded typeref: Si; flags: 0xffd68042.
    public var bytes: Int = 0
    public init() {}
}

/// Original nominal: BeansDiagnosticsSettingsView; kind: struct; descriptor: 0x7c3880; fields: 9.
public struct BeansDiagnosticsSettingsView_2_0_3 {
    /// Original field: _dismiss; encoding: <unresolved>; decoded typeref: symbolic@0xb0a63cysymbolic@0xb0a85cG; flags: 0x2.
    public var _dismiss: Any = ()
    /// Original field: _diagnostics; encoding: <unresolved>; decoded typeref: symbolic@0xb0aa0cyBeansDiagnosticsG; flags: 0x2.
    public var _diagnostics: Any = ()
    /// Original field: _logger; encoding: <unresolved>; decoded typeref: symbolic@0xb0aa0cysymbolic@0xb08fecG; flags: 0x2.
    public var _logger: Any = ()
    /// Original field: __filter; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ysymbolic@0xb0900cSgG; flags: 0x2.
    public var __filter: Any = ()
    /// Original field: __query; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySSG; flags: 0x2.
    public var __query: Any = ()
    /// Original field: __files; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySayBeansDiagnosticFileGG; flags: 0x2.
    public var __files: Any = ()
    /// Original field: __confirmClear; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __confirmClear: Any = ()
    /// Original field: _exporter; encoding: <unresolved>; decoded typeref: symbolic@0xb0a66cysymbolic@0xb08e0cG; flags: 0x2.
    public var _exporter: Any = ()
    /// Original field: __clearError; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySSSgG; flags: 0xffd64d4a.
    public var __clearError: Any = ()
    public init() {}
}

/// Original nominal: BeansDiagnosticGlassSurface; kind: struct; descriptor: 0x7c38b0; fields: 1.
public struct BeansDiagnosticGlassSurface_2_0_3 {
    /// Original field: _theme; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb0908cG; flags: 0xffd6802c.
    public var _theme: Any = ()
    public init() {}
}

/// Original nominal: BeansDiagnosticFileView; kind: struct; descriptor: 0x7c38d4; fields: 2.
public struct BeansDiagnosticFileView_2_0_3 {
    /// Original field: url; encoding: <unresolved>; decoded typeref: symbolic@0xb0e014; flags: 0x2.
    public var url: Any = ()
    /// Original field: __content; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySSG; flags: 0xffd6800a.
    public var __content: Any = ()
    public init() {}
}

/// Original nominal: BeansDiagnosticTextView; kind: struct; descriptor: 0x7c3904; fields: 2.
public struct BeansDiagnosticTextView_2_0_3 {
    /// Original field: title; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var title: String = ""
    /// Original field: text; encoding: SS; decoded typeref: SS; flags: 0xffd685ec.
    public var text: String = ""
    public init() {}
}

/// Original nominal: BilibiliAudioCommentsPage; kind: struct; descriptor: 0x7c40d8; fields: 1.
public struct BilibiliAudioCommentsPage_2_0_3 {
    /// Original field: song; encoding: <unresolved>; decoded typeref: symbolic@0xb09894; flags: 0xffd6894e.
    public var song: Any = ()
    public init() {}
}

/// Original nominal: ChangelogListView; kind: struct; descriptor: 0x7c4600; fields: 3.
public struct ChangelogListView_2_0_3 {
    /// Original field: _dismiss; encoding: <unresolved>; decoded typeref: symbolic@0xb0a63cysymbolic@0xb0a85cG; flags: 0x2.
    public var _dismiss: Any = ()
    /// Original field: __remoteLogs; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySayVersionLogGG; flags: 0x2.
    public var __remoteLogs: Any = ()
    /// Original field: __isLoading; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0xffd6b278.
    public var __isLoading: Any = ()
    public init() {}
}

/// Original nominal: CommentsSheetHost; kind: struct; descriptor: 0x7c46a0; fields: 2.
public struct CommentsSheetHost_2_0_3 {
    /// Original field: song; encoding: <unresolved>; decoded typeref: symbolic@0xb09894; flags: 0x2.
    public var song: Any = ()
    /// Original field: presentation; encoding: <unresolved>; decoded typeref: CommentsSheetPresentation; flags: 0xffd6b256.
    public var presentation: Any = ()
    public init() {}
}

/// Original nominal: CommentsSheetDetentHost; kind: struct; descriptor: 0x7c46d0; fields: 3.
public struct CommentsSheetDetentHost_2_0_3 {
    /// Original field: song; encoding: <unresolved>; decoded typeref: symbolic@0xb09894; flags: 0x0.
    public var song: Any = ()
    /// Original field: presentation; encoding: <unresolved>; decoded typeref: CommentsSheetPresentation; flags: 0x2.
    public var presentation: Any = ()
    /// Original field: __selectedDetent; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ysymbolic@0xb09814G; flags: 0xffd6b254.
    public var __selectedDetent: Any = ()
    public init() {}
}

/// Original nominal: CommentsSheet; kind: struct; descriptor: 0x7c46f8; fields: 21.
public struct CommentsSheet_2_0_3 {
    /// Original field: _theme; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb0908cG; flags: 0x2.
    public var _theme: Any = ()
    /// Original field: _dismiss; encoding: <unresolved>; decoded typeref: symbolic@0xb0a63cysymbolic@0xb0a85cG; flags: 0x0.
    public var _dismiss: Any = ()
    /// Original field: song; encoding: <unresolved>; decoded typeref: symbolic@0xb09894; flags: 0x2.
    public var song: Any = ()
    /// Original field: isExpanded; encoding: Sb; decoded typeref: Sb; flags: 0x2.
    public var isExpanded: Bool = false
    /// Original field: presentation; encoding: <unresolved>; decoded typeref: CommentsSheetPresentation; flags: 0x2.
    public var presentation: Any = ()
    /// Original field: __page; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ysymbolic@0xb0903cSgG; flags: 0x2.
    public var __page: Any = ()
    /// Original field: __qqHotComments; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySaysymbolic@0xb090ecGG; flags: 0x2.
    public var __qqHotComments: Any = ()
    /// Original field: __qqLatestComments; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySaysymbolic@0xb090ecGG; flags: 0x2.
    public var __qqLatestComments: Any = ()
    /// Original field: __qqTotal; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySiG; flags: 0x2.
    public var __qqTotal: Any = ()
    /// Original field: __qqPageNum; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySiG; flags: 0x2.
    public var __qqPageNum: Any = ()
    /// Original field: __kugouHotComments; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySaysymbolic@0xb090ecGG; flags: 0x2.
    public var __kugouHotComments: Any = ()
    /// Original field: __kugouLatestComments; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySaysymbolic@0xb090ecGG; flags: 0x2.
    public var __kugouLatestComments: Any = ()
    /// Original field: __kugouTotal; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySiG; flags: 0x2.
    public var __kugouTotal: Any = ()
    /// Original field: __kugouPageNum; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySiG; flags: 0x2.
    public var __kugouPageNum: Any = ()
    /// Original field: __loading; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __loading: Any = ()
    /// Original field: __errorMessage; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySSSgG; flags: 0x2.
    public var __errorMessage: Any = ()
    /// Original field: __offset; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySiG; flags: 0x2.
    public var __offset: Any = ()
    /// Original field: _selectedSection; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4yCommentSectionG; flags: 0x2.
    public var _selectedSection: Any = ()
    /// Original field: __lastBilibiliPageCount; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySiG; flags: 0x2.
    public var __lastBilibiliPageCount: Any = ()
    /// Original field: __loadingNextPage; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x0.
    public var __loadingNextPage: Any = ()
    /// Original field: qqPageSize; encoding: Si; decoded typeref: Si; flags: 0xffd6f60a.
    public var qqPageSize: Int = 0
    public init() {}
}

/// Original nominal: CommentsSheetPresentation; kind: enum; descriptor: 0x7c4720; fields: 2.
public enum CommentsSheetPresentation_2_0_3 {
    /// Original field: standard; encoding: <unresolved>; decoded typeref: <unresolved>; flags: 0x0.
    public static let standard: Any = ()
    /// Original field: reference; encoding: <unresolved>; decoded typeref: <unresolved>; flags: 0xffd6b274.
    public static let reference: Any = ()
}

/// Original nominal: GlobalFloatingImageCache; kind: class; descriptor: 0x7c4e74; fields: 2.
public final class GlobalFloatingImageCache_2_0_3 {
    /// Original field: encodedValue; encoding: SS; decoded typeref: SS; flags: 0x2.
    public var encodedValue: String = ""
    /// Original field: cachedImage; encoding: So7UIImageCSg; decoded typeref: So7UIImageCSg; flags: 0xffd7033c.
    public var cachedImage: Any = ()
    public init() {}
}

/// Original nominal: CoverBlurView; kind: class; descriptor: 0x7c5980; fields: 6.
public final class CoverBlurView_2_0_3 {
    /// Original field: imageView; encoding: So11UIImageViewC; decoded typeref: So11UIImageViewC; flags: 0x0.
    public var imageView: Any = ()
    /// Original field: gradientLayer; encoding: So15CAGradientLayerC; decoded typeref: So15CAGradientLayerC; flags: 0x0.
    public var gradientLayer: Any = ()
    /// Original field: gradientHost; encoding: So6UIViewC; decoded typeref: So6UIViewC; flags: 0x0.
    public var gradientHost: Any = ()
    /// Original field: tintView; encoding: So6UIViewC; decoded typeref: So6UIViewC; flags: 0x2.
    public var tintView: Any = ()
    /// Original field: currentURL; encoding: <unresolved>; decoded typeref: symbolic@0xb0e014Sg; flags: 0x2.
    public var currentURL: Any = ()
    /// Original field: animationsEnabled; encoding: Sb; decoded typeref: Sb; flags: 0xffd791e4.
    public var animationsEnabled: Bool = false
    public init() {}
}

/// Original nominal: CoverBlurBackground; kind: struct; descriptor: 0x7c59b8; fields: 3.
public struct CoverBlurBackground_2_0_3 {
    /// Original field: url; encoding: <unresolved>; decoded typeref: symbolic@0xb0e014Sg; flags: 0x0.
    public var url: Any = ()
    /// Original field: scheme; encoding: <unresolved>; decoded typeref: symbolic@0xb0a5a4; flags: 0x2.
    public var scheme: Any = ()
    /// Original field: animationsEnabled; encoding: Sb; decoded typeref: Sb; flags: 0xffd79218.
    public var animationsEnabled: Bool = false
    public init() {}
}

/// Original nominal: DetailSongsCache; kind: class; descriptor: 0x7c5cc4; fields: 6.
public final class DetailSongsCache_2_0_3 {
    /// Original field: defaults; encoding: So14NSUserDefaultsC; decoded typeref: So14NSUserDefaultsC; flags: 0x0.
    public var defaults: UserDefaults = .standard
    /// Original field: storageKey; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var storageKey: String = ""
    /// Original field: lock; encoding: So6NSLockC; decoded typeref: So6NSLockC; flags: 0x0.
    public var lock: NSLock = NSLock()
    /// Original field: persistenceQueue; encoding: So17OS_dispatch_queueC; decoded typeref: So17OS_dispatch_queueC; flags: 0x2.
    public var persistenceQueue: Any = ()
    /// Original field: entries; encoding: <unresolved>; decoded typeref: SDySSEntryG; flags: 0x0.
    public var entries: Any = ()
    /// Original field: ttl; encoding: Sd; decoded typeref: Sd; flags: 0xffd791ce.
    public var ttl: Double = 0
    public init() {}
}

/// Original nominal: DeviceReporter; kind: class; descriptor: 0x7c5f40; fields: 5.
public final class DeviceReporter_2_0_3 {
    /// Original field: reported; encoding: Sb; decoded typeref: Sb; flags: 0x2.
    public var reported: Bool = false
    /// Original field: heartbeatTask; encoding: <unresolved>; decoded typeref: ScTyytsymbolic@0xb0d314GSg; flags: 0x2.
    public var heartbeatTask: Any = ()
    /// Original field: heartbeatInFlight; encoding: Sb; decoded typeref: Sb; flags: 0x0.
    public var heartbeatInFlight: Bool = false
    /// Original field: apiEndpoint; encoding: <unresolved>; decoded typeref: symbolic@0xb0e014; flags: 0x0.
    public var apiEndpoint: Any = ()
    /// Original field: legacyHeartbeatEndpoint; encoding: <unresolved>; decoded typeref: symbolic@0xb0e014; flags: 0xffd8c86a.
    public var legacyHeartbeatEndpoint: Any = ()
    public init() {}
}

/// Original nominal: FeedbackListResponse; kind: struct; descriptor: 0x7c6090; fields: 3.
public struct FeedbackListResponse_2_0_3 {
    /// Original field: ok; encoding: SbSg; decoded typeref: SbSg; flags: 0x0.
    public var ok: Bool? = nil
    /// Original field: message; encoding: SSSg; decoded typeref: SSSg; flags: 0x0.
    public var message: String? = nil
    /// Original field: feedback; encoding: <unresolved>; decoded typeref: Saysymbolic@0xb0948cG; flags: 0xffd8b738.
    public var feedback: Any = ()
    public init() {}
}

/// Original nominal: DiscoverCache; kind: class; descriptor: 0x7c6230; fields: 7.
public final class DiscoverCache_2_0_3 {
    /// Original field: listTTL; encoding: Sd; decoded typeref: Sd; flags: 0x0.
    public var listTTL: Double = 0
    /// Original field: dailyTTL; encoding: Sd; decoded typeref: Sd; flags: 0x0.
    public var dailyTTL: Double = 0
    /// Original field: qqRecommendationTTL; encoding: Sd; decoded typeref: Sd; flags: 0x0.
    public var qqRecommendationTTL: Double = 0
    /// Original field: storageKey; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var storageKey: String = ""
    /// Original field: qishuiSnapshotVersionKey; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var qishuiSnapshotVersionKey: String = ""
    /// Original field: qishuiSnapshotVersion; encoding: Si; decoded typeref: Si; flags: 0x2.
    public var qishuiSnapshotVersion: Int = 0
    /// Original field: store; encoding: <unresolved>; decoded typeref: SDySSSnapshotG; flags: 0xffd8c338.
    public var store: Any = ()
    public init() {}
}

/// Original nominal: BeansFavoriteDetailSwipeBack; kind: struct; descriptor: 0x7c68b0; fields: 1.
public struct BeansFavoriteDetailSwipeBack_2_0_3 {
    /// Original field: onBack; encoding: yyc; decoded typeref: yyc; flags: 0xffd500e0.
    public var onBack: Any = ()
    public init() {}
}

/// Original nominal: FeedbackHistoryStore; kind: class; descriptor: 0x7c695c; fields: 5.
public final class FeedbackHistoryStore_2_0_3 {
    /// Original field: _entries; encoding: <unresolved>; decoded typeref: symbolic@0xb09f7cySayFeedbackHistoryEntryGG; flags: 0x2.
    public var _entries: Any = ()
    /// Original field: _unreadReplyCount; encoding: <unresolved>; decoded typeref: symbolic@0xb09f7cySiG; flags: 0x0.
    public var _unreadReplyCount: Any = ()
    /// Original field: storageKey; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var storageKey: String = ""
    /// Original field: seenReplyIDsKey; encoding: SS; decoded typeref: SS; flags: 0x2.
    public var seenReplyIDsKey: String = ""
    /// Original field: seenReplyIDs; encoding: ShySSG; decoded typeref: ShySSG; flags: 0xffdbc71a.
    public var seenReplyIDs: Set<String> = []
    public init() {}
}

/// Original nominal: FeedbackHistoryEntry; kind: struct; descriptor: 0x7c69a4; fields: 6.
public struct FeedbackHistoryEntry_2_0_3 {
    /// Original field: id; encoding: <unresolved>; decoded typeref: symbolic@0xb0e1e4; flags: 0x0.
    public var id: Any = ()
    /// Original field: feedbackID; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var feedbackID: String = ""
    /// Original field: submittedAt; encoding: <unresolved>; decoded typeref: symbolic@0xb0e184; flags: 0x0.
    public var submittedAt: Date = Date()
    /// Original field: problem; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var problem: String = ""
    /// Original field: attachmentCount; encoding: Si; decoded typeref: Si; flags: 0x2.
    public var attachmentCount: Int = 0
    /// Original field: replies; encoding: <unresolved>; decoded typeref: Saysymbolic@0xb0918cG; flags: 0xffdbc704.
    public var replies: Any = ()
    public init() {}
}

/// Original nominal: FeedbackServerRecord; kind: struct; descriptor: 0x7c69f0; fields: 5.
public struct FeedbackServerRecord_2_0_3 {
    /// Original field: id; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var id: String = ""
    /// Original field: submittedAt; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var submittedAt: String = ""
    /// Original field: problem; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var problem: String = ""
    /// Original field: attachmentCount; encoding: Si; decoded typeref: Si; flags: 0x0.
    public var attachmentCount: Int = 0
    /// Original field: replies; encoding: <unresolved>; decoded typeref: Saysymbolic@0xb0918cG; flags: 0xffdbc678.
    public var replies: Any = ()
    public init() {}
}

/// Original nominal: FeedbackReply; kind: struct; descriptor: 0x7c6a0c; fields: 5.
public struct FeedbackReply_2_0_3 {
    /// Original field: id; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var id: String = ""
    /// Original field: feedbackID; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var feedbackID: String = ""
    /// Original field: text; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var text: String = ""
    /// Original field: attachments; encoding: <unresolved>; decoded typeref: Saysymbolic@0xb0981cG; flags: 0x0.
    public var attachments: Any = ()
    /// Original field: sentAt; encoding: SS; decoded typeref: SS; flags: 0xffdbc6be.
    public var sentAt: String = ""
    public init() {}
}

/// Original nominal: FeedbackRemoteAttachment; kind: struct; descriptor: 0x7c6a60; fields: 5.
public struct FeedbackRemoteAttachment_2_0_3 {
    /// Original field: name; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var name: String = ""
    /// Original field: originalName; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var originalName: String = ""
    /// Original field: mimeType; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var mimeType: String = ""
    /// Original field: size; encoding: Si; decoded typeref: Si; flags: 0x0.
    public var size: Int = 0
    /// Original field: url; encoding: SS; decoded typeref: SS; flags: 0xffdbc632.
    public var url: String = ""
    public init() {}
}

/// Original nominal: FeedbackDocumentPicker; kind: struct; descriptor: 0x7c6b18; fields: 1.
public struct FeedbackDocumentPicker_2_0_3 {
    /// Original field: onPick; encoding: <unresolved>; decoded typeref: ySaysymbolic@0xb0e014Gc; flags: 0xffdbc5b8.
    public var onPick: Any = ()
    public init() {}
}

/// Original nominal: FeedbackPhotoPicker; kind: struct; descriptor: 0x7c6b3c; fields: 1.
public struct FeedbackPhotoPicker_2_0_3 {
    /// Original field: onPick; encoding: <unresolved>; decoded typeref: ySaysymbolic@0xb0e69cGc; flags: 0xffdbc5c4.
    public var onPick: Any = ()
    public init() {}
}

/// Original nominal: FeedbackAttachment; kind: struct; descriptor: 0x7c6b60; fields: 3.
public struct FeedbackAttachment_2_0_3 {
    /// Original field: id; encoding: <unresolved>; decoded typeref: symbolic@0xb0e1e4; flags: 0x0.
    public var id: Any = ()
    /// Original field: url; encoding: <unresolved>; decoded typeref: symbolic@0xb0e014; flags: 0x0.
    public var url: Any = ()
    /// Original field: contentType; encoding: <unresolved>; decoded typeref: symbolic@0xb0d924; flags: 0xffdbc59c.
    public var contentType: Any = ()
    public init() {}
}

/// Original nominal: FeedbackSheet; kind: struct; descriptor: 0x7c6b88; fields: 14.
public struct FeedbackSheet_2_0_3 {
    /// Original field: _dismiss; encoding: <unresolved>; decoded typeref: symbolic@0xb0a63cysymbolic@0xb0a85cG; flags: 0x2.
    public var _dismiss: Any = ()
    /// Original field: _theme; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb0908cG; flags: 0x2.
    public var _theme: Any = ()
    /// Original field: _history; encoding: <unresolved>; decoded typeref: symbolic@0xb0aa0cysymbolic@0xb09484G; flags: 0x2.
    public var _history: Any = ()
    /// Original field: __phoneModel; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySSG; flags: 0x2.
    public var __phoneModel: Any = ()
    /// Original field: __phoneSystem; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySSG; flags: 0x2.
    public var __phoneSystem: Any = ()
    /// Original field: __problem; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySSG; flags: 0x2.
    public var __problem: Any = ()
    /// Original field: __attachments; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySayFeedbackAttachmentGG; flags: 0x2.
    public var __attachments: Any = ()
    /// Original field: __showPhotoPicker; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __showPhotoPicker: Any = ()
    /// Original field: __showDocumentPicker; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __showDocumentPicker: Any = ()
    /// Original field: __isSubmitting; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __isSubmitting: Any = ()
    /// Original field: __errorMessage; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySSSgG; flags: 0x2.
    public var __errorMessage: Any = ()
    /// Original field: __feedbackToDelete; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ysymbolic@0xb0947cSgG; flags: 0x2.
    public var __feedbackToDelete: Any = ()
    /// Original field: __showDeleteConfirmation; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __showDeleteConfirmation: Any = ()
    /// Original field: __deletingFeedbackID; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySSSgG; flags: 0xffdc7b54.
    public var __deletingFeedbackID: Any = ()
    public init() {}
}

/// Original nominal: KaraokeLyricText; kind: struct; descriptor: 0x7c7280; fields: 8.
public struct KaraokeLyricText_2_0_3 {
    /// Original field: line; encoding: <unresolved>; decoded typeref: symbolic@0xb0991c; flags: 0x0.
    public var line: Any = ()
    /// Original field: playbackTime; encoding: Sdyc; decoded typeref: Sdyc; flags: 0x0.
    public var playbackTime: (Double) -> Void = { _ in }
    /// Original field: isPlaying; encoding: Sb; decoded typeref: Sb; flags: 0x0.
    public var isPlaying: Bool = false
    /// Original field: isActive; encoding: Sb; decoded typeref: Sb; flags: 0x0.
    public var isActive: Bool = false
    /// Original field: enabled; encoding: Sb; decoded typeref: Sb; flags: 0x0.
    public var enabled: Bool = false
    /// Original field: font; encoding: <unresolved>; decoded typeref: symbolic@0xb0ba5c; flags: 0x0.
    public var font: Any = ()
    /// Original field: style; encoding: <unresolved>; decoded typeref: symbolic@0xb0c27c; flags: 0x0.
    public var style: Any = ()
    /// Original field: fallbackOpacity; encoding: Sd; decoded typeref: Sd; flags: 0xffdcedce.
    public var fallbackOpacity: Double = 0
    public init() {}
}

/// Original nominal: BeansLXScriptUtilsBridge; kind: class; descriptor: 0x7c73f8; fields: 2.
public final class BeansLXScriptUtilsBridge_2_0_3 {
    /// Original field: buffer; encoding: <unresolved>; decoded typeref: BeansLXScriptBufferBridge; flags: 0x0.
    public var buffer: Any = ()
    /// Original field: crypto; encoding: <unresolved>; decoded typeref: BeansLXScriptCryptoBridge; flags: 0xffdd056c.
    public var crypto: Any = ()
    public init() {}
}

/// Original nominal: BeansLXScriptDoneBridge; kind: class; descriptor: 0x7c7450; fields: 3.
public final class BeansLXScriptDoneBridge_2_0_3 {
    /// Original field: onResolve; encoding: yypSgcSg; decoded typeref: yypSgcSg; flags: 0x2.
    public var onResolve: Any = ()
    /// Original field: onReject; encoding: ySScSg; decoded typeref: ySScSg; flags: 0x2.
    public var onReject: Any = ()
    /// Original field: finished; encoding: Sb; decoded typeref: Sb; flags: 0xffdd0546.
    public var finished: Bool = false
    public init() {}
}

/// Original nominal: BeansLXScriptBridge; kind: class; descriptor: 0x7c747c; fields: 8.
public final class BeansLXScriptBridge_2_0_3 {
    /// Original field: runtimeQueue; encoding: So17OS_dispatch_queueC; decoded typeref: So17OS_dispatch_queueC; flags: 0x0.
    public var runtimeQueue: Any = ()
    /// Original field: session; encoding: So12NSURLSessionC; decoded typeref: So12NSURLSessionC; flags: 0x2.
    public var session: URLSession = .shared
    /// Original field: runtime; encoding: <unresolved>; decoded typeref: BeansLXScriptRuntimeSgXw; flags: 0x0.
    public var runtime: Any = ()
    /// Original field: EVENT_NAMES; encoding: So12NSDictionaryC; decoded typeref: So12NSDictionaryC; flags: 0x0.
    public var EVENT_NAMES: Any = ()
    /// Original field: env; encoding: So12NSDictionaryC; decoded typeref: So12NSDictionaryC; flags: 0x0.
    public var env: Any = ()
    /// Original field: utils; encoding: <unresolved>; decoded typeref: BeansLXScriptUtilsBridge; flags: 0x0.
    public var utils: Any = ()
    /// Original field: version; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var version: String = ""
    /// Original field: currentScriptInfo; encoding: So12NSDictionaryC; decoded typeref: So12NSDictionaryC; flags: 0xffdd04f8.
    public var currentScriptInfo: Any = ()
    public init() {}
}

/// Original nominal: BeansLXScriptTimerBridge; kind: class; descriptor: 0x7c74b8; fields: 5.
public final class BeansLXScriptTimerBridge_2_0_3 {
    /// Original field: runtimeQueue; encoding: So17OS_dispatch_queueC; decoded typeref: So17OS_dispatch_queueC; flags: 0x0.
    public var runtimeQueue: Any = ()
    /// Original field: lock; encoding: So6NSLockC; decoded typeref: So6NSLockC; flags: 0x2.
    public var lock: NSLock = NSLock()
    /// Original field: nextID; encoding: Si; decoded typeref: Si; flags: 0x2.
    public var nextID: Int = 0
    /// Original field: workItems; encoding: <unresolved>; decoded typeref: SDySisymbolic@0xb0d7c4G; flags: 0x2.
    public var workItems: Any = ()
    /// Original field: repeatingTimers; encoding: SDySiSo24OS_dispatch_source_timer_pG; decoded typeref: SDySiSo24OS_dispatch_source_timer_pG; flags: 0xffdd04e4.
    public var repeatingTimers: Any = ()
    public init() {}
}

/// Original nominal: BeansLXScriptRuntime; kind: class; descriptor: 0x7c74f4; fields: 8.
public final class BeansLXScriptRuntime_2_0_3 {
    /// Original field: sourceID; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var sourceID: String = ""
    /// Original field: queue; encoding: So17OS_dispatch_queueC; decoded typeref: So17OS_dispatch_queueC; flags: 0x0.
    public var queue: Any = ()
    /// Original field: context; encoding: So9JSContextC; decoded typeref: So9JSContextC; flags: 0x0.
    public var context: Any = ()
    /// Original field: bridge; encoding: <unresolved>; decoded typeref: BeansLXScriptBridge; flags: 0x0.
    public var bridge: Any = ()
    /// Original field: timers; encoding: <unresolved>; decoded typeref: BeansLXScriptTimerBridge; flags: 0x2.
    public var timers: Any = ()
    /// Original field: handlers; encoding: SDySSSo7JSValueCG; decoded typeref: SDySSSo7JSValueCG; flags: 0x2.
    public var handlers: Any = ()
    /// Original field: capabilities; encoding: SDySSSaySSGG; decoded typeref: SDySSSaySSGG; flags: 0x2.
    public var capabilities: Any = ()
    /// Original field: qualityCapabilities; encoding: SDySSSaySSGG; decoded typeref: SDySSSaySSGG; flags: 0xffdd04a8.
    public var qualityCapabilities: Any = ()
    public init() {}
}

/// Original nominal: LXScriptSourceRunner; kind: class; descriptor: 0x7c7530; fields: 2.
public final class LXScriptSourceRunner_2_0_3 {
    /// Original field: runtimeQueue; encoding: So17OS_dispatch_queueC; decoded typeref: So17OS_dispatch_queueC; flags: 0x2.
    public var runtimeQueue: Any = ()
    /// Original field: cache; encoding: <unresolved>; decoded typeref: SDySSBeansLXScriptRuntimeG; flags: 0xffdd05ac.
    public var cache: Any = ()
    public init() {}
}

/// Original nominal: LocalMusicSection; kind: struct; descriptor: 0x7c7778; fields: 15.
public struct LocalMusicSection_2_0_3 {
    /// Original field: _store; encoding: <unresolved>; decoded typeref: symbolic@0xb0aa0cysymbolic@0xb0937cG; flags: 0x2.
    public var _store: Any = ()
    /// Original field: _player; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb091d4G; flags: 0x2.
    public var _player: Any = ()
    /// Original field: _auth; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb09904G; flags: 0x2.
    public var _auth: Any = ()
    /// Original field: _favorites; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb09224G; flags: 0x2.
    public var _favorites: Any = ()
    /// Original field: _theme; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb0908cG; flags: 0x2.
    public var _theme: Any = ()
    /// Original field: _languageRaw; encoding: <unresolved>; decoded typeref: symbolic@0xb0a40cySSG; flags: 0x2.
    public var _languageRaw: Any = ()
    /// Original field: __showCreate; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __showCreate: Any = ()
    /// Original field: __showImportPlaylist; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __showImportPlaylist: Any = ()
    /// Original field: __showPlaylistOrder; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __showPlaylistOrder: Any = ()
    /// Original field: __newName; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySSG; flags: 0x2.
    public var __newName: Any = ()
    /// Original field: __selected; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ysymbolic@0xb091b4SgG; flags: 0x2.
    public var __selected: Any = ()
    /// Original field: __syncing; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __syncing: Any = ()
    /// Original field: __syncMessage; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySSG; flags: 0x2.
    public var __syncMessage: Any = ()
    /// Original field: __showSyncPicker; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __showSyncPicker: Any = ()
    /// Original field: __selectedSyncTargets; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4yShySyncTargetGG; flags: 0xffde6e8c.
    public var __selectedSyncTargets: Any = ()
    public init() {}
}

/// Original nominal: LyricDebugOverlayWindow; kind: class; descriptor: 0x7c7b34; fields: 2.
public final class LyricDebugOverlayWindow_2_0_3 {
    /// Original field: window; encoding: <unresolved>; decoded typeref: LyricDebugWindowSg; flags: 0x2.
    public var window: Any = ()
    /// Original field: player; encoding: <unresolved>; decoded typeref: symbolic@0xb091d4SgXw; flags: 0xffdf07e8.
    public var player: Any = ()
    public init() {}
}

/// Original nominal: LyricDebugButtonController; kind: class; descriptor: 0x7c7bac; fields: 7.
public final class LyricDebugButtonController_2_0_3 {
    /// Original field: player; encoding: <unresolved>; decoded typeref: symbolic@0xb091d4; flags: 0x0.
    public var player: Any = ()
    /// Original field: button; encoding: So8UIButtonC; decoded typeref: So8UIButtonC; flags: 0x2.
    public var button: Any = ()
    /// Original field: dragStart; encoding: <unresolved>; decoded typeref: CGPoint; flags: 0x2.
    public var dragStart: Any = ()
    /// Original field: previousKeyWindow; encoding: So8UIWindowCSgXw; decoded typeref: So8UIWindowCSgXw; flags: 0x2.
    public var previousKeyWindow: Any = ()
    /// Original field: subscription; encoding: <unresolved>; decoded typeref: symbolic@0xb09efcSg; flags: 0x0.
    public var subscription: Any = ()
    /// Original field: xKey; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var xKey: String = ""
    /// Original field: yKey; encoding: SS; decoded typeref: SS; flags: 0xffdf07c0.
    public var yKey: String = ""
    public init() {}
}

/// Original nominal: LyricDebugPanel; kind: struct; descriptor: 0x7c7be8; fields: 10.
public struct LyricDebugPanel_2_0_3 {
    /// Original field: player; encoding: <unresolved>; decoded typeref: symbolic@0xb091d4; flags: 0x2.
    public var player: Any = ()
    /// Original field: onClose; encoding: yyc; decoded typeref: yyc; flags: 0x2.
    public var onClose: Any = ()
    /// Original field: _dismiss; encoding: <unresolved>; decoded typeref: symbolic@0xb0a63cysymbolic@0xb0a85cG; flags: 0x2.
    public var _dismiss: Any = ()
    /// Original field: _capture; encoding: <unresolved>; decoded typeref: symbolic@0xb0aa0cysymbolic@0xb09314G; flags: 0x2.
    public var _capture: Any = ()
    /// Original field: __snapshot; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySDyS2SGG; flags: 0x2.
    public var __snapshot: Any = ()
    /// Original field: __busy; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __busy: Any = ()
    /// Original field: __errorMessage; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySSSgG; flags: 0x2.
    public var __errorMessage: Any = ()
    /// Original field: __shareURL; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ysymbolic@0xb0e014SgG; flags: 0x2.
    public var __shareURL: Any = ()
    /// Original field: __showShare; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __showShare: Any = ()
    /// Original field: __probeTask; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4yScTyytsymbolic@0xb0d314GSgG; flags: 0xffdf1b6a.
    public var __probeTask: Any = ()
    public init() {}
}

/// Original nominal: LyricRendererDiagnostic; kind: struct; descriptor: 0x7c7c40; fields: 7.
public struct LyricRendererDiagnostic_2_0_3 {
    /// Original field: name; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var name: String = ""
    /// Original field: wordCapable; encoding: Sb; decoded typeref: Sb; flags: 0x0.
    public var wordCapable: Bool = false
    /// Original field: lines; encoding: <unresolved>; decoded typeref: Saysymbolic@0xb0991cG; flags: 0x2.
    public var lines: Any = ()
    /// Original field: _player; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb091d4G; flags: 0x2.
    public var _player: Any = ()
    /// Original field: __id; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ysymbolic@0xb0e1e4G; flags: 0x2.
    public var __id: Any = ()
    /// Original field: __isVisible; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __isVisible: Any = ()
    /// Original field: _enabled; encoding: <unresolved>; decoded typeref: symbolic@0xb0a40cySbG; flags: 0xffdf4ac8.
    public var _enabled: Any = ()
    public init() {}
}

/// Original nominal: LyricDiagnostics; kind: class; descriptor: 0x7c7c90; fields: 11.
public final class LyricDiagnostics_2_0_3 {
    /// Original field: _isRecording; encoding: <unresolved>; decoded typeref: symbolic@0xb09f7cySbG; flags: 0x0.
    public var _isRecording: Any = ()
    /// Original field: lock; encoding: So6NSLockC; decoded typeref: So6NSLockC; flags: 0x2.
    public var lock: NSLock = NSLock()
    /// Original field: enabled; encoding: Sb; decoded typeref: Sb; flags: 0x2.
    public var enabled: Bool = false
    /// Original field: state; encoding: SDyS2SG; decoded typeref: SDyS2SG; flags: 0x2.
    public var state: [String: String] = [:]
    /// Original field: events; encoding: <unresolved>; decoded typeref: SayLyricDiagnosticEventG; flags: 0x2.
    public var events: Any = ()
    /// Original field: activeSongKey; encoding: SS; decoded typeref: SS; flags: 0x2.
    public var activeSongKey: String = ""
    /// Original field: activeRenderer; encoding: <unresolved>; decoded typeref: symbolic@0xb0e1e4Sg; flags: 0x2.
    public var activeRenderer: Any = ()
    /// Original field: loadedLines; encoding: <unresolved>; decoded typeref: Saysymbolic@0xb0991cG; flags: 0x2.
    public var loadedLines: Any = ()
    /// Original field: timer; encoding: So7NSTimerCSg; decoded typeref: So7NSTimerCSg; flags: 0x2.
    public var timer: Any = ()
    /// Original field: startedAt; encoding: Sd; decoded typeref: Sd; flags: 0x2.
    public var startedAt: Double = 0
    /// Original field: player; encoding: <unresolved>; decoded typeref: symbolic@0xb091d4SgXw; flags: 0xffdf4a52.
    public var player: Any = ()
    public init() {}
}

/// Original nominal: LyricDiagnosticEvent; kind: struct; descriptor: 0x7c7cd8; fields: 3.
public struct LyricDiagnosticEvent_2_0_3 {
    /// Original field: time; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var time: String = ""
    /// Original field: event; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var event: String = ""
    /// Original field: values; encoding: SDyS2SG; decoded typeref: SDyS2SG; flags: 0xffdf4a74.
    public var values: [String: String] = [:]
    public init() {}
}

/// Original nominal: LyricDiagnosticReport; kind: struct; descriptor: 0x7c7d18; fields: 7.
public struct LyricDiagnosticReport_2_0_3 {
    /// Original field: schema; encoding: Si; decoded typeref: Si; flags: 0x0.
    public var schema: Int = 0
    /// Original field: appVersion; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var appVersion: String = ""
    /// Original field: build; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var build: String = ""
    /// Original field: system; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var system: String = ""
    /// Original field: generatedAt; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var generatedAt: String = ""
    /// Original field: state; encoding: SDyS2SG; decoded typeref: SDyS2SG; flags: 0x0.
    public var state: [String: String] = [:]
    /// Original field: events; encoding: <unresolved>; decoded typeref: SayLyricDiagnosticEventG; flags: 0xffdf4a98.
    public var events: Any = ()
    public init() {}
}

/// Original nominal: LyricsCache; kind: class; descriptor: 0x7c7d58; fields: 2.
public final class LyricsCache_2_0_3 {
    /// Original field: prefix; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var prefix: String = ""
    /// Original field: maxAge; encoding: Sd; decoded typeref: Sd; flags: 0xffdf4a40.
    public var maxAge: Double = 0
    public init() {}
}

/// Original nominal: MiniPlayerLyricLine; kind: struct; descriptor: 0x7c7e7c; fields: 5.
public struct MiniPlayerLyricLine_2_0_3 {
    /// Original field: _clock; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb091bcG; flags: 0x2.
    public var _clock: Any = ()
    /// Original field: _lyricOffset; encoding: <unresolved>; decoded typeref: symbolic@0xb0a40cySdG; flags: 0x0.
    public var _lyricOffset: Any = ()
    /// Original field: lyrics; encoding: <unresolved>; decoded typeref: Saysymbolic@0xb0991cG; flags: 0x0.
    public var lyrics: Any = ()
    /// Original field: artist; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var artist: String = ""
    /// Original field: isInline; encoding: Sb; decoded typeref: Sb; flags: 0xffdf636a.
    public var isInline: Bool = false
    public init() {}
}

/// Original nominal: LyricLine; kind: struct; descriptor: 0x7c7fb4; fields: 5.
public struct LyricLine_2_0_3 {
    /// Original field: id; encoding: <unresolved>; decoded typeref: symbolic@0xb0e1e4; flags: 0x0.
    public var id: Any = ()
    /// Original field: time; encoding: Sd; decoded typeref: Sd; flags: 0x0.
    public var time: Double = 0
    /// Original field: text; encoding: SS; decoded typeref: SS; flags: 0x2.
    public var text: String = ""
    /// Original field: translation; encoding: SSSg; decoded typeref: SSSg; flags: 0x2.
    public var translation: String? = nil
    /// Original field: words; encoding: <unresolved>; decoded typeref: SayLyricWordGSg; flags: 0xffd5a918.
    public var words: Any = ()
    public init() {}
}

/// Original nominal: Artist; kind: struct; descriptor: 0x7c7fdc; fields: 4.
public struct Artist_2_0_3 {
    /// Original field: id; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var id: String = ""
    /// Original field: name; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var name: String = ""
    /// Original field: coverURL; encoding: <unresolved>; decoded typeref: symbolic@0xb0e014Sg; flags: 0x0.
    public var coverURL: Any = ()
    /// Original field: source; encoding: <unresolved>; decoded typeref: symbolic@0xb09084; flags: 0xffdcd7ae.
    public var source: Any = ()
    public init() {}
}

/// Original nominal: LyricWord; kind: struct; descriptor: 0x7c819c; fields: 3.
public struct LyricWord_2_0_3 {
    /// Original field: text; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var text: String = ""
    /// Original field: start; encoding: Sd; decoded typeref: Sd; flags: 0x0.
    public var start: Double = 0
    /// Original field: duration; encoding: Sd; decoded typeref: Sd; flags: 0xffdf6064.
    public var duration: Double = 0
    public init() {}
}

/// Original nominal: LyricPreviewRow; kind: struct; descriptor: 0x7c8a68; fields: 2.
public struct LyricPreviewRow_2_0_3 {
    /// Original field: text; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var text: String = ""
    /// Original field: isCurrent; encoding: Sb; decoded typeref: Sb; flags: 0xffed7fce.
    public var isCurrent: Bool = false
    public init() {}
}

/// Original nominal: LyricsSection; kind: struct; descriptor: 0x7c8a84; fields: 30.
public struct LyricsSection_2_0_3 {
    /// Original field: _player; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb091d4G; flags: 0x2.
    public var _player: Any = ()
    /// Original field: _clock; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb091bcG; flags: 0x0.
    public var _clock: Any = ()
    /// Original field: lyrics; encoding: <unresolved>; decoded typeref: Saysymbolic@0xb0991cG; flags: 0x0.
    public var lyrics: Any = ()
    /// Original field: accent; encoding: <unresolved>; decoded typeref: symbolic@0xb0c27c; flags: 0x0.
    public var accent: Any = ()
    /// Original field: secondary; encoding: <unresolved>; decoded typeref: symbolic@0xb0c27c; flags: 0x2.
    public var secondary: Any = ()
    /// Original field: gradientStart; encoding: <unresolved>; decoded typeref: symbolic@0xb0c27cSg; flags: 0x2.
    public var gradientStart: Any = ()
    /// Original field: gradientEnd; encoding: <unresolved>; decoded typeref: symbolic@0xb0c27cSg; flags: 0x2.
    public var gradientEnd: Any = ()
    /// Original field: baseFontSize; encoding: <unresolved>; decoded typeref: symbolic@0xb0e584; flags: 0x2.
    public var baseFontSize: Any = ()
    /// Original field: lineSpacing; encoding: <unresolved>; decoded typeref: symbolic@0xb0e584; flags: 0x2.
    public var lineSpacing: Any = ()
    /// Original field: glowRadius; encoding: <unresolved>; decoded typeref: symbolic@0xb0e584; flags: 0x2.
    public var glowRadius: Any = ()
    /// Original field: showTranslation; encoding: Sb; decoded typeref: Sb; flags: 0x2.
    public var showTranslation: Bool = false
    /// Original field: alignment; encoding: <unresolved>; decoded typeref: symbolic@0xb0b1f4; flags: 0x2.
    public var alignment: Any = ()
    /// Original field: offsetX; encoding: <unresolved>; decoded typeref: symbolic@0xb0e584; flags: 0x2.
    public var offsetX: Any = ()
    /// Original field: anchor; encoding: <unresolved>; decoded typeref: symbolic@0xb0c96c; flags: 0x2.
    public var anchor: Any = ()
    /// Original field: glowColorOverride; encoding: <unresolved>; decoded typeref: symbolic@0xb0c27cSg; flags: 0x2.
    public var glowColorOverride: Any = ()
    /// Original field: blurStart; encoding: <unresolved>; decoded typeref: symbolic@0xb0e584; flags: 0x2.
    public var blurStart: Any = ()
    /// Original field: blurAmount; encoding: <unresolved>; decoded typeref: symbolic@0xb0e584; flags: 0x2.
    public var blurAmount: Any = ()
    /// Original field: tilt; encoding: <unresolved>; decoded typeref: symbolic@0xb0e584; flags: 0x2.
    public var tilt: Any = ()
    /// Original field: tiltY; encoding: <unresolved>; decoded typeref: symbolic@0xb0e584; flags: 0x2.
    public var tiltY: Any = ()
    /// Original field: lyricOffset; encoding: <unresolved>; decoded typeref: symbolic@0xb0e584; flags: 0x0.
    public var lyricOffset: Any = ()
    /// Original field: onTapLine; encoding: <unresolved>; decoded typeref: ysymbolic@0xb0991cc; flags: 0x2.
    public var onTapLine: Any = ()
    /// Original field: __selectionMode; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __selectionMode: Any = ()
    /// Original field: __selected; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4yShySiGG; flags: 0x2.
    public var __selected: Any = ()
    /// Original field: __isUserScrolling; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __isUserScrolling: Any = ()
    /// Original field: _lyricDragActive; encoding: <unresolved>; decoded typeref: symbolic@0xb0a734ySbG; flags: 0x2.
    public var _lyricDragActive: Any = ()
    /// Original field: __resumeScrollTask; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4yScTyytsymbolic@0xb0d314GSgG; flags: 0x2.
    public var __resumeScrollTask: Any = ()
    /// Original field: __focusedIndex; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySiSgG; flags: 0x2.
    public var __focusedIndex: Any = ()
    /// Original field: __selectedLyricIndex; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySiSgG; flags: 0x2.
    public var __selectedLyricIndex: Any = ()
    /// Original field: __lyricTapTask; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4yScTyytsymbolic@0xb0d314GSgG; flags: 0x2.
    public var __lyricTapTask: Any = ()
    /// Original field: __viewportHeight; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ysymbolic@0xb0e584G; flags: 0xffed7e8e.
    public var __viewportHeight: Any = ()
    public init() {}
}

/// Original nominal: PlaylistSquareCache; kind: class; descriptor: 0x7c8e00; fields: 1.
public final class PlaylistSquareCache_2_0_3 {
    /// Original field: ttl; encoding: Sd; decoded typeref: Sd; flags: 0xffee8638.
    public var ttl: Double = 0
    public init() {}
}

/// Original nominal: PlaylistSquareCategory; kind: struct; descriptor: 0x7c8e3c; fields: 3.
public struct PlaylistSquareCategory_2_0_3 {
    /// Original field: id; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var id: String = ""
    /// Original field: name; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var name: String = ""
    /// Original field: remoteID; encoding: SiSg; decoded typeref: SiSg; flags: 0xffee85fc.
    public var remoteID: Int? = nil
    public init() {}
}

/// Original nominal: PlaylistSquareView; kind: struct; descriptor: 0x7c8f04; fields: 25.
public struct PlaylistSquareView_2_0_3 {
    /// Original field: _theme; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb0908cG; flags: 0x2.
    public var _theme: Any = ()
    /// Original field: _auth; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb09904G; flags: 0x2.
    public var _auth: Any = ()
    /// Original field: _player; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb091d4G; flags: 0x2.
    public var _player: Any = ()
    /// Original field: _usesSharedRootBackdrop; encoding: <unresolved>; decoded typeref: symbolic@0xb0a63cySbG; flags: 0x2.
    public var _usesSharedRootBackdrop: Any = ()
    /// Original field: _platformPrefs; encoding: <unresolved>; decoded typeref: symbolic@0xb0aa0cysymbolic@0xb0980cG; flags: 0x2.
    public var _platformPrefs: Any = ()
    /// Original field: _playlistSourceRaw; encoding: <unresolved>; decoded typeref: symbolic@0xb0a40cySSG; flags: 0x2.
    public var _playlistSourceRaw: Any = ()
    /// Original field: _uiStyleRaw; encoding: <unresolved>; decoded typeref: symbolic@0xb0a40cySSG; flags: 0x2.
    public var _uiStyleRaw: Any = ()
    /// Original field: __playlists; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySaysymbolic@0xb098d4GG; flags: 0x2.
    public var __playlists: Any = ()
    /// Original field: __selectedCategory; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySSG; flags: 0x2.
    public var __selectedCategory: Any = ()
    /// Original field: __categories; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySaysymbolic@0xb097ccGG; flags: 0x2.
    public var __categories: Any = ()
    /// Original field: __searchText; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySSG; flags: 0x2.
    public var __searchText: Any = ()
    /// Original field: __searchResults; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySaysymbolic@0xb098d4GG; flags: 0x2.
    public var __searchResults: Any = ()
    /// Original field: __isSearching; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __isSearching: Any = ()
    /// Original field: __isSearchLoading; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __isSearchLoading: Any = ()
    /// Original field: __searchTask; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4yScTyytsymbolic@0xb0d314GSgG; flags: 0x2.
    public var __searchTask: Any = ()
    /// Original field: __isLoading; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __isLoading: Any = ()
    /// Original field: __errorMessage; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySSSgG; flags: 0x2.
    public var __errorMessage: Any = ()
    /// Original field: __expanded; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __expanded: Any = ()
    /// Original field: __loadRequestID; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ysymbolic@0xb0e1e4G; flags: 0x2.
    public var __loadRequestID: Any = ()
    /// Original field: __neteaseHasMore; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __neteaseHasMore: Any = ()
    /// Original field: __neteaseOffset; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySiG; flags: 0x2.
    public var __neteaseOffset: Any = ()
    /// Original field: __isLoadingMore; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __isLoadingMore: Any = ()
    /// Original field: __showPlaylistPlatformMenu; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x0.
    public var __showPlaylistPlatformMenu: Any = ()
    /// Original field: neteasePageSize; encoding: Si; decoded typeref: Si; flags: 0x0.
    public var neteasePageSize: Int = 0
    /// Original field: neteaseCategories; encoding: SaySSG; decoded typeref: SaySSG; flags: 0xffef30b4.
    public var neteaseCategories: [String] = []
    public init() {}
}

/// Original nominal: PlaylistSquareToolbarModifier; kind: struct; descriptor: 0x7c8f34; fields: 6.
public struct PlaylistSquareToolbarModifier_2_0_3 {
    /// Original field: title; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var title: String = ""
    /// Original field: providers; encoding: <unresolved>; decoded typeref: Saysymbolic@0xb09254G; flags: 0x0.
    public var providers: Any = ()
    /// Original field: current; encoding: <unresolved>; decoded typeref: symbolic@0xb09254; flags: 0x0.
    public var current: Any = ()
    /// Original field: searchText; encoding: <unresolved>; decoded typeref: symbolic@0xb0c5fcySSG; flags: 0x0.
    public var searchText: Any = ()
    /// Original field: onSubmitSearch; encoding: yyc; decoded typeref: yyc; flags: 0x0.
    public var onSubmitSearch: Any = ()
    /// Original field: onSelect; encoding: <unresolved>; decoded typeref: ysymbolic@0xb09254c; flags: 0xffef316c.
    public var onSelect: Any = ()
    public init() {}
}

/// Original nominal: QishuiCacheBox; kind: unknown; descriptor: 0x7c982c; fields: 2.
public struct QishuiCacheBox_2_0_3 {
    /// Original field: value; encoding: x; decoded typeref: x; flags: 0x0.
    public var value: Any = ()
    /// Original field: savedAt; encoding: <unresolved>; decoded typeref: symbolic@0xb0e184; flags: 0xfff4e49c.
    public var savedAt: Date = Date()
    public init() {}
}

/// Original nominal: RecordModeMiniLyrics; kind: struct; descriptor: 0x7c9a24; fields: 4.
public struct RecordModeMiniLyrics_2_0_3 {
    /// Original field: _clock; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb091bcG; flags: 0x2.
    public var _clock: Any = ()
    /// Original field: _lyricOffset; encoding: <unresolved>; decoded typeref: symbolic@0xb0a40cySdG; flags: 0x0.
    public var _lyricOffset: Any = ()
    /// Original field: lyrics; encoding: <unresolved>; decoded typeref: Saysymbolic@0xb0991cG; flags: 0x0.
    public var lyrics: Any = ()
    /// Original field: onOpen; encoding: yyc; decoded typeref: yyc; flags: 0xfff5e216.
    public var onOpen: Any = ()
    public init() {}
}

/// Original nominal: BeansLyricOffsetSheet; kind: struct; descriptor: 0x7c9ce4; fields: 2.
public struct BeansLyricOffsetSheet_2_0_3 {
    /// Original field: _lyricOffset; encoding: <unresolved>; decoded typeref: symbolic@0xb0a40cySdG; flags: 0x2.
    public var _lyricOffset: Any = ()
    /// Original field: _dismiss; encoding: <unresolved>; decoded typeref: symbolic@0xb0a63cysymbolic@0xb0a85cG; flags: 0xfff601a8.
    public var _dismiss: Any = ()
    public init() {}
}

/// Original nominal: AppleMusicLyricsSection; kind: struct; descriptor: 0x7c9d50; fields: 16.
public struct AppleMusicLyricsSection_2_0_3 {
    /// Original field: _player; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb091d4G; flags: 0x2.
    public var _player: Any = ()
    /// Original field: _clock; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb091bcG; flags: 0x2.
    public var _clock: Any = ()
    /// Original field: _karaokeEnabled; encoding: <unresolved>; decoded typeref: symbolic@0xb0a40cySbG; flags: 0x0.
    public var _karaokeEnabled: Any = ()
    /// Original field: lyrics; encoding: <unresolved>; decoded typeref: Saysymbolic@0xb0991cG; flags: 0x0.
    public var lyrics: Any = ()
    /// Original field: primary; encoding: <unresolved>; decoded typeref: symbolic@0xb0c27c; flags: 0x0.
    public var primary: Any = ()
    /// Original field: secondary; encoding: <unresolved>; decoded typeref: symbolic@0xb0c27c; flags: 0x0.
    public var secondary: Any = ()
    /// Original field: lyricOffset; encoding: <unresolved>; decoded typeref: symbolic@0xb0e584; flags: 0x0.
    public var lyricOffset: Any = ()
    /// Original field: onTapLine; encoding: <unresolved>; decoded typeref: ysymbolic@0xb0991cc; flags: 0x2.
    public var onTapLine: Any = ()
    /// Original field: __lyricCenters; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySDysymbolic@0xb0e1e4symbolic@0xb0e584GG; flags: 0x2.
    public var __lyricCenters: Any = ()
    /// Original field: __focusedLyricID; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ysymbolic@0xb0e1e4SgG; flags: 0x2.
    public var __focusedLyricID: Any = ()
    /// Original field: __selectedLyricID; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ysymbolic@0xb0e1e4SgG; flags: 0x2.
    public var __selectedLyricID: Any = ()
    /// Original field: __viewportHeight; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ysymbolic@0xb0e584G; flags: 0x2.
    public var __viewportHeight: Any = ()
    /// Original field: __isDraggingLyrics; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ySbG; flags: 0x2.
    public var __isDraggingLyrics: Any = ()
    /// Original field: _lyricDragActive; encoding: <unresolved>; decoded typeref: symbolic@0xb0a734ySbG; flags: 0x2.
    public var _lyricDragActive: Any = ()
    /// Original field: __resumeTask; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4yScTyytsymbolic@0xb0d314GSgG; flags: 0x2.
    public var __resumeTask: Any = ()
    /// Original field: __lyricTapTask; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4yScTyytsymbolic@0xb0d314GSgG; flags: 0xfff5fed0.
    public var __lyricTapTask: Any = ()
    public init() {}
}

/// Original nominal: MiniLyricsPreview; kind: struct; descriptor: 0x7c9e10; fields: 4.
public struct MiniLyricsPreview_2_0_3 {
    /// Original field: lines; encoding: <unresolved>; decoded typeref: Saysymbolic@0xb0991cG; flags: 0x0.
    public var lines: Any = ()
    /// Original field: primary; encoding: <unresolved>; decoded typeref: symbolic@0xb0c27c; flags: 0x0.
    public var primary: Any = ()
    /// Original field: secondary; encoding: <unresolved>; decoded typeref: symbolic@0xb0c27c; flags: 0x0.
    public var secondary: Any = ()
    /// Original field: action; encoding: yyc; decoded typeref: yyc; flags: 0xfff761f6.
    public var action: Any = ()
    public init() {}
}

/// Original nominal: RelatedAlbumsCache; kind: class; descriptor: 0x7ca080; fields: 6.
public final class RelatedAlbumsCache_2_0_3 {
    /// Original field: defaults; encoding: So14NSUserDefaultsC; decoded typeref: So14NSUserDefaultsC; flags: 0x0.
    public var defaults: UserDefaults = .standard
    /// Original field: storageKey; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var storageKey: String = ""
    /// Original field: lock; encoding: So6NSLockC; decoded typeref: So6NSLockC; flags: 0x0.
    public var lock: NSLock = NSLock()
    /// Original field: persistenceQueue; encoding: So17OS_dispatch_queueC; decoded typeref: So17OS_dispatch_queueC; flags: 0x2.
    public var persistenceQueue: Any = ()
    /// Original field: entries; encoding: <unresolved>; decoded typeref: SDySSEntryG; flags: 0x0.
    public var entries: Any = ()
    /// Original field: ttl; encoding: Sd; decoded typeref: Sd; flags: 0xfff78518.
    public var ttl: Double = 0
    public init() {}
}

/// Original nominal: SearchResultCacheEntry; kind: struct; descriptor: 0x7cba08; fields: 4.
public struct SearchResultCacheEntry_2_0_3 {
    /// Original field: songs; encoding: <unresolved>; decoded typeref: Saysymbolic@0xb09894G; flags: 0x0.
    public var songs: Any = ()
    /// Original field: artists; encoding: <unresolved>; decoded typeref: Saysymbolic@0xb098a4G; flags: 0x0.
    public var artists: Any = ()
    /// Original field: albums; encoding: <unresolved>; decoded typeref: Saysymbolic@0xb0989cG; flags: 0x0.
    public var albums: Any = ()
    /// Original field: playlists; encoding: <unresolved>; decoded typeref: Saysymbolic@0xb098d4G; flags: 0xfff95a68.
    public var playlists: Any = ()
    public init() {}
}

/// Original nominal: SearchResultCacheKey; kind: struct; descriptor: 0x7cba2c; fields: 3.
public struct SearchResultCacheKey_2_0_3 {
    /// Original field: keyword; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var keyword: String = ""
    /// Original field: provider; encoding: <unresolved>; decoded typeref: SearchCatalogProvider; flags: 0x0.
    public var provider: Any = ()
    /// Original field: resultType; encoding: <unresolved>; decoded typeref: SearchResultType; flags: 0xfff95aa2.
    public var resultType: Any = ()
    public init() {}
}

/// Original nominal: SearchResultType; kind: enum; descriptor: 0x7cba48; fields: 5.
public enum SearchResultType_2_0_3 {
    /// Original field: all; encoding: <unresolved>; decoded typeref: <unresolved>; flags: 0x0.
    public static let all: Any = ()
    /// Original field: song; encoding: <unresolved>; decoded typeref: <unresolved>; flags: 0x0.
    public static let song: Any = ()
    /// Original field: artist; encoding: <unresolved>; decoded typeref: <unresolved>; flags: 0x0.
    public static let artist: Any = ()
    /// Original field: album; encoding: <unresolved>; decoded typeref: <unresolved>; flags: 0x0.
    public static let album: Any = ()
    /// Original field: playlist; encoding: <unresolved>; decoded typeref: <unresolved>; flags: 0xfff95ad0.
    public static let playlist: Any = ()
}

/// Original nominal: SyncedPlaylistCache; kind: class; descriptor: 0x7cbcf8; fields: 9.
public final class SyncedPlaylistCache_2_0_3 {
    /// Original field: defaults; encoding: So14NSUserDefaultsC; decoded typeref: So14NSUserDefaultsC; flags: 0x0.
    public var defaults: UserDefaults = .standard
    /// Original field: playlistsKey; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var playlistsKey: String = ""
    /// Original field: songsKey; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var songsKey: String = ""
    /// Original field: lock; encoding: So6NSLockC; decoded typeref: So6NSLockC; flags: 0x0.
    public var lock: NSLock = NSLock()
    /// Original field: persistenceQueue; encoding: So17OS_dispatch_queueC; decoded typeref: So17OS_dispatch_queueC; flags: 0x2.
    public var persistenceQueue: Any = ()
    /// Original field: playlistEntries; encoding: <unresolved>; decoded typeref: SDySSPlaylistEntryG; flags: 0x2.
    public var playlistEntries: Any = ()
    /// Original field: songEntries; encoding: <unresolved>; decoded typeref: SDySSSongEntryG; flags: 0x0.
    public var songEntries: Any = ()
    /// Original field: playlistTTL; encoding: Sd; decoded typeref: Sd; flags: 0x0.
    public var playlistTTL: Double = 0
    /// Original field: songTTL; encoding: Sd; decoded typeref: Sd; flags: 0xfffd48a4.
    public var songTTL: Double = 0
    public init() {}
}

/// Original nominal: SyncedPlaylistOrderSheet; kind: struct; descriptor: 0x7cbdcc; fields: 6.
public struct SyncedPlaylistOrderSheet_2_0_3 {
    /// Original field: title; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var title: String = ""
    /// Original field: source; encoding: <unresolved>; decoded typeref: symbolic@0xb09084; flags: 0x2.
    public var source: Any = ()
    /// Original field: _playlists; encoding: <unresolved>; decoded typeref: symbolic@0xb0c5fcySaysymbolic@0xb098d4GG; flags: 0x2.
    public var _playlists: Any = ()
    /// Original field: _theme; encoding: <unresolved>; decoded typeref: symbolic@0xb0ae5cysymbolic@0xb0908cG; flags: 0x2.
    public var _theme: Any = ()
    /// Original field: _dismiss; encoding: <unresolved>; decoded typeref: symbolic@0xb0a63cysymbolic@0xb0a85cG; flags: 0x2.
    public var _dismiss: Any = ()
    /// Original field: __editMode; encoding: <unresolved>; decoded typeref: symbolic@0xb0c3f4ysymbolic@0xb0c6e4G; flags: 0xfffd4ef4.
    public var __editMode: Any = ()
    public init() {}
}

/// Original nominal: SyncedPlaylistOrderStore; kind: class; descriptor: 0x7cbe1c; fields: 3.
public final class SyncedPlaylistOrderStore_2_0_3 {
    /// Original field: defaults; encoding: So14NSUserDefaultsC; decoded typeref: So14NSUserDefaultsC; flags: 0x0.
    public var defaults: UserDefaults = .standard
    /// Original field: key; encoding: SS; decoded typeref: SS; flags: 0x2.
    public var key: String = ""
    /// Original field: orders; encoding: SDySSSaySiGG; decoded typeref: SDySSSaySiGG; flags: 0xfffd4ed4.
    public var orders: Any = ()
    public init() {}
}

/// Original nominal: ResolutionCacheEntry; kind: struct; descriptor: 0x7cc25c; fields: 2.
public struct ResolutionCacheEntry_2_0_3 {
    /// Original field: resolved; encoding: <unresolved>; decoded typeref: Resolved; flags: 0x0.
    public var resolved: Any = ()
    /// Original field: expiresAt; encoding: <unresolved>; decoded typeref: symbolic@0xb0e184; flags: 0xfffddb64.
    public var expiresAt: Date = Date()
    public init() {}
}

/// Original nominal: PersistentResolutionCacheEntry; kind: struct; descriptor: 0x7cc28c; fields: 4.
public struct PersistentResolutionCacheEntry_2_0_3 {
    /// Original field: url; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var url: String = ""
    /// Original field: source; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var source: String = ""
    /// Original field: quality; encoding: SS; decoded typeref: SS; flags: 0x0.
    public var quality: String = ""
    /// Original field: expiresAt; encoding: <unresolved>; decoded typeref: symbolic@0xb0e184; flags: 0xfffddb80.
    public var expiresAt: Date = Date()
    public init() {}
}
