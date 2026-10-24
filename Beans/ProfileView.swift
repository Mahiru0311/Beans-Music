import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers


private struct BeansProfileGlobalFrameKey: PreferenceKey {
    static let defaultValue = CGRect.zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

/// 白卡顶部在全局坐标里的位置：用来判断白卡是否已滑到状态栏区域，
/// 以便在黑头在顶时用浅色状态栏文字、白卡滑到顶时切回深色文字。
private struct BeansProfileCardTopKey: PreferenceKey {
    static let defaultValue = CGFloat.greatestFiniteMagnitude

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// 我的页头部全局 frame：单层壁纸层据此算顶边与底边。
private struct CoProfileHeaderFrameKey: PreferenceKey {
    static let defaultValue = CGRect.zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

/// 注意：我的页下拉放大不再用 PreferenceKey 读数链驱动（见 headerDragPull 处注释）。
/// 旧的 CoProfilePullKey 已删：zoom、zoom2、pullfix、baseline 四轮都是同一条
/// PreferenceKey + @State 回写链，真机上放大都出不来或只出一点点。

/// 我的页 ScrollView 顶部安全区处理（只在我的 tab 用，头像 sheet 不用）：
/// ScrollView 忽略顶部安全区后，它的 frame 才到屏幕顶边，头部背景里的壁纸
/// 才能画到状态栏区；同时加一个高度 = 顶部安全区的透明 safeAreaInset，
/// 让滚动内容本身仍从安全区下方开始（头像位置、歌单格 scrollTo 锚点都不变），
/// 避免标题被灵动岛/状态栏盖住。

private struct CoMyTabScrollTopInset: ViewModifier {
    let enabled: Bool
    let topSafeArea: CGFloat
    func body(content: Content) -> some View {
        if enabled {
            content
                .ignoresSafeArea(edges: .top)
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear.frame(height: topSafeArea)
                }
        } else {
            content
        }
    }
}

/// 只改窗口级状态栏样式，不改页面颜色：窗口改深色只影响状态栏文字，
/// 页面颜色由 body 上的 preferredColorScheme（见 profileEffectiveScheme）单独定，
/// 白卡在浅色主题下仍是白卡、深色文字，不会被窗口样式带翻。
private enum CoProfileStatusBarStyle {
    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })
    }

    /// 无条件设置，不用 applied 守卫：旧守卫在多实例 / 切 tab 时一旦被 restore 掉，
    /// 之后 update 不再触发就永远设不回深色，是窗口桥三轮失效的另一半原因。
    /// 调用方每次 update 都同步设一次 + 下一 runloop 再设一次，顶掉根视图 preferredColorScheme 的重断言。
    static func applyDark() {
        keyWindow()?.overrideUserInterfaceStyle = .dark
    }

    static func restore() {
        keyWindow()?.overrideUserInterfaceStyle = .unspecified
    }
}


/// 我的页头部壁纸（独立于整站主题壁纸）：只影响我的页头部那整块背景。
/// 默认无图 = 现在黑色；选图后存沙盒文件，不打包进 IPA、不上传、不走主题壁纸库与备份。
/// 静态图，不带连续动画引擎，不发热。
final class CoProfileHeaderWallpaper: ObservableObject {
    static let shared = CoProfileHeaderWallpaper()
    @Published private(set) var image: UIImage?
    /// 壁纸顶部（上 1/4）平均亮度是否偏亮：true = 浅色顶，状态栏用黑字；false = 深色顶/无图，状态栏用白字。
    /// 用确定格式的 CGContext 重绘取样（RGBA 大端），不依赖渲染器像素顺序。
    @Published private(set) var topIsLight = false

    private static func computeTopIsLight(_ image: UIImage) -> Bool {
        let w = 64, h = 64
        guard let cg = image.cgImage,
              let cs = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return false }
        var sum: Double = 0
        var count = 0
        for y in 0..<(h / 4) {
            for x in 0..<w {
                let off = y * w * 4 + x * 4
                let r = Double(data.load(fromByteOffset: off, as: UInt8.self))
                let g = Double(data.load(fromByteOffset: off + 1, as: UInt8.self))
                let b = Double(data.load(fromByteOffset: off + 2, as: UInt8.self))
                sum += (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
                count += 1
            }
        }
        guard count > 0 else { return false }
        return (sum / Double(count)) > 0.55
    }
    private var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CoProfileHeaderWallpaper.jpg")
    }
    private init() { load() }
    private func load() {
        guard let url = fileURL, let data = try? Data(contentsOf: url), let img = UIImage(data: data) else { return }
        image = img
        topIsLight = Self.computeTopIsLight(img)
    }
    func save(data: Data) {
        guard let raw = UIImage(data: data) else { return }
        save(image: raw)
    }
    /// 直接存一张已裁好的图：与 save(data:) 同规格（最长边 1600、JPEG 0.85），
    /// 供裁切完成后调用；取消时不调它，旧壁纸原样保留。
    /// 返回是否真的写进了沙盒：写失败时调用方必须提示、不要静默关掉裁切页。
    @discardableResult
    func save(image raw: UIImage) -> Bool {
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(raw.size.width, raw.size.height))
        let img: UIImage
        if scale < 1 {
            let size = CGSize(width: raw.size.width * scale, height: raw.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: size)
            img = renderer.image { _ in raw.draw(in: CGRect(origin: .zero, size: size)) }
        } else {
            img = raw
        }
        guard let jpeg = img.jpegData(compressionQuality: 0.85), let url = fileURL else { return false }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            try jpeg.write(to: url, options: .atomic)
        } catch {
            return false
        }
        let light = Self.computeTopIsLight(img)
        DispatchQueue.main.async { self.image = img; self.topIsLight = light }
        return true
    }
    /// 把一张图转成方向朝上的图（像素尺寸 = 原图的方向后尺寸），裁切时按它算 rect，
    /// 否则手机拍的竖图/横图用 cgImage 直接裁会转错方向。scale 保持原图 scale，
    /// 这样裁切 rect 从显示尺寸换算到像素尺寸时比例一致。
    static func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        var format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
    }
    /// 按显示坐标裁一刀：cropRectInImagePoints 是裁切框在原图显示尺寸（points，
    /// 已按方向归一化）里的 rect，返回裁好的 UIImage（方向朝上）；rect 越界时钳到图内。
    /// 注意：动态图（GIF 等）或 CIImage 图的 cgImage 可能为空，上一轮这里直接
    /// 返回空、完成按钮按了等于没按；本轮先把它重绘成一张静态图再裁，保证
    /// 只要图能显示、完成就一定能裁出来（极端情况下调用方还会用原图兜底）。
    static func croppedImage(_ image: UIImage, rectInPoints: CGRect) -> UIImage? {
        var normalized = normalizedImage(image)
        if normalized.cgImage == nil {
            let format = UIGraphicsImageRendererFormat()
            format.scale = normalized.scale
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(size: normalized.size, format: format)
            normalized = renderer.image { _ in normalized.draw(in: CGRect(origin: .zero, size: normalized.size)) }
        }
        guard let cg = normalized.cgImage else { return nil }
        let scaleX = CGFloat(cg.width) / max(1, normalized.size.width)
        let scaleY = CGFloat(cg.height) / max(1, normalized.size.height)
        var pixelRect = CGRect(
            x: rectInPoints.origin.x * scaleX,
            y: rectInPoints.origin.y * scaleY,
            width: rectInPoints.width * scaleX,
            height: rectInPoints.height * scaleY
        )
        pixelRect = pixelRect.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard pixelRect.width >= 1, pixelRect.height >= 1,
              let cropped = cg.cropping(to: pixelRect.integral) else { return nil }
        return UIImage(cgImage: cropped, scale: normalized.scale, orientation: .up)
    }
    func clear() {
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
        DispatchQueue.main.async { self.image = nil; self.topIsLight = false }
    }
}

private struct BeansProfileThemeRevealOverlay: View {
    let snapshot: UIImage
    let origin: CGPoint
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let farthestX = max(origin.x, proxy.size.width - origin.x)
            let farthestY = max(origin.y, proxy.size.height - origin.y)
            let radius = hypot(farthestX, farthestY) + 4

            Image(uiImage: snapshot)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .mask {
                    Rectangle()
                        .fill(Color.white)
                        .overlay {
                            Circle()
                                .fill(Color.black)
                                .frame(width: radius * 2, height: radius * 2)
                                .scaleEffect(max(progress, 0.001))
                                .position(origin)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct BeansExclusiveIDBadgeSurface: View {
    let style: BeansExclusiveIDBadgeStyle

    var body: some View {
        Group {
            if style == .classicGold {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.42, green: 0.23, blue: 0.03), Color(red: 0.96, green: 0.66, blue: 0.12), Color(red: 0.50, green: 0.29, blue: 0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Capsule().strokeBorder(Color(red: 1, green: 0.90, blue: 0.55).opacity(0.9), lineWidth: 1)
                    }
                    .shadow(color: Color(red: 0.94, green: 0.59, blue: 0.06).opacity(0.36), radius: 5, y: 1)
            } else {
                TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { timeline in
                    let phase = Angle.degrees((timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 12)) * 30)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.035, green: 0.025, blue: 0.075),
                                    Color(red: 0.16, green: 0.055, blue: 0.25),
                                    Color(red: 0.055, green: 0.03, blue: 0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    AngularGradient(
                                        colors: [
                                            Color(red: 0.43, green: 0.24, blue: 0.74),
                                            Color(red: 1.0, green: 0.84, blue: 0.36),
                                            Color(red: 0.68, green: 0.43, blue: 0.10),
                                            Color(red: 0.43, green: 0.24, blue: 0.74)
                                        ],
                                        center: .center,
                                        angle: phase
                                    ),
                                    lineWidth: 1
                                )
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.45)
                                .padding(1.2)
                        }
                        .shadow(color: Color(red: 0.52, green: 0.26, blue: 0.90).opacity(0.42), radius: 5, y: 1)
                        .shadow(color: Color(red: 1.0, green: 0.72, blue: 0.16).opacity(0.24), radius: 3, y: 1)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ProfileView: View {
    /// 由主页头像以 sheet 打开时，使用主页同一套壁纸背景。
    var forceHomeBackdrop = false
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var favorites: FavoritesStore
    @Environment(\.beansUsesSharedRootBackdrop) private var usesSharedRootBackdrop
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("beans.themeMode") private var themeModeRaw = BeansThemeMode.system.rawValue
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    @AppStorage("beans.homeHeaderHideSort") private var homeHeaderHideSort = false
    @AppStorage("beans.pauseHomeRendering") private var homeRenderingPaused = false
    @AppStorage(BeansBackendSettings.exclusiveIDKey) private var hasExclusiveID = false
    @AppStorage(BeansBackendSettings.exclusiveIDBadgeStyleKey) private var exclusiveBadgeStyleRaw = BeansExclusiveIDBadgeStyle.blackPurpleGold.rawValue
    @AppStorage(BeansBackendSettings.publicIDRevisionKey) private var publicIDRevision = 0

    @State private var showHistory = false
    @State private var showFavorites = false
    @State private var showTopPlayed = false
    @State private var showMyPlaylists = false
    @State private var myPlaylists: [Playlist] = []
    @State private var myPlaylistsLoading = false
    // 隐藏歌单只在设置里开关（2026-10-24 用户拍板）：我的页不再长按隐藏，
    // 这里只保留隐藏记录的读取与过滤，只藏显示、不删歌单，按酷狗账号区分存，见 CoHiddenPlaylists。
    @State private var hiddenPlaylistEntries: [(id: Int, name: String)] = []
    // 旧线 1.9.4 做法：歌单行不用 NavigationLink（其内部点按手势会吞掉长按），
    // 改用 Button 点按，导航由下方隐藏链接驱动，仍是页面推入、不是 sheet。
    @State private var navPlaylist: Playlist?

    /// 统一账号登录面板（网易云 + QQ 音乐整合）
    @State private var showAccountHub = false
    /// 设置页（外观 + 歌词翻译等）
    @State private var showSettings = false
    @State private var themeRevealSnapshot: UIImage?
    @State private var themeRevealOrigin = CGPoint.zero
    @State private var themeRevealProgress: CGFloat = 0
    @State private var profileGlobalFrame = CGRect.zero
    @State private var didRefreshProfileAccount = false
    @State private var showAvatarPicker = false
    @State private var showProfileNameBackgroundPicker = false
    @AppStorage("beans.profile.customNickname") private var customNickname = ""
    @ObservedObject private var avatarStore = BeansAvatarStore.shared
    @ObservedObject private var profileHeaderWallpaper = CoProfileHeaderWallpaper.shared
    @ObservedObject private var profileNameBackgroundStore = BeansProfileNameBackgroundStore.shared
    @ObservedObject private var kugouAuth = KugouMusicAuth.shared
    @ObservedObject private var platformPrefs = PlatformPreferenceStore.shared
    @AppStorage("beans.language") private var languageRaw = AppLanguage.chinese.rawValue
    @AppStorage("beans.globalFloatingEffect") private var globalFloatingEffectRaw = BeansGlobalFloatingEffect.off.rawValue
    @AppStorage("beans.globalFloatingDensity") private var globalFloatingDensity = 1.0
    @AppStorage("beans.globalFloatingSize") private var globalFloatingSize = 1.0
    @AppStorage("beans.globalFloatingSpeed") private var globalFloatingSpeed = 1.0
    @AppStorage("beans.globalFloatingText") private var globalFloatingText = "❄️"
    @AppStorage("beans.globalFloatingRotation") private var globalFloatingRotation = 0.0
    @AppStorage("beans.globalFloatingSkew") private var globalFloatingSkew = 0.0

    private var themeMode: BeansThemeMode {
        BeansThemeMode(rawValue: themeModeRaw) ?? .system
    }

    private var isNativeClean: Bool {
        BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    private var usesExclusiveIDBadge: Bool {
        DeviceIdentity.isDeveloperInstallation || hasExclusiveID
    }

    private var exclusiveBadgeStyle: BeansExclusiveIDBadgeStyle {
        BeansExclusiveIDBadgeStyle(rawValue: exclusiveBadgeStyleRaw) ?? .blackPurpleGold
    }

    private var isEnglish: Bool { languageRaw == AppLanguage.english.rawValue }

    private var displayPlatformSummary: String {
        isEnglish ? "Kugou Music" : "酷狗音乐"
    }

    /// 登录状态提示（酷狗专版：只展示酷狗登录状态）
    private var accountStatusLine: String {
        if kugouAuth.isLoggedIn {
            return isEnglish ? "Kugou Music Logged In" : "酷狗已登录"
        }
        return isEnglish ? "Sign in to sync \(displayPlatformSummary) playlists" : "登录后可同步 \(displayPlatformSummary) 歌单"
    }

    private var hasVisibleAccountLogin: Bool {
        kugouAuth.isLoggedIn
    }

    /// 白卡是否已滑到状态栏区域（卡顶全局 y <= 28pt，约状态栏文字中心高度）。
    @State private var isCardAtTop = false

    /// 我的页头部在全局坐标里的 frame：状态栏滑出判断据此定位。
    /// frame 为空（首帧未上报）时按静止状态处理。
    @State private var profileHeaderFrame = CGRect.zero

    /// 头部下拉量（我的 tab 专属），本轮改由与滚动视图同时识别的拖动手势直接驱动：
    /// 限制与放大到底怎么回事——baseline 包查完的结论是 PreferenceKey + @State 回写链
    /// 本身在回弹过程中不跟手，不是基线数值问题：zoom（头部全局 frame 经偏好回写）、
    /// zoom2（滚动视图顶部读数经偏好回写）、pullfix（读数减安全区）、baseline（首帧零点）
    /// 四轮都是同一条链，真机上放大要么完全没出来、要么只出到约 1.2 倍；回弹是 UIKit
    /// 层面的位移，SwiftUI 布局/偏好上报在回弹过程中不实时重算，读数只在松手后才跳变，
    /// 所以跟手放大出不来。反过来，zoom3/zoom4 那种不经过偏好上报的内联读取曾在
    /// 真机上确实有效果，说明“不依赖布局重算的直接驱动”才是对的路。本轮就用这条路：
    /// 拖动手势的手指位移是事件直接给的，不依赖布局重算，所以跟手就一定能动——
    /// 手指往下走多少，缩放就跟多少，封顶 120pt / 约 1.2 倍（放慢后，
    /// 不再是原来 120pt 就到 1.4 倍那种一眼很夸张的效果）。
    /// 挂法教训：zoom6 把高优先级手势只挂在头部上，被滚动视图平移截获而失效；
    /// 本轮手势挂在整个滚动视图上、用 .simultaneousGesture 同时识别，只驱动
    /// headerDragPull 这一个状态，不再和任何 PreferenceKey 双重驱动。
    /// 门控（不是驱动）：手势开始时只看头部是不是在顶部——用已有的状态栏用
    /// profileHeaderFrame（静止时头部在顶部，minY 约 0；已下滑时 minY 为负），
    /// 只在顶部开始的手势才放大，避免从下面往上滑回顶部时一路放大；一旦在顶部
    /// 开始，就用手指位移全程驱动，不再看门控值。
    /// 内容位移仍靠系统回弹：120pt 封的是壁纸效果（缩放、框高增长），不是
    /// 系统回弹本身；拉到 120pt 后图不再放大、框高不再增长，松手慢速平滑回 0。
    /// 120pt 的理由：头部高约 300pt，120pt 约为头部高的 40%；放慢后缩放
    /// 1 + 120/600 = 约 1.2 倍、框高只跟下拉量的一半走（封顶 +60pt），
    /// 不再是原来 1 + 120/300 = 1.4 倍、框高 1:1 暴涨那种一眼很夸张的效果；
    /// 上一轮拉到 217pt、缩放失控就是没有硬上限的后果。
    @State private var headerDragPull: CGFloat = 0
    @State private var pullGestureActive = false
    @State private var pullGestureStartedAtTop = false

    /// 上滑量（我的 tab 专属）：固定壁纸层在滚动视图之外，下拉时顶边固定是对的，
    /// 上滑时却粘在顶边不动——内容往上滑走了，它还留在 0–423pt，卡片一上移就把
    /// 它露在卡片下面（上滑截图里卡片下面那条壁纸带），再往下又是页面底色。
    /// 修法：固定层按上滑量整体往上移，移多少由下面两路读数取大值，相对位置和
    /// 头部、卡片保持不变（就像壁纸本来就在内容里一样），上滑多少就移多少。
    /// 下拉时两路都钳为 0，顶边仍固定、放大仍只走同时识别拖动手势、120pt 封顶不变。
    /// 基线只在首帧定一次：视图创建时滚动一定在顶部，首帧就是静止值；之后再也
    /// 不重定，避免从歌单页返回（滚动停在半途）时把半途误当成静止值。
    @State private var headerRestMinY: CGFloat? = nil
    @State private var scrollRestOffset: CGFloat? = nil
    @State private var scrollContentOffset: CGFloat = 0
    private var headerScrollUp: CGFloat {
        guard let rest = headerRestMinY, !profileHeaderFrame.isEmpty else { return 0 }
        return max(0, rest - profileHeaderFrame.minY)
    }
    private var contentScrollUp: CGFloat {
        guard let rest = scrollRestOffset else { return 0 }
        return max(0, scrollContentOffset - rest)
    }
    private var wallpaperScrollUp: CGFloat { max(headerScrollUp, contentScrollUp) }

    // 旧首帧零点（pullBaseline）本轮已删：放大不再走 PreferenceKey 回写链，见上面 headerDragPull 注释。

    /// 头部是否已基本滑出状态栏文字区：头部底边 <= 24pt 时，状态栏区背景已是白卡，
    /// 状态栏文字应切回深色；否则头部（黑/壁纸）仍盖住状态栏区，文字应为白色。
    private var profileHeaderScrolledAway: Bool {
        !profileHeaderFrame.isEmpty && profileHeaderFrame.maxY <= 24
    }

    /// 页面实际生效的深浅色：显式浅色/深色与原来一致；跟随系统时取屏幕级深浅色，
    /// 而不是窗口级——这样窗口为状态栏改深色时，页面颜色不会被带翻。
    private var profileEffectiveScheme: ColorScheme {
        if let scheme = themeMode.colorScheme { return scheme }
        return UIScreen.main.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }

    /// 顶部安全区真实值（灵动岛机型约 59pt）：固定黑条的高度，取关键窗口真实值，兜底 59。
    private var profileTopSafeArea: CGFloat {
        let top = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 59
        return top > 0 ? top : 59
    }

    /// 状态栏方案：我的页顶部恒有一条黑色固定条，浅色主题下也用深色方案，
    /// 状态栏文字才为白色；白卡/歌单颜色用下方显式颜色，不随本方案翻转。
    private var profileStatusBarScheme: ColorScheme {
        if forceHomeBackdrop { return profileEffectiveScheme }
        // 头部滑出状态栏区后，状态栏区背景已是白卡，回到生效方案。
        if profileHeaderScrolledAway { return profileEffectiveScheme }
        // 头部在顶时按壁纸顶部亮度定黑白字（方案 ① 采样，不用渐隐罩赌白字）：
        // 无图黑头、深色顶 -> 深色方案（白字）；浅色顶 -> 浅色方案（黑字，新截图里壁纸顶部就是浅色，黑字可读）。
        if profileEffectiveScheme == .dark { return .dark }
        if profileHeaderWallpaper.image == nil { return .dark }
        return profileHeaderWallpaper.topIsLight ? .light : .dark
    }

    /// 显式颜色（不随 environment 颜色方案翻转）：浅色主题下黑字/灰字/浅灰底，
    /// 深色主题下白字/半透明白字/深灰底。只用于我的页白卡区。
    private var coEffectiveLabel: Color { profileEffectiveScheme == .dark ? .white : .black }
    private var coEffectiveSecondary: Color { profileEffectiveScheme == .dark ? .white.opacity(0.65) : Color(red: 0.45, green: 0.45, blue: 0.47) }
    /// 我的页卡片色（唯一来源）：浅色白、深色系统次级背景。页面底色、卡片、
    /// 歌单行背景三处都复用它，不再各写各的——深色下底色纯黑与卡片深灰两截、
    /// 浅色下行背景 0.96 灰与卡片白差一截，就是上滑截图里“颜色不一样”的来源。
    private var coCardBackground: Color { profileEffectiveScheme == .dark ? Color(.secondarySystemBackground) : Color.white }
    private var coEffectiveRowBackground: Color { coCardBackground }

    /// 状态栏样式与页面状态同步：浅色主题且黑头在顶时用浅色文字；
    /// 深色主题（文字本来就是浅色）、白卡滑到顶、白卡在顶时都不需要窗口改色。
    /// 主页头像 sheet 打开的 profile（forceHomeBackdrop）不参与，避免与 tab 页互相抢。
    private func updateProfileStatusBarStyle() {
        guard !forceHomeBackdrop else { return }
        let apply = {
            if self.profileStatusBarScheme == .dark {
                CoProfileStatusBarStyle.applyDark()
            } else {
                CoProfileStatusBarStyle.restore()
            }
        }
        apply()
        // 根视图的 preferredColorScheme 会在重渲染时重断言窗口样式，下一 runloop 再设一次顶回去。
        DispatchQueue.main.async { apply() }
    }

    private var resolvedThemeToggleTarget: BeansThemeMode {
        if themeMode == .dark { return .light }
        if themeMode == .light { return .dark }
        return colorScheme == .dark ? .light : .dark
    }

    @ViewBuilder
    private var profileThemeToggleButton: some View {
        // 定稿分拆：黑白切换只在头像界面（forceHomeBackdrop）放，我的 tab 里不放。
        // 原代码是反过来的（只在 tab 显示、sheet 里藏起），本轮把条件翻转。
        if forceHomeBackdrop {
            BeansThemeToggleButton(colorScheme: colorScheme)
        }
    }

    private func beginProfileThemeReveal(from globalLocation: CGPoint?) {
        let target = resolvedThemeToggleTarget
        guard themeRevealSnapshot == nil else { return }

        if reduceMotion {
            themeModeRaw = target.rawValue
            return
        }

        guard let captured = currentProfileWindowSnapshot() else {
            themeModeRaw = target.rawValue
            return
        }

        let frame = profileGlobalFrame == .zero
            ? CGRect(origin: .zero, size: captured.size)
            : profileGlobalFrame
        let requested = globalLocation ?? CGPoint(x: frame.midX, y: frame.midY)
        themeRevealOrigin = CGPoint(
            x: min(max(requested.x - frame.minX, 0), frame.width),
            y: min(max(requested.y - frame.minY, 0), frame.height)
        )
        themeRevealSnapshot = captured.image
        themeRevealProgress = 0

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            themeModeRaw = target.rawValue
        }

        DispatchQueue.main.async {
            withAnimation(.timingCurve(0.16, 0.82, 0.22, 1.0, duration: 1.12)) {
                themeRevealProgress = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.22) {
            themeRevealSnapshot = nil
            themeRevealProgress = 0
        }
    }

    private func currentProfileWindowSnapshot() -> (image: UIImage, size: CGSize)? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter { $0.windowLevel == .normal && !$0.isHidden }
        guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else { return nil }

        // Render the visible profile region into a same-sized image so a sheet
        // presentation does not misalign the reveal overlay on older iOS.
        let globalFrame = profileGlobalFrame == .zero
            ? window.convert(window.bounds, to: nil)
            : profileGlobalFrame
        let windowFrame = window.convert(globalFrame, from: nil)
        guard windowFrame.width > 1, windowFrame.height > 1 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = min(window.screen.scale, 1.5)
        format.opaque = false
        let image = UIGraphicsImageRenderer(
            size: windowFrame.size,
            format: format
        ).image { context in
            context.cgContext.translateBy(x: -windowFrame.minX, y: -windowFrame.minY)
            if !window.drawHierarchy(in: window.bounds, afterScreenUpdates: false) {
                window.layer.render(in: context.cgContext)
            }
        }
        return (image, windowFrame.size)
    }

    /// Delay presentation by one main-queue turn so the active profile tab
    /// finishes its update before the settings controller is created.
    private func openSettings() {
        guard !showSettings else { return }
        BeansHaptics.tap()
        homeRenderingPaused = true
        DispatchQueue.main.async {
            showSettings = true
        }
    }

    private func settingsScreen(_ screen: SettingsView) -> some View {
        screen
            .environmentObject(theme)
            .environmentObject(player)
            .environmentObject(auth)
    }




    var body: some View {
        let _ = theme.accent
        // 我的页自带导航栈：歌单行用 NavigationLink 直接推入原有歌单页，返回键是唯一关闭路径，不再经过 sheet +“完成”按钮。
        BeansNavigationStack {
            ZStack {
            if forceHomeBackdrop || !usesSharedRootBackdrop {
                // 头像入口作为主页延伸时始终沿用主页壁纸；常规“我的”页继续遵循同步开关。
                GlassBackdrop(
                    customColor: forceHomeBackdrop ? theme.customBackground : (theme.backgroundSyncAll ? theme.customBackground : nil),
                    homeMode: forceHomeBackdrop
                )
            }
            // 实例级 UITabBar 清透风格（固定全透明，无需调节）
            TabBarAppearanceConfigurator()
            // 返工：页面底色显式化（无自定义背景时才铺，避免自定义壁纸被盖住），
            // 防止深色状态栏方案把白卡下方的空白区也带翻成深色。
            if !forceHomeBackdrop && theme.customBackground == nil {
                coCardBackground
                    .ignoresSafeArea()
            }
            // 重建：唯一的一层壁纸在滚动视图之外（见 coFixedHeaderWallpaper），
            // 框顶边固定在屏幕顶边、只做中心缩放、拖动量硬上限 120pt；
            // 不再用头部 background、体外 ZStack 直接子视图、固定条三层叠加。
            if !forceHomeBackdrop {
                coFixedHeaderWallpaper
            }
            ScrollView {
                VStack(spacing: 0) {
                // 拉动恢复：头部本身不再带壁纸层（壁纸在滚动视图之外的固定层）。
                // 顶部读数器已删：放大不再走 PreferenceKey 回写链，改由下面挂在
                // 整个滚动视图上的同时识别拖动手势直接驱动；内容位移仍靠系统回弹，
                // 从头部、白卡、歌单区任何地方下拉，只要页面在顶部，系统回弹都会
                // 把内容往下带，固定壁纸层只放大、不跟着头部走，顶部就不再留黑边。
                // 头像按钮点按不受手势影响（拖动最小距离 8pt，点按不到 8pt 不触发拖动）。
                coNeteaseHeader
                // 头像界面精简：白卡（含数据行与歌单）只在我的 tab 里渲染，头像 sheet 里整张白卡都不出现——
                // 不是留一张空白卡占位，sheet 下面直接是主页延伸背景，头像界面只剩头部（头像/昵称/VIP/状态/黑白切换/设置）。
                if !forceHomeBackdrop {
                    coNeteaseMainCard
                        .padding(.top, -24)
                }
            }
            // 底部留白返工：迷你播放器约 50pt + 底栏约 57pt + 底部间距/安全区，合计约 165pt；
            // 300pt → 240pt，仍比叠层高约 75pt 余量，最后一行能完整滑出；不收到 190pt 以下（上一轮 190pt 时底部行曾被盖过）。
            .padding(.bottom, 240)
            .beansAdaptiveContentWidth()
            }
            .beansScrollIndicatorsHidden()
            // 拉动恢复：回弹改回始终可回弹（.always），不是按尺寸。
            // .basedOnSize 在我的页只有 1 条歌单、内容不满屏时直接关了
            // 回弹，是 zoom6“拉不动”的第二环：从白卡/歌单区下拉、
            // 从头部下拉（头部手势又被截获）全都拉不动。
            // .always 让内容不满屏时也能拉动，拉动本身先恢复；
            // 壁纸效果仍封顶在 120pt：超过 120pt 后固定壁纸层不再
            // 继续放大、不再继续变高，顶部黑边不会再变大。
            // 注意：这个上限封的是壁纸效果，不是系统回弹本身——
            // 系统回弹位移本身用最简单逻辑截断不了，内容本身在
            // 超过 120pt 后仍会随系统回弹往下走，但壁纸顶边固定、
            // 缩放封顶，顶部不会再留更大的黑边。
            .scrollBounceBehavior(.always, axes: .vertical)
            .coordinateSpace(name: "coProfileScroll")
            .modifier(CoMyTabScrollTopInset(enabled: !forceHomeBackdrop, topSafeArea: profileTopSafeArea))
            // 上滑读数第二路：滚动几何的内容偏移，正常滚动时确实更新，
            // 与头部 frame 上报互为备份，两路取大值（见 wallpaperScrollUp）。
            // 首帧就是静止偏移，之后不再重定，理由同 headerRestMinY。
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { _, newValue in
                if scrollRestOffset == nil { scrollRestOffset = newValue }
                scrollContentOffset = newValue
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        guard !forceHomeBackdrop else { return }
                        // 门控只在手势开始时定一次：头部在顶部才放大。
                        // profileHeaderFrame 是状态栏已在用的头部全局 frame，
                        // 静止在顶部时 minY 约 0，已下滑时 minY 为负；首帧
                        // frame 为空时 minY 为 0，同样算在顶部，不会把第一次
                        // 下拉挡住。门控定了以后，全程只看手指位移。
                        if !pullGestureActive {
                            pullGestureActive = true
                            pullGestureStartedAtTop = profileHeaderFrame.minY >= -20
                        }
                        guard pullGestureStartedAtTop else {
                            headerDragPull = 0
                            return
                        }
                        // 手指位移直接驱动：往下走多少就放大多少，封顶 120pt；
                        // 上滑、横向拖动时高度差为负，钳为 0 不放大。
                        headerDragPull = min(max(0, value.translation.height), 120)
                    }
                    .onEnded { _ in
                        pullGestureActive = false
                        pullGestureStartedAtTop = false
                        // 松手慢速平滑回静态大小：response 0.9、damping 1.0，
                        // 无弹跳感，不是原来 response 0.35 的快弹簧“啪”一下弹回去。
                        withAnimation(.spring(response: 0.9, dampingFraction: 1.0)) {
                            headerDragPull = 0
                        }
                    }
            )

            if let themeRevealSnapshot {
                BeansProfileThemeRevealOverlay(
                    snapshot: themeRevealSnapshot,
                    origin: themeRevealOrigin,
                    progress: themeRevealProgress
                )
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: BeansProfileGlobalFrameKey.self,
                    value: proxy.frame(in: .global)
                )
            }
        }
        .onPreferenceChange(BeansProfileGlobalFrameKey.self) { frame in
            profileGlobalFrame = frame
        }
        .task {
            guard !didRefreshProfileAccount else { return }
            didRefreshProfileAccount = true
            await auth.refreshAccount()
        }
        .task(id: kugouAuth.userId) { loadHiddenPlaylists() }
        // The avatar-presented profile is its own sheet, so its content must
        // receive the selected color scheme instead of only the backdrop.
        // 状态栏方案（见 profileStatusBarScheme）：浅色主题下也用深色方案，状态栏文字为白色；
        // 白卡区颜色用显式颜色（coEffective*），不被本方案带翻。
        .preferredColorScheme(profileStatusBarScheme)
        .onAppear { updateProfileStatusBarStyle() }
        .onDisappear {
            if !forceHomeBackdrop { CoProfileStatusBarStyle.restore() }
        }
        .onChange(of: themeModeRaw) { _ in updateProfileStatusBarStyle() }
        .onChange(of: isCardAtTop) { _ in updateProfileStatusBarStyle() }
        .onChange(of: profileHeaderFrame) { _ in updateProfileStatusBarStyle() }
        .onChange(of: profileHeaderWallpaper.topIsLight) { _ in updateProfileStatusBarStyle() }
        .onPreferenceChange(BeansProfileCardTopKey.self) { minY in
            isCardAtTop = minY <= 28
        }
        .onPreferenceChange(CoProfileHeaderFrameKey.self) { frame in
            profileHeaderFrame = frame
            if headerRestMinY == nil && !frame.isEmpty { headerRestMinY = frame.minY }
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
                .environmentObject(player)
                .environmentObject(auth)
                .environmentObject(theme)
                .preferredColorScheme(profileEffectiveScheme)
        }
        .sheet(isPresented: $showAvatarPicker) {
            AvatarMediaPicker { selection in
                if selection.isVideo {
                    avatarStore.saveVideo(data: selection.data, fileExtension: selection.fileExtension)
                } else {
                    avatarStore.save(data: selection.data)
                }
            }
        }
        .sheet(isPresented: $showProfileNameBackgroundPicker) {
            AvatarMediaPicker { selection in
                profileNameBackgroundStore.save(data: selection.data, fileExtension: selection.fileExtension)
            }
        }
        .sheet(isPresented: $showSettings) {
            settingsScreen(SettingsView(onClose: { showSettings = false }))
                .modifier(BeansSheetModifier(detents: [.fraction(0.62), .large], dragIndicator: true))
                .modifier(SettingsLiquidSheetPresentation())
        }
        .sheet(isPresented: $showAccountHub) {
            AccountHubSheet()
                .environmentObject(theme)
                .environmentObject(auth)
                .preferredColorScheme(profileEffectiveScheme)
        }
        .sheet(isPresented: $showFavorites) {
            CoSongListSheet(title: "我喜欢", songs: favorites.allLikedSongs)
                .environmentObject(player)
                .environmentObject(theme)
                .preferredColorScheme(profileEffectiveScheme)
        }
        .sheet(isPresented: $showTopPlayed) {
            CoSongListSheet(
                title: "常听",
                songs: player.topPlayed.map(\.song),
                subtitles: Dictionary(uniqueKeysWithValues: player.topPlayed.map { ($0.song.identityKey, "\($0.count)次") }),
                // 外面那格是总播放次数（41 次是 41 次播放，不是 41 首歌），
                // 里面列表是按次数排的歌 + 对不上的那部分，两者口径写清。
                totalPlayCount: player.playCounts.values.reduce(0, +),
                orphanPlayCount: player.orphanPlayCount,
                onClear: { player.clearTopPlayed() }
            )
                .environmentObject(player)
                .environmentObject(theme)
                .preferredColorScheme(profileEffectiveScheme)
        }
        .sheet(isPresented: $showMyPlaylists) {
            CoMyPlaylistsSheet(
                playlists: myPlaylists,
                isLoading: myPlaylistsLoading,
                hasAnyPlaylists: !myPlaylists.isEmpty,
                onRefresh: { await coLoadMyPlaylists(force: true) }
            )
                .environmentObject(player)
                .environmentObject(auth)
                .environmentObject(theme)
                .preferredColorScheme(profileEffectiveScheme)
        }
        .task(id: kugouAuth.isLoggedIn) {
            await coLoadMyPlaylists()
        }
        .onReceive(NotificationCenter.default.publisher(for: .beansKugouLoginDidUpdate)) { _ in
            Task { await coLoadMyPlaylists(force: true) }
        }
        // 我的页本身不占导航栏：顶部黑色头部直接贴顶；推入的歌单页自带标题与返回键，不受本条影响。
        .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Co 简洁我的页（本页专属，不动其他 tab）


    private var coDisplayName: String {
        if kugouAuth.isLoggedIn {
            return kugouAuth.nickname.isEmpty ? "酷狗音乐" : kugouAuth.nickname
        }
        if !customNickname.isEmpty { return customNickname }
        return "未登录"
    }

    private var coAccountCard: some View {
        Button {
            BeansHaptics.tap()
            showAccountHub = true
        } label: {
            HStack(spacing: 14) {
                BeansAvatarView(remoteURL: kugouAuth.avatarURL, size: 64, useCustom: true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(coDisplayName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.beansLabel)
                            .lineLimit(1)
                        if kugouAuth.isLoggedIn, let badge = kugouAuth.vipBadge {
                            VIPBadgeView(text: badge)
                        }
                    }
                    Text(accountStatusLine)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.beansSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.beansSecondary)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }



    private var coPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("我的歌单")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(coEffectiveLabel)
                Spacer()
            }
            if !kugouAuth.isLoggedIn {
                Button {
                    BeansHaptics.tap()
                    showAccountHub = true
                } label: {
                    Text("登录酷狗音乐后可同步云端歌单")
                        .font(.system(size: 14))
                        .foregroundStyle(coEffectiveSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                        .background(coEffectiveRowBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            } else if myPlaylistsLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if myPlaylists.isEmpty {
                Text("暂未同步到酷狗歌单，请稍后重试")
                    .font(.system(size: 14))
                    .foregroundStyle(coEffectiveSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                    .background(coEffectiveRowBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else if visiblePlaylists.isEmpty {
                Text("暂无歌单")
                    .font(.system(size: 14))
                    .foregroundStyle(coEffectiveSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                    .background(coEffectiveRowBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(visiblePlaylists) { playlist in
                        ZStack {
                            // 隐藏链接：只负责推入歌单页，本身不显示；点按走下方 Button。
                            NavigationLink(destination: PlaylistView(playlist: playlist), isActive: Binding(get: { navPlaylist?.id == playlist.id }, set: { if !$0 { navPlaylist = nil } })) {
                                EmptyView()
                            }
                            .opacity(0)
                            Button {
                                BeansHaptics.tap()
                                navPlaylist = playlist
                            } label: {
                                CoPlaylistRowLabel(playlist: playlist, label: coEffectiveLabel, secondary: coEffectiveSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        if playlist.id != visiblePlaylists.last?.id {
                            Divider().padding(.leading, 78)
                        }
                    }
                }
                .background(coEffectiveRowBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                // 歌单列表容器一圈边框：描边放在 clipShape 之后，不会被裁成半线；
                // 数值复用设置页卡片描边风格（1pt，primary 0.08，深浅主题下都可见，
                // 深色下是白 8%、浅色下是黑 8%，不自创粗黑边）。只加在列表容器上，
                // 每行不单独套框；未登录/加载中/空态占位块保持原样。
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Co 网易云风格我的页（本页专属，不动其他 tab）
    // 参考结构：wy.dwkc.cn 已记录的网易云风格我的页（只借鉴版式与信息层级，不抄素材/图标/商标/文案）
    // 顶部无“我的”大标题；头部区只留居中圆形头像、昵称旁小 VIP 徽标、状态行；
    // 数据行已移到下方白卡里（在“我的歌单”上方，不在黑色背景上）；
    // 下方主卡片用大圆角盖住头部下沿，卡片里是数据行 + 我的歌单（常用整区已删，见简便化）。
    // 沉浸：头部背景用 ignoresSafeArea 延伸进顶部安全区，黑头从屏幕顶边开始，
    // 不再是白色状态栏条 + 黑头拼接；状态栏文字颜色见 updateProfileStatusBarStyle。
    // 上一轮修复保留：插值一律单反斜杠、账号已登录第二行恒为“酷狗已登录”、底部内边距本轮改为 240pt（见 body 处算余量）。

    /// 我的 tab 固定壁纸层（重建后唯一的一层壁纸，滚动视图之外）：
    /// 放在 body 的 ZStack 里、滚动视图之前，框顶边用 ignoresSafeArea 固定在屏幕顶边，
    /// 下拉时框顶边一动不动，只有框里的图以中心锚点放大、向左右两边扩。
    /// 框高 = max(屏幕宽 + 30pt, 410pt) + 拖动量的一半（放慢后，120pt 封顶 +60pt）：
    /// 屏幕宽约等于静止时头部高 + 安全区，
    /// 410pt 下限是头部顶垫 116pt 后的新头部高约 322pt 再加约 88pt 余量，
    /// 保证在任何机型宽度下壁纸底边都压在白卡下面、不在白卡与壁纸之间留缝，
    /// 多余部分被不透明白卡盖住；框高随拖动量的一半变大，配合缩放放慢，
    /// 白卡与壁纸的重叠（-24pt）始终不变。图用 scaleEffect(中心) 后 .clipped() 裁到框里，
    /// 所以放大后图不会跑到白卡下面再露一段。无图时整张填黑，同样固定顶边、同样封顶。
    private var coFixedHeaderWallpaper: some View {
        // 框高跟着新头部高度走：头部顶部内边距 116pt 后，新头部高约
        // 322pt（116 顶垫 + 其余约 206pt），框高下限 410pt 保证在窄屏机型上
        // 底边仍压在不透明白卡之下至少约 88pt、白卡与壁纸之间无缝；宽屏机型
        // 上仍是屏幕宽 + 30pt（用户机型约 423pt，已高于下限），框高、图本身
        // 的缩放与位置都不动，图顶边仍固定在屏幕顶边，头像下移露出的只是
        // 原来被白卡盖住的那段壁纸下部，不是图被挪动或放大了。
        let base = max(UIScreen.main.bounds.width + 30, 410)
        // 放慢后：缩放 1 + 下拉量/600（120pt 封顶约 1.2 倍），与歌单页同套参数。
        let zoom = 1 + headerDragPull / 600
        return ZStack {
            if let image = profileHeaderWallpaper.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                Color.black.opacity(0.45)
            } else {
                Color.black
            }
        }
        // 框高放慢：只跟下拉量的一半走（120pt 封顶 +60pt），不再 1:1 暴涨。
        .frame(width: UIScreen.main.bounds.width, height: base + headerDragPull / 2)
        .scaleEffect(zoom, anchor: .center)
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
        // 上滑时整体往上移（移量 = 上滑量），下拉时移量为 0、顶边不动。
        // 移量只改固定层的位置，不改框高、不改缩放，相对头部/卡片的位置不变，
        // 所以卡片下面不会再露壁纸带；滑回顶部时移量回 0，一切复原。
        .offset(y: -wallpaperScrollUp)
        .allowsHitTesting(false)
    }

    private var coNeteaseHeader: some View {
        VStack(spacing: 0) {
            // 定稿分拆：顶行（黑白切换 + 设置齿轮）只在头像界面放，我的 tab 里整行不出现；
            // 头像、昵称、VIP、状态行两边都保留，见下方。
            if forceHomeBackdrop {
                HStack {
                    profileThemeToggleButton
                    Spacer()
                    Button {
                        openSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("设置")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            Button {
                BeansHaptics.tap()
                showAccountHub = true
            } label: {
                VStack(spacing: 8) {
                    BeansAvatarView(remoteURL: kugouAuth.avatarURL, size: 88, useCustom: true)
                    HStack(spacing: 6) {
                        Text(coDisplayName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                        if kugouAuth.isLoggedIn, let badge = kugouAuth.vipBadge {
                            VIPBadgeView(text: badge)
                        }
                    }
                    // “酷狗已登录”删除（2026-10-23 用户定）：我的 tab 里不再显示这行，
                    // 只在头像界面（forceHomeBackdrop）条件保留——头部组件两边共用，
                    // 这里用条件保留，不是两边一起删。
                    // 位置补偿：删掉这行后头部会矮约 25pt（13pt 字约 17pt 行高 + 8pt
                    // 间距），我的 tab 底部内边距从 48pt 加到 73pt 补回来，头部总高
                    // 不变，头像中心仍在第二张截图约 267/1000、白卡顶部仍在约 434/1000；
                    // 头像尺寸、头像与昵称间距都不动。头像界面底部内边距仍是 36pt 不动。
                    if forceHomeBackdrop {
                        Text(accountStatusLine)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            // 数据行已不在黑头里：见下方白卡里的 coNeteaseStatsInCard（只在我的 tab 里渲染，头像 sheet 里整张白卡都不出现）。
            // 重建：我的 tab 的壁纸不在这里、也不在任何 background 里，唯一的一层在 body 的滚动视图之外
            // （见 coFixedHeaderWallpaper，框顶边固定在屏幕顶边）；这里只留头像 sheet 的静态壁纸和状态栏用的 frame 上报。
            // 我的页整体下调：头部底部 36pt → 48pt（只在我的 tab 里加，头像 sheet 仍 36pt），
            // 删“酷狗已登录”后补到 73pt（见上面删除处注释），头部总高不变；
            // 卡片 -24pt 重叠后仍有 24pt 头部可见（原来 12pt），白卡往下移、壁纸可见区反而更大——壁纸没调小，是调大了。
            .padding(.bottom, forceHomeBackdrop ? 36 : 73)
        }
        // 我的页头像下移（2026-10-23 第二张截图定稿）：第一张截图里头像中心
        // 约 131/1000、白卡顶部约 303/1000，头像快挨着灵动岛/状态栏；第二张
        // 目标里头像中心约 267/1000、白卡顶部约 434/1000，差值约 136/1000
        // 与 131/1000，换算到 852pt 高的屏幕约 115pt。做法只改这一处：我的页
        // 头部顶部内边距从 44pt 加到 159pt（44 + 115），头像、昵称、VIP、
        // 状态行、白卡全部跟着整体往下 115pt，头像尺寸、头像与昵称间距、
        // 壁纸图本身都不动；头像界面（forceHomeBackdrop）仍有顶行，顶部
        // 间距不动，不跟着下移。
        // 2026-10-24 真机返工：159pt 版我的页比用户要的目标（图三）整体低了
        // 约 46-50/1000（头像中心 281→231、白卡顶边 449→403，852pt 屏约 40-43pt），
        // 只改这一处：159pt → 116pt（159 - 43），头像、昵称、VIP、白卡 -24pt
        // 重叠、底部 240pt、固定壁纸层、下拉放大 120pt 封顶、上滑跟走一律不动；
        // 头部总高约从 365pt 变成约 322pt，仍低于固定壁纸框高下限 410pt，
        // 壁纸底边仍压在白卡之下，不留新黑边或壁纸条；头像 sheet 分支仍是 0，不动。
        .padding(.top, forceHomeBackdrop ? 0 : 116)
        .frame(maxWidth: .infinity)
        .background {
            // 重建：我的 tab 的壁纸不在 background 里（background 溢出会被裁掉，上一轮黑带的根源），
            // 唯一的一层在 body 的滚动视图之外（见 coFixedHeaderWallpaper，框顶边固定在屏幕顶边）；
            // 这里只留头像 sheet 的静态壁纸和状态栏用的 frame 上报（只上报、不画图）。
            ZStack {
                if forceHomeBackdrop {
                    if let image = profileHeaderWallpaper.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                        Color.black.opacity(0.45)
                    } else {
                        Color.black
                    }
                }
                GeometryReader { geo in
                    Color.clear.preference(key: CoProfileHeaderFrameKey.self, value: geo.frame(in: .global))
                }
            }
        }
    }

    private func coNeteaseStatButton(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(coEffectiveLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(coEffectiveSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 数据行（白卡版）：从黑头移到白卡里、“我的歌单”标题上方，跳转功能与黑头版一致。
    /// 颜色改回深色（数字 beansLabel、标签 beansSecondary），白卡上不再用白字。
    private var coNeteaseStatsInCard: some View {
        HStack(spacing: 0) {
            coNeteaseStatButton(title: "我喜欢", value: "\(favorites.allLikedSongs.count)") { showFavorites = true }
            // 歌单数按总数算（含已隐藏，2026-10-23 用户拍板）：歌单是几个就是几个，
            // 没必要隐藏了就不显示实体数量；列表本身仍按隐藏逻辑显示，隐藏的歌单
            // 仍不在列表里、仍可在设置里恢复，只改数据格这个数，不改列表。
            coNeteaseStatButton(title: "歌单", value: "\(myPlaylists.count)") {
                // 2026-10-24 歌单弹窗：点“歌单”格出歌单列表弹窗（同我喜欢/历史/常听的 sheet 款式），
                // 不再只滑到下方歌单区（滑到位置就感觉点不动）；未登录时仍进登录，门不变。
                if !kugouAuth.isLoggedIn { showAccountHub = true } else { showMyPlaylists = true }
            }
            coNeteaseStatButton(title: "历史", value: "\(player.history.count)") { showHistory = true }
            coNeteaseStatButton(title: "常听", value: "\(player.playCounts.values.reduce(0, +))") { showTopPlayed = true }
        }
    }

    private var coNeteaseMainCard: some View {
        // 头像界面精简：本卡片（含数据行与歌单）只在我的 tab 里渲染，body 里已用 if !forceHomeBackdrop 挡住，
        // 头像 sheet 里不会出现数据行、歌单、空白卡三者中的任何一个；数据行代码本身保留给我的页用。
        // 数据行“歌单”点按出歌单列表弹窗，未登录时进登录（见 coNeteaseStatsInCard）。
        VStack(alignment: .leading, spacing: 20) {
            coNeteaseStatsInCard
            if !forceHomeBackdrop {
                coPlaylistsSection
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 28, style: .continuous)
                .fill(coCardBackground)
        )
        .background {
            // 上报白卡顶部全局位置，供状态栏浅/深色切换用（见 BeansProfileCardTopKey）。
            GeometryReader { proxy in
                Color.clear.preference(key: BeansProfileCardTopKey.self, value: proxy.frame(in: .global).minY)
            }
        }
    }

    // MARK: - 我的页隐藏歌单（旧线 1.8.5 移植，只藏显示、不删歌单）
    private var hiddenPlaylistIds: Set<Int> { Set(hiddenPlaylistEntries.map(\.id)) }
    private var visiblePlaylists: [Playlist] { myPlaylists.filter { !hiddenPlaylistIds.contains($0.id) } }
    private func loadHiddenPlaylists() {
        hiddenPlaylistEntries = CoHiddenPlaylists.load(userId: kugouAuth.userId)
    }

    private func coLoadMyPlaylists(force: Bool = false) async {
        guard kugouAuth.isLoggedIn else {
            myPlaylists = []
            myPlaylistsLoading = false
            return
        }
        let cache = SyncedPlaylistCache.shared
        if myPlaylists.isEmpty, let cached = cache.cachedPlaylists(source: .kugou, accountID: kugouAuth.userId) {
            myPlaylists = cached.playlists
        }
        if !force, !myPlaylists.isEmpty { return }
        myPlaylistsLoading = myPlaylists.isEmpty
        do {
            let list = try await KugouMusicAPI.shared.userPlaylists()
            if !list.isEmpty {
                myPlaylists = list
                cache.savePlaylists(list, source: .kugou, accountID: kugouAuth.userId)
            }
        } catch {
            BeansLogger.shared.log("酷狗歌单同步失败：\(error.localizedDescription)", level: .error)
            if myPlaylists.isEmpty { myPlaylists = [] }
        }
        myPlaylistsLoading = false
    }


    private var compactIdentityButton: some View {
        let _ = publicIDRevision
        let isExclusive = usesExclusiveIDBadge
        return Button {
            UIPasteboard.general.string = DeviceIdentity.publicID
            BeansHaptics.tap()
            ToastCenter.shared.show("用户 ID 已复制")
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isExclusive ? "crown.fill" : "number.circle.fill")
                    .font(.system(size: 9, weight: .bold))
                Text(isExclusive ? "专属 ID · \(DeviceIdentity.publicID)" : "ID · \(DeviceIdentity.publicID)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(isExclusive ? Color(red: 1.0, green: 0.89, blue: 0.52) : Color(red: 0.30, green: 0.34, blue: 0.40))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                if isExclusive {
                    BeansExclusiveIDBadgeSurface(style: exclusiveBadgeStyle)
                } else {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.82), Color(red: 0.62, green: 0.66, blue: 0.73).opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Capsule().strokeBorder(Color.white.opacity(0.72), lineWidth: 0.7)
                        }
                        .shadow(color: Color.black.opacity(0.10), radius: 4, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("用户 ID \(DeviceIdentity.publicID)，点击复制")
    }
    private func profileStat(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.beansAmber)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(BeansFont.appFont(11, .medium))
                    .foregroundStyle(Color.beansSecondary)
                Text(value)
                    .font(BeansFont.appFont(15, .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var userCard: some View {
        VStack(spacing: 16) {
            Button {
                BeansHaptics.tap()
                // 统一账号面板：酷狗音乐登录
                showAccountHub = true
            } label: {
                HStack(spacing: 14) {
                    // 头像：主题渐变描边环
                    BeansAvatarView(remoteURL: auth.user?.avatarURL, size: 64, useCustom: true)
                    .background(Color.beansGlassFill, in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(auth.user?.nickname ?? (auth.isLoggedIn ? (isEnglish ? "Kugou Music Logged In" : "酷狗音乐已登录") : (isEnglish ? "Guest · Tap to Sign In" : "免登录 · 点击登录")))
                                .font(BeansFont.appFont(20, .bold))
                                .foregroundStyle(Color.beansLabel)
                                .lineLimit(1)
                            if auth.isLoggedIn, let badge = auth.user?.vipBadge {
                                VIPBadgeView(text: badge)
                            }
                        }
                        Text(accountStatusLine)
                            .font(BeansFont.appFont(12, .regular, .monospaced))
                            .foregroundStyle(Color.beansComment)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.beansComment.opacity(0.7))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if kugouAuth.isLoggedIn {
                platformStatusRow
            }
        }
        .padding(16)
        .background {
                        BeansGlass(shape: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .beansCardShadow(radius: 10, y: 4)
    }

    /// 酷狗登录状态展示
    private var platformStatusRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            if kugouAuth.isLoggedIn {
                platformChip(imageName: "BrandKugou", name: "酷狗音乐", status: kugouAuth.nickname.isEmpty ? "已登录" : kugouAuth.nickname, badge: kugouAuth.vipBadge)
            }
        }
        .padding(.top, 2)
    }

    private func platformChip(imageName: String, name: String, status: String, badge: String?) -> some View {
        HStack(spacing: 6) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
            Text(name)
                .font(BeansFont.appFont(12, .semibold))
                .foregroundStyle(Color.beansLabel)
            Text(status)
                .font(BeansFont.appFont(11))
                .foregroundStyle(Color.beansComment)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if let badge {
                VIPBadgeView(text: badge)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background { BeansSurface(shape: Capsule()) }
    }



    /// 壁纸格子：点击应用为当前背景；使用中的壁纸显示主题色边框+勾选；右上角删除
    private func wallpaperCell(path: String) -> some View {
        let isActive = path == theme.backgroundImagePath
        return ZStack(alignment: .topTrailing) {
            Button {
                BeansHaptics.tap()
                theme.applyWallpaper(at: path)
            } label: {
                Group {
                    if let img = BeansImageFileCache.image(at: path) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.beansGlassFill
                    }
                }
                .frame(height: 108)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.beansAmber)
                            .background { BeansSurface(shape: Circle()) }
                            .padding(5)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                BeansHaptics.medium()
                theme.deleteWallpaper(at: path)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.beansComment)
                    .frame(width: 28, height: 28)
                    .background { BeansSurface(shape: Circle()) }
                    .clipShape(Circle())
                    .contentShape(Circle())
                    .padding(6)
            }
            .buttonStyle(.plain)
            .zIndex(2)
        }
    }

    /// 功能宫格：常用功能统一整合排版
    private var featuresGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "我的功能")
            VStack(spacing: 12) {
                featureCell(icon: "clock.arrow.circlepath", title: "播放历史", subtitle: String(format: NSLocalizedString("最近播放 %d 首", comment: ""), player.history.count)) {
                    showHistory = true
                }
                featureCell(icon: hasVisibleAccountLogin ? "checkmark.seal.fill" : "globe", title: isEnglish ? "Accounts and Sign-in" : "账号与登录", subtitle: hasVisibleAccountLogin ? accountStatusLine : (isEnglish ? "Sign in to \(displayPlatformSummary)" : "登录 \(displayPlatformSummary)")) {
                    BeansHaptics.tap()
                    showAccountHub = true
                }
            }
        }
    }

    private func featureCell(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.beansAmber)
                    .frame(width: 34, height: 34)
                    .background(Color.beansGlassFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                        .font(BeansFont.appFont(14, .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text(subtitle)
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background {
                                BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.97))
    }

}

private extension ProfileView {
    var userIdentityCard: some View {
        let isDeveloper = DeviceIdentity.isDeveloperInstallation
        return Button {
            UIPasteboard.general.string = DeviceIdentity.publicID
            BeansHaptics.tap()
            ToastCenter.shared.show("用户 ID 已复制")
        } label: {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 9) {
                    Image(systemName: isDeveloper ? "crown.fill" : "number.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isDeveloper ? Color.white : Color.beansAmber)
                        .frame(width: 30, height: 30)
                        .background {
                            if isDeveloper {
                                Circle().fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.98, green: 0.33, blue: 0.57), Color(red: 0.34, green: 0.29, blue: 0.96)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            } else {
                                Circle().fill(Color.beansGlassFill)
                            }
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isDeveloper ? "Beans Creator" : "用户 ID")
                            .font(BeansFont.appFont(14, .semibold))
                            .foregroundStyle(Color.beansLabel)
                        Text(isDeveloper ? "专属开发者铭牌" : "绑定当前设备，永久保留")
                            .font(BeansFont.appFont(11))
                            .foregroundStyle(Color.beansComment)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isDeveloper ? Color.white.opacity(0.86) : Color.beansComment)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if isDeveloper {
                        Text(DeviceIdentity.publicID)
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.98, green: 0.42, blue: 0.67), Color(red: 0.42, green: 0.48, blue: 1.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .monospacedDigit()
                    } else {
                        Text(DeviceIdentity.publicID)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.beansLabel)
                            .monospacedDigit()
                    }
                    if isDeveloper {
                        Text("5201314")
                            .font(BeansFont.appFont(10, .bold))
                            .foregroundStyle(Color.beansLabel.opacity(0.7))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.16), in: Capsule())
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(15)
            .background {
                if isDeveloper {
                    ZStack {
                        BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous), forceLiquid: true)
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.95, green: 0.25, blue: 0.55).opacity(0.12),
                                        Color(red: 0.26, green: 0.35, blue: 0.98).opacity(0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.55), Color.white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                } else {
                    BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.98))
        .accessibilityLabel("用户 ID \(DeviceIdentity.publicID)，点击复制")
    }
}

// MARK: - 交流群二维码

// MARK: - 统一账号登录面板（酷狗音乐）

/// 我的页“我喜欢 / 常听”共用歌曲列表：点行即播放并自动关闭，关 sheet 只靠下滑，不再另设“完成”按钮。
/// 歌单列表弹窗（2026-10-24，只做歌单弹窗+新建，我的页其他地方不动）：
/// 点数据行“歌单”格出本弹窗，款式同我喜欢/历史/常听的 sheet（自带 BeansNavigationStack、
/// inline 标题、系统返回键）；列表口径是全部歌单（myPlaylists，不用隐藏逻辑，
/// 歌单是几个就是几个，下方歌单区的隐藏逻辑与设置恢复不受影响）；每条行点按用
/// NavigationLink 推入原有 PlaylistView，是真歌单页，
/// 不是假详情；返回键回到本弹窗列表、再下滑关闭回我的页。
/// 新建歌单走真实酷狗接口 KugouMusicAPI.createPlaylist（不是本地歌单），建完强制刷新
/// 我的歌单列表；新建的歌单先本地补进本弹窗列表（防服务端刷新延迟），点进去也是真歌单页。
/// 歌单行共用行 UI：下方歌单区与歌单弹窗各写各的行是重复，抽成一个只负责
/// 行内布局的组件，颜色由调用方传（下方行用我的页显式色、弹窗行用系统色），
/// 行外是 Button 还是 NavigationLink、背景与分隔线仍由调用方定，行为不变。
private struct CoPlaylistRowLabel: View {
    let playlist: Playlist
    let label: Color
    let secondary: Color
    var body: some View {
        HStack(spacing: 12) {
            CoverImage(url: playlist.coverURL, size: 52, cornerRadius: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(.system(size: 16))
                    .foregroundStyle(label)
                    .lineLimit(1)
                Text(beansSongCountText(playlist.trackCount))
                    .font(.system(size: 13))
                    .foregroundStyle(secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// 歌单弹窗的图标+文字空状态（未同步/暂无歌单两处共用，文案不同而已）。
private struct CoPlaylistEmptyState: View {
    let text: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.system(size: 28))
                .foregroundStyle(Color.beansSecondary)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Color.beansSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CoMyPlaylistsSheet: View {
    let playlists: [Playlist]
    let isLoading: Bool
    let hasAnyPlaylists: Bool
    var onRefresh: () async -> Void

    @State private var displayed: [Playlist] = []
    @State private var showCreatePrompt = false
    @State private var newName = ""
    @State private var isCreating = false
    @State private var createError: String? = nil
    @State private var showCreateError = false

    var body: some View {
        BeansNavigationStack {
            Group {
                if isLoading && displayed.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("正在同步歌单…")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !hasAnyPlaylists {
                    CoPlaylistEmptyState(text: "暂未同步到酷狗歌单，请稍后重试")
                } else if displayed.isEmpty {
                    CoPlaylistEmptyState(text: "暂无歌单")
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(displayed) { playlist in
                                NavigationLink(destination: PlaylistView(playlist: playlist)) {
                                    CoPlaylistRowLabel(playlist: playlist, label: Color.beansLabel, secondary: Color.beansSecondary)
                                }
                                .buttonStyle(.plain)
                                if playlist.id != displayed.last?.id {
                                    Divider().padding(.leading, 78)
                                }
                            }
                        }
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("我的歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("新建") {
                        newName = ""
                        showCreatePrompt = true
                    }
                    .disabled(isCreating)
                }
            }
            .alert("新建歌单", isPresented: $showCreatePrompt) {
                TextField("歌单名称", text: $newName)
                Button("创建") { Task { await createPlaylist() } }
                Button("取消", role: .cancel) {}
            } message: {
                Text("新建的歌单会同步到酷狗音乐，创建后会出现在列表里。")
            }
            .alert("新建歌单失败", isPresented: $showCreateError) {
                Button("确定", role: .cancel) { createError = nil }
            } message: {
                Text(createError ?? "请稍后重试")
            }
            .onAppear { if displayed.isEmpty { displayed = playlists } }
            .onChange(of: playlists) { newValue in
                // 合并而非直接覆盖：新建歌单先本地补进列表、再强制刷新，服务端刷新若还没
                // 带上新建的那条，直接覆盖会把新建的歌单从弹窗里抹掉；保留父列表里没有的
                // 本地项（即刚建的那条），等服务端带上它后自然去重。
                let extra = displayed.filter { item in !newValue.contains(where: { $0.id == item.id }) }
                displayed = newValue + extra
            }
            .overlay(alignment: .bottom) {
                if isCreating {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("正在创建歌单…")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.beansSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: Capsule())
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private func createPlaylist() async {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            createError = "歌单名称不能为空"
            showCreateError = true
            return
        }
        isCreating = true
        defer { isCreating = false }
        do {
            let created = try await KugouMusicAPI.shared.createPlaylist(name: name)
            if !displayed.contains(where: { $0.id == created.id }) {
                displayed.append(created)
            }
            newName = ""
            await onRefresh()
            ToastCenter.shared.show("已创建")
        } catch {
            createError = error.localizedDescription
            showCreateError = true
        }
    }
}

struct CoSongListSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss
    let title: String
    let songs: [Song]
    var subtitles: [String: String] = [:]
    /// 常听详情专用：外面那格是总播放次数（不是歌数），里面列表是按次数排的歌。
    /// orphanPlayCount 是有计数、但歌名记录已对不上的那部分，要诚实显示，
    /// 不能因为它没有歌名就让整页空白。
    var totalPlayCount: Int? = nil
    var orphanPlayCount: Int = 0
    /// 常听详情专用清除：只有常听 sheet 传它（“我喜欢”不传，表现不变）。
    /// 清除入口放在详情页顶部工具栏，不放在我的页数据格上（点数据格是进详情页，
    /// 不要把进详情和清除混成一个动作）。
    var onClear: (() -> Void)? = nil
    @State private var showClearConfirm = false

    var body: some View {
        // 常听 sheet 要读实时数据：清除后 playCounts 一变，详情页本身就要
        // 立刻变回空状态，不能等父视图重传 songs（父视图不一定重算）。
        // 所以传了 onClear 的 sheet 用 player 的实时 topPlayed/计数，不用传入的快照。
        let displaySongs = onClear == nil ? songs : player.topPlayed.map(\.song)
        let displaySubtitles = onClear == nil ? subtitles : Dictionary(uniqueKeysWithValues: player.topPlayed.map { ($0.song.identityKey, "\($0.count)次") })
        let displayTotal = onClear == nil ? totalPlayCount : player.playCounts.values.reduce(0, +)
        let displayOrphan = onClear == nil ? orphanPlayCount : player.orphanPlayCount
        return BeansNavigationStack {
            Group {
                if displaySongs.isEmpty && displayOrphan == 0 {
                    VStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.beansSecondary)
                        Text("这里还没有歌曲")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.beansSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if displaySongs.isEmpty {
                    // 外面有次数、里面没有能显示的歌名时：不要留一个“这里还没有歌曲”
                    // 就打发掉——总次数是真的，把有计数、无歌名的那部分写出来。
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.beansSecondary)
                        if let total = displayTotal {
                            Text("共 \(total) 次播放")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.beansLabel)
                        }
                        Text("其中 \(displayOrphan) 次的歌名记录已不在（历史被清空或旧记录无法对应），没有编一首假歌；新播放的歌会从这里开始出现。")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.beansSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(displaySongs, id: \.identityKey) { song in
                            Button {
                                if let index = displaySongs.firstIndex(where: { $0.identityKey == song.identityKey }) {
                                    player.play(songs: displaySongs, startAt: index)
                                }
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    CoverImage(url: song.coverURL, size: 44, cornerRadius: 8)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(song.name)
                                            .font(.system(size: 16))
                                            .foregroundStyle(Color.beansLabel)
                                            .lineLimit(1)
                                        Text([song.artists, displaySubtitles[song.identityKey]].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.beansSecondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 8)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        // 有歌名、也有对不上的计数时：下面补一行“其他已播放”，
                        // 不点按、不编歌名，让外面那个总数和里面列表对得上。
                        if displayOrphan > 0 {
                            HStack(spacing: 12) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.beansSecondary)
                                    .frame(width: 44, height: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("其他已播放歌曲")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.beansLabel)
                                        .lineLimit(1)
                                    Text("\(displayOrphan)次 · 歌名记录已不在")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.beansSecondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 8)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 常听清除入口（只在传了 onClear 的常听 sheet 里出现）：
                // 放在详情页顶部工具栏，不放在我的页数据格上。
                if onClear != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("清除", role: .destructive) { showClearConfirm = true }
                    }
                }
            }
            .alert("清除常听记录？", isPresented: $showClearConfirm) {
                Button("清除", role: .destructive) { onClear?() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将清除全部常听播放次数，此操作不可恢复；历史、收藏、歌单不受影响。")
            }
            // 关闭路径只剩下滑关闭：点行即播后自动关闭，不再另设“完成”按钮。
        }
    }
}

struct AccountHubSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @ObservedObject private var kugouAuth = KugouMusicAuth.shared
    @ObservedObject private var platformPrefs = PlatformPreferenceStore.shared
    @AppStorage("beans.language") private var languageRaw = AppLanguage.chinese.rawValue
    @Environment(\.dismiss) private var dismiss

    @State private var showKugouLogin = false
    @State private var confirmKugouLogout = false

    private var isEnglish: Bool { languageRaw == AppLanguage.english.rawValue }
    private var displayPlatformSummary: String {
        isEnglish ? "Kugou Music" : "酷狗音乐"
    }

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "账号")
                        kugouCard
                    }
                    .padding(16)
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("账号登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showKugouLogin) {
            KugouLoginSheet()
                .environmentObject(theme)
        }
        .confirmationDialog("退出酷狗音乐？", isPresented: $confirmKugouLogout, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) {
                kugouAuth.logout()
                WebLoginDataCleaner.clearKugou()
                ToastCenter.shared.show("已退出酷狗音乐")
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var kugouCard: some View {
        Button {
            BeansHaptics.tap()
            if kugouAuth.isLoggedIn { confirmKugouLogout = true } else { showKugouLogin = true }
        } label: {
            HStack(spacing: 14) {
                Image("BrandKugou")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color(red: 0.08, green: 0.43, blue: 1.0).opacity(0.22), radius: 10, y: 4)
                VStack(alignment: .leading, spacing: 3) {
                    Text("酷狗音乐")
                        .font(BeansFont.appFont(15, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    HStack(spacing: 6) {
                        Group {
                            if kugouAuth.isLoggedIn {
                                Text(kugouAuth.nickname.isEmpty ? NSLocalizedString("已登录", comment: "") : kugouAuth.nickname)
                            } else {
                                Text(LocalizedStringKey("未登录 · App 扫码同步歌单"))
                            }
                        }
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        if kugouAuth.isLoggedIn, let badge = kugouAuth.vipBadge {
                            VIPBadgeView(text: badge)
                        }
                    }
                }
                Spacer()
                Text(kugouAuth.isLoggedIn ? "退出" : "登录")
                    .font(BeansFont.appFont(13, .medium))
                    .foregroundStyle(kugouAuth.isLoggedIn ? Color.red : Color.beansAmber)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background { BeansSurface(shape: Capsule()) }
            }
            .padding(14)
            .background {
                BeansGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.97))
    }
}

// MARK: - 设置页（外观 + 歌词翻译，从「我的」右上角齿轮进入）

struct SettingsView: View {
    var onClose: (() -> Void)? = nil
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("beans.themeMode") private var themeModeRaw = BeansThemeMode.system.rawValue
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    @AppStorage("beans.disableLiquidGlass") private var disableLiquidGlass = false
    @AppStorage("beans.language") private var languageRaw = AppLanguage.chinese.rawValue
    @AppStorage("beans.globalFloatingEffect") private var globalFloatingEffectRaw = BeansGlobalFloatingEffect.off.rawValue
    @AppStorage("beans.globalFloatingDensity") private var globalFloatingDensity = 1.0
    @AppStorage("beans.globalFloatingSize") private var globalFloatingSize = 1.0
    @AppStorage("beans.globalFloatingSpeed") private var globalFloatingSpeed = 1.0
    @AppStorage("beans.globalFloatingText") private var globalFloatingText = "❄️"
    @AppStorage("beans.globalFloatingRotation") private var globalFloatingRotation = 0.0
    @AppStorage("beans.globalFloatingSkew") private var globalFloatingSkew = 0.0
    @AppStorage("beans.globalFloatingImageData") private var globalFloatingImageData = ""
    @AppStorage("beans.homeWallpaperBlur") private var homeWallpaperBlur = 0.0
    /// 底栏是否显示文字（关闭后只显示图标）
    @AppStorage("beans.tabLabelsVisible") private var tabLabelsVisible = true
    @AppStorage("beans.tabIconStyle") private var tabIconStyleRaw = BeansTabIconStyle.sfSymbols.rawValue
    @AppStorage("beans.legacyTabCornerRadius") private var legacyTabCornerRadius = 32.0
    @AppStorage("beans.legacyTabWidth") private var legacyTabWidth = 356.0
    @AppStorage("beans.legacyTabOffsetX") private var legacyTabOffsetX = 0.0
    @AppStorage("beans.legacyTabOffsetY") private var legacyTabOffsetY = 0.0
    /// 第三方音源播放会员歌成功时提醒，默认开启
    @AppStorage("beans.showThirdPartyVIPNotice") private var showThirdPartyVIPNotice = true
    @AppStorage("beans.showSongVIPBadge") private var showSongVIPBadge = true
    @AppStorage("beans.audio.mixothers.v1") private var mixesWithOthers = false
    @AppStorage("beans.nowPlaying.enabled.v1") private var nowPlayingEnabled = true
    @AppStorage("beans.audioQuality") private var playbackAudioQualityRaw = BeansAudioQuality.hires.rawValue
    @AppStorage(PlayerManager.playbackSourcePreferenceKey) private var playbackSourcePreferenceRaw = PlaybackSourcePreference.automatic.rawValue
    @AppStorage(NetworkAudioQuality.connectionAwareKey) private var connectionAwareQuality = false
    @AppStorage(NetworkAudioQuality.wifiOfficialKey) private var wifiPlaybackAudioQualityRaw = BeansAudioQuality.hires.rawValue
    @AppStorage(NetworkAudioQuality.cellularOfficialKey) private var cellularPlaybackAudioQualityRaw = BeansAudioQuality.higher.rawValue
    @AppStorage(BeansHaptics.enabledKey) private var hapticsEnabled = true
    @AppStorage("beans.playback.autoResumeLast") private var autoResumeLastPlayback = false
    @AppStorage("beans.labelColorHex") private var labelColorHex = ""
    @AppStorage("beans.homeGreetingText") private var homeGreetingText = ""
    @AppStorage("beans.homeGreetingSize") private var homeGreetingSize = 30.0
    @AppStorage("beans.homeGreetingHeight") private var homeGreetingHeight = 0.0
    @AppStorage("beans.homeGreetingColorHex") private var homeGreetingColorHex = ""
    @AppStorage("beans.homeGreetingLine1Size") private var homeGreetingLine1Size = 0.0
    @AppStorage("beans.homeGreetingLine2Size") private var homeGreetingLine2Size = 0.0
    @AppStorage("beans.homeGreetingLine3Size") private var homeGreetingLine3Size = 0.0
    @AppStorage("beans.homeGreetingLine1ColorHex") private var homeGreetingLine1ColorHex = ""
    @AppStorage("beans.homeGreetingLine2ColorHex") private var homeGreetingLine2ColorHex = ""
    @AppStorage("beans.homeGreetingLine3ColorHex") private var homeGreetingLine3ColorHex = ""
    @AppStorage("beans.homeGreetingLine1OffsetY") private var homeGreetingLine1OffsetY = 0.0
    @AppStorage("beans.homeGreetingLine2OffsetY") private var homeGreetingLine2OffsetY = 0.0
    @AppStorage("beans.homeGreetingLine3OffsetY") private var homeGreetingLine3OffsetY = 0.0
    @AppStorage("beans.homeGreetingLine1GradientStartHex") private var homeGreetingLine1GradientStartHex = ""
    @AppStorage("beans.homeGreetingLine2GradientStartHex") private var homeGreetingLine2GradientStartHex = ""
    @AppStorage("beans.homeGreetingLine3GradientStartHex") private var homeGreetingLine3GradientStartHex = ""
    @AppStorage("beans.homeGreetingLine1GradientEndHex") private var homeGreetingLine1GradientEndHex = ""
    @AppStorage("beans.homeGreetingLine2GradientEndHex") private var homeGreetingLine2GradientEndHex = ""
    @AppStorage("beans.homeGreetingLine3GradientEndHex") private var homeGreetingLine3GradientEndHex = ""
    @AppStorage("beans.homeGreetingGlowEnabled") private var homeGreetingGlowEnabled = false
    @AppStorage("beans.homeGreetingGlowIntensity") private var homeGreetingGlowIntensity = 0.45
    @AppStorage("beans.homeGreetingUnderline") private var homeGreetingUnderline = false
    @AppStorage("beans.homeGreetingGradient") private var homeGreetingGradient = false
    @AppStorage("beans.homeGreetingGradientStartHex") private var homeGreetingGradientStartHex = ""
    @AppStorage("beans.homeGreetingGradientEndHex") private var homeGreetingGradientEndHex = ""
    @AppStorage("beans.pauseHomeRendering") private var homeRenderingPaused = false
    @AppStorage("beans.homeHeaderHideSort") private var homeHeaderHideSort = false
    @AppStorage("beans.home.dailySongsListStyle") private var dailySongsListStyle = false
    @ObservedObject private var equalizer = BeansEqualizer.shared
    @ObservedObject private var platformPrefs = PlatformPreferenceStore.shared
    @ObservedObject private var kugouAuth = KugouMusicAuth.shared

    @State private var appearanceExpanded = false
    @State private var appearanceDetailsExpanded = false
    // 设置里隐藏歌单开关（2026-10-24 用户拍板：只留设置里这一处，我的页长按已删）。
    @State private var hiddenPlaylistsExpanded = false
    @State private var settingsCachedPlaylists: [Playlist] = []
    @State private var settingsCurrentHidden: [(id: Int, name: String)] = []
    @State private var settingsOtherHidden: [(userId: String, entries: [(id: Int, name: String)])] = []
    @State private var playbackExpanded = false
    @State private var audioQualityExpanded = false
    @State private var showWallpaperPicker = false
    @State private var showProfileHeaderWallpaperPicker = false
    // 选图后先裁切、不直接存：有值时弹裁切页，点“完成”才存、点“取消”不存旧图不动。
    @State private var pendingHeaderWallpaperCropImage: UIImage?
    // 选图格式解不出来时不要静默退出：弹提示、留在设置页、旧壁纸不动。
    @State private var showWallpaperFormatError = false
    @ObservedObject private var profileHeaderWallpaper = CoProfileHeaderWallpaper.shared
    /// 更新日志
    @State private var showChangelog = false
    @State private var backupDoc: BackupDocument?
    @State private var showExportBackup = false
    @State private var showRestorePicker = false
    @State private var pendingRestore: [String: Any]?
    @State private var showRestoreConfirm = false
    @State private var showEqualizer = false
    @State private var backupExpanded = false
    @State private var backupIncludeAccounts = false
    @State private var backupIncludeWallpapers = false
    @State private var backupMessage: String?
    @State private var clearingImageCache = false
    @State private var showAccountHub = false
    @State private var disclaimerExpanded = false
    @State private var showFloatingImagePicker = false
    @State private var showTabVisibilitySettings = false
    @State private var settingsSearchText = ""
    @State private var settingsContentReady = false
    @State private var runtimeEnvironmentExpanded = false
    @AppStorage(BeansLockScreenArtwork.enabledKey) private var lockScreenImmersiveArtworkEnabled = true
    @AppStorage(BeansImmersiveDetailHeader.enabledKey) private var immersiveDetailEnabled = true

    private var themeMode: BeansThemeMode {
        BeansThemeMode(rawValue: themeModeRaw) ?? .system
    }

    /// 深色模式开关（2026-10-23 用户定：设置页外观区直达入口）：复用已有存储键
    /// beans.themeMode，不新发明键。开 = 深色，关 = 浅色；跟随系统仍走下方主题模式
    /// 三段选择（跟随系统/浅色/深色），开关只反映“当前是否显式深色”。

    private var isNativeClean: Bool {
        BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    private var usesCustomWallpaper: Bool {
        theme.backgroundSyncAll && theme.customBackgroundImage(for: colorScheme) != nil
    }

    /// iOS/iPadOS 26 and earlier can tear down a large full-screen SwiftUI tree
    /// while its presenting tab is being recomputed.  Present a stable shell
    /// first, then attach the existing settings content on the next run loop.
    private var defersSettingsContentForCompatibility: Bool {
        if #available(iOS 27, *) { return false }
        return true
    }

    private func settingsMatches(_ terms: String...) -> Bool {
        let query = settingsSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return terms.joined(separator: " ").localizedCaseInsensitiveContains(query)
    }

    @ViewBuilder
    private func liquidQualityOptionBackground(selected: Bool) -> some View {
        ZStack {
            BeansGlass(shape: Capsule())
            if selected {
                Capsule()
                    .fill(Color.beansAmber.opacity(0.16))
            }
        }
    }

    private var playbackAudioQualitySelection: Binding<BeansAudioQuality> {
        Binding(
            get: { BeansAudioQuality(rawValue: playbackAudioQualityRaw) ?? .hires },
            set: { playbackAudioQualityRaw = $0.rawValue }
        )
    }

    private var wifiPlaybackAudioQualitySelection: Binding<BeansAudioQuality> {
        Binding(
            get: { BeansAudioQuality(rawValue: wifiPlaybackAudioQualityRaw) ?? .hires },
            set: { wifiPlaybackAudioQualityRaw = $0.rawValue }
        )
    }

    private var cellularPlaybackAudioQualitySelection: Binding<BeansAudioQuality> {
        Binding(
            get: { BeansAudioQuality(rawValue: cellularPlaybackAudioQualityRaw) ?? .higher },
            set: { cellularPlaybackAudioQualityRaw = $0.rawValue }
        )
    }


    private var playbackQualitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: "waveform")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.beansAmber)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(beansLocalized("播放音质", "Playback quality"))
                        .font(BeansFont.appFont(14, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Text(beansLocalized("按列表选择，无法使用时会由平台自动降级。", "Choose a quality below; the platform will downgrade automatically when unavailable."))
                        .font(BeansFont.appFont(10))
                        .foregroundStyle(Color.beansComment)
                        .lineLimit(1)
                }
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BeansAudioQuality.allCases) { quality in
                        let selected = playbackAudioQualitySelection.wrappedValue == quality
                        Button {
                            playbackAudioQualitySelection.wrappedValue = quality
                            BeansHaptics.select()
                        } label: {
                            HStack(spacing: 5) {
                                Text(quality.displayName)
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                }
                            }
                            .font(BeansFont.appFont(12, selected ? .semibold : .medium))
                            .foregroundStyle(selected ? Color.beansAmber : Color.beansLabel)
                            .padding(.horizontal, 12)
                            .frame(height: 31)
                            .background {
                                liquidQualityOptionBackground(selected: selected)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private var homeGreetingLines: [String] {
        let custom = homeGreetingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if custom.isEmpty { return ["自动问候"] }
        return custom.components(separatedBy: .newlines)
    }

    private func greetingLineSizeBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: {
                switch index {
                case 0: return homeGreetingLine1Size > 0 ? homeGreetingLine1Size : homeGreetingSize
                case 1: return homeGreetingLine2Size > 0 ? homeGreetingLine2Size : homeGreetingSize
                default: return homeGreetingLine3Size > 0 ? homeGreetingLine3Size : homeGreetingSize
                }
            },
            set: { value in
                switch index {
                case 0: homeGreetingLine1Size = value
                case 1: homeGreetingLine2Size = value
                default: homeGreetingLine3Size = value
                }
            }
        )
    }

    private func greetingLineColorBinding(_ index: Int) -> Binding<Color> {
        Binding(
            get: {
                let raw: String
                switch index {
                case 0: raw = homeGreetingLine1ColorHex
                case 1: raw = homeGreetingLine2ColorHex
                default: raw = homeGreetingLine3ColorHex
                }
                return Color(hex: raw) ?? (Color(hex: homeGreetingColorHex) ?? Color.beansLabel)
            },
            set: { color in
                let hex = color.hexString
                switch index {
                case 0: homeGreetingLine1ColorHex = hex
                case 1: homeGreetingLine2ColorHex = hex
                default: homeGreetingLine3ColorHex = hex
                }
            }
        )
    }

    private func greetingLineOffsetBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: {
                switch index {
                case 0: return homeGreetingLine1OffsetY
                case 1: return homeGreetingLine2OffsetY
                default: return homeGreetingLine3OffsetY
                }
            },
            set: { value in
                switch index {
                case 0: homeGreetingLine1OffsetY = value
                case 1: homeGreetingLine2OffsetY = value
                default: homeGreetingLine3OffsetY = value
                }
            }
        )
    }

    private func greetingLineGradientStartBinding(_ index: Int) -> Binding<Color> {
        Binding(
            get: {
                let raw: String
                switch index {
                case 0: raw = homeGreetingLine1GradientStartHex
                case 1: raw = homeGreetingLine2GradientStartHex
                default: raw = homeGreetingLine3GradientStartHex
                }
                return Color(hex: raw) ?? (Color(hex: homeGreetingGradientStartHex) ?? Color.beansLabel)
            },
            set: { color in
                switch index {
                case 0: homeGreetingLine1GradientStartHex = color.hexString
                case 1: homeGreetingLine2GradientStartHex = color.hexString
                default: homeGreetingLine3GradientStartHex = color.hexString
                }
            }
        )
    }

    private func greetingLineGradientEndBinding(_ index: Int) -> Binding<Color> {
        Binding(
            get: {
                let raw: String
                switch index {
                case 0: raw = homeGreetingLine1GradientEndHex
                case 1: raw = homeGreetingLine2GradientEndHex
                default: raw = homeGreetingLine3GradientEndHex
                }
                return Color(hex: raw) ?? (Color(hex: homeGreetingGradientEndHex) ?? Color.beansLabel)
            },
            set: { color in
                switch index {
                case 0: homeGreetingLine1GradientEndHex = color.hexString
                case 1: homeGreetingLine2GradientEndHex = color.hexString
                default: homeGreetingLine3GradientEndHex = color.hexString
                }
            }
        )
    }

    private func resetGreetingLineStyle(_ index: Int) {
        switch index {
        case 0:
            homeGreetingLine1Size = 0
            homeGreetingLine1ColorHex = ""
            homeGreetingLine1OffsetY = 0
            homeGreetingLine1GradientStartHex = ""
            homeGreetingLine1GradientEndHex = ""
        case 1:
            homeGreetingLine2Size = 0
            homeGreetingLine2ColorHex = ""
            homeGreetingLine2OffsetY = 0
            homeGreetingLine2GradientStartHex = ""
            homeGreetingLine2GradientEndHex = ""
        default:
            homeGreetingLine3Size = 0
            homeGreetingLine3ColorHex = ""
            homeGreetingLine3OffsetY = 0
            homeGreetingLine3GradientStartHex = ""
            homeGreetingLine3GradientEndHex = ""
        }
    }

    var body: some View {
        ZStack {
            // Settings is presented over the home screen. Sample the same
            // wallpaper/backdrop as the home cards so its clear glass does not
            // turn into a milky white surface at either sheet detent.
            GlassBackdrop(
                customColor: theme.customBackground,
                homeMode: true,
                includeDynamicWallpaper: false
            )
            SettingsCompactGlassSurface()
            if settingsContentReady {
                settingsScrollContent
            } else {
                ProgressView()
                    .tint(Color.beansAmber)
                    .controlSize(.regular)
            }
        }
        .environment(\.beansSettingsPerformanceMode, false)
        .preferredColorScheme(themeMode.colorScheme)
        .onAppear {
            if defersSettingsContentForCompatibility {
                DispatchQueue.main.async {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        settingsContentReady = true
                    }
                }
            } else {
                settingsContentReady = true
            }
        }
        .sheet(isPresented: $showWallpaperPicker) {
            WallpaperPhotoPicker { data in
                theme.addWallpaperForBothSchemes(data)
                BeansHaptics.success()
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showFloatingImagePicker) {
            WallpaperPhotoPicker(allowsMultiple: false) { data in
                if let base64 = normalizedFloatingImageBase64(from: data) {
                    globalFloatingImageData = base64
                }
            }
            .ignoresSafeArea()
        }
        // 我的页头部壁纸选图 + 裁切（根层级呈现，不再挂在折叠区 HStack 上）：
        // 选图用 WallpaperImagePicker（多路解码兜底），解不出来走 onFailed 弹提示，
        // 不静默退出、不换旧壁纸；解出来才进裁切，裁切页用系统导航栏 + 底部大按钮。
        .sheet(isPresented: $showProfileHeaderWallpaperPicker) {
            WallpaperImagePicker(
                onPicked: { pendingHeaderWallpaperCropImage = $0 },
                onFailed: { showWallpaperFormatError = true }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { pendingHeaderWallpaperCropImage != nil },
                set: { if !$0 { pendingHeaderWallpaperCropImage = nil } }
            )
        ) {
            if let picked = pendingHeaderWallpaperCropImage {
                CoHeaderWallpaperCropView(
                    image: picked,
                    onDone: { cropped in
                        let ok = CoProfileHeaderWallpaper.shared.save(image: cropped)
                        if ok { pendingHeaderWallpaperCropImage = nil }
                        return ok
                    },
                    onCancel: {
                        pendingHeaderWallpaperCropImage = nil
                    }
                )
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .alert("此图片格式不支持", isPresented: $showWallpaperFormatError) {
            Button("好", role: .cancel) {}
        } message: {
            Text("请换一张 JPG、PNG、HEIC/HEIF 图片；GIF 取第一帧。WebP 视系统解码器而定，解不出来时也会这样提示，旧壁纸没有被换掉。")
        }
        .sheet(isPresented: $showChangelog) {
            ChangelogListView()
                .environmentObject(theme)
        }
        .fileExporter(
            isPresented: $showExportBackup,
            document: backupDoc,
            contentType: .json,
            defaultFilename: "Beans设置备份-\(Self.backupDateString())"
        ) { result in
            switch result {
            case .success:
                backupMessage = "配置备份已导出"
                ToastCenter.shared.show("配置备份已导出")
            case .failure(let error):
                backupMessage = "导出失败：\(error.localizedDescription)"
                ToastCenter.shared.show("导出失败")
            }
        }
        .sheet(isPresented: $showAccountHub) {
            AccountHubSheet()
                .environmentObject(auth)
                .environmentObject(theme)
        }
        .sheet(isPresented: $showEqualizer) {
            EqualizerSettingsView()
                .environmentObject(theme)
        }
        .sheet(isPresented: $showTabVisibilitySettings) {
            TabVisibilitySettingsSheet()
                .environmentObject(theme)
        }
        .fullScreenCover(isPresented: $showRestorePicker) {
            BackupDocumentPicker { url in
                handleBackupImport(url)
            }
            .ignoresSafeArea()
        }
        .confirmationDialog("导入备份将覆盖当前部分设置，是否继续？", isPresented: $showRestoreConfirm, titleVisibility: .visible) {
            Button("恢复", role: .destructive) {
                applyRestore(pendingRestore)
            }
            Button("取消", role: .cancel) {}
        }
        .onAppear {
            homeRenderingPaused = true
        }
        .onDisappear {
            homeRenderingPaused = false
            onClose?()
        }
    }

    private var settingsScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AnyView(settingsSearchField)
                AnyView(coreSettingsGroup)
                AnyView(playbackSettingsGroup)
                AnyView(utilitySettingsGroup)
                if !hasSettingsSearchResults {
                    Text("没有找到相关设置")
                        .font(BeansFont.appFont(14))
                        .foregroundStyle(Color.beansComment)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                }
            }
            // 设置页右侧开关“被裁”定性（2026-10-24 真机图一）：不是壁纸层裁的——
            // GlassBackdrop 只在 ZStack 背景层、无 .clipped()、不约束兄弟层，
            // SettingsCompactGlassSurface 在推入页里因高度条件不成立根本不渲染；
            // 真因是两层 16pt 横向内边距叠加（这里 16 + 下面卡片组的 16 = 32pt），
            // 开关右缘落在屏宽 - 32pt（约 919/1000）而不是屏宽 - 16pt。
            // 本轮两层各减到 8pt，合计仍是 16pt，卡片仍有 8pt 外边距、8pt 内呼吸，
            // 开关右缘回到屏宽 - 16pt（约 959/1000），卡片外观与内边距逻辑不动。
            .padding(.horizontal, 8)
            .padding(.top, 14)
            // 底部留白：原 40pt 根本不够迷你播放器（约 50pt）+ 底栏（约 57pt）
            // + 安全区，最后一行会被盖住；按我的页同款 240pt 给足，不只加 10pt。
            .padding(.bottom, 240)
            .beansAdaptiveContentWidth()
        }
        .beansScrollIndicatorsHidden()
    }

    private func closeSettings() {
        onClose?()
        dismiss()
    }

    private var showAccountSettings: Bool {
        settingsMatches("账号 登录 酷狗")
    }
    private var showHiddenPlaylistsSettings: Bool {
        settingsMatches("隐藏 歌单")
    }

    private var settingsSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.beansComment)
            TextField("搜索设置", text: $settingsSearchText)
                .font(BeansFont.appFont(16, .medium))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !settingsSearchText.isEmpty {
                Button {
                    settingsSearchText = ""
                    BeansHaptics.tap()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.beansComment.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background {
            BeansGlass(shape: Capsule())
        }
        .overlay {
            Capsule()
                .strokeBorder(Color.beansLabel.opacity(0.08), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private var showAppearanceSettings: Bool { settingsMatches("主题 外观 背景 壁纸 底栏 颜色 赞助 深色 深浅") }
    private var showAudioSettings: Bool { settingsMatches("音源 音质 网络 Wi-Fi 蜂窝 导入") }
    private var showPlaybackSettings: Bool { settingsMatches("播放 触感 锁屏 灵动岛") }
    private var showEqualizerSettings: Bool { settingsMatches("均衡器 音效") }
    private var showBackupSettings: Bool { settingsMatches("备份 恢复 导出 导入 缓存") }
    private var showChangelogSettings: Bool { settingsMatches("日志 版本") }
    private var showSupportSettings: Bool { settingsMatches("帮助 声明") }
    private var hasSettingsSearchResults: Bool {
        showAccountSettings || showHiddenPlaylistsSettings || showAppearanceSettings
            || showAudioSettings || showPlaybackSettings || showEqualizerSettings
            || showBackupSettings || showChangelogSettings || showSupportSettings
    }

    @ViewBuilder
    private var coreSettingsGroup: some View {
        if showAccountSettings || showHiddenPlaylistsSettings || showAppearanceSettings {
            SettingsCatalogGroup {
                if showAccountSettings { accountSection }
                if showAccountSettings && (showAppearanceSettings || showHiddenPlaylistsSettings) { catalogDivider }
                if showAppearanceSettings { appearanceSection }
                if showAppearanceSettings && showHiddenPlaylistsSettings { catalogDivider }
                if showHiddenPlaylistsSettings { hiddenPlaylistsSettingsSection }
            }
        }
    }

    // MARK: - 隐藏的歌单（2026-10-24 用户拍板：只留设置里的开关）
    // 设置里显示当前账号全部歌单，点眼睛切换显示/隐藏；我的页长按隐藏已删。
    // 数据来源是已同步歌单缓存（我的页也是先读这个缓存再联网同步），不编造歌单；
    // 缓存为空时不显示空白列表冒充全量，给诚实提示 + 刷新按钮。
    private var settingsCurrentHiddenKey: String { kugouAuth.userId.isEmpty ? "local" : kugouAuth.userId }
    private var settingsAllPlaylistRows: [(id: Int, name: String, trackCount: Int?)] {
        let cachedIds = Set(settingsCachedPlaylists.map(\.id))
        var rows: [(id: Int, name: String, trackCount: Int?)] = settingsCachedPlaylists.map { (id: $0.id, name: $0.name, trackCount: $0.trackCount) }
        // 隐藏记录里有、缓存里已没有的（例如酷狗里已删）也追加在末尾、可点恢复，
        // 不要因为缓存里没了就把隐藏记录悄悄丢掉。
        for entry in settingsCurrentHidden where !cachedIds.contains(entry.id) {
            rows.append((id: entry.id, name: entry.name, trackCount: nil))
        }
        return rows
    }
    private var settingsHiddenIds: Set<Int> { Set(settingsCurrentHidden.map(\.id)) }
    private func refreshHiddenPlaylistsSettings() {
        settingsCachedPlaylists = SyncedPlaylistCache.shared.cachedPlaylists(source: .kugou, accountID: kugouAuth.userId)?.playlists ?? []
        settingsCurrentHidden = CoHiddenPlaylists.load(userId: kugouAuth.userId)
        settingsOtherHidden = CoHiddenPlaylists.allAccounts().filter { $0.userId != settingsCurrentHiddenKey }
    }
    private func toggleSettingsPlaylistHidden(id: Int, name: String) {
        var entries = settingsCurrentHidden
        if entries.contains(where: { $0.id == id }) {
            entries.removeAll { $0.id == id }
            ToastCenter.shared.show("已恢复显示")
        } else {
            entries.append((id: id, name: name))
            ToastCenter.shared.show("已隐藏")
        }
        CoHiddenPlaylists.save(userId: kugouAuth.userId, entries: entries)
        settingsCurrentHidden = entries
        BeansHaptics.select()
    }

    private var hiddenPlaylistsSettingsSection: some View {
        // 外观行用 Button + 上下箭头（只有一个指示符），隐藏行原来用 DisclosureGroup，
        // 系统会在行尾再补一个黑粗右箭头，变成“无 + 下箭头 + 右箭头”两个指示符叠加，
        // 且 label 没有图标位、没有和其他行一样的内边距，整行贴到卡片左边缘才显得突出。
        // 改成和外观行一样的 Button 结构：只有一个上下箭头，图标位、内边距、字号全对齐。
        VStack(alignment: .leading, spacing: 12) {
            Button {
                BeansHaptics.select()
                refreshHiddenPlaylistsSettings()
                withAnimation(.easeInOut(duration: 0.25)) {
                    hiddenPlaylistsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 28)
                    Text("隐藏的歌单")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(settingsAllPlaylistRows.isEmpty ? "无" : "\(settingsHiddenIds.count) 条已隐藏 / 共 \(settingsAllPlaylistRows.count) 条")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                    Image(systemName: hiddenPlaylistsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.beansComment.opacity(0.6))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.98))
            if hiddenPlaylistsExpanded {
            VStack(alignment: .leading, spacing: 14) {
                Button { refreshHiddenPlaylistsSettings() } label: {
                    Text("刷新列表").font(BeansFont.appFont(13, .medium)).foregroundStyle(Color.beansAmber)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background { BeansSurface(shape: Capsule()) }
                }
                .buttonStyle(.plain)
                if settingsAllPlaylistRows.isEmpty {
                    Text("暂未同步到歌单，先打开“我的”页同步一次；同步后这里会显示全部歌单，点眼睛可隐藏或显示，隐藏只不在“我的”页显示，歌单本身不删除。")
                        .font(BeansFont.appFont(12)).foregroundStyle(Color.beansComment)
                } else {
                    ForEach(settingsAllPlaylistRows, id: \.id) { row in
                        let hidden = settingsHiddenIds.contains(row.id)
                        Button { toggleSettingsPlaylistHidden(id: row.id, name: row.name) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.name).font(BeansFont.appFont(14)).foregroundStyle(Color.beansLabel).lineLimit(1)
                                    if let count = row.trackCount {
                                        Text("\(count) 首").font(BeansFont.appFont(11)).foregroundStyle(Color.beansComment)
                                    } else {
                                        Text("歌单 ID \(row.id)").font(BeansFont.appFont(11)).foregroundStyle(Color.beansComment)
                                    }
                                }
                                Spacer()
                                Text(hidden ? "已隐藏" : "显示中").font(BeansFont.appFont(12)).foregroundStyle(Color.beansComment)
                                Image(systemName: hidden ? "eye.slash.fill" : "eye.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(hidden ? Color.beansAmber : Color.beansLabel)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !settingsOtherHidden.isEmpty {
                    Text("其他账号已隐藏的歌单")
                        .font(BeansFont.appFont(12, .semibold)).foregroundStyle(Color.beansComment)
                    ForEach(settingsOtherHidden, id: \.userId) { account in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(account.userId == "local" ? "本地（未登录）" : "账号 \(account.userId)")
                                .font(BeansFont.appFont(12, .semibold)).foregroundStyle(Color.beansComment)
                            ForEach(account.entries, id: \.id) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name).font(BeansFont.appFont(14)).foregroundStyle(Color.beansLabel).lineLimit(1)
                                        Text("歌单 ID \(entry.id)").font(BeansFont.appFont(11)).foregroundStyle(Color.beansComment)
                                    }
                                    Spacer()
                                    Button {
                                        let entries = account.entries.filter { $0.id != entry.id }
                                        CoHiddenPlaylists.save(userId: account.userId, entries: entries)
                                        refreshHiddenPlaylistsSettings()
                                        BeansHaptics.select()
                                        ToastCenter.shared.show("已恢复显示")
                                    } label: {
                                        Text("恢复显示").font(BeansFont.appFont(13, .medium)).foregroundStyle(Color.beansAmber)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background { BeansSurface(shape: Capsule()) }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .onAppear { refreshHiddenPlaylistsSettings() }
            }
        }
    }

    @ViewBuilder
    private var playbackSettingsGroup: some View {
        if showAudioSettings || showPlaybackSettings || showEqualizerSettings {
            SettingsCatalogGroup {
                if showAudioSettings { audioQualitySection }
                if showAudioSettings && (showPlaybackSettings || showEqualizerSettings) { catalogDivider }
                if showPlaybackSettings { playbackSection }
                if showPlaybackSettings && showEqualizerSettings { catalogDivider }
                if showEqualizerSettings { equalizerSection }
            }
        }
    }

    @ViewBuilder
    private var utilitySettingsGroup: some View {
        if showBackupSettings || showChangelogSettings || showSupportSettings {
            SettingsCatalogGroup {
                if showBackupSettings { backupSection }
                if showBackupSettings && (showChangelogSettings || showSupportSettings) { catalogDivider }
                if showChangelogSettings { changelogSection }
                if showChangelogSettings && showSupportSettings { catalogDivider }
                if showSupportSettings { settingsSupportSection }
            }
        }
    }

    private var catalogDivider: some View {
        Divider()
            .overlay(Color.primary.opacity(0.09))
            .padding(.leading, 48)
    }

    private func officialQualityPills(_ selection: Binding<BeansAudioQuality>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BeansAudioQuality.allCases) { quality in
                    let selected = selection.wrappedValue == quality
                    Button {
                        selection.wrappedValue = quality
                        BeansHaptics.select()
                    } label: {
                        Text(quality.displayName)
                            .font(BeansFont.appFont(12, selected ? .semibold : .medium))
                            .foregroundStyle(selected ? Color.beansAmber : Color.beansLabel)
                            .padding(.horizontal, 12)
                            .frame(height: 31)
                            .background { liquidQualityOptionBackground(selected: selected) }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func networkQualityRow(
        title: String,
        icon: String,
        officialSelection: Binding<BeansAudioQuality>
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(BeansFont.appFont(14, .semibold))
                .foregroundStyle(Color.beansLabel)
            Text("官方音质")
                .font(BeansFont.appFont(11))
                .foregroundStyle(Color.beansComment)
            officialQualityPills(officialSelection)
        }
        .padding(12)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var audioQualitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                BeansHaptics.select()
                withAnimation(.easeInOut(duration: 0.22)) {
                    audioQualityExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.beansAmber)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("音源与音质")
                            .font(BeansFont.appFont(15))
                            .foregroundStyle(Color.beansLabel)
                        Text(connectionAwareQuality ? "已按 Wi-Fi / 蜂窝网络分别选择" : "统一音质")
                            .font(BeansFont.appFont(11))
                            .foregroundStyle(Color.beansComment)
                    }
                    Spacer()
                    Image(systemName: audioQualityExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.beansComment.opacity(0.6))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.98))

            if audioQualityExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("播放来源")
                            .font(BeansFont.appFont(14, .semibold))
                            .foregroundStyle(Color.beansLabel)
                        Picker("播放来源", selection: $playbackSourcePreferenceRaw) {
                            ForEach(PlaybackSourcePreference.allCases) { preference in
                                Text(preference.title).tag(preference.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text((PlaybackSourcePreference(rawValue: playbackSourcePreferenceRaw) ?? .automatic).detail)
                            .font(BeansFont.appFont(11))
                            .foregroundStyle(Color.beansComment)
                    }

                    Divider().overlay(Color.beansComment.opacity(0.15))
                    Toggle("按网络类型选择音质", isOn: $connectionAwareQuality)
                        .font(BeansFont.appFont(14))
                        .tint(Color.beansAmber)

                    if connectionAwareQuality {
                        networkQualityRow(
                            title: "Wi-Fi",
                            icon: "wifi",
                            officialSelection: wifiPlaybackAudioQualitySelection
                        )
                        networkQualityRow(
                            title: "蜂窝数据",
                            icon: "antenna.radiowaves.left.and.right",
                            officialSelection: cellularPlaybackAudioQualitySelection
                        )
                    } else {
                        playbackQualitySection
                    }


                }
                .padding(.horizontal, 4)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// 主题相关设置统一归组，避免平台和排行榜外观选项散落在设置页。

    private var accountSection: some View {
        Button {
            BeansHaptics.tap()
            showAccountHub = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.beansAmber)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(beansLocalized("账号登录", "Account sign-in"))
                        .font(BeansFont.appFont(15, .semibold))
                        .foregroundStyle(Color.beansLabel)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.beansComment.opacity(0.65))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.98))
    }

    /// 校验扩展名并安装字体（asCopy 返回的 URL 已在沙盒内，可直接读取）


    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 外观设置行：点击展开 / 收起全部外观设置
            Button {
                BeansHaptics.select()
                withAnimation(.easeInOut(duration: 0.25)) {
                    appearanceExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 28)
                    Text("外观设置")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Image(systemName: appearanceExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.beansComment.opacity(0.6))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.98))

            if appearanceExpanded {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("我的页头部壁纸")
                            .font(BeansFont.appFont(15))
                            .foregroundStyle(Color.beansLabel)
                        Text(profileHeaderWallpaper.image == nil ? "当前：默认黑色" : "当前：已应用壁纸")
                            .font(BeansFont.appFont(12))
                            .foregroundStyle(Color.beansComment)
                    }
                    Spacer()
                    if profileHeaderWallpaper.image != nil {
                        Button {
                            profileHeaderWallpaper.clear()
                            BeansHaptics.select()
                        } label: {
                            Text("恢复默认")
                                .font(BeansFont.appFont(13, .medium))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background { BeansSurface(shape: Capsule()) }
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        showProfileHeaderWallpaperPicker = true
                    } label: {
                        Text("更换")
                            .font(BeansFont.appFont(13, .medium))
                            .foregroundStyle(Color.beansAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background { BeansSurface(shape: Capsule()) }
                    }
                    .buttonStyle(.plain)
                }
                // 选图与裁切的呈现不再挂在折叠区里的这个 HStack 上：
                // 上一轮裁切完成反复点不到，呈现层级是嫌疑之一（嵌在折叠区
                // 里的全屏弹窗 + 自定义顶部栏）。本轮把 sheet / 全屏弹窗移到
                // SettingsView 根层级（见 body 处），这里只留“更换”按钮。
                Picker("主题模式", selection: $themeModeRaw) {
                    ForEach(BeansThemeMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.title)).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("沉浸详情界面", isOn: $immersiveDetailEnabled)
                    .tint(Color.beansAmber)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("beans.settings.immersive-detail")

                Picker("语言", selection: $languageRaw) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.beansAmber)

                if #available(iOS 26, *) {
                    Toggle("关闭液态模式", isOn: $disableLiquidGlass)
                        .font(BeansFont.appFont(15))
                        .tint(Color.beansAmber)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                DisclosureGroup(isExpanded: $appearanceDetailsExpanded) {
                    VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("全局漂浮特效")
                                .font(BeansFont.appFont(15))
                                .foregroundStyle(Color.beansLabel)
                        }
                    }
                    Picker("全局漂浮特效", selection: $globalFloatingEffectRaw) {
                        ForEach(BeansGlobalFloatingEffect.allCases) { effect in
                            Label(effect.title, systemImage: effect.icon).tag(effect.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(Color.beansAmber)
                    if globalFloatingEffectRaw != BeansGlobalFloatingEffect.off.rawValue {
                        layoutSettingSlider("特效密度", value: $globalFloatingDensity, range: 0.4...2.4, step: 0.1, format: "%.1fx")
                        layoutSettingSlider("粒子大小", value: $globalFloatingSize, range: 0.6...2.2, step: 0.1, format: "%.1fx")
                        layoutSettingSlider("动画速度", value: $globalFloatingSpeed, range: 0.4...1.8, step: 0.1, format: "%.1fx")
                        if globalFloatingEffectRaw == BeansGlobalFloatingEffect.customText.rawValue {
                            TextField("文字或 Emoji", text: $globalFloatingText)
                                .textFieldStyle(.roundedBorder)
                                .font(BeansFont.appFont(14))
                            HStack(spacing: 12) {
                                Button {
                                    showFloatingImagePicker = true
                                } label: {
                                    Label(
                                        globalFloatingImageData.isEmpty ? "上传漂浮图片" : "更换漂浮图片",
                                        systemImage: "photo.badge.plus"
                                    )
                                    .font(BeansFont.appFont(13, .medium))
                                    .foregroundStyle(Color.beansAmber)
                                }
                                .buttonStyle(.plain)
                                if !globalFloatingImageData.isEmpty {
                                    Button("清除图片") {
                                        globalFloatingImageData = ""
                                    }
                                    .font(BeansFont.appFont(12))
                                    .foregroundStyle(Color.beansComment)
                                    .buttonStyle(.plain)
                                }
                            }
                            layoutSettingSlider("旋转", value: $globalFloatingRotation, range: -180...180, step: 1, format: "%.0f°")
                            layoutSettingSlider("倾斜", value: $globalFloatingSkew, range: -45...45, step: 1, format: "%.0f°")
                        }
                    }
                }

                Toggle(isOn: $tabLabelsVisible) {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.3.group")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("底栏显示文字")
                                .font(BeansFont.appFont(15))
                                .foregroundStyle(Color.beansLabel)
                        }
                    }
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)

                Button {
                    BeansHaptics.tap()
                    showTabVisibilitySettings = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.3.group.bubble")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("底部栏显示")
                                .font(BeansFont.appFont(15))
                                .foregroundStyle(Color.beansLabel)
                            Text("选择要显示的主页入口")
                                .font(BeansFont.appFont(12))
                                .foregroundStyle(Color.beansComment)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.beansComment)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        Text("底栏图标样式")
                            .font(BeansFont.appFont(15))
                            .foregroundStyle(Color.beansLabel)
                    }
                    Picker("底栏图标样式", selection: $tabIconStyleRaw) {
                        ForEach(BeansTabIconStyle.allCases) { style in
                            Text(style.title).tag(style.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(Color.beansAmber)
                }

                Toggle(isOn: $showSongVIPBadge) {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("显示歌曲 VIP 图标")
                                .font(BeansFont.appFont(15))
                                .foregroundStyle(Color.beansLabel)
                        }
                    }
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().overlay(Color.beansComment.opacity(0.15))

                Divider().overlay(Color.beansComment.opacity(0.15))

                if #unavailable(iOS 26) {
                    legacyTabBarSettings

                    Divider().overlay(Color.beansComment.opacity(0.15))
                }

                 VStack(alignment: .leading, spacing: 8) {
                     HStack {
                         Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        Text("全局 UI 样式")
                            .font(BeansFont.appFont(15))
                            .foregroundStyle(Color.beansLabel)
                        Spacer()
                    }
                    Picker("全局 UI 样式", selection: Binding(
                        get: { theme.uiStyle },
                        set: { theme.setUIStyle($0) }
                    )) {
                        ForEach(BeansUIStyle.allCases, id: \.self) { style in
                            Text(LocalizedStringKey(style.title)).tag(style)
                        }
                    }
                     .pickerStyle(.segmented)
                 }

                 HStack {
                     Image(systemName: "drop.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("液态容器颜色")
                            .font(BeansFont.appFont(15))
                            .foregroundStyle(Color.beansLabel)
                        Text("只影响 Beans 自定义液态容器，系统原生玻璃不变")
                            .font(BeansFont.appFont(11))
                            .foregroundStyle(Color.beansComment)
                    }
                    Spacer(minLength: 10)
                    ColorPicker("", selection: Binding(
                        get: {
                            theme.liquidGlassColor ?? Color(red: 0.86, green: 0.91, blue: 1.0)
                        },
                        set: { theme.setLiquidGlassColor($0.hexString) }
                    ), supportsOpacity: false)
                    .labelsHidden()
                }
                HStack(spacing: 12) {
                    Button {
                        theme.clearLiquidGlassColor()
                        BeansHaptics.select()
                    } label: {
                        Text("恢复默认")
                            .font(BeansFont.appFont(13, .medium))
                            .foregroundStyle(Color.beansAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background { BeansSurface(shape: Capsule()) }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(theme.liquidGlassColorHex == nil ? "默认清透" : "已自定义")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }

                Divider().overlay(Color.beansComment.opacity(0.15))

                HStack {
                    Image(systemName: "eyedropper.halffull")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 28)
                    Text("自定义强调色")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { theme.customAccent ?? Color.beansAmber },
                        set: { theme.setCustomAccent($0.hexString) }
                    ))
                    .labelsHidden()
                }
                HStack(spacing: 12) {
                    Button {
                        theme.clearCustomAccent()
                        BeansHaptics.select()
                    } label: {
                        Text("恢复预设")
                            .font(BeansFont.appFont(13, .medium))
                            .foregroundStyle(Color.beansAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background { BeansSurface(shape: Capsule()) }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                            Text(LocalizedStringKey(theme.customAccentHex == nil ? "使用预设主题" : "已自定义"))
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }

                    Divider().overlay(Color.beansComment.opacity(0.15))

                    HStack {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        Text(beansLocalized("主页背景色", "Home Background Color"))
                            .font(BeansFont.appFont(15))
                            .foregroundStyle(Color.beansLabel)
                        Spacer()
                    }
                    HStack {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        Text(beansLocalized("背景颜色", "Background Color"))
                            .font(BeansFont.appFont(15))
                            .foregroundStyle(Color.beansLabel)
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { theme.customBackground ?? Color.beansBackground },
                            set: { theme.setBackground($0.hexString, for: .light); theme.setBackground($0.hexString, for: .dark) }
                        ))
                        .labelsHidden()
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        Button {
                            showWallpaperPicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Text("上传壁纸（可多张）")
                                    .font(BeansFont.appFont(15))
                                    .foregroundStyle(Color.beansLabel)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.beansAmber)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    // 壁纸库：所有已上传壁纸，点击即应用为当前背景
                    if !theme.wallpaperPaths.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            ForEach(theme.wallpaperPaths, id: \.self) { path in
                                wallpaperCell(path: path)
                            }
                        }
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.beansComment)
                            Text("还没有壁纸，上传后会显示在这里")
                                .font(BeansFont.appFont(12))
                                .foregroundStyle(Color.beansComment)
                            Spacer()
                        }
                    }
                    HStack(spacing: 12) {
                        if theme.customBackgroundImage != nil {
                            Button {
                                theme.clearBackgroundImage(for: .light); theme.clearBackgroundImage(for: .dark)
                                BeansHaptics.select()
                            } label: {
                                Text("清除当前背景")
                                    .font(BeansFont.appFont(13, .medium))
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background { BeansSurface(shape: Capsule()) }
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                            Text(LocalizedStringKey(theme.customBackgroundImage == nil ? "当前：默认背景" : "当前：已应用壁纸"))
                            .font(BeansFont.appFont(12))
                            .foregroundStyle(Color.beansComment)
                    }
                Toggle(isOn: Binding(
                    get: { theme.backgroundSyncAll },
                    set: { theme.setBackgroundSyncAll($0) }
                )) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.beansAmber)
                        Text(LocalizedStringKey("同步到搜索 / 音乐库 / 我的"))
                            .font(BeansFont.appFont(13))
                            .foregroundStyle(Color.beansLabel)
                    }
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)

                Divider().overlay(Color.beansComment.opacity(0.15))

                HStack {
                    Button {
                        theme.setBackground("")
                        BeansHaptics.select()
                    } label: {
                        Text("恢复默认背景")
                            .font(BeansFont.appFont(13, .medium))
                            .foregroundStyle(Color.beansAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        .background { BeansSurface(shape: Capsule()) }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }

                Divider().overlay(Color.beansComment.opacity(0.15))

                HStack {
                    Image(systemName: "text.quote")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 28)
                    Text("注释文字颜色")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: {
                            if let raw = UserDefaults.standard.string(forKey: "beans.commentColorHex"),
                               let c = Color(hex: raw) { return c }
                            return Color.beansComment
                        },
                        set: { UserDefaults.standard.set($0.hexString, forKey: "beans.commentColorHex") }
                    ))
                    .labelsHidden()
                }
                HStack(spacing: 12) {
                    Button {
                        UserDefaults.standard.removeObject(forKey: "beans.commentColorHex")
                        BeansHaptics.select()
                    } label: {
                        Text("恢复默认")
                            .font(BeansFont.appFont(13, .medium))
                            .foregroundStyle(Color.beansAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        .background { BeansSurface(shape: Capsule()) }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(LocalizedStringKey("全 App 说明文字颜色"))
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }

                Divider().overlay(Color.beansComment.opacity(0.15))

                HStack {
                    Image(systemName: "house.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 28)
                    Text("主文字颜色")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: {
                            if let c = Color(hex: labelColorHex) { return c }
                            return Color.beansLabel
                        },
                        set: {
                            labelColorHex = $0.hexString
                            theme.objectWillChange.send()
                        }
                    ), supportsOpacity: false)
                    .labelsHidden()
                }
                HStack(spacing: 12) {
                    Button {
                        labelColorHex = ""
                        theme.objectWillChange.send()
                        BeansHaptics.select()
                    } label: {
                        Text("恢复默认")
                            .font(BeansFont.appFont(13, .medium))
                            .foregroundStyle(Color.beansAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        .background { BeansSurface(shape: Capsule()) }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(LocalizedStringKey("全 App 主文字颜色"))
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }

                Divider().overlay(Color.beansComment.opacity(0.15))


                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("主页壁纸模糊度")
                        Spacer()
                        Text("\(Int(homeWallpaperBlur))")
                            .foregroundStyle(Color.beansComment)
                    }
                    .font(BeansFont.appFont(12))
                    Slider(value: $homeWallpaperBlur, in: 0...30, step: 1)
                        .tint(Color.beansAmber)
                }

                Divider().overlay(Color.beansComment.opacity(0.15))

                appearanceToggle("隐藏所有界面排序按钮", isOn: $homeHeaderHideSort)
                appearanceToggle("每日推荐使用旧版样式", isOn: $dailySongsListStyle)
                
                    }
                } label: {
                    Label("更多外观与主页设置", systemImage: "slider.horizontal.3")
                        .font(BeansFont.appFont(14, .semibold))
                        .foregroundStyle(Color.beansLabel)
                }
                .tint(Color.beansAmber)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 14)
            }
        }
    }

    private func appearanceToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(BeansFont.appFont(13))
            .toggleStyle(.switch)
            .tint(Color.beansAmber)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 10)
            .contentShape(Rectangle())
    }

    /// 播放与歌词设置。
    private var equalizerSection: some View {
        Button {
            BeansHaptics.select()
            showEqualizer = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.beansAmber)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(beansLocalized("均衡器", "Equalizer"))
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                }
                Spacer()
                Text(equalizer.isEnabled ? beansLocalized("已开启", "On") : beansLocalized("已关闭", "Off"))
                    .font(BeansFont.appFont(12, .medium))
                    .foregroundStyle(equalizer.isEnabled ? Color.beansAmber : Color.beansComment)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.beansComment.opacity(0.6))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.98))
    }

    private var playbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                BeansHaptics.select()
                withAnimation(.easeInOut(duration: 0.22)) {
                    playbackExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("播放设置")
                            .font(BeansFont.appFont(15))
                            .foregroundStyle(Color.beansLabel)
                    }
                    Spacer()
                    Image(systemName: playbackExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.beansComment.opacity(0.6))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.98))

            if playbackExpanded {
            VStack(spacing: 14) {
                Toggle(isOn: $mixesWithOthers) {
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("与其他音频同时播放")
                                .font(BeansFont.appFont(15))
                                .foregroundStyle(Color.beansLabel)
                        }
                    }
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)
                .onChange(of: mixesWithOthers) { value in
                    player.setMixesWithOthers(value)
                }

                Divider().overlay(Color.beansComment.opacity(0.15))

                Toggle(isOn: $nowPlayingEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.iphone")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(beansLocalized("显示锁屏与灵动岛播放器", "Show Lock Screen and Dynamic Island player"))
                                .font(BeansFont.appFont(15))
                                .foregroundStyle(Color.beansLabel)
                        }
                    }
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)
                .onChange(of: nowPlayingEnabled) { value in
                    player.setNowPlayingEnabled(value)
                }

                Toggle("锁屏沉浸封面", isOn: $lockScreenImmersiveArtworkEnabled)
                    .tint(Color.beansAmber)
                    .accessibilityIdentifier("beans.settings.lock-screen-artwork")
                    .onChange(of: lockScreenImmersiveArtworkEnabled) { _, _ in player.refreshLockScreenArtwork() }
                Text("支持专辑封面、自定义 GIF 和视频封面。显示效果由系统和辅助功能设置决定。")
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
                Button("清理未使用的锁屏素材") {
                    ToastCenter.shared.show("锁屏视频素材已在酷狗专版移除")
                }

                Divider().overlay(Color.beansComment.opacity(0.15))

                Toggle(isOn: $autoResumeLastPlayback) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.square.stack.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(beansLocalized("启动时自动播放上次歌曲", "Auto-play the last song on launch"))
                                .font(BeansFont.appFont(15))
                                .foregroundStyle(Color.beansLabel)
                            Text(beansLocalized("打开软件后自动恢复上次未播放完的歌曲", "Automatically resume the last unfinished song when the app starts."))
                                .font(BeansFont.appFont(11))
                                .foregroundStyle(Color.beansComment)
                        }
                    }
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)

                Divider().overlay(Color.beansComment.opacity(0.15))


                Divider().overlay(Color.beansComment.opacity(0.15))

                Toggle(isOn: $hapticsEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        Text(beansLocalized("触感反馈", "Haptic Feedback"))
                            .font(BeansFont.appFont(15))
                            .foregroundStyle(Color.beansLabel)
                    }
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)

                Divider().overlay(Color.beansComment.opacity(0.15))

                Toggle(isOn: $showThirdPartyVIPNotice) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(beansLocalized("第三方播放会员歌提醒", "VIP song notice for third-party playback"))
                                .font(BeansFont.appFont(15))
                                .foregroundStyle(Color.beansLabel)
                        }
                    }
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)

            }
            .padding(.horizontal, 4)
            .padding(.bottom, 14)
            .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// 更新日志入口
    private var changelogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                BeansHaptics.tap()
                showChangelog = true
            } label: {
                HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.beansAmber)
                        .frame(width: 28)
                    Text("更新日志")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text("v\(ChangelogStore.currentVersion)")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.beansComment.opacity(0.6))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
    }
    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                BeansHaptics.select()
                withAnimation(.easeInOut(duration: 0.22)) {
                    backupExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "externaldrive.fill")
                        .foregroundStyle(Color.beansAmber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("备份与恢复")
                            .font(BeansFont.appFont(15))
                            .foregroundStyle(Color.beansLabel)
                    }
                    Spacer()
                    Image(systemName: backupExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Color.beansComment)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if backupExpanded {
            VStack(spacing: 10) {
                Toggle("备份登录信息", isOn: $backupIncludeAccounts)
                    .tint(Color.beansAmber)
                    .font(BeansFont.appFont(13))
                Divider().opacity(0.35)
                Toggle("备份壁纸图片", isOn: $backupIncludeWallpapers)
                    .tint(Color.beansAmber)
                    .font(BeansFont.appFont(13))
                Divider().opacity(0.35)
                Text("默认不带账号登录信息；关闭壁纸后只备份普通设置，不写入壁纸图片数据")
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background {
                BeansGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            HStack(spacing: 10) {
                backupActionButton(icon: "square.and.arrow.up", title: "导出备份") {
                    BeansHaptics.tap()
                    exportBackup(includeAccounts: backupIncludeAccounts, includeWallpapers: backupIncludeWallpapers)
                }
                backupActionButton(icon: "square.and.arrow.down", title: "导入恢复") {
                    BeansHaptics.tap()
                    showRestorePicker = true
                }
            }
            backupActionButton(
                icon: clearingImageCache ? "arrow.triangle.2.circlepath" : "trash",
                title: clearingImageCache ? "正在清除图片缓存…" : "清除图片缓存"
            ) {
                guard !clearingImageCache else { return }
                clearingImageCache = true
                BeansCoverImageStore.clearCache { success in
                    clearingImageCache = false
                    backupMessage = success ? "已清除封面图片缓存" : "清除图片缓存失败"
                }
            }
            .disabled(clearingImageCache)
            if let backupMessage {
                Text(backupMessage)
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            }
        }
    }

    private func backupActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(LocalizedStringKey(title))
            }
            .font(BeansFont.appFont(14, .semibold))
            .foregroundStyle(Color.beansLabel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                BeansGlass(shape: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.95))
    }

    private static func isAccountBackupKey(_ key: String) -> Bool {
        key == "beans.user"
            || key.hasPrefix("beans.netease.")
            || key.hasPrefix("beans.qqmusic.")
            || key.hasPrefix("beans.kugou.")
    }

    private static func isPrivacyBackupKey(_ key: String) -> Bool {
        key.hasPrefix("beans.search.")
            || key.hasPrefix("beans.log")
            || key.hasPrefix("beans.crash")
            || key == "beans.thirdPartyAPIKeys"
            || key == "beans.launchInProgress"
            || key == "beans.wallpapers.deleted"
    }

    private static func isWallpaperBackupKey(_ key: String) -> Bool {
        key == "beans.background.image"
            || key == "beans.background.image.light"
            || key == "beans.background.image.dark"
            || key == "beans.background.custom"
            || key == "beans.background.custom.light"
            || key == "beans.background.custom.dark"
            || key == "beans.wallpapers.list"
            || key == "beans.wallpapers.data"
            || key == "beans.lyricBackground.image"
            || key == "beans.lyricBackground.data"
    }

    private static func isSystemBackupKey(_ key: String) -> Bool {
        key.hasPrefix("Apple")
            || key.hasPrefix("NS")
            || key.hasPrefix("com.apple.")
            || key == "AddingEmojiKeybordHandled"
    }

    private static func isBackupCandidateKey(_ key: String) -> Bool {
        key.hasPrefix("beans.") && !isSystemBackupKey(key)
    }

    private static func isExcludedBackupKey(_ key: String, includeAccounts: Bool = false, includeWallpapers: Bool = true) -> Bool {
        (!includeAccounts && isAccountBackupKey(key))
            || (!includeWallpapers && isWallpaperBackupKey(key))
            || isPrivacyBackupKey(key)
            || key == "beans.backup.meta"
            || key == "beans.font.restore"
    }

    /// 导出：收集本 App 设置，排除账号、搜索记录和日志，交给系统原生导出面板
    private func exportBackup(includeAccounts: Bool, includeWallpapers: Bool) {
        let defaults = UserDefaults.standard
        var payload: [String: Any] = [:]
        if includeWallpapers {
            theme.refreshWallpaperBackupForExport()
            LyricBackgroundStore.refreshForExport()
        }
        for (key, value) in defaults.dictionaryRepresentation() {
            guard Self.isBackupCandidateKey(key) else { continue }
            guard !Self.isExcludedBackupKey(key, includeAccounts: includeAccounts, includeWallpapers: includeWallpapers) else { continue }
            // 超大原始 Data 直接跳过（壁纸 base64 已以字符串形式存于 beans.wallpapers.data，不受影响）
            if let data = value as? Data, data.count > 2 * 1024 * 1024 { continue }
            let safe = backupJSONSafe(value)
            // 逐个校验可序列化，异常类型直接跳过，避免整份备份生成失败
            guard JSONSerialization.isValidJSONObject([key: safe]) else { continue }
            payload[key] = safe
        }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        payload["beans.backup.meta"] = [
            "app": "Beans Music",
            "created": ISO8601DateFormatter().string(from: Date()),
            "version": version,
            "includedAccounts": includeAccounts,
            "includedWallpapers": includeWallpapers,
            "excluded": [
                includeAccounts ? nil : "account",
                includeWallpapers ? nil : "wallpapers",
                "search history",
                "logs",
            ].compactMap { $0 }.joined(separator: ", "),
        ] as [String: Any]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            backupMessage = "备份生成失败：存在无法序列化的设置项"
            ToastCenter.shared.show("备份生成失败")
            return
        }
        backupDoc = BackupDocument(data: data)
        backupMessage = nil
        BeansLogger.shared.log("导出配置备份（\(payload.count) 项，账号=\(includeAccounts ? "包含" : "排除") 壁纸=\(includeWallpapers ? "包含" : "排除")）", level: .info)
        showExportBackup = true
    }

    private static func backupDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// 读取用户选择的备份文件并解析，弹确认后恢复
    private func handleBackupImport(_ url: URL) {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            ToastCenter.shared.show("备份文件解析失败")
            return
        }
        pendingRestore = json
        showRestoreConfirm = true
    }

    /// 恢复：把 JSON 备份中除账号、搜索记录和日志外的本 App 设置写回 UserDefaults
    private func applyRestore(_ json: [String: Any]?) {
        guard let json else { return }
        let defaults = UserDefaults.standard
        var count = 0
        for (key, value) in json {
            guard Self.isBackupCandidateKey(key) else { continue }
            guard !Self.isExcludedBackupKey(key, includeAccounts: true, includeWallpapers: true) else { continue }
            guard let restored = backupPlistSafe(value) else { continue }
            defaults.set(restored, forKey: key)
            count += 1
        }
        // 兼容旧备份：旧版本只有一套背景，恢复后让浅色和深色都继承它。
        if json["beans.background.custom.light"] == nil,
           json["beans.background.custom.dark"] == nil,
           let legacy = json["beans.background.custom"] as? String {
            defaults.set(legacy, forKey: "beans.background.custom.light")
            defaults.set(legacy, forKey: "beans.background.custom.dark")
        }
        if json["beans.background.image.light"] == nil,
           json["beans.background.image.dark"] == nil,
           let legacy = json["beans.background.image"] as? String {
            defaults.set(legacy, forKey: "beans.background.image.light")
            defaults.set(legacy, forKey: "beans.background.image.dark")
        }
        theme.reloadBackgroundSettings()
        defaults.removeObject(forKey: "beans.wallpapers.deleted")
        // 恢复壁纸：写回 beans.wallpapers.* 后重建文件（沙盒路径变化也能恢复）
        theme.reloadWallpapersFromBackup()
        // 恢复歌词背景图片：路径变化时按备份的 base64 重建文件
        LyricBackgroundStore.restoreFromBackup()
        BeansLogger.shared.log("恢复配置备份：\(count) 项设置", level: .info)
        if count > 0 {
            BeansHaptics.success()
            backupMessage = "已恢复 \(count) 项设置，部分设置需重启应用后完全生效"
            ToastCenter.shared.show("已恢复 \(count) 项设置")
        } else {
            backupMessage = "备份中未找到可恢复的设置"
        }
    }

    private var legacyTabBarSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "iphone.gen3")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.beansAmber)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("低系统悬浮底栏")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                    Text("仅 iOS 26 以下生效，用来模拟高系统悬浮底栏")
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer()
                Button("默认") {
                    resetLegacyTabBar()
                    BeansHaptics.select()
                }
                .font(BeansFont.appFont(12, .semibold))
                .foregroundStyle(Color.beansAmber)
                .buttonStyle(.plain)
            }
            settingsSlider("圆润度", valueText: "\(Int(legacyTabCornerRadius))") {
                Slider(value: $legacyTabCornerRadius, in: 18...42, step: 1)
                    .tint(Color.beansAmber)
            }
            settingsSlider("长度", valueText: "\(Int(legacyTabWidth))") {
                Slider(value: $legacyTabWidth, in: 300...420, step: 1)
                    .tint(Color.beansAmber)
            }
            settingsSlider("X 位置", valueText: signedIntText(legacyTabOffsetX)) {
                Slider(value: $legacyTabOffsetX, in: -40...40, step: 1)
                    .tint(Color.beansAmber)
            }
            settingsSlider("Y 位置", valueText: signedIntText(legacyTabOffsetY)) {
                Slider(value: $legacyTabOffsetY, in: -36...36, step: 1)
                    .tint(Color.beansAmber)
            }
        }
        .padding(14)
        .background {
            BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func resetLegacyTabBar() {
        legacyTabCornerRadius = 32
        legacyTabWidth = 356
        legacyTabOffsetX = 0
        legacyTabOffsetY = 0
    }

    private func signedIntText(_ value: Double) -> String {
        let intValue = Int(value.rounded())
        if intValue == 0 { return "0" }
        return intValue > 0 ? "+\(intValue)" : "\(intValue)"
    }

    private func layoutSettingSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String
    ) -> some View {
        settingsSlider(title, valueText: String(format: format, value.wrappedValue)) {
            Slider(value: value, in: range, step: step)
                .tint(Color.beansAmber)
        }
    }

    private func settingsSlider<Content: View>(_ title: String, valueText: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(LocalizedStringKey(title))
                    .font(BeansFont.appFont(13))
                    .foregroundStyle(Color.beansLabel)
                Spacer()
                Text(valueText)
                    .font(BeansFont.appFont(12, .semibold))
                    .foregroundStyle(Color.beansAmber)
            }
            content()
                .transaction { transaction in transaction.animation = nil }
        }
    }

    /// 任意 UserDefaults 值 → JSON 可序列化（Data 转 base64、Date 转时间戳）
    private func backupJSONSafe(_ value: Any) -> Any {
        if let data = value as? Data {
            return ["__beansData__": data.base64EncodedString()]
        }
        if let date = value as? Date { return date.timeIntervalSince1970 }
        if let dict = value as? [String: Any] { return dict.mapValues { backupJSONSafe($0) } }
        if let array = value as? [Any] { return array.map { backupJSONSafe($0) } }
        if let dict = value as? [String: String] { return dict }
        if let array = value as? [String] { return array }
        return value
    }

    /// JSON 值 → UserDefaults 可存类型（只保留 plist 兼容类型）
    private func backupPlistSafe(_ value: Any) -> Any? {
        if let dict = value as? [String: Any], dict.count == 1,
           let b64 = dict["__beansData__"] as? String,
           let data = Data(base64Encoded: b64) {
            return data
        }
        if value is String || value is NSNumber { return value }
        if let array = value as? [Any] {
            let mapped = array.compactMap { backupPlistSafe($0) }
            return mapped.count == array.count ? mapped : nil
        }
        if let dict = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (k, v) in dict {
                guard let mv = backupPlistSafe(v) else { return nil }
                result[k] = mv
            }
            return result
        }
        return nil
    }

    private var settingsSupportSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
            }
            catalogDivider
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { disclaimerExpanded.toggle() }
                } label: {
                    HStack(spacing: 9) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.beansAmber)
                        Text("免责声明")
                        .font(BeansFont.appFont(14, .semibold))
                            .foregroundStyle(Color.beansLabel)
                        Spacer()
                        Image(systemName: disclaimerExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(Color.beansComment)
                    }
                }
                .buttonStyle(.plain)
                if disclaimerExpanded {
                    VStack(alignment: .leading, spacing: 9) {
                        disclaimerRow(1, "本软件仅为个人技术学习与开源展示用途，非商业软件、无任何盈利行为。")
                        disclaimerRow(2, "本软件所有音乐、歌词、图片等内容版权归原版权方所有，仅来源于公开网络接口聚合展示。")
                        disclaimerRow(3, "本软件不存储、不上传、不私自分发任何版权资源，仅提供在线试听与检索工具能力。")
                        disclaimerRow(4, "用户下载、保存、传播音频资源的一切行为由用户自行承担法律责任，与软件开发者无关。")
                        disclaimerRow(5, "若有版权侵权问题，版权方可联系开发者，我方将第一时间下架相关内容。")
                        disclaimerRow(6, "使用者默认同意本免责条款，禁止用于商业、盈利、侵权传播场景。")
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 14)
            catalogDivider
            runtimeEnvironmentFooter
        }
    }

    private var runtimeEnvironmentFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    runtimeEnvironmentExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "iphone.gen3")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.beansComment)
                        .frame(width: 28)
                    Text("运行环境")
                        .font(BeansFont.appFont(14, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Spacer(minLength: 0)
                    Image(systemName: runtimeEnvironmentExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.beansComment)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if runtimeEnvironmentExpanded {
                runtimeEnvironmentRow("设备", value: "\(UIDevice.current.model) · \(DeviceIdentity.hardwareModel)")
                runtimeEnvironmentRow("系统", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                runtimeEnvironmentRow("版本", value: runtimeVersionText)
                runtimeEnvironmentRow("界面尺寸", value: runtimeScreenDimensions)
                Button {
                    UIPasteboard.general.string = DeviceIdentity.userID
                    ToastCenter.shared.show("设备标识已复制")
                } label: {
                    runtimeEnvironmentRow("设备标识", value: DeviceIdentity.userID, monospaced: true)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 14)
    }

    private func runtimeEnvironmentRow(_ title: String, value: String, monospaced: Bool = false) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(BeansFont.appFont(12))
                .foregroundStyle(Color.beansSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(monospaced ? .system(size: 11, design: .monospaced) : BeansFont.appFont(12, .medium))
                .foregroundStyle(Color.beansComment)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var runtimeVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "Beans \(version) (Build \(build))"
    }

    private var runtimeScreenDimensions: String {
        let bounds = UIScreen.main.bounds
        return "\(Int(bounds.width)) × \(Int(bounds.height)) @\(Int(UIScreen.main.scale.rounded()))x"
    }

    private func disclaimerRow(_ index: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\(index)")
                .font(BeansFont.appFont(11, .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.beansAmber, Color.beansHighlight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            Text(text)
                .font(BeansFont.appFont(13, .semibold))
                .foregroundStyle(Color.beansAmber)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.beansAmber.opacity(0.075))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.beansAmber.opacity(0.22), lineWidth: 0.8)
                }
        )
    }

    private func settingsSupportButton(
        icon: String,
        title: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28)
                Text(title)
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(Color.beansLabel)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.beansComment.opacity(0.65))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.98))
    }

    private func normalizedFloatingImageBase64(from data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        let maxDimension: CGFloat = 240
        let longestSide = max(image.size.width, image.size.height)
        let scale = longestSide > maxDimension ? maxDimension / longestSide : 1
        let size = CGSize(
            width: max(1, image.size.width * scale),
            height: max(1, image.size.height * scale)
        )
        let renderer = UIGraphicsImageRenderer(size: size)
        let normalized = renderer.jpegData(withCompressionQuality: 0.82) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return normalized.base64EncodedString()
    }

    /// 壁纸格子：点击应用到所选外观；使用中的壁纸显示主题色边框+勾选；右上角删除
    private func wallpaperCell(path: String) -> some View {
        let isActive = path == theme.backgroundImagePath(for: .light) || path == theme.backgroundImagePath(for: .dark)
        return ZStack(alignment: .topTrailing) {
            Button {
                BeansHaptics.tap()
                theme.applyWallpaper(at: path, for: .light); theme.applyWallpaper(at: path, for: .dark)
            } label: {
                Group {
                    if let img = BeansImageFileCache.image(at: path) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.beansGlassFill
                    }
                }
                .frame(height: 108)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.beansAmber)
                            .background { BeansSurface(shape: Circle()) }
                            .padding(5)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                BeansHaptics.medium()
                theme.deleteWallpaper(at: path)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.beansComment)
                    .frame(width: 28, height: 28)
                    .background { BeansSurface(shape: Circle()) }
                    .clipShape(Circle())
                    .contentShape(Circle())
                    .padding(6)
            }
            .buttonStyle(.plain)
            .zIndex(2)
        }
    }
}

// MARK: - 均衡器

private struct SettingsCatalogGroup<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
            // 见 settingsScrollContent 处注释：与外层 8pt 叠加合计 16pt，
            // 原来两层 16pt 叠加成 32pt 是设置页开关右缘偏内的真因。
            .padding(.horizontal, 8)
            .background {
                let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
                BeansGlass(shape: shape)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

// 由 private 改为内部可见（2026-10-23）：主页右上角头像直进设置时，DiscoverView
// 的设置 sheet 也要用同一个液态呈现修饰符，否则编译报 private 不可访问。
struct SettingsLiquidSheetPresentation: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content
                .presentationBackground(.clear)
                .presentationCornerRadius(28)
        } else {
            content
        }
    }
}

/// The iOS 26 sheet host can drop its glass sampling layer at the compact
/// detent. Keep a single transparent glass surface only while compact, rather
/// than stacking another glass layer after the sheet has expanded.
private struct SettingsCompactGlassSurface: View {
    @AppStorage("beans.disableLiquidGlass") private var disableLiquidGlass = false
    @ObservedObject private var theme = ThemeStore.shared

    private var usesNativeLiquidSurface: Bool {
        guard !disableLiquidGlass else { return false }
        return theme.uiStyle == .liquid || theme.uiStyle == .nativeClean
    }

    var body: some View {
        GeometryReader { proxy in
            if #available(iOS 26, *), usesNativeLiquidSurface,
               proxy.size.height < UIScreen.main.bounds.height * 0.82 {
                GlassEffectContainer {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.clear, in: .rect(cornerRadius: 28))
                }
                .ignoresSafeArea()
            }
        }
        .allowsHitTesting(false)
    }
}

/// 单独呈现底栏可见项编辑，避免首次打开设置时同时创建多组 Tab 状态绑定。
private struct TabVisibilitySettingsSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @State private var visibility = BeansTabVisibility.load()
    @AppStorage("beans.headerAccessoryMode") private var headerAccessoryModeRaw = BeansHeaderAccessoryMode.avatar.rawValue

    private var visibleTabCount: Int {
        RootTab.bottomTabs.filter { visibility.isVisible($0) }.count
    }

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                SettingsCatalogGroup {
                    tabToggle("主页", systemName: "house.fill", tab: .discover)
                    Divider().overlay(Color.beansComment.opacity(0.15))
                    tabToggle("精选", systemName: "dot.radiowaves.left.and.right", tab: .playlists)
                    Divider().overlay(Color.beansComment.opacity(0.15))
                    tabToggle("歌单", systemName: "music.note.list", tab: .library)
                    Divider().overlay(Color.beansComment.opacity(0.15))
                    tabToggle("我的", systemName: "person.crop.circle", tab: .profile)
                    Divider().overlay(Color.beansComment.opacity(0.15))
                    tabToggle("搜索", systemName: "magnifyingglass", tab: .search)
                    Divider().overlay(Color.beansComment.opacity(0.15))
                    Picker("右上角入口", selection: $headerAccessoryModeRaw) {
                        ForEach(BeansHeaderAccessoryMode.allCases) { item in
                            Text(item.title).tag(item.rawValue)
                        }
                    }
                    .font(BeansFont.appFont(15))
                    .tint(Color.beansAmber)
                    .padding(.vertical, 8)
                }
                .padding(16)
            }
            .navigationTitle("底部栏显示")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundStyle(Color.beansAmber)
                }
            }
        }
        .modifier(BeansSheetModifier(detents: [.fraction(0.5)], dragIndicator: true))
    }

    private func tabToggle(_ title: String, systemName: String, tab: RootTab) -> some View {
        Toggle(isOn: visibilityBinding(for: tab)) {
            Label(title, systemImage: systemName)
                .font(BeansFont.appFont(15))
                .foregroundStyle(Color.beansLabel)
        }
        .toggleStyle(.switch)
        .tint(Color.beansAmber)
        .padding(.vertical, 10)
        .disabled(visibility.isVisible(tab) && visibleTabCount <= 1)
    }

    private func visibilityBinding(for tab: RootTab) -> Binding<Bool> {
        Binding(
            get: { visibility.isVisible(tab) },
            set: { isVisible in
                guard !(visibility.isVisible(tab) && !isVisible && visibleTabCount <= 1) else { return }
                visibility.setVisible(isVisible, for: tab)
                visibility.save()
            }
        )
    }
}

struct EqualizerSettingsView: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var equalizer = BeansEqualizer.shared
    @State private var newPresetName = ""
    @State private var showPresetNamePrompt = false

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { equalizer.isEnabled },
            set: { equalizer.setEnabled($0) }
        )
    }

    private func gainBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: { equalizer.bandGains.indices.contains(index) ? equalizer.bandGains[index] : 0 },
            set: { equalizer.setBandGain(at: index, to: $0) }
        )
    }

    private var preampBinding: Binding<Double> {
        Binding(
            get: { equalizer.preampGain },
            set: { equalizer.setPreampGain($0) }
        )
    }

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        EqualizerResponseView(
                            gains: equalizer.bandGains,
                            preampGain: equalizer.preampGain
                        )
                        controlCard
                        presetCard
                        bandsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                    .beansAdaptiveContentWidth(compact: 680, regular: 980)
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle(beansLocalized("均衡器", "Equalizer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(beansLocalized("完成", "Done")) { dismiss() }
                }
            }
            .alert(
                beansLocalized("保存自定义预设", "Save custom preset"),
                isPresented: $showPresetNamePrompt
            ) {
                TextField(
                    beansLocalized("预设名称", "Preset name"),
                    text: $newPresetName
                )
                Button(beansLocalized("保存", "Save")) {
                    if equalizer.saveCustomPreset(name: newPresetName) {
                        BeansHaptics.select()
                    }
                    newPresetName = ""
                }
                Button(beansLocalized("取消", "Cancel"), role: .cancel) {
                    newPresetName = ""
                }
            } message: {
                Text(beansLocalized("保存当前频段和前级增益，之后可以一键恢复。", "Save the current bands and preamp for one-tap recall later."))
            }
        }
    }

    private var controlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: enabledBinding) {
                HStack(spacing: 11) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(beansLocalized("启用均衡器", "Enable Equalizer"))
                            .font(BeansFont.appFont(15, .semibold))
                            .foregroundStyle(Color.beansLabel)
                    }
                }
            }
            .toggleStyle(.switch)
            .tint(Color.beansAmber)

            Divider().overlay(Color.beansComment.opacity(0.14))

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(beansLocalized("前级增益", "Preamp"))
                        .font(BeansFont.appFont(13, .medium))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(String(format: "%+.1f dB", equalizer.preampGain))
                        .font(BeansFont.appFont(12, .semibold))
                        .foregroundStyle(abs(equalizer.preampGain) > 0.01 ? Color.beansAmber : Color.beansComment)
                        .monospacedDigit()
                }
                Slider(value: preampBinding, in: -BeansEqualizer.maximumGain...BeansEqualizer.maximumGain, step: 0.5)
                    .tint(Color.beansAmber)
                    .transaction { transaction in transaction.animation = nil }
                HStack {
                    Text("-12")
                    Spacer()
                    Text(beansLocalized("不增益", "Unity"))
                    Spacer()
                    Text("+12")
                }
                .font(BeansFont.appFont(10))
                .foregroundStyle(Color.beansComment.opacity(0.75))
            }
        }
        .padding(14)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    private var presetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(beansLocalized("预设", "Preset"))
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(Color.beansLabel)
                Spacer()
                Menu {
                    ForEach(BeansEqualizerPreset.allCases.filter { $0 != .custom }) { preset in
                        Button(preset.displayName) {
                            equalizer.applyPreset(preset)
                            BeansHaptics.select()
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(equalizer.selectedCustomPresetName ?? equalizer.selectedPreset.displayName)
                            .font(BeansFont.appFont(13, .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.beansAmber)
                    .padding(.horizontal, 11)
                    .frame(height: 31)
                    .background { BeansSurface(shape: Capsule()) }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(BeansEqualizerPreset.allCases.filter { $0 != .custom }) { preset in
                    let selected = equalizer.selectedPreset == preset
                    Button {
                        equalizer.applyPreset(preset)
                        BeansHaptics.select()
                    } label: {
                        Text(preset.displayName)
                            .font(BeansFont.appFont(11.5, selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Color.beansAmber : Color.beansLabel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background {
                                Capsule().fill(selected ? Color.beansAmber.opacity(0.14) : Color.primary.opacity(0.035))
                            }
                            .overlay {
                                Capsule().strokeBorder(selected ? Color.beansAmber.opacity(0.42) : Color.primary.opacity(0.06), lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            if !equalizer.customPresets.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text(beansLocalized("我的预设", "My presets"))
                        .font(BeansFont.appFont(12, .semibold))
                        .foregroundStyle(Color.beansComment)
                    ForEach(equalizer.customPresets) { preset in
                        HStack(spacing: 8) {
                            Button {
                                equalizer.applyCustomPreset(preset)
                                BeansHaptics.select()
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: equalizer.selectedCustomPresetName == preset.name ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(equalizer.selectedCustomPresetName == preset.name ? Color.beansAmber : Color.beansComment)
                                    Text(preset.name)
                                        .font(BeansFont.appFont(12.5, .medium))
                                        .foregroundStyle(Color.beansLabel)
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            Button {
                                equalizer.deleteCustomPreset(preset)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.beansComment)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    newPresetName = equalizer.selectedCustomPresetName ?? ""
                    showPresetNamePrompt = true
                } label: {
                    Label(beansLocalized("保存当前预设", "Save current preset"), systemImage: "square.and.arrow.down")
                        .font(BeansFont.appFont(12.5, .medium))
                        .foregroundStyle(Color.beansAmber)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 10, style: .continuous)) }
                }
                .buttonStyle(.plain)

                Button {
                    equalizer.reset()
                    BeansHaptics.select()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.beansComment)
                        .frame(width: 42, height: 34)
                        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 10, style: .continuous)) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(beansLocalized("重置调节", "Reset adjustments"))
            }
        }
        .padding(14)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    private var bandsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(beansLocalized("自定义调节", "Custom tuning"))
                        .font(BeansFont.appFont(14, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Text(beansLocalized("范围 -12 dB 至 +12 dB", "Range: -12 dB to +12 dB"))
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer()
            }

            ForEach(Array(BeansEqualizer.bandFrequencies.enumerated()), id: \.offset) { index, frequency in
                equalizerBandRow(index: index, frequency: frequency)
                if index < BeansEqualizer.bandFrequencies.count - 1 {
                    Divider().overlay(Color.beansComment.opacity(0.14))
                }
            }
        }
        .padding(14)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    private func equalizerBandRow(index: Int, frequency: Double) -> some View {
        let gain = equalizer.bandGains.indices.contains(index) ? equalizer.bandGains[index] : 0
        return VStack(spacing: 6) {
            HStack {
                Text(frequencyLabel(frequency))
                    .font(BeansFont.appFont(13, .medium))
                    .foregroundStyle(Color.beansLabel)
                Spacer()
                Text(String(format: "%+.1f dB", gain))
                    .font(BeansFont.appFont(12, .semibold))
                    .foregroundStyle(abs(gain) > 0.01 ? Color.beansAmber : Color.beansComment)
                    .monospacedDigit()
            }
            Slider(value: gainBinding(index), in: -BeansEqualizer.maximumGain...BeansEqualizer.maximumGain, step: 0.5)
                .tint(Color.beansAmber)
                .transaction { transaction in transaction.animation = nil }
            HStack {
                Text("-12")
                Spacer()
                Text("0")
                Spacer()
                Text("+12")
            }
            .font(BeansFont.appFont(10))
            .foregroundStyle(Color.beansComment.opacity(0.75))
        }
    }

    private func frequencyLabel(_ frequency: Double) -> String {
        if frequency >= 1_000 {
            let value = frequency / 1_000
            return value.rounded() == value ? "\(Int(value)) kHz" : String(format: "%.1f kHz", value)
        }
        return "\(Int(frequency)) Hz"
    }
}

private struct EqualizerResponseView: View {
    let gains: [Double]
    let preampGain: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(beansLocalized("频响预览", "Response preview"))
                        .font(BeansFont.appFont(14, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Text(beansLocalized("拖动下方频段，实时塑造声音", "Shape the sound in real time by tuning each band below"))
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer()
                Image(systemName: "waveform.path")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.beansAmber)
            }

            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let values = responseValues
                ZStack {
                    VStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { _ in
                            Divider().overlay(Color.beansComment.opacity(0.12))
                            Spacer()
                        }
                    }
                    Path { path in
                        guard let first = values.first else { return }
                        path.move(to: CGPoint(x: 0, y: yPosition(first, height: height)))
                        for index in values.indices.dropFirst() {
                            let x = width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                            path.addLine(to: CGPoint(x: x, y: yPosition(values[index], height: height)))
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [Color.beansAmber.opacity(0.65), Color.beansAmber, Color.beansHighlight],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                    )
                    Path { path in
                        guard let first = values.first else { return }
                        path.move(to: CGPoint(x: 0, y: height))
                        path.addLine(to: CGPoint(x: 0, y: yPosition(first, height: height)))
                        for index in values.indices.dropFirst() {
                            let x = width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                            path.addLine(to: CGPoint(x: x, y: yPosition(values[index], height: height)))
                        }
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color.beansAmber.opacity(0.22), Color.beansAmber.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .frame(height: 108)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.7)
            }

            HStack {
                Text("31 Hz")
                Spacer()
                Text("1 kHz")
                Spacer()
                Text("16 kHz")
            }
            .font(BeansFont.appFont(10))
            .foregroundStyle(Color.beansComment)
        }
        .padding(14)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    private var responseValues: [Double] {
        guard !gains.isEmpty else { return [preampGain] }
        return gains.map { min(max($0 + preampGain * 0.35, -12), 12) }
    }

    private func yPosition(_ value: Double, height: CGFloat) -> CGFloat {
        let normalized = (value + 12) / 24
        return height * CGFloat(1 - normalized)
    }
}

// MARK: - 壁纸照片选择器（PHPicker 封装：iOS 14+ 兼容，支持多选图片）

struct WallpaperPhotoPicker: UIViewControllerRepresentable {
    var allowsMultiple = true
    let onPicked: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        // Explicitly use a generous finite limit. `0` means unlimited on most
        // systems, but some older Photos pickers silently cap that mode.
        config.selectionLimit = allowsMultiple ? 100 : 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: WallpaperPhotoPicker
        init(_ parent: WallpaperPhotoPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            for result in results {
                let provider = result.itemProvider
                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                        guard let data, !data.isEmpty else { return }
                        DispatchQueue.main.async {
                            self.parent.onPicked(data)
                        }
                    }
                }
            }
        }
    }
}

/// 我的页头部壁纸专用选图器（与上面那个只回 Data 的选图器分开）：
/// 上一轮的问题：只用一条路——先 canLoadObject(UIImage) 再按 public.image 取 data、
/// 再用 UIImage(data:) 解码，任何一步失败都静默无回调，选图器一关就“直接退出”，
/// 用户不知道是格式不支持、还是没选上。本轮用三路兜底，全部失败才走 onFailed：
/// ① 直接载 UIImage 对象（系统解码，含 HEIC/JPG/PNG/GIF 首帧等）；
/// ② 按注册的图片类型逐个取 data，先 UIImage(data:) 再用 ImageIO CGImageSource
///    解第一帧（GIF 取第一帧；WebP 能不能解看系统 ImageIO 支不支持，不硬说支持）；
/// ③ 取文件表示再按②解。preferredAssetRepresentationMode 用 .compatible，
///    系统对部分格式会先转码成兼容表示，等于多了一层系统兜底。
/// 注意：Live Photo 取的是静态图，视频不在 filter 里，选不到视频。
struct WallpaperImagePicker: UIViewControllerRepresentable {
    let onPicked: (UIImage) -> Void
    let onFailed: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .compatible
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    static func decodeImage(from data: Data) -> UIImage? {
        if let img = UIImage(data: data), img.size.width > 0, img.size.height > 0 {
            return img
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return UIImage(cgImage: cg)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: WallpaperImagePicker
        private var finished = false
        init(_ parent: WallpaperImagePicker) { self.parent = parent }

        private func succeed(_ image: UIImage) {
            guard !finished else { return }
            finished = true
            DispatchQueue.main.async { self.parent.onPicked(image) }
        }

        private func fail() {
            guard !finished else { return }
            finished = true
            DispatchQueue.main.async { self.parent.onFailed() }
        }

        private func tryData(_ provider: NSItemProvider) {
            let imageTypes = provider.registeredTypeIdentifiers.filter {
                UTType($0)?.conforms(to: .image) == true
            }
            // 先按注册的图片类型逐个取 data，再按通用 public.image 取一次兜底。
            let candidates = imageTypes + [UTType.image.identifier]
            func tryNext(_ index: Int) {
                guard index < candidates.count else {
                    // 最后一条路：取文件表示再解。
                    provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                        guard let url, let data = try? Data(contentsOf: url),
                              let img = WallpaperImagePicker.decodeImage(from: data) else {
                            self.fail()
                            return
                        }
                        self.succeed(img)
                    }
                    return
                }
                provider.loadDataRepresentation(forTypeIdentifier: candidates[index]) { data, _ in
                    if let data, let img = WallpaperImagePicker.decodeImage(from: data) {
                        self.succeed(img)
                    } else {
                        tryNext(index + 1)
                    }
                }
            }
            tryNext(0)
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider else { return }
            // 用户取消选图（results 为空）时不弹“格式不支持”，直接什么都不做。
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    if let img = object as? UIImage, img.size.width > 0, img.size.height > 0 {
                        self.succeed(img)
                    } else {
                        self.tryData(provider)
                    }
                }
            } else {
                tryData(provider)
            }
        }
    }
}

/// 我的页头部壁纸裁切：选图后先裁、裁完点“完成”才存，不直接显示原图。
/// 裁切框宽高比 = 头部壁纸框宽高比（框宽 = 屏幕宽，框高 = max(屏幕宽 + 30, 410)，
/// 用户机型约 393/423），按当前机型实时算，不写死一个比；裁好的图宽高比与头部框
/// 一致，头部再用 scaledToFill 显示时就不会再切掉主体（只剩像素取整的 1pt 级误差）。
/// 手势只用系统手势，不引第三方裁切库：单指拖动平移、双指缩放；框外部分是暗的，
/// 框内看到什么、头部就显示什么。取消不存图，旧壁纸原样保留。
struct CoHeaderWallpaperCropView: View {
    /// onDone 返回是否真的存进了沙盒：存失败时裁切页不关、弹提示，不静默无反应。
    let image: UIImage
    let onDone: (UIImage) -> Bool
    let onCancel: () -> Void

    @State private var userScale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var showSaveError = false

    /// 完成动作（顶部工具栏与底部大按钮共用同一条路）：
    /// 先算裁切图，算不出来就退回用原图保存，绝不静默失败；
    /// 保存失败就弹提示、页不关，保存成功才由调用方关页。
    private func finish() {
        let toSave = CoProfileHeaderWallpaper.croppedImage(image, rectInPoints: cropRectInImagePoints()) ?? image
        if onDone(toSave) {
            BeansHaptics.success()
        } else {
            showSaveError = true
        }
    }

    private var cropWidth: CGFloat { UIScreen.main.bounds.width }
    private var cropHeight: CGFloat { max(cropWidth + 30, 410) }

    private var coverScale: CGFloat {
        max(cropWidth / max(1, image.size.width), cropHeight / max(1, image.size.height))
    }
    private var displayedSize: CGSize {
        CGSize(width: image.size.width * coverScale * userScale,
               height: image.size.height * coverScale * userScale)
    }
    private func clampedOffset(_ value: CGSize, scale: CGFloat) -> CGSize {
        let w = image.size.width * coverScale * scale
        let h = image.size.height * coverScale * scale
        let maxX = max(0, (w - cropWidth) / 2)
        let maxY = max(0, (h - cropHeight) / 2)
        return CGSize(width: min(max(value.width, -maxX), maxX),
                      height: min(max(value.height, -maxY), maxY))
    }
    /// 裁切框在原图显示尺寸里的 rect：图中心 = 裁切框中心 + offset，图左上角 =
    /// 中心 - 显示尺寸/2，框原点 (0,0) 减左上角再除以总缩放即是框在图里的位置。
    private func cropRectInImagePoints() -> CGRect {
        let totalScale = coverScale * userScale
        let displayed = displayedSize
        let topLeft = CGPoint(x: cropWidth / 2 + offset.width - displayed.width / 2,
                              y: cropHeight / 2 + offset.height - displayed.height / 2)
        return CGRect(x: (0 - topLeft.x) / totalScale,
                      y: (0 - topLeft.y) / totalScale,
                      width: cropWidth / totalScale,
                      height: cropHeight / totalScale)
    }

    var body: some View {
        // 上一轮的教训：自定义顶部栏 + 全屏弹窗的组合在真机上反复出问题
        // （先是忽略安全区顶到状态栏，修了安全区还是点不到——因为完成回调
        // 里裁切图为空就静默无反应，页也不关）。本轮不再用自定义顶部栏：
        // 用系统导航栏工具栏放取消/完成（系统保证它在灵动岛下方、可点），
        // 再在底部放一个满宽大完成按钮作第二条路，两条路走同一个 finish()，
        // 完成一定有反应：要么关页换壁纸，要么弹保存失败提示。
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                Color.black
                Image(uiImage: image)
                    .resizable()
                    .frame(width: image.size.width, height: image.size.height)
                    .scaleEffect(coverScale * userScale, anchor: .center)
                    .offset(offset)
            }
            .frame(width: cropWidth, height: cropHeight)
            .clipped()
            .overlay {
                // 白框线画在裁切框边上：框内看到什么、头部就显示什么。
                Rectangle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 1)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = clampedOffset(CGSize(width: baseOffset.width + value.translation.width,
                                                      height: baseOffset.height + value.translation.height),
                                               scale: userScale)
                    }
                    .onEnded { _ in baseOffset = offset }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        let newScale = min(max(baseScale * value, 1), 4)
                        userScale = newScale
                        offset = clampedOffset(offset, scale: newScale)
                    }
                    .onEnded { _ in
                        baseScale = userScale
                        baseOffset = offset
                    }
            )
            Spacer()
            Text("拖动平移，双指缩放，框内即头部显示范围")
                .font(.system(size: 13))
                .foregroundStyle(Color.secondary)
                .padding(.bottom, 12)
            // 底部大完成按钮：与顶部工具栏的“完成”走同一个 finish()，
            // 顶部万一再出问题，底部这条路一定能点到、一定有反应。
            Button(action: finish) {
                Text("完成")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            }
            .navigationTitle("裁切头部壁纸")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", action: finish)
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .alert("保存失败", isPresented: $showSaveError) {
                Button("好", role: .cancel) {}
            } message: {
                Text("壁纸没有存上，请再点一次完成；如果一直失败，请换一张图片重试。")
            }
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(Color.white)
    }
}

struct AvatarMediaSelection {
    let data: Data
    let fileExtension: String
    let isVideo: Bool
}

/// 头像可从相册选择静态图片或视频；视频保留为本地文件供头像循环播放。
struct AvatarMediaPicker: UIViewControllerRepresentable {
    let onPicked: (AvatarMediaSelection) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .any(of: [.images, .videos])
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: AvatarMediaPicker

        init(_ parent: AvatarMediaPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider else { return }

            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    guard let url, let data = try? Data(contentsOf: url), !data.isEmpty else { return }
                    let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                    DispatchQueue.main.async {
                        self.parent.onPicked(AvatarMediaSelection(data: data, fileExtension: ext, isVideo: true))
                    }
                }
            } else {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data, !data.isEmpty else { return }
                    let imageExtension = provider.registeredTypeIdentifiers
                        .compactMap { UTType($0)?.preferredFilenameExtension }
                        .first ?? "jpg"
                    DispatchQueue.main.async {
                        self.parent.onPicked(AvatarMediaSelection(data: data, fileExtension: imageExtension, isVideo: false))
                    }
                }
            }
        }
    }
}


// MARK: - 配置备份文档（SwiftUI 原生 fileExporter 导出，稳定可靠）

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
// MARK: - 配置备份文件选择器（UIDocumentPicker 封装：比 SwiftUI fileImporter 稳定，所有文件可选）

struct BackupDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json, .plainText, .item], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: BackupDocumentPicker
        init(_ parent: BackupDocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}

