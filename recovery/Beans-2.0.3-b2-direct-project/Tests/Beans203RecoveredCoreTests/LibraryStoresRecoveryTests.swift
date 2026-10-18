import XCTest
@testable import Beans203RecoveredCore

final class LibraryStoresRecoveryTests: XCTestCase {
    func testFavoritesStoreUsesPublishedSongCollections() {
        let store = FavoritesStore_2_0_3()
        store.qqFavoriteSongs = [Song_2_0_3(id: 1, name: "QQ")]
        store.neteaseFavoriteSongs = [Song_2_0_3(id: 2, name: "NetEase")]
        store.kugouFavoriteSongs = [Song_2_0_3(id: 3, name: "Kugou")]

        XCTAssertEqual(store.qqFavoriteSongs.first?.id, 1)
        XCTAssertEqual(store.neteaseFavoriteSongs.first?.id, 2)
        XCTAssertEqual(store.kugouFavoriteSongs.first?.id, 3)
    }

    func testMusicCollectionsStoreUsesTypedCollections() {
        let store = MusicCollectionsStore_2_0_3()
        store.albums = [Album_2_0_3(id: "a", name: "Album")]
        store.artists = [Artist_2_0_3(id: "ar", name: "Artist")]
        store.playlists = [Playlist_2_0_3(id: 4, name: "Playlist")]

        XCTAssertEqual(store.albums.first?.id, "a")
        XCTAssertEqual(store.artists.first?.name, "Artist")
        XCTAssertEqual(store.playlists.first?.id, 4)
    }
}
