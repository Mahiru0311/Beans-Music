import Foundation
import Combine

/// Original nominal: SongSource; IPA exposes eight cases.
public enum SongSource_2_0_3: CaseIterable, Hashable, Sendable {
    case netease, qq, kugou, kuwo, migu, qishui, bilibili, webdav
}

/// Original nominal: PlaybackClock; fields are `Published<Double>` backing values.
public final class PlaybackClock_2_0_3: ObservableObject {
    @Published public var progress: Double = 0
    @Published public var duration: Double = 0
    public init() {}
}

/// Original nominal: PlayMode; IPA exposes four cases.
public enum PlayMode_2_0_3: CaseIterable, Hashable, Sendable {
    case sequential, repeatAll, repeatOne, shuffle
}

/// Original nominal: ThirdPartyAudioQuality; IPA exposes eight cases.
public enum ThirdPartyAudioQuality_2_0_3: CaseIterable, Hashable, Sendable {
    case kb128, kb320, flac, flac24bit, hires, atmos, atmosPlus, master
}

/// Original nominal: ThirdPartyVIPNotice; field types are directly decoded.
public struct ThirdPartyVIPNotice_2_0_3 {
    public var songKey: String
    public var message: String
    public init(songKey: String = "", message: String = "") {
        self.songKey = songKey
        self.message = message
    }
}

/// Original nominal: PlaybackSeekState; `pendingRevision` is `Int?`.
public struct PlaybackSeekState_2_0_3 {
    public var pendingRevision: Int?
    public init(pendingRevision: Int? = nil) {
        self.pendingRevision = pendingRevision
    }
}

/// Original nominal: Song; all concrete scalar/container types below come from IPA typerefs.
public struct Song_2_0_3 {
    public var id: Int
    public var name: String
    public var artists: String
    public var album: String
    public var coverURL: URL?
    public var duration: Double
    public var source: SongSource_2_0_3
    public var qqMid: String?
    public var qqMediaMid: String?
    public var kugouHash: String?
    public var kugouAlbumAudioId: String?
    public var kugouAlbumId: String?
    public var kugouQualityHashes: [String: String]?
    public var miguCopyrightId: String?
    public var miguLyricURL: URL?
    public var qishuiID: String?
    public var bilibiliID: String?
    public var webDAV: WebDAVTrack_2_0_3?
    public var fee: Int

    public init(id: Int = 0, name: String = "", artists: String = "", album: String = "",
                coverURL: URL? = nil, duration: Double = 0,
                source: SongSource_2_0_3 = .netease, qqMid: String? = nil,
                qqMediaMid: String? = nil, kugouHash: String? = nil,
                kugouAlbumAudioId: String? = nil, kugouAlbumId: String? = nil,
                kugouQualityHashes: [String: String]? = nil, miguCopyrightId: String? = nil,
                miguLyricURL: URL? = nil, qishuiID: String? = nil,
                bilibiliID: String? = nil, webDAV: WebDAVTrack_2_0_3? = nil, fee: Int = 0) {
        self.id = id; self.name = name; self.artists = artists; self.album = album
        self.coverURL = coverURL; self.duration = duration; self.source = source
        self.qqMid = qqMid; self.qqMediaMid = qqMediaMid; self.kugouHash = kugouHash
        self.kugouAlbumAudioId = kugouAlbumAudioId; self.kugouAlbumId = kugouAlbumId
        self.kugouQualityHashes = kugouQualityHashes; self.miguCopyrightId = miguCopyrightId
        self.miguLyricURL = miguLyricURL; self.qishuiID = qishuiID
        self.bilibiliID = bilibiliID; self.webDAV = webDAV; self.fee = fee
    }
}
