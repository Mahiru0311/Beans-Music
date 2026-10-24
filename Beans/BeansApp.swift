import SwiftUI
import UIKit

/// 存储键与沙盒文件迁移：旧版 beans.* → 新版 co.*。
///
/// 只复制、不删除旧键：万一有漏改的读取点，旧键还在可回落；
/// 删除留给后续版本验证后做。每次启动都跑（幂等）：新键缺失且
/// 旧键存在时补抄，旧备份恢复后旧键重现时也能自动补。
/// 文件同步搬家：头像、壁纸、歌词背景、自定义封面、日志、封面缓存
/// 的旧目录/文件搬到新名下（新名已存在时不动，不覆盖用户数据）。
/// 存量字符串值里的旧路径段同步修正（壁纸列表、壁纸备份字典的键、
/// 头像文件名等），否则搬了目录、值还指旧路。
/// 注意：KugouMusicAuth 里的 "beans-kugou" 是设备指纹种子，改了会
/// 改变设备身份，故意不改，不属于名称迁移范围。
private enum CoKeyMigration {
    private static let fileMoves: [(base: FileManager.SearchPathDirectory, old: String, new: String)] = [
        (.applicationSupportDirectory, "BeansProfileAvatar.jpg", "CoProfileAvatar.jpg"),
        (.applicationSupportDirectory, "BeansCustomSongCovers", "CoCustomSongCovers"),
        (.documentDirectory, "BeansLyricBackground", "CoLyricBackground"),
        (.documentDirectory, "BeansLogs", "CoLogs"),
        (.documentDirectory, "BeansWallpapers", "CoWallpapers"),
        (.cachesDirectory, "BeansCoverImageFiles", "CoCoverImageFiles"),
        (.cachesDirectory, "BeansCoverImageCache", "CoCoverImageCache"),
    ]

    private static let pathSegments: [(old: String, new: String)] = [
        ("BeansWallpapers", "CoWallpapers"),
        ("BeansLyricBackground", "CoLyricBackground"),
        ("BeansLogs", "CoLogs"),
        ("BeansCustomSongCovers", "CoCustomSongCovers"),
        ("BeansCoverImageFiles", "CoCoverImageFiles"),
        ("BeansCoverImageCache", "CoCoverImageCache"),
        ("BeansProfileAvatar", "CoProfileAvatar"),
        ("BeansProfileNameBackground-", "CoProfileNameBackground-"),
    ]

    static func run() {
        let defaults = UserDefaults.standard
        let snapshot = defaults.dictionaryRepresentation()
        for (key, value) in snapshot where key.hasPrefix("beans.") {
            let newKey = "co.\(key.dropFirst("beans.".count))"
            if snapshot[newKey] == nil {
                defaults.set(value, forKey: newKey)
            }
        }
        // 存量值里的旧路径段修正（只动 co.* 键，旧键原样保留）。
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix("co.") {
            if let fixed = fixedValue(value), !isEqualValue(fixed, value) {
                defaults.set(fixed, forKey: key)
            }
        }
        moveFiles()
    }

    private static func fixedValue(_ value: Any) -> Any? {
        if let string = value as? String {
            return fixPath(string)
        }
        if let array = value as? [String] {
            return array.map(fixPath)
        }
        if let dict = value as? [String: String] {
            var fixed: [String: String] = [:]
            for (key, item) in dict { fixed[fixPath(key)] = item }
            return fixed
        }
        return nil
    }

    private static func isEqualValue(_ lhs: Any, _ rhs: Any) -> Bool {
        if let a = lhs as? String, let b = rhs as? String { return a == b }
        if let a = lhs as? [String], let b = rhs as? [String] { return a == b }
        if let a = lhs as? [String: String], let b = rhs as? [String: String] { return a == b }
        return false
    }

    private static func fixPath(_ path: String) -> String {
        var result = path
        for (old, new) in pathSegments {
            result = result.replacingOccurrences(of: old, with: new)
        }
        return result
    }

    private static func moveFiles() {
        let manager = FileManager.default
        for move in fileMoves {
            guard let base = manager.urls(for: move.base, in: .userDomainMask).first else { continue }
            let oldURL = base.appendingPathComponent(move.old)
            let newURL = base.appendingPathComponent(move.new)
            guard manager.fileExists(atPath: oldURL.path),
                  !manager.fileExists(atPath: newURL.path) else { continue }
            try? manager.moveItem(at: oldURL, to: newURL)
        }
        // 头像与昵称背景是按前缀散落的文件（多扩展名），逐个改名前缀。
        guard let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let names = try? manager.contentsOfDirectory(atPath: support.path) else { return }
        for name in names {
            for (oldPrefix, newPrefix) in [("BeansProfileAvatar", "CoProfileAvatar"),
                                            ("BeansProfileNameBackground-", "CoProfileNameBackground-")] where name.hasPrefix(oldPrefix) {
                let newName = newPrefix + name.dropFirst(oldPrefix.count)
                let oldURL = support.appendingPathComponent(name)
                let newURL = support.appendingPathComponent(newName)
                if !manager.fileExists(atPath: newURL.path) {
                    try? manager.moveItem(at: oldURL, to: newURL)
                }
            }
        }
    }
}

@main
struct CoApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var auth = AuthStore()
    @StateObject private var player = PlayerManager()
    @StateObject private var theme = ThemeStore.shared
    @StateObject private var favorites = FavoritesStore.shared
    /// 免责声明确认状态：未确认前主界面在模糊层下方可见，确认后移除门禁
    @AppStorage("co.disclaimerAccepted") private var disclaimerAccepted = false
    @AppStorage("co.language") private var languageRaw = AppLanguage.chinese.rawValue

    init() {
        // 迁移必须在任何读取之前跑：它是本 init 的第一行。
        CoKeyMigration.run()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--co-ui-smoke") {
            UserDefaults.standard.set(true, forKey: "co.disclaimerAccepted")
            UserDefaults.standard.set(SearchProvider.kugou.rawValue, forKey: "co.homeSource")
        }
        #endif
        // 主页暂停只应在设置页打开期间生效，避免异常退出后把暂停状态永久写入本地。，
        UserDefaults.standard.set(false, forKey: "co.pauseHomeRendering")
        UserDefaults.standard.register(defaults: [
            "co.uiStyle": CoUIStyle.nativeClean.rawValue,
            "co.coverPlayerStyle": CoCoverPlayerStyle.appleMusic.rawValue,
            "co.appleMusic.showVolume": false,
            "co.homeHeaderHideSort": true,
            "co.homeWallpaperBlur": 0.0,
            "co.haptics.enabled": true,
            "co.playback.autoResumeLast": false,
            "co.playback.autoSkipOnFailure": true,
            "co.nowPlaying.enabled.v1": true
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
            .background(CoScrollFadeProbe())
            .environment(\.locale, Locale(identifier: languageRaw))
            .onAppear {
                CoCarPlayCoordinator.shared.configure(player: player)
            }
            .task {
                // 直接进入主页，首帧完成后恢复已安装用户的数据与媒体偏好。
                await Task.yield()
                player.restorePersistedPlayMode()
                player.resumePersistedPlaybackIfEnabled()
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

