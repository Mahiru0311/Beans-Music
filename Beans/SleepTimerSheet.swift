import SwiftUI

struct SleepTimerSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss

    private let options = [5, 15, 30, 45, 60, 90]
    /// 自定义定时分钟数
    @State private var customMinutesText = "30"

    var body: some View {
        let _ = theme.accent
        ZStack {
            CoLiquidSheetBackground()

            CoNavigationStack {
                List {
                    if player.sleepTimerRemaining > 0 {
                        Section("当前定时") {
                            Label {
                                Text(String(format: NSLocalizedString("剩余 %@", comment: ""), player.sleepTimerFormatted ?? "0:00"))
                            } icon: {
                                Image(systemName: "moon.zzz.fill")
                                    .foregroundStyle(Color.coAmber)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    Section("定时关闭播放") {
                        ForEach(options, id: \.self) { minutes in
                            Button {
                                player.startSleepTimer(minutes: minutes)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(String(format: NSLocalizedString("%d 分钟后关闭", comment: ""), minutes))
                                        .foregroundStyle(Color.coLabel)
                                    Spacer()
                                    if isActive(minutes) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.coAmber)
                                    }
                                }
                            }
                            .listRowBackground(Color.clear)
                        }
                        Button(role: .destructive) {
                            player.stopSleepTimer()
                            dismiss()
                        } label: {
                            Label("关闭定时", systemImage: "xmark.circle")
                        }
                        .listRowBackground(Color.clear)
                    }
                    Section("播放结束") {
                        Button {
                            player.stopAfterCurrentSong.toggle()
                        } label: {
                            HStack {
                                Label("当前歌曲播放结束后停止", systemImage: "stop.circle")
                                    .foregroundStyle(Color.coLabel)
                                Spacer()
                                if player.stopAfterCurrentSong {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.coAmber)
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    Section("自定义时长") {
                        HStack {
                            Text("分钟")
                                .foregroundStyle(Color.coLabel)
                            Spacer()
                            TextField("分钟", text: $customMinutesText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                                .textFieldStyle(.roundedBorder)
                        }
                        .listRowBackground(Color.clear)
                        Button {
                            let minutes = min(max(Int(customMinutesText) ?? 30, 1), 720)
                            player.startSleepTimer(minutes: minutes)
                            dismiss()
                        } label: {
                            Label("开始自定义定时", systemImage: "timer")
                                .foregroundStyle(Color.coLabel)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
                .coScrollContentBackgroundHidden()
                .background(Color.clear)
                .navigationTitle("睡眠定时")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { dismiss() }
                    }
                }
            }
        }
        .background(CoSheetPresentationSurfaceClearer())
    }

    private func isActive(_ minutes: Int) -> Bool {
        guard let end = player.sleepTimerEndsAt else { return false }
        let remaining = end.timeIntervalSinceNow
        return remaining > 0 && remaining < TimeInterval(minutes * 60) + 5
    }
}

struct SleepTimerSheetHost: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var theme: ThemeStore

    var body: some View {
        let content = SleepTimerSheet()
            .environmentObject(player)
            .environmentObject(theme)

        content
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.clear)
            .presentationCornerRadius(28)
    }
}
