import Foundation

// State-bearing API/store reconstruction from the 2.0.3 build 2 IPA.
// Field names are direct reflection records. Types mapped to Any remain unresolved.

/// Original nominal kind: class; descriptor: 0x7c3e8c; fields: 9.
public final class BilibiliAPI_2_0_3 {
    /// Original field: $defaultActor; encoding: BD; flags: 0x0.
    public var field_0__defaultActor: Any = ()
    /// Original field: session; encoding: So12NSURLSessionC; flags: 0x2.
    public var session: URLSession = .shared
    /// Original field: cookie; encoding: SS; flags: 0x2.
    public var cookie: String = ""
    /// Original field: restoredSession; encoding: Sb; flags: 0x2.
    public var restoredSession: Bool = false
    /// Original field: pendingQRLogin; encoding: <unresolved>; flags: 0x2.
    public var pendingQRLogin: Any = ()
    /// Original field: fingerprint; encoding: SS; flags: 0x2.
    public var fingerprint: String = ""
    /// Original field: wbiKey; encoding: SS; flags: 0x2.
    public var wbiKey: String = ""
    /// Original field: wbiDate; unresolved field encoding points at the same
    /// relative typeref used by `Foundation.Date` fields elsewhere in this IPA.
    public var wbiDate: Date = Date()
    /// Original field: cache; encoding: <unresolved>; flags: 0xffd6897e.
    public var cache: Any = ()
}

/// Original nominal kind: class; descriptor: 0x7c834c; fields: 15.
public final class NetEaseAPI_2_0_3 {
    /// Original field: domain; encoding: SS; flags: 0x0.
    public var domain: String = ""
    /// Original field: apiDomain; encoding: SS; flags: 0x0.
    public var apiDomain: String = ""
    /// Original field: session; encoding: So12NSURLSessionC; flags: 0x0.
    public var session: URLSession = .shared
    /// Original field: os; encoding: SS; flags: 0x0.
    public var os: String = ""
    /// Original field: appver; encoding: SS; flags: 0x0.
    public var appver: String = ""
    /// Original field: osver; encoding: SS; flags: 0x0.
    public var osver: String = ""
    /// Original field: channel; encoding: SS; flags: 0x0.
    public var channel: String = ""
    /// Original field: nuid; encoding: SS; flags: 0x0.
    public var nuid: String = ""
    /// Original field: deviceId; encoding: SS; flags: 0x0.
    public var deviceId: String = ""
    /// Original field: wnMcid; encoding: SS; flags: 0x0.
    public var wnMcid: String = ""
    /// Original field: cookiesKey; encoding: SS; flags: 0x2.
    public var cookiesKey: String = ""
    /// Original field: storedCookies; encoding: SDyS2SG; flags: 0x2.
    public var storedCookies: [String: String] = [:]
    /// Original field: personalFMCache; encoding: <unresolved>; flags: 0x2.
    public var personalFMCache: [Song_2_0_3] = []
    /// Original field: personalFMCacheDate; same IPA-relative typeref as
    /// `Foundation.Date` (`savedAt`, `createdAt`, and `lastRefresh` records).
    public var personalFMCacheDate: Date = Date()
    /// Original field: personalFMCacheTTL; encoding: Sd; flags: 0xffdf5cc0.
    public var personalFMCacheTTL: Double = 0
}

/// Original nominal kind: class; descriptor: 0x7c963c; fields: 3.
public final class QQMusicAPI_2_0_3 {
    /// Original field: base; encoding: SS; flags: 0x0.
    public var base: String = ""
    /// Original field: searchBase; encoding: SS; flags: 0x0.
    public var searchBase: String = ""
    /// Original field: session; encoding: So12NSURLSessionC; flags: 0xfff4da14.
    public var session: URLSession = .shared
}

/// Original nominal kind: class; descriptor: 0x7c7320; fields: 22.
public final class KugouMusicAPI_2_0_3 {
    /// Original field: gateway; encoding: SS; flags: 0x0.
    public var gateway: String = ""
    /// Original field: loginBase; encoding: SS; flags: 0x0.
    public var loginBase: String = ""
    /// Original field: userService; encoding: SS; flags: 0x0.
    public var userService: String = ""
    /// Original field: upstreamAppID; encoding: SS; flags: 0x0.
    public var upstreamAppID: String = ""
    /// Original field: upstreamClientVersion; encoding: SS; flags: 0x0.
    public var upstreamClientVersion: String = ""
    /// Original field: upstreamSignSalt; encoding: SS; flags: 0x0.
    public var upstreamSignSalt: String = ""
    /// Original field: upstreamSongClientVersion; encoding: SS; flags: 0x0.
    public var upstreamSongClientVersion: String = ""
    /// Original field: appid; encoding: SS; flags: 0x0.
    public var appid: String = ""
    /// Original field: clientver; encoding: SS; flags: 0x0.
    public var clientver: String = ""
    /// Original field: qrAppid; encoding: SS; flags: 0x0.
    public var qrAppid: String = ""
    /// Original field: qrSrcAppid; encoding: SS; flags: 0x0.
    public var qrSrcAppid: String = ""
    /// Original field: androidSignKey; encoding: SS; flags: 0x0.
    public var androidSignKey: String = ""
    /// Original field: webSignKey; encoding: SS; flags: 0x0.
    public var webSignKey: String = ""
    /// Original field: playSalt; encoding: SS; flags: 0x0.
    public var playSalt: String = ""
    /// Original field: playSignSalt; encoding: SS; flags: 0x0.
    public var playSignSalt: String = ""
    /// Original field: playAppid; encoding: SS; flags: 0x0.
    public var playAppid: String = ""
    /// Original field: playClientver; encoding: SS; flags: 0x0.
    public var playClientver: String = ""
    /// Original field: androidUA; encoding: SS; flags: 0x0.
    public var androidUA: String = ""
    /// Original field: playbackUA; encoding: SS; flags: 0x0.
    public var playbackUA: String = ""
    /// Original field: rsaPublicKeyBase64; encoding: SS; flags: 0x0.
    public var rsaPublicKeyBase64: String = ""
    /// Original field: session; encoding: So12NSURLSessionC; flags: 0x2.
    public var session: URLSession = .shared
    /// Original field: lastMembershipProbeAt; same IPA-relative typeref as
    /// `Foundation.Date`, with the optionality marker retained by the field
    /// reference (`...DateSg`).
    public var lastMembershipProbeAt: Date? = nil
}

/// Original nominal kind: class; descriptor: 0x7c65a4; fields: 3.
public final class DownloadManager_2_0_3 {
    /// Original field: _songProgress; encoding: <unresolved>; flags: 0x2.
    public var _songProgress: Any = ()
    /// Original field: progressOrder; encoding: SaySSG; flags: 0x2.
    public var progressOrder: [String] = []
    /// Original field: transferTokens; encoding: <unresolved>; flags: 0xffdb7968.
    public var transferTokens: Any = ()
}

/// Original nominal kind: class; descriptor: 0x7c663c; fields: 10.
public final class BatchDownloadManager_2_0_3 {
    /// Original field: _totalCount; encoding: <unresolved>; flags: 0x2.
    public var _totalCount: Any = ()
    /// Original field: _completedCount; encoding: <unresolved>; flags: 0x2.
    public var _completedCount: Any = ()
    /// Original field: _succeededCount; encoding: <unresolved>; flags: 0x2.
    public var _succeededCount: Any = ()
    /// Original field: _failedSongs; encoding: <unresolved>; flags: 0x2.
    public var _failedSongs: Any = ()
    /// Original field: _currentSongName; encoding: <unresolved>; flags: 0x2.
    public var _currentSongName: Any = ()
    /// Original field: _currentSongKey; encoding: <unresolved>; flags: 0x2.
    public var _currentSongKey: Any = ()
    /// Original field: _downloadedFiles; encoding: <unresolved>; flags: 0x2.
    public var _downloadedFiles: Any = ()
    /// Original field: _isDownloading; encoding: <unresolved>; flags: 0x2.
    public var _isDownloading: Any = ()
    /// Original field: _wasCancelled; encoding: <unresolved>; flags: 0x2.
    public var _wasCancelled: Any = ()
    /// Original field: downloadTask; encoding: <unresolved>; flags: 0xffdb791a.
    public var downloadTask: Any = ()
}

/// Original nominal kind: class; descriptor: 0x7c68cc; fields: 9.
public final class FavoritesStore_2_0_3 {
    /// Original field: _qqFavoriteSongs; encoding: <unresolved>; flags: 0x2.
    public var _qqFavoriteSongs: Any = ()
    /// Original field: _neteaseFavoriteSongs; encoding: <unresolved>; flags: 0x2.
    public var _neteaseFavoriteSongs: Any = ()
    /// Original field: _kugouFavoriteSongs; encoding: <unresolved>; flags: 0x2.
    public var _kugouFavoriteSongs: Any = ()
    /// Original field: _kugouOfficialFavoriteSongs; encoding: <unresolved>; flags: 0x0.
    public var _kugouOfficialFavoriteSongs: Any = ()
    /// Original field: defaults; encoding: So14NSUserDefaultsC; flags: 0x0.
    public var defaults: UserDefaults = .standard
    /// Original field: neteaseKey; encoding: SS; flags: 0x0.
    public var neteaseKey: String = ""
    /// Original field: qqKey; encoding: SS; flags: 0x0.
    public var qqKey: String = ""
    /// Original field: kugouKey; encoding: SS; flags: 0x0.
    public var kugouKey: String = ""
    /// Original field: kugouOfficialKey; encoding: SS; flags: 0xffdbc740.
    public var kugouOfficialKey: String = ""
}

/// Original nominal kind: class; descriptor: 0x7c6914; fields: 7.
public final class MusicCollectionsStore_2_0_3 {
    /// Original field: _albums; encoding: <unresolved>; flags: 0x2.
    public var _albums: Any = ()
    /// Original field: _artists; encoding: <unresolved>; flags: 0x2.
    public var _artists: Any = ()
    /// Original field: _playlists; encoding: <unresolved>; flags: 0x0.
    public var _playlists: Any = ()
    /// Original field: defaults; encoding: So14NSUserDefaultsC; flags: 0x0.
    public var defaults: UserDefaults = .standard
    /// Original field: albumsKey; encoding: SS; flags: 0x0.
    public var albumsKey: String = ""
    /// Original field: artistsKey; encoding: SS; flags: 0x0.
    public var artistsKey: String = ""
    /// Original field: playlistsKey; encoding: SS; flags: 0xffdbc74e.
    public var playlistsKey: String = ""
}
