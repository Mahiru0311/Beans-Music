import Foundation
import Combine

/// Original nominal: LocalPlaylist; field types are decoded directly from the IPA.
public struct LocalPlaylist_2_0_3 {
    public var id: UUID
    public var name: String
    public var songs: [Song_2_0_3]
    public var createdAt: Date
    public var coverURL: URL?
    public var sourceName: String?
    public init(id: UUID = UUID(), name: String = "", songs: [Song_2_0_3] = [],
                createdAt: Date = Date(), coverURL: URL? = nil, sourceName: String? = nil) {
        self.id = id; self.name = name; self.songs = songs; self.createdAt = createdAt
        self.coverURL = coverURL; self.sourceName = sourceName
    }
}

/// Original nominal: LocalLibraryStore; `_playlists` is Published<[LocalPlaylist]>.
public final class LocalLibraryStore_2_0_3 {
    @Published public var playlists: [LocalPlaylist_2_0_3] = []
    public var defaults: UserDefaults = .standard
    public var key: String = ""
    public init() {}
}

/// Original nominal: PlaylistEntry.
public struct PlaylistEntry_2_0_3 {
    public var playlists: [Playlist_2_0_3]
    public var savedAt: Date
    public init(playlists: [Playlist_2_0_3] = [], savedAt: Date = Date()) {
        self.playlists = playlists; self.savedAt = savedAt
    }
}

/// Original nominal: SongEntry.
public struct SongEntry_2_0_3 {
    public var songs: [Song_2_0_3]
    public var savedAt: Date
    public init(songs: [Song_2_0_3] = [], savedAt: Date = Date()) {
        self.songs = songs; self.savedAt = savedAt
    }
}
