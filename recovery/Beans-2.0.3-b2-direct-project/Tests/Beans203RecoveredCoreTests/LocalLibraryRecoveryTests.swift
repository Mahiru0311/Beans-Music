import XCTest
@testable import Beans203RecoveredCore

final class LocalLibraryRecoveryTests: XCTestCase {
    func testLocalLibraryAndEntriesUseRecoveredSongAndPlaylistTypes() {
        let song = Song_2_0_3(id: 5, name: "Local")
        let playlist = Playlist_2_0_3(id: 6, name: "Saved")
        let local = LocalPlaylist_2_0_3(name: "Local list", songs: [song])
        let store = LocalLibraryStore_2_0_3()
        store.playlists = [local]
        let playlistEntry = PlaylistEntry_2_0_3(playlists: [playlist])
        let songEntry = SongEntry_2_0_3(songs: [song])

        XCTAssertEqual(store.playlists.first?.songs.first?.id, 5)
        XCTAssertEqual(playlistEntry.playlists.first?.id, 6)
        XCTAssertEqual(songEntry.songs.first?.name, "Local")
    }

    func testSyncedPlaylistCacheUsesTypedDictionaries() {
        let cache = SyncedPlaylistCache_2_0_3()
        cache.playlistEntries["p"] = PlaylistEntry_2_0_3(
            playlists: [Playlist_2_0_3(id: 1, name: "P")]
        )
        cache.songEntries["s"] = SongEntry_2_0_3(
            songs: [Song_2_0_3(id: 2, name: "S")]
        )

        XCTAssertEqual(cache.playlistEntries["p"]?.playlists.first?.name, "P")
        XCTAssertEqual(cache.songEntries["s"]?.songs.first?.id, 2)
    }
}
