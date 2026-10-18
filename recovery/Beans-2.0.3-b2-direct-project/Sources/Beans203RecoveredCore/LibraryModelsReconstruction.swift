import Foundation

/// Original nominal: Artist; fields decoded from the IPA.
public struct Artist_2_0_3 {
    public var id: String
    public var name: String
    public var coverURL: URL?
    public var source: SongSource_2_0_3
    public init(id: String = "", name: String = "", coverURL: URL? = nil,
                source: SongSource_2_0_3 = .netease) {
        self.id = id; self.name = name; self.coverURL = coverURL; self.source = source
    }
}

/// Original nominal: PlaylistSnapshot; its queue element type is Song.
public struct PlaylistSnapshot_2_0_3 {
    public var key: String
    public var songs: [Song_2_0_3]
    public init(key: String = "", songs: [Song_2_0_3] = []) {
        self.key = key; self.songs = songs
    }
}

/// Original nominal: Playlist; all scalar and optional types are direct IPA typerefs.
public struct Playlist_2_0_3 {
    public var id: Int
    public var name: String
    public var coverURL: URL?
    public var trackCount: Int
    public var playCount: Int
    public var creatorName: String
    public var creatorAvatarURL: URL?
    public var playlistDescription: String
    public var specialType: Int
    public var kugouGlobalCollectionID: String?
    public var source: SongSource_2_0_3
    public var qishuiID: String?
    public var bilibiliID: String?
    public var savedSnapshot: PlaylistSnapshot_2_0_3?
    public init(id: Int = 0, name: String = "", coverURL: URL? = nil, trackCount: Int = 0,
                playCount: Int = 0, creatorName: String = "", creatorAvatarURL: URL? = nil,
                playlistDescription: String = "", specialType: Int = 0,
                kugouGlobalCollectionID: String? = nil, source: SongSource_2_0_3 = .netease,
                qishuiID: String? = nil, bilibiliID: String? = nil,
                savedSnapshot: PlaylistSnapshot_2_0_3? = nil) {
        self.id = id; self.name = name; self.coverURL = coverURL; self.trackCount = trackCount
        self.playCount = playCount; self.creatorName = creatorName
        self.creatorAvatarURL = creatorAvatarURL; self.playlistDescription = playlistDescription
        self.specialType = specialType; self.kugouGlobalCollectionID = kugouGlobalCollectionID
        self.source = source; self.qishuiID = qishuiID; self.bilibiliID = bilibiliID
        self.savedSnapshot = savedSnapshot
    }
}

/// Original nominal: Album.
public struct Album_2_0_3 {
    public var id: String
    public var name: String
    public var artistName: String
    public var coverURL: URL?
    public var source: SongSource_2_0_3
    public var trackCount: Int?
    public var releaseType: String?
    public var releaseDate: String?
    public var albumDescription: String?
    public init(id: String = "", name: String = "", artistName: String = "", coverURL: URL? = nil,
                source: SongSource_2_0_3 = .netease, trackCount: Int? = nil,
                releaseType: String? = nil, releaseDate: String? = nil,
                albumDescription: String? = nil) {
        self.id = id; self.name = name; self.artistName = artistName; self.coverURL = coverURL
        self.source = source; self.trackCount = trackCount; self.releaseType = releaseType
        self.releaseDate = releaseDate; self.albumDescription = albumDescription
    }
}

/// Original nominal: TopList.
public struct TopList_2_0_3 {
    public var id: Int
    public var name: String
    public var coverURL: URL?
    public var updateFrequency: String
    public var trackCount: Int?
    public var playCount: Int?
    public var chartDescription: String?
    public var creatorName: String?
    public var creatorAvatarURL: URL?
    public init(id: Int = 0, name: String = "", coverURL: URL? = nil,
                updateFrequency: String = "", trackCount: Int? = nil, playCount: Int? = nil,
                chartDescription: String? = nil, creatorName: String? = nil,
                creatorAvatarURL: URL? = nil) {
        self.id = id; self.name = name; self.coverURL = coverURL
        self.updateFrequency = updateFrequency; self.trackCount = trackCount
        self.playCount = playCount; self.chartDescription = chartDescription
        self.creatorName = creatorName; self.creatorAvatarURL = creatorAvatarURL
    }
}

/// Original nominal: Snapshot; concrete array element types are decoded from IPA typerefs.
public struct Snapshot_2_0_3 {
    public var dailySongs: [Song_2_0_3]
    public var newAlbums: [Album_2_0_3]
    public var topArtists: [Artist_2_0_3]
    public var topLists: [TopList_2_0_3]
    public var personalized: [Playlist_2_0_3]
    /// The IPA leaves the element nominals symbolic for these provider-specific arrays.
    public var qqTopLists: [Any]
    public var kugouTopLists: [Any]
    public var savedAt: Date
    public init(dailySongs: [Song_2_0_3] = [], newAlbums: [Album_2_0_3] = [],
                topArtists: [Artist_2_0_3] = [], topLists: [TopList_2_0_3] = [],
                personalized: [Playlist_2_0_3] = [], qqTopLists: [Any] = [],
                kugouTopLists: [Any] = [], savedAt: Date = Date()) {
        self.dailySongs = dailySongs; self.newAlbums = newAlbums; self.topArtists = topArtists
        self.topLists = topLists; self.personalized = personalized; self.qqTopLists = qqTopLists
        self.kugouTopLists = kugouTopLists; self.savedAt = savedAt
    }
}

/// Original nominal: PersistedPlaybackState.
public struct PersistedPlaybackState_2_0_3 {
    public var queue: [Song_2_0_3]
    public var currentIndex: Int
    public var progress: Double
    public var duration: Double
    public var savedAt: Date
    public init(queue: [Song_2_0_3] = [], currentIndex: Int = 0, progress: Double = 0,
                duration: Double = 0, savedAt: Date = Date()) {
        self.queue = queue; self.currentIndex = currentIndex; self.progress = progress
        self.duration = duration; self.savedAt = savedAt
    }
}

/// Original nominal: SongURLResult.
public struct SongURLResult_2_0_3 {
    public var url: String
    public var br: String
    public var attemptedBRs: [String]
    public init(url: String = "", br: String = "", attemptedBRs: [String] = []) {
        self.url = url; self.br = br; self.attemptedBRs = attemptedBRs
    }
}

/// Original nominal: ResolvedDownloadURL.
public struct ResolvedDownloadURL_2_0_3 {
    public var url: URL
    public var source: String
    public var quality: ThirdPartyAudioQuality_2_0_3
    public init(url: URL = URL(fileURLWithPath: "/"), source: String = "",
                quality: ThirdPartyAudioQuality_2_0_3 = .kb128) {
        self.url = url; self.source = source; self.quality = quality
    }
}

/// Original nominal: DownloadResult.
public struct DownloadResult_2_0_3 {
    public var url: URL
    public var requestedQuality: ThirdPartyAudioQuality_2_0_3
    public var actualQuality: ThirdPartyAudioQuality_2_0_3
    public var downgraded: Bool
    public var sourceName: String?
    public init(url: URL = URL(fileURLWithPath: "/"),
                requestedQuality: ThirdPartyAudioQuality_2_0_3 = .kb128,
                actualQuality: ThirdPartyAudioQuality_2_0_3 = .kb128,
                downgraded: Bool = false, sourceName: String? = nil) {
        self.url = url; self.requestedQuality = requestedQuality
        self.actualQuality = actualQuality; self.downgraded = downgraded
        self.sourceName = sourceName
    }
}
