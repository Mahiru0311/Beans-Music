import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var theme: ThemeStore
    @State private var showClearConfirm = false

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                if player.history.isEmpty {
                    EmptyStateView(icon: "clock.arrow.circlepath", text: "暂无播放历史")
                } else {
                    List {
                        ForEach(Array(player.history.enumerated()), id: \.element.identityKey) { index, song in
                            SongCell(song: song) { open(song, index: index) }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onDelete { offsets in
                            player.removeHistory(at: offsets)
                        }
                    }
                    .beansScrollContentBackgroundHidden()
                    .listStyle(.plain)
                }
            }
            .navigationTitle("最近播放")
            .navigationBarTitleDisplayMode(.inline)
            .alert("清除播放历史？", isPresented: $showClearConfirm) {
                Button("清除", role: .destructive) { player.clearHistory() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将清除全部播放历史，此操作不可恢复；收藏、歌单不受影响。")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !player.history.isEmpty {
                        Button("清空") {
                            showClearConfirm = true
                        }
                    }
                }
            }
        }
    }

    private func open(_ song: Song, index: Int) {
        player.play(songs: player.history, startAt: index)
    }
}

