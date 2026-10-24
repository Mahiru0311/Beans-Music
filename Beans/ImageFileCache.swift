import UIKit
import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

/// 主页和“我的”共用的自定义头像，图片只保存在本机沙盒内。
@MainActor
final class CoAvatarStore: ObservableObject {
    static let shared = CoAvatarStore()

    @Published private(set) var path: String
    @Published private(set) var revision = 0
    private let defaultsKey = "co.profile.customAvatarPath"
    private let dataKey = "co.profile.customAvatarData"
    private let filenameKey = "co.profile.customAvatarFilename"

    private static var storageDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    private init() {
        let defaults = UserDefaults.standard
        let storedPath = defaults.string(forKey: defaultsKey) ?? ""
        let storedFilename = defaults.string(forKey: filenameKey) ?? ""
        let migratedFilename = storedPath.isEmpty ? "" : URL(fileURLWithPath: storedPath).lastPathComponent
        let stableFilenames = [storedFilename, migratedFilename].filter { !$0.isEmpty }

        if let stableURL = stableFilenames.lazy
            .map({ Self.storageDirectory.appendingPathComponent($0) })
            .first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            path = stableURL.path
            defaults.set(stableURL.path, forKey: defaultsKey)
            defaults.set(stableURL.lastPathComponent, forKey: filenameKey)
        } else if !storedPath.isEmpty, FileManager.default.fileExists(atPath: storedPath) {
            path = storedPath
            defaults.set(URL(fileURLWithPath: storedPath).lastPathComponent, forKey: filenameKey)
        } else if let encoded = defaults.string(forKey: dataKey),
                  let data = Data(base64Encoded: encoded),
                  let image = UIImage(data: data),
                  let jpeg = image.jpegData(compressionQuality: 0.88) {
            let fileURL = Self.storageDirectory
                .appendingPathComponent("CoProfileAvatar.jpg")
            do {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try jpeg.write(to: fileURL, options: .atomic)
                path = fileURL.path
                defaults.set(path, forKey: defaultsKey)
                defaults.set(fileURL.lastPathComponent, forKey: filenameKey)
            } catch {
                path = ""
            }
        } else {
            path = ""
        }
    }

    var isVideo: Bool {
        guard !path.isEmpty,
              let type = UTType(filenameExtension: URL(fileURLWithPath: path).pathExtension) else { return false }
        return type.conforms(to: .movie)
    }

    func save(data: Data) {
        let fileURL = Self.storageDirectory
            .appendingPathComponent("CoProfileAvatar.jpg")
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            guard let image = UIImage(data: data),
                  let jpeg = image.jpegData(compressionQuality: 0.88) else { return }
            if !path.isEmpty, path != fileURL.path {
                try? FileManager.default.removeItem(atPath: path)
                CoImageFileCache.remove(path)
            }
            try jpeg.write(to: fileURL, options: .atomic)
            path = fileURL.path
            UserDefaults.standard.set(path, forKey: defaultsKey)
            UserDefaults.standard.set(jpeg.base64EncodedString(), forKey: dataKey)
            UserDefaults.standard.set(fileURL.lastPathComponent, forKey: filenameKey)
            CoImageFileCache.remove(path)
            revision &+= 1
        } catch {
            CoLogger.shared.log("自定义头像保存失败：\(error.localizedDescription)", level: .warn)
        }
    }

    func saveVideo(data: Data, fileExtension: String) {
        let ext = fileExtension.isEmpty ? "mov" : fileExtension.lowercased()
        let directory = Self.storageDirectory
        let fileURL = directory.appendingPathComponent("CoProfileAvatar").appendingPathExtension(ext)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if !path.isEmpty, path != fileURL.path {
                try? FileManager.default.removeItem(atPath: path)
                CoImageFileCache.remove(path)
            }
            try data.write(to: fileURL, options: .atomic)
            path = fileURL.path
            UserDefaults.standard.set(path, forKey: defaultsKey)
            UserDefaults.standard.removeObject(forKey: dataKey)
            UserDefaults.standard.set(fileURL.lastPathComponent, forKey: filenameKey)
            revision &+= 1
        } catch {
            CoLogger.shared.log("自定义视频头像保存失败：\(error.localizedDescription)", level: .warn)
        }
    }

    func clear() {
        if !path.isEmpty {
            try? FileManager.default.removeItem(atPath: path)
            CoImageFileCache.remove(path)
        }
        path = ""
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        UserDefaults.standard.removeObject(forKey: dataKey)
        UserDefaults.standard.removeObject(forKey: filenameKey)
        revision &+= 1
    }
}

/// 本地“我的”昵称区域背景，独立于主页壁纸，支持图片、GIF 和视频并在覆盖安装后保留。
@MainActor
final class CoProfileNameBackgroundStore: ObservableObject {
    static let shared = CoProfileNameBackgroundStore()

    @Published private(set) var path: String
    @Published private(set) var revision = 0

    private let pathKey = "co.profile.nameBackgroundPath"
    private let filenameKey = "co.profile.nameBackgroundFilename"

    private static var storageDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    private init() {
        let defaults = UserDefaults.standard
        let storedPath = defaults.string(forKey: pathKey) ?? ""
        let storedFilename = defaults.string(forKey: filenameKey) ?? ""
        let candidates = [storedFilename, storedPath.isEmpty ? "" : URL(fileURLWithPath: storedPath).lastPathComponent]
            .filter { !$0.isEmpty }

        if let stableURL = candidates
            .map({ Self.storageDirectory.appendingPathComponent($0) })
            .first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            path = stableURL.path
            defaults.set(stableURL.path, forKey: pathKey)
            defaults.set(stableURL.lastPathComponent, forKey: filenameKey)
        } else if !storedPath.isEmpty, FileManager.default.fileExists(atPath: storedPath) {
            path = storedPath
            defaults.set(URL(fileURLWithPath: storedPath).lastPathComponent, forKey: filenameKey)
        } else {
            path = ""
        }
    }

    var url: URL? {
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    func save(data: Data, fileExtension: String) {
        guard !data.isEmpty else { return }
        let ext = fileExtension.isEmpty ? "jpg" : fileExtension.lowercased()
        let fileURL = Self.storageDirectory
            // Give every replacement a new URL so AVPlayer and SwiftUI cannot
            // reuse a cached video when two uploads share the same extension.
            .appendingPathComponent("CoProfileNameBackground-\(UUID().uuidString)")
            .appendingPathExtension(ext)
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if !path.isEmpty, path != fileURL.path {
                try? FileManager.default.removeItem(atPath: path)
                CoImageFileCache.remove(path)
            }
            try data.write(to: fileURL, options: .atomic)
            path = fileURL.path
            UserDefaults.standard.set(path, forKey: pathKey)
            UserDefaults.standard.set(fileURL.lastPathComponent, forKey: filenameKey)
            CoImageFileCache.remove(path)
            revision &+= 1
        } catch {
            CoLogger.shared.log("昵称背景保存失败：\(error.localizedDescription)", level: .warn)
        }
    }

    func clear() {
        if !path.isEmpty {
            try? FileManager.default.removeItem(atPath: path)
            CoImageFileCache.remove(path)
        }
        path = ""
        UserDefaults.standard.removeObject(forKey: pathKey)
        UserDefaults.standard.removeObject(forKey: filenameKey)
        revision &+= 1
    }
}


struct CoAvatarView: View {
    let remoteURL: URL?
    var size: CGFloat = 40
    var useCustom: Bool = false

    @ObservedObject private var store = CoAvatarStore.shared

    var body: some View {
        Group {
            if useCustom, store.isVideo {
                CustomCoverMediaView(url: URL(fileURLWithPath: store.path), isMuted: true)
                    .id(store.revision)
            } else if useCustom, let custom = CoImageFileCache.image(at: store.path) {
                Image(uiImage: custom)
                    .resizable()
                    .scaledToFill()
            } else if let remoteURL {
                CoverImage(url: remoteURL, size: size, cornerRadius: size / 2)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(Color.coComment)
                    .frame(width: size, height: size)
                    .background(Color.coGlassFill)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// 各主页面共用的“我的”快捷入口，始终优先显示用户选择的本地头像。
struct CoProfileShortcutButton: View {
    @EnvironmentObject private var auth: AuthStore
    // 主页头像直接读与我的页同一个源（KugouMusicAuth.shared，@ObservedObject 监听）：
    // AuthStore 只在 init / finishLogin / refreshAccount / loadLibrary 时从酷狗同步一次快照，
    // 登录发生在 AuthStore 初始化之后、用户还没打开过我的页时，auth.user 就是旧的/空的，
    // 头像只能显示灰色人形占位——而我的页直接读 kugouAuth 不会有这个问题。
    // 直接读酷狗源后，登录保存瞬间 @Published 变化就会刷新头像，不依赖快照时机；
    // auth 仍保留在环境里（其他调用点与环境注入不动），头像本身不再读它。
    @ObservedObject private var kugouAuth = KugouMusicAuth.shared
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("co.headerAccessoryMode") private var accessoryModeRaw = CoHeaderAccessoryMode.avatar.rawValue
    var action: () -> Void

    var body: some View {
        Group {
            switch CoHeaderAccessoryMode(rawValue: accessoryModeRaw) ?? .avatar {
            case .avatar:
                Button {
                    CoHaptics.tap()
                    action()
                } label: {
                    avatarLabel
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.92))
                .frame(width: 46, height: 46)
                .fixedSize()
                .accessibilityLabel(beansLocalized("我的", "Profile"))
            case .themeToggle:
                CoThemeToggleButton(colorScheme: colorScheme)
            case .hidden:
                EmptyView()
            }
        }
    }

    private var avatarLabel: some View {
        // 与我的页同源：酷狗头像（本地自定义头像优先逻辑在 CoAvatarView 的 useCustom 里，不动）。
        CoAvatarView(remoteURL: kugouAuth.avatarURL, size: 38, useCustom: true)
            .frame(width: 38, height: 38)
            .overlay {
                Circle().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.8)
            }
            .padding(4)
            .background {
                CoGlass(shape: Circle(), forceLiquid: true)
            }
            .clipShape(Circle())
            .contentShape(Circle())
            .frame(width: 46, height: 46)
            .fixedSize()
    }
}

struct CoThemeToggleButton: View {
    let colorScheme: ColorScheme
    var usesGlassContainer = true
    var onToggle: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Image(systemName: colorScheme == .dark ? "sun.max.fill" : "moon.stars.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.coLabel)
                .frame(width: 38, height: 38)
                .background {
                    if usesGlassContainer {
                        CoGlass(shape: Circle(), forceLiquid: true)
                    }
                }
                .contentShape(Circle())
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onEnded { value in
                    CoHaptics.tap()
                    if let onToggle {
                        onToggle()
                    } else {
                        NotificationCenter.default.post(
                            name: .coThemeToggleRequested,
                            object: CoThemeToggleRequest(location: value.location)
                        )
                    }
                }
        )
        .accessibilityLabel(beansLocalized("切换浅深色模式", "Toggle light and dark mode"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            CoHaptics.tap()
            if let onToggle {
                onToggle()
            } else {
                NotificationCenter.default.post(
                    name: .coThemeToggleRequested,
                    object: CoThemeToggleRequest(
                        location: CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
                    )
                )
            }
        }
    }
}

/// 复用本地图片解码结果，避免设置页/歌词页滚动时反复从磁盘解码大图。
enum CoImageFileCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(at path: String) -> UIImage? {
        guard !path.isEmpty else { return nil }
        let key = path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = UIImage(contentsOfFile: path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    static func remove(_ path: String) {
        guard !path.isEmpty else { return }
        cache.removeObject(forKey: path as NSString)
    }

    static func removeAll() {
        cache.removeAllObjects()
    }
}
