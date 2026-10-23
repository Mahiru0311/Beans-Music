import SwiftUI
import UIKit

@main
struct BeansApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var auth = AuthStore()
    @StateObject private var player = PlayerManager()
    @StateObject private var theme = ThemeStore.shared
    @StateObject private var favorites = FavoritesStore.shared
    /// 免责声明确认状态：未确认前主界面在模糊层下方可见，确认后移除门禁
    @AppStorage("beans.disclaimerAccepted") private var disclaimerAccepted = false
    @AppStorage("beans.language") private var languageRaw = AppLanguage.chinese.rawValue

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--beans-ui-smoke") {
            UserDefaults.standard.set(true, forKey: "beans.disclaimerAccepted")
            UserDefaults.standard.set(SearchProvider.kugou.rawValue, forKey: "beans.homeSource")
        }
        #endif
        // 主页暂停只应在设置页打开期间生效，避免异常退出后把暂停状态永久写入本地。，
        UserDefaults.standard.set(false, forKey: "beans.pauseHomeRendering")
        UserDefaults.standard.register(defaults: [
            "beans.uiStyle": BeansUIStyle.nativeClean.rawValue,
            "beans.coverPlayerStyle": BeansCoverPlayerStyle.appleMusic.rawValue,
            "beans.appleMusic.showVolume": false,
            "beans.homeHideUsername": true,
            "beans.homeHeaderHideSort": true,
            "beans.homeHeaderHideRefresh": true,
            PlatformPreferenceStore.hidePickerKey: true,
            "beans.homeWallpaperBlur": 0.0,
            "beans.haptics.enabled": true,
            "beans.playback.autoResumeLast": false,
            "beans.playback.autoSkipOnFailure": true,
            "beans.nowPlaying.enabled.v1": true
        ])

        // Restore wallpaper files before the first SwiftUI frame is created.
        // Doing this in the launch task made the root view render once with a
        // fallback background and then switch to the restored wallpaper,
        // which was visible as a brief flash on every launch.
        ThemeStore.shared.restoreWallpapersIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(auth)
                    .environmentObject(player)
                    .environmentObject(theme)
                    .environmentObject(favorites)
                // 未确认前展示首次使用引导页（分页引导 + 免责确认）
                if !disclaimerAccepted {
                    OnboardingView { disclaimerAccepted = true }
                }
            }
            .background(BeansScrollFadeProbe())
            .environment(\.locale, Locale(identifier: languageRaw))
            .onAppear {
                BeansCarPlayCoordinator.shared.configure(player: player)
            }
            .task {
                // 直接进入主页，首帧完成后恢复已安装用户的数据与媒体偏好。
                await Task.yield()
                player.restorePersistedPlayMode()
                player.resumePersistedPlaybackIfEnabled()
                FontManager.reinstallIfNeeded()
                await RemoteControlStore.shared.refreshIfNeeded(force: true)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await RemoteControlStore.shared.refreshIfNeeded()
                }
            }
        }
    }
}

