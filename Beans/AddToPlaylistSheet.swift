import SwiftUI

struct AddToPlaylistSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    private let favorites = FavoritesStore.shared
    @Environment(\.dismiss) private var dismiss

    let song: Song
    @State private var newName = ""
    @State private var showCreateField = false
    @State private var message: String?

    var body: some View {
        let _ = theme.accent
        CoNavigationStack {
            List {
                if auth.playlists.isEmpty {
                    Text("暂无歌单，请先创建一个")
                        .foregroundStyle(Color.coComment)
                } else {
                    Section("选择歌单") {
                        ForEach(auth.playlists) { playlist in
                            Button {
                                Task { await add(to: playlist) }
                            } label: {
                                HStack(spacing: 12) {
                                    CoverImage(url: playlist.coverURL, size: 38, cornerRadius: 8)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name)
                                            .font(CoFont.appFont(15))
                                            .foregroundStyle(Color.coLabel)
                                            .lineLimit(1)
                                        Text(beansSongCountText(playlist.trackCount))
                                            .font(CoFont.appFont(11))
                                            .foregroundStyle(Color.coComment)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }

                if showCreateField {
                    Section("新建歌单") {
                        TextField("歌单名称", text: $newName)
                            .submitLabel(.done)
                        Button {
                            Task { await createAndAdd() }
                        } label: {
                            Text("创建并添加")
                                .font(CoFont.appFont(15, .semibold))
                                .foregroundStyle(Color.coAmber)
                        }
                    }
                } else {
                    Button {
                        showCreateField = true
                    } label: {
                        Label("新建歌单", systemImage: "plus.circle")
                    }
                }

                if let message {
                    Section {
                        Text(message)
                            .font(CoFont.appFont(13))
                            .foregroundStyle(Color.coSage)
                    }
                }
            }
            .navigationTitle("添加到歌单")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func add(to playlist: Playlist) async {
        let ok = (try? await KugouMusicAPI.shared.addToPlaylist(playlistID: playlist.id, songs: [song])) ?? false
        if ok {
            if !favorites.isLiked(song) {
                _ = await favorites.toggle(song)
            }
            dismiss()
        } else {
            message = "添加失败，请重试"
        }
    }

    private func createAndAdd() async {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            let created = try await KugouMusicAPI.shared.createPlaylist(name: name)
            let ok = try await KugouMusicAPI.shared.addToPlaylist(playlistID: created.id, songs: [song])
            if ok {
                if !favorites.isLiked(song) {
                    _ = await favorites.toggle(song)
                }
                try? await auth.loadLibrary()
                dismiss()
            } else {
                message = "歌单已创建，但添加歌曲失败"
            }
        } catch {
            message = error.localizedDescription
        }
    }
}
