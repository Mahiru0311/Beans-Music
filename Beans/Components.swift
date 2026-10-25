import SwiftUI
import UIKit
import CryptoKit
import ObjectiveC

private struct CoSharedRootBackdropKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var coUsesSharedRootBackdrop: Bool {
        get { self[CoSharedRootBackdropKey.self] }
        set { self[CoSharedRootBackdropKey.self] = newValue }
    }
}

struct FavoriteHeartView: View {
    let mark: FavoriteMark
    var size: CGFloat = 17
    var inactiveColor: Color = .white.opacity(0.78)

    @ViewBuilder
    var body: some View {
        switch mark {
        case .both, .official, .local:
            Image(systemName: "heart.fill")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Color.red)
        case .none:
            Image(systemName: "heart")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(inactiveColor)
        }
    }
}
import CoreImage.CIFilterBuiltins

extension View {
    /// 在紧凑宽度保持手机排版，在规则宽度适当放宽内容区域。
    func coAdaptiveContentWidth(compact: CGFloat = 860, regular: CGFloat = 1100) -> some View {
        modifier(CoAdaptiveContentWidthModifier(compact: compact, regular: regular))
    }

    /// 横向卡片列表的滚动裁剪：卡片自然延伸。
    @ViewBuilder
    func coCompatScrollClipDisabled() -> some View {
        scrollClipDisabled()
    }
}

private struct CoAdaptiveContentWidthModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let compact: CGFloat
    let regular: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: horizontalSizeClass == .regular ? regular : compact)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - 工具

func coSongCountText(_ count: Int) -> String {
    coLocalized("\(count) 首", "\(count) songs")
}

func coLocalSongCountText(_ count: Int) -> String {
    coLocalized("\(count) 首 · 本机", "\(count) songs · On device")
}

func coTimeString(_ seconds: Double) -> String {
    let total = max(0, Int(seconds))
    return String(format: "%d:%02d", total / 60, total % 60)
}

// MARK: - 触感反馈（复用生成器实例，避免每次点击创建新对象造成额外开销/发热）

enum CoHaptics {
    static let enabledKey = "co.haptics.enabled"

    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let notification = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()

    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static func prepare() {
        guard isEnabled else { return }
        lightImpact.prepare()
        mediumImpact.prepare()
        selection.prepare()
    }

    static func tap() {
        guard isEnabled else { return }
        lightImpact.impactOccurred()
    }

    static func medium() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred()
    }

    static func success() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    static func select() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }
}

// MARK: - 按压动效

struct GlassPressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? 0.025 : 0)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

// MARK: - 背景氛围（液态玻璃需要有可采样的动态内容）

struct GlassBackdrop: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.colorScheme) private var colorScheme
    /// 自定义背景色（nil 使用默认氛围渐变）
    var customColor: Color? = nil
    /// 主页模式：即使“同步到全部页面”关闭，也始终显示壁纸/背景色（仅发现页传 true）
    var homeMode: Bool = false
    /// 详情页使用原生氛围背景，不跟随全局壁纸同步
    var ignoreCustomBackground: Bool = false
    /// 主页壁纸额外模糊半径
    var wallpaperBlur: CGFloat = 0
    /// 当前页面是否启用自定义背景：同步开启时全部页面生效，关闭时仅主页生效
    private var showCustomBackground: Bool {
        !ignoreCustomBackground && (theme.backgroundSyncAll || homeMode)
    }

    /// 背景图上叠加的可读性遮罩：浅色模式几乎不压暗，深色模式适度压暗
    private var wallpaperOverlay: [Color] {
        colorScheme == .dark
            ? [.black.opacity(0.35), .black.opacity(0.55)]
            : [.black.opacity(0.08), .black.opacity(0.18)]
    }

    private var uiStyle: CoUIStyle {
        theme.uiStyle
    }

    var body: some View {
        let _ = theme.accent
        let activeBackgroundColor = theme.customBackground(for: colorScheme) ?? customColor
        let activeBackgroundImage = theme.customBackgroundImage(for: colorScheme)
        ZStack {
            if uiStyle == .nativeClean, !showCustomBackground || (activeBackgroundImage == nil && activeBackgroundColor == nil) {
                Color(UIColor.systemBackground)
            } else if let image = activeBackgroundImage, showCustomBackground {
                WallpaperImage(image: image, blurRadius: wallpaperBlur)
                LinearGradient(colors: wallpaperOverlay, startPoint: .top, endPoint: .bottom)
            } else if showCustomBackground, let activeBackgroundColor {
                LinearGradient(
                    colors: [activeBackgroundColor.opacity(0.9), activeBackgroundColor.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
            } else {
                LinearGradient.coBackdrop
            }
            if uiStyle != .nativeClean {
                Circle()
                    .fill(Color.coAmber.opacity(0.14))
                    .frame(width: 340, height: 340)
                    .blur(radius: 100)
                    .offset(x: 150, y: -300)
                Circle()
                    .fill(Color.coSage.opacity(0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 110)
                    .offset(x: -160, y: 340)
            }
            GlobalFloatingEffectView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

/// 全局背景漂浮效果：低频、低对比度绘制，避免遮挡正文和操作控件。
struct GlobalFloatingEffectView: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("co.globalFloatingEffect") private var effectRaw = CoGlobalFloatingEffect.off.rawValue
    @AppStorage("co.globalFloatingDensity") private var density = 1.0
    @AppStorage("co.globalFloatingSize") private var size = 1.0
    @AppStorage("co.globalFloatingSpeed") private var speed = 1.0
    @AppStorage("co.globalFloatingText") private var floatingText = "❄️"
    @AppStorage("co.globalFloatingRotation") private var rotation = 0.0
    @AppStorage("co.globalFloatingSkew") private var skew = 0.0
    @AppStorage("co.globalFloatingImageData") private var floatingImageData = ""

    private var effect: CoGlobalFloatingEffect {
        CoGlobalFloatingEffect(rawValue: effectRaw) ?? .off
    }

    private var floatingImage: UIImage? {
        GlobalFloatingImageCache.shared.image(for: floatingImageData)
    }

    var body: some View {
        Group {
            if effect != .off {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate * max(0.25, min(speed, 2.0))
                let accent = theme.customAccent ?? (colorScheme == .dark ? Color.coAmber : Color.coHighlight)
                let count = max(8, min(64, Int((18 * density).rounded())))
                ZStack {
                    Canvas { context, canvasSize in
                        guard canvasSize.width > 1, canvasSize.height > 1 else { return }
                        if effect == .snow {
                            for index in 0..<count {
                                let seed = Double(index)
                                let x = ((seed * 0.173).truncatingRemainder(dividingBy: 1.0)) * canvasSize.width
                                let fall = ((time * (0.035 + seed.truncatingRemainder(dividingBy: 7) * 0.006) + seed * 0.071).truncatingRemainder(dividingBy: 1.15))
                                let y = fall * canvasSize.height - canvasSize.height * 0.08
                                let drift = sin(time * 0.32 + seed * 1.7) * canvasSize.width * 0.012
                                let center = CGPoint(x: x + drift, y: y)
                                let arm = max(3.4, min(10.5, size * (4.0 + seed.truncatingRemainder(dividingBy: 3) * 1.4)))
                                var flake = Path()
                                for armIndex in 0..<3 {
                                    let angle = Double(armIndex) * .pi / 3
                                    let dx = cos(angle) * arm
                                    let dy = sin(angle) * arm
                                    flake.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
                                    flake.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy))
                                }
                                context.stroke(
                                    flake,
                                    with: .color(.white.opacity(0.34 + 0.14 * sin(seed))),
                                    lineWidth: max(0.8, min(1.5, size * 0.9))
                                )
                            }
                        }
                    }
                    if effect == .customText {
                        GeometryReader { geometry in
                            ForEach(0..<count, id: \.self) { index in
                                let seed = Double(index)
                                let x = ((seed * 0.173).truncatingRemainder(dividingBy: 1.0)) * geometry.size.width
                                let y = ((time * (0.035 + seed.truncatingRemainder(dividingBy: 7) * 0.006) + seed * 0.071).truncatingRemainder(dividingBy: 1.15)) * geometry.size.height
                                Group {
                                    if let floatingImage {
                                        Image(uiImage: floatingImage)
                                            .resizable()
                                            .scaledToFit()
                                    } else {
                                        Text(floatingText.isEmpty ? "✦" : floatingText)
                                            .font(.system(size: max(10, min(30, size * 14)), weight: .medium))
                                            .foregroundStyle(accent.opacity(0.24))
                                    }
                                }
                                .frame(width: max(14, min(42, size * 20)), height: max(14, min(42, size * 20)))
                                .opacity(floatingImage == nil ? 1 : 0.72)
                                .rotationEffect(.degrees(rotation + sin(time * 0.4 + seed) * 8))
                                .transformEffect(CGAffineTransform(a: 1, b: 0, c: CGFloat(tan(skew * .pi / 180)), d: 1, tx: 0, ty: 0))
                                .position(x: x, y: y)
                            }
                        }
                    }
                }
            }
            }
        }
        .allowsHitTesting(false)
    }
}

private final class GlobalFloatingImageCache {
    static let shared = GlobalFloatingImageCache()

    private var encodedValue = ""
    private var cachedImage: UIImage?

    func image(for encodedValue: String) -> UIImage? {
        guard encodedValue != self.encodedValue else { return cachedImage }
        self.encodedValue = encodedValue
        guard !encodedValue.isEmpty, let data = Data(base64Encoded: encodedValue) else {
            cachedImage = nil
            return nil
        }
        cachedImage = UIImage(data: data)
        return cachedImage
    }
}


// MARK: - 背景墙纸（上传图片：固定全屏布局，不影响其他 UI 尺寸；小图轻度柔化避免像素感）

struct WallpaperImage: View {
    let image: UIImage
    var blurRadius: CGFloat = 0

    /// 小于约 700x700 视为小图：放大时轻度模糊柔化，避免满屏马赛克
    private static func isSmall(_ image: UIImage) -> Bool {
        image.size.width * image.size.height < 480_000
    }

    var body: some View {
        // 用 GeometryReader 明确采用父容器尺寸渲染，图片尺寸/比例与 UI 布局完全隔离
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .blur(radius: max(Self.isSmall(image) ? 5 : 0, blurRadius))
        }
        .ignoresSafeArea()
    }
}

// MARK: - 全局容器（跟随全局 UI 样式）

struct CoGlass<S: Shape>: View {
    @AppStorage("co.disableLiquidGlass") private var disableLiquidGlass = false
    @ObservedObject private var theme = ThemeStore.shared
    @Environment(\.colorScheme) private var colorScheme

    let shape: S
    var forceLiquid = false

    private var uiStyle: CoUIStyle {
        // ThemeStore is the single source of truth. Reading UserDefaults
        // directly here could leave a sheet-created view on the old liquid
        // branch for one render after the style picker changes.
        theme.uiStyle
    }

    private var isLiquid: Bool {
        !disableLiquidGlass && (forceLiquid || uiStyle == .liquid || uiStyle == .nativeClean)
    }

    private var liquidTintOpacity: Double {
        colorScheme == .dark ? 0.16 : 0.10
    }

    @ViewBuilder
    private var regularBody: some View {
        Group {
            if disableLiquidGlass {
                // Disabling liquid glass must not fall back to a live blur.
                // A stable opaque fill is cheaper to composite while scrolling.
                shape
                    .fill(Color.coGlassFill.opacity(0.94))
            } else if isLiquid {
                GlassEffectContainer {
                    ZStack {
                        shape
                            .fill(.clear)
                            .glassEffect(.clear, in: shape)
                        if let liquidGlassColor = theme.liquidGlassColor {
                            shape
                                .fill(liquidGlassColor.opacity(liquidTintOpacity))
                                .allowsHitTesting(false)
                        }
                    }
                }
            } else {
                switch uiStyle {
                case .clear, .liquid:
                    shape
                        .fill(.ultraThinMaterial)
                case .compact:
                    shape
                        .fill(Color.coGlassFill.opacity(0.74))
                case .nativeClean:
                    shape
                        .fill(Color.coGlassFill.opacity(0.62))
                }
            }
        }
        // iOS 26 的玻璃容器只负责绘制背景，不能拦截设置控件的触摸。
        .allowsHitTesting(false)
    }

    var body: some View {
        regularBody
    }
}

/// Shared translucent sheet background. Keep the sheet host transparent so
/// the page below remains visible through the same liquid surface as comments.
struct CoLiquidSheetBackground: View {
    @EnvironmentObject private var theme: ThemeStore

    var body: some View {
        ZStack {
            GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
            CoGlass(shape: Rectangle(), forceLiquid: true)
        }
        .background(CoSheetPresentationSurfaceClearer())
        .ignoresSafeArea()
    }
}

/// 统一表面容器：Apple 简洁样式使用低存在感的平面底色，
/// 其他样式继续沿用原有的玻璃材质，避免页面局部出现不同质感。
struct CoSurface<S: Shape>: View {
    let shape: S

    var body: some View {
        CoGlass(shape: shape)
    }
}




/// 播放/暂停 morph 图标：三角播放态与双竖线暂停态共享一个固定画布，避免按钮尺寸跳动。
struct PlayPauseMorphIcon: View {
    let isPlaying: Bool
    var size: CGFloat = 22

    private var progress: CGFloat { isPlaying ? 1 : 0 }

    var body: some View {
        ZStack {
            Image(systemName: "play.fill")
                .font(.system(size: size, weight: .semibold))
                .opacity(1 - progress)
                .scaleEffect(1 - progress * 0.18)
                .offset(x: progress * 5)
            HStack(spacing: max(3, size * 0.18)) {
                RoundedRectangle(cornerRadius: max(1.5, size * 0.08), style: .continuous)
                    .frame(width: max(4, size * 0.24), height: size * 0.86)
                RoundedRectangle(cornerRadius: max(1.5, size * 0.08), style: .continuous)
                    .frame(width: max(4, size * 0.24), height: size * 0.86)
            }
            .opacity(progress)
            .scaleEffect(0.82 + progress * 0.18)
            .offset(x: (1 - progress) * -5)
        }
        .frame(width: size + 6, height: size + 6)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isPlaying)
    }
}


// MARK: - Native navigation

struct CoNavigationStack<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .background(CoNavigationSurfaceClearer())
        }
    }
}

/// 带可编程路径的导航堆栈，用于从卡片点击进入统一的详情页。
struct CoNavigationStackWithPath<Route: Hashable, Content: View>: View {
    @Binding var path: [Route]
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack(path: $path) {
            content()
                .background(CoNavigationSurfaceClearer())
        }
    }
}

private var coScrollFadeObserverAssociationKey: UInt8 = 0

private final class CoScrollFadeObserver: NSObject {
    private weak var scrollView: UIScrollView?
    private var observations: [NSKeyValueObservation] = []
    private var updateScheduled = false
    private var lastTopFade: Bool?
    private var lastBottomFade: Bool?
    private var lastSize = CGSize.zero

    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
        super.init()
        observations = [
            scrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
            scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
        ]
        updateMask()
    }

    func refresh() {
        scheduleUpdate()
    }

    private func scheduleUpdate() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.scheduleUpdate() }
            return
        }
        guard !updateScheduled else { return }
        updateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateScheduled = false
            self.updateMask()
        }
    }

    private func updateMask() {
        guard let scrollView, scrollView.bounds.height > 1 else { return }
        let topLimit = -scrollView.adjustedContentInset.top
        let bottomLimit = max(
            topLimit,
            scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )
        let canScrollVertically = bottomLimit > topLimit + 1
        let showTopFade = canScrollVertically && scrollView.contentOffset.y > topLimit + 1
        let showBottomFade = canScrollVertically && scrollView.contentOffset.y < bottomLimit - 1
        let size = scrollView.bounds.size

        guard lastTopFade != showTopFade || lastBottomFade != showBottomFade || lastSize != size else {
            WCLGFadeContentMaskUpdateFrame(scrollView)
            return
        }

        lastTopFade = showTopFade
        lastBottomFade = showBottomFade
        lastSize = size
        WCLGFadeContentMaskApply(scrollView, 0, showTopFade ? 42 : 0, 0, showBottomFade ? 54 : 0)
    }
}

private enum CoScrollFadeInstaller {
    private static var lastScanByWindow: [ObjectIdentifier: TimeInterval] = [:]
    private static var isScanning = false

    static func scan(window: UIWindow?, force: Bool = false) {
        guard let window, !isScanning else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let windowID = ObjectIdentifier(window)
        if !force, now - (lastScanByWindow[windowID] ?? 0) < 0.75 { return }
        lastScanByWindow[windowID] = now
        isScanning = true
        defer { isScanning = false }

        func visit(_ view: UIView) {
            if let scrollView = view as? UIScrollView {
                if let observer = objc_getAssociatedObject(scrollView, &coScrollFadeObserverAssociationKey) as? CoScrollFadeObserver {
                    observer.refresh()
                } else {
                    let observer = CoScrollFadeObserver(scrollView: scrollView)
                    objc_setAssociatedObject(
                        scrollView,
                        &coScrollFadeObserverAssociationKey,
                        observer,
                        .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                    )
                }
            }
            view.subviews.forEach(visit)
        }

        visit(window)
    }
}

private final class CoScrollFadeProbeController: UIViewController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CoScrollFadeInstaller.scan(window: view.window)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CoScrollFadeInstaller.scan(window: view.window, force: true)
    }
}

struct CoScrollFadeProbe: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = CoScrollFadeProbeController()
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        CoScrollFadeInstaller.scan(window: uiViewController.view.window)
    }
}

/// SwiftUI 的 NavigationStack 会在透明内容后方保留系统默认底色。
/// 将导航容器和承载控制器设为透明后，iPad 横屏页面才能透出根层唯一的主页壁纸。
private struct CoNavigationSurfaceClearer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = CoScrollFadeProbeController()
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            var current: UIViewController? = uiViewController
            while let controller = current {
                controller.view.backgroundColor = .clear
                if let navigationController = controller as? UINavigationController {
                    navigationController.view.backgroundColor = .clear
                    navigationController.topViewController?.view.backgroundColor = .clear
                    break
                }
                current = controller.parent
            }
            CoScrollFadeInstaller.scan(window: uiViewController.view.window)
        }
    }
}

extension View {
    /// 类型化导航目的地。
    func coNavigationDestination<Route: Hashable, Destination: View>(
        for route: Route.Type,
        @ViewBuilder destination: @escaping (Route) -> Destination
    ) -> some View {
        navigationDestination(for: route, destination: destination)
    }
}

/// 弹窗尺寸（自定义枚举）
enum CoDetent {
    case medium
    case large
    case fraction(CGFloat)
    case height(CGFloat)
}

/// 弹窗尺寸与拖拽指示条
struct CoSheetModifier: ViewModifier {
    let detents: [CoDetent]
    var dragIndicator: Bool?

    private static func makeDetents(_ detents: [CoDetent]) -> Set<PresentationDetent> {
        var result: Set<PresentationDetent> = []
        for detent in detents {
            switch detent {
            case .medium: result.insert(.medium)
            case .large: result.insert(.large)
            case .fraction(let f): result.insert(.fraction(f))
            case .height(let h): result.insert(.height(h))
            }
        }
        return result
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if let dragIndicator {
            content
                .presentationDetents(Self.makeDetents(detents))
                .presentationDragIndicator(dragIndicator ? .visible : .hidden)
        } else {
            content
                .presentationDetents(Self.makeDetents(detents))
        }
    }
}

/// Clear the UIKit presentation host used by a translucent sheet.
/// SwiftUI's clear presentation background does not clear every intermediate
/// host on older system builds, which can leave a solid white surface behind
/// an otherwise transparent liquid sheet.
struct CoSheetPresentationSurfaceClearer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        controller.view.isOpaque = false
        controller.view.isUserInteractionEnabled = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            var current: UIViewController? = uiViewController
            var depth = 0
            while let controller = current, depth < 10 {
                controller.view.backgroundColor = .clear
                controller.view.isOpaque = false
                controller.parent?.view.backgroundColor = .clear
                controller.parent?.view.isOpaque = false
                controller.presentationController?.containerView?.backgroundColor = .clear
                controller.presentationController?.containerView?.isOpaque = false
                controller.presentationController?.presentedView?.backgroundColor = .clear
                controller.presentationController?.presentedView?.isOpaque = false
                current = controller.parent
                depth += 1
            }
        }
    }
}

extension View {
    /// 主页在 iOS 26+ 使用透明导航栏，让壁纸和内容可延伸到顶部安全区域。
    @ViewBuilder
    func coHomeNavigationBarTransparent() -> some View {
        self.toolbarBackground(.hidden, for: .navigationBar)
    }

    /// 隐藏滚动条
    @ViewBuilder
    func coScrollIndicatorsHidden() -> some View {
        self.scrollIndicators(.hidden)
    }

    /// 滚动时收起键盘
    @ViewBuilder
    func coScrollDismissesKeyboard() -> some View {
        self.scrollDismissesKeyboard(.interactively)
    }

    /// 隐藏滚动内容默认背景
    @ViewBuilder
    func coScrollContentBackgroundHidden() -> some View {
        self.scrollContentBackground(.hidden)
    }

}

// MARK: - 我的页隐藏歌单存储（旧线 1.8.5，只藏显示、不删歌单）
// 按酷狗账号 userId 区分键：beans.hiddenPlaylists.<userId>，未登录时为 "local"。
// 每条存 "id|name"（恢复入口靠名字展示，靠 id 恢复），换号后各号的隐藏互不串。
struct CoHiddenPlaylists {
    static func key(userId: String) -> String {
        "co.hiddenPlaylists.\(userId.isEmpty ? "local" : userId)"
    }
    static func load(userId: String) -> [(id: Int, name: String)] {
        let raw = UserDefaults.standard.stringArray(forKey: key(userId: userId)) ?? []
        return raw.compactMap { s in
            guard let sep = s.firstIndex(of: "|"), let id = Int(s[..<sep]) else { return nil }
            return (id: id, name: String(s[s.index(after: sep)...]))
        }
    }
    static func save(userId: String, entries: [(id: Int, name: String)]) {
        UserDefaults.standard.set(entries.map { "\($0.id)|\($0.name)" }, forKey: key(userId: userId))
    }
    static func allAccounts() -> [(userId: String, entries: [(id: Int, name: String)])] {
        UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("co.hiddenPlaylists.") }
            .sorted()
            .map { (userId: String($0.dropFirst("co.hiddenPlaylists.".count)), entries: load(userId: String($0.dropFirst("co.hiddenPlaylists.".count)))) }
            .filter { !$0.entries.isEmpty }
    }
}

// MARK: - 歌单本地覆盖层（只在 Co 里生效，不同步到酷狗官方 App）
// 原因：酷狗接口里只有 createPlaylist(name:)（/v5/add_list，name only，无 cover 参数），
// 没有重命名、没有改封面的接口，编一个“已同步到酷狗”就是假功能。所以改名、改封面
// 只存本机：名字存 UserDefaults JSON（按酷狗歌单 id），封面存沙盒文件（按歌单 id 命名，
// 最长边 1600、JPEG 0.85，与我的页头部壁纸同规格）。显示时优先读覆盖层，没有就回落
// 服务端原值；服务端刷新（SyncedPlaylistCache）只换缓存，不动覆盖层，所以刷新后不丢。
// 封面文件本身不上传、不进公开仓库。
final class CoPlaylistOverrides: ObservableObject {
    static let shared = CoPlaylistOverrides()
    @Published private(set) var revision = 0

    private struct Entry: Codable {
        var name: String?
        var hasCover: Bool
    }

    private static let defaultsKey = "co.playlistOverrides.v1"
    private var entries: [String: Entry] = [:]

    private init() { load() }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
        revision &+= 1
    }

    func customName(for id: Int) -> String? {
        guard let name = entries[String(id)]?.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return name
    }

    func hasCustomCover(for id: Int) -> Bool {
        guard entries[String(id)]?.hasCover == true else { return false }
        return FileManager.default.fileExists(atPath: CoPlaylistCoverFiles.fileURL(forKugouID: id).path)
    }

    func displayName(for playlist: Playlist) -> String {
        customName(for: playlist.id) ?? playlist.name
    }

    func coverURL(for playlist: Playlist) -> URL? {
        hasCustomCover(for: playlist.id) ? CoPlaylistCoverFiles.fileURL(forKugouID: playlist.id) : playlist.coverURL
    }

    func coverImage(for id: Int) -> UIImage? {
        guard hasCustomCover(for: id) else { return nil }
        return UIImage(contentsOfFile: CoPlaylistCoverFiles.fileURL(forKugouID: id).path)
    }

    func setName(id: Int, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var entry = entries[String(id)] ?? Entry(name: nil, hasCover: false)
        entry.name = trimmed.isEmpty ? nil : trimmed
        if entry.name == nil && !entry.hasCover {
            entries.removeValue(forKey: String(id))
        } else {
            entries[String(id)] = entry
        }
        save()
    }

    func clearName(id: Int) {
        setName(id: id, name: "")
    }

    @discardableResult
    func setCover(id: Int, image: UIImage) -> Bool {
        guard let url = CoPlaylistCoverFiles.save(image: image, fileName: "kugou-\(id).jpg") else { return false }
        _ = url
        var entry = entries[String(id)] ?? Entry(name: nil, hasCover: false)
        entry.hasCover = true
        entries[String(id)] = entry
        save()
        return true
    }

    func clearCover(id: Int) {
        try? FileManager.default.removeItem(at: CoPlaylistCoverFiles.fileURL(forKugouID: id))
        var entry = entries[String(id)] ?? Entry(name: nil, hasCover: false)
        entry.hasCover = false
        if entry.name == nil {
            entries.removeValue(forKey: String(id))
        } else {
            entries[String(id)] = entry
        }
        save()
    }
}

enum CoPlaylistCoverFiles {
    private static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CoPlaylistCovers", isDirectory: true)
    }

    static func fileURL(forKugouID id: Int) -> URL {
        directory.appendingPathComponent("kugou-\(id).jpg")
    }

    /// 与我的页头部壁纸同规格存一张图：最长边 1600、JPEG 0.85。返回写好的文件 URL，写失败返回 nil。
    static func save(image raw: UIImage, fileName: String) -> URL? {
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
        let url = directory.appendingPathComponent(fileName)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            guard let jpeg = img.jpegData(compressionQuality: 0.85) else { return nil }
            try jpeg.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - 封面图

/// 固定尺寸的扫光骨架，占位期间不改变父布局尺寸。
struct CoShimmerSkeleton: View {
    var cornerRadius: CGFloat = 12
    var baseOpacity: Double = 0.12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var shimmerActive = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let bandWidth = max(width * 0.6, 1)
            let baseColor = colorScheme == .dark ? Color.white : Color.black
            let highlightColor = colorScheme == .dark ? Color.white : Color.white

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(baseColor.opacity(max(baseOpacity, 0.14)))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(baseColor.opacity(0.10), lineWidth: 0.6)
                    }

                if reduceMotion {
                    Color.clear
                } else {
                    LinearGradient(
                        colors: [
                            .clear,
                            highlightColor.opacity(0.22),
                            baseColor.opacity(0.08),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: bandWidth, height: height)
                    .offset(x: shimmerActive ? width * 1.6 : -bandWidth)
                    .onAppear {
                        guard !shimmerActive else { return }
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            shimmerActive = true
                        }
                    }
                    .onDisappear {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            shimmerActive = false
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

struct CoverImage: View {
    let url: URL?
    var song: Song? = nil
    var size: CGFloat
    var aspectRatio: CGFloat = 1
    var cornerRadius: CGFloat = 12
    /// 封面未加载时的提示文字（播放器大封面用：等待开始播放）；nil 显示中性图标
    var emptyHint: String? = nil
    var playsCoverVideoAudio = false

    @StateObject private var imageLoader = CoCoverImageLoader()
    @ObservedObject private var customCovers = CustomSongCoverStore.shared

    // 布局尺寸完全由外层固定容器决定；AsyncImage 只放在 overlay 中渲染，
    // 图片加载完成与否都不会改变任何布局尺寸（根治"封面加载后错乱"）。
    var body: some View {
        let resolvedURL = customCovers.url(for: song) ?? customCovers.resolvedURL(for: url)
        let usesCustomMediaRenderer = customCovers.isStoredCover(resolvedURL)
        // Do not synchronously decode disk cache entries from body. A scroll can
        // create many CoverImage values in one frame, so body only reads the
        // loader's in-memory result while disk rehydration runs off the main thread.
        // Keep already decoded covers visible while a recycled row rebinds its
        // loader. This avoids a skeleton/white frame when a cached detail page
        // is reopened or scrolled back into view.
        let cachedImage = imageLoader.image(for: resolvedURL)
            ?? CoCoverImageStore.memoryImage(for: resolvedURL)
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.coGlassFill)
            .frame(width: size * max(aspectRatio, 0.1), height: size)
            .overlay {
                Group {
                    if let resolvedURL, usesCustomMediaRenderer {
                        CustomCoverMediaView(
                            url: resolvedURL,
                            isMuted: !playsCoverVideoAudio || !customCovers.videoAudioEnabled(for: resolvedURL)
                        )
                    } else if let image = cachedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .transaction { transaction in
                                transaction.animation = nil
                            }
                    } else if url == nil || imageLoader.didFail {
                        placeholderIcon
                    } else {
                        // Cover placeholders must stay visually stable while a
                        // cached/network image is decoded. The animated white
                        // shimmer was the source of the one-frame flash seen
                        // across detail pages and the Discover screen.
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.coGlassFill.opacity(0.72))
                    }
                }
                .frame(width: size * max(aspectRatio, 0.1), height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                if !usesCustomMediaRenderer { imageLoader.load(url: resolvedURL) }
            }
            .onChange(of: url) { nextURL in
                let resolvedURL = customCovers.url(for: song) ?? customCovers.resolvedURL(for: nextURL)
                if !customCovers.isStoredCover(resolvedURL) {
                    imageLoader.load(url: resolvedURL)
                }
            }
            .onChange(of: song?.identityKey) { _ in
                let resolvedURL = customCovers.url(for: song) ?? customCovers.resolvedURL(for: url)
                if !customCovers.isStoredCover(resolvedURL) {
                    imageLoader.load(url: resolvedURL)
                }
            }
    }

    private var placeholderIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.coGlassFill)
            if let emptyHint {
                Text(emptyHint)
                    .font(CoFont.appFont(max(11, min(size * 0.09, 15)), .medium))
                    .foregroundStyle(Color.coComment)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            } else {
                // 中性等待图标（不再使用音乐音符）
                Image(systemName: "waveform")
                    .font(.system(size: size * 0.28, weight: .medium))
                    .foregroundStyle(Color.coComment)
            }
        }
            .frame(width: size * max(aspectRatio, 0.1), height: size)
    }
}

/// 所有歌曲封面共用的内存与 URLCache 缓存，避免详情页每次进入都重新下载封面。
/// 封面图片共享缓存：内存缓存负责当前页面快速显示，URLCache 负责跨页面和重启后的磁盘缓存。
/// 预加载器与 CoverImage 使用同一个 URLSession，避免启动时预加载的图片无法被页面复用。
final class CoCoverImageStore {
    static let memoryCache = NSCache<NSURL, UIImage>()
    private static let diskCacheLimit = 300 * 1024 * 1024
    private static let diskQueue = DispatchQueue(label: "com.beans.music.cover-image-cache", qos: .utility)
    private static let diskCacheDirectory: URL = {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = root.appendingPathComponent("CoCoverImageFiles", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            diskPath: "CoCoverImageCache"
        )
        return URLSession(configuration: configuration)
    }()

    /// Read decoded memory or disk-backed URLCache data synchronously.
    /// CoverImage uses this during its first body evaluation to avoid a
    /// skeleton flash when the cover was already cached.
    static func cachedImage(for url: URL?) -> UIImage? {
        guard let url else { return nil }
        if url.isFileURL {
            return CustomCoverMedia.previewImage(at: url)
        }
        if let image = memoryCache.object(forKey: url as NSURL) {
            return image
        }
        let fileURL = diskFileURL(for: url)
        if let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
           let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: url as NSURL)
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
            return image
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        guard let response = session.configuration.urlCache?.cachedResponse(for: request),
              let image = UIImage(data: response.data) else { return nil }
        persist(data: response.data, for: url)
        memoryCache.setObject(image, forKey: url as NSURL)
        return image
    }

    /// Return only the decoded in-memory image. This is intentionally cheap
    /// enough to use during SwiftUI body evaluation; disk rehydration remains
    /// asynchronous in `loadCachedImage`.
    static func memoryImage(for url: URL?) -> UIImage? {
        guard let url, !url.isFileURL else { return nil }
        return memoryCache.object(forKey: url as NSURL)
    }

    /// Rehydrate persisted covers away from SwiftUI's rendering path. The
    /// completion always returns on the main queue so callers can update view state.
    static func loadCachedImage(for url: URL, completion: @escaping (UIImage?) -> Void) {
        if url.isFileURL {
            DispatchQueue.main.async {
                completion(CustomCoverMedia.previewImage(at: url))
            }
            return
        }
        if let image = memoryCache.object(forKey: url as NSURL) {
            DispatchQueue.main.async { completion(image) }
            return
        }

        let fileURL = diskFileURL(for: url)
        diskQueue.async {
            let image: UIImage?
            if let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
               let cachedImage = UIImage(data: data) {
                memoryCache.setObject(cachedImage, forKey: url as NSURL)
                try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
                image = cachedImage
            } else {
                var request = URLRequest(url: url)
                request.cachePolicy = .returnCacheDataElseLoad
                if let response = session.configuration.urlCache?.cachedResponse(for: request),
                   let cachedImage = UIImage(data: response.data) {
                    memoryCache.setObject(cachedImage, forKey: url as NSURL)
                    persist(data: response.data, for: url)
                    image = cachedImage
                } else {
                    image = nil
                }
            }
            DispatchQueue.main.async { completion(image) }
        }
    }

    static func clearCache(completion: @escaping (Bool) -> Void) {
        memoryCache.removeAllObjects()
        session.configuration.urlCache?.removeAllCachedResponses()
        let directory = diskCacheDirectory
        diskQueue.async {
            do {
                if FileManager.default.fileExists(atPath: directory.path) {
                    try FileManager.default.removeItem(at: directory)
                }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                DispatchQueue.main.async { completion(true) }
            } catch {
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    /// 分批下载封面，避免首次启动时同时创建大量网络任务。
    static func prefetch(urls: Set<URL>) async {
        let uniqueURLs = Array(urls)
        guard !uniqueURLs.isEmpty else { return }

        let batchSize = 6
        for start in stride(from: 0, to: uniqueURLs.count, by: batchSize) {
            if Task.isCancelled { return }
            let end = min(start + batchSize, uniqueURLs.count)
            let batch = Array(uniqueURLs[start..<end])
            await withTaskGroup(of: Void.self) { group in
                for url in batch {
                    group.addTask {
                        await prefetch(url: url)
                    }
                }
            }
        }
    }

    private static func prefetch(url: URL) async {
        if memoryCache.object(forKey: url as NSURL) != nil { return }
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  200..<300 ~= http.statusCode,
                  !data.isEmpty else { return }
            // 显式写入磁盘缓存，兼容部分封面服务器没有返回可缓存响应头的情况。
            session.configuration.urlCache?.storeCachedResponse(
                CachedURLResponse(response: response, data: data),
                for: request
            )
            persist(data: data, for: url)
        } catch {
            // 预加载失败不影响页面显示，进入页面后 CoverImage 仍会按需重试。
        }
    }

    static func persist(data: Data, for url: URL) {
        guard !data.isEmpty else { return }
        let destination = diskFileURL(for: url)
        diskQueue.async {
            do {
                try FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
                try data.write(to: destination, options: .atomic)
                trimDiskCacheIfNeeded()
            } catch {
                // Disk caching is opportunistic; rendering falls back to URLCache or the network.
            }
        }
    }

    private static func diskFileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let filename = digest.map { String(format: "%02x", $0) }.joined()
        return diskCacheDirectory.appendingPathComponent(filename).appendingPathExtension("cover")
    }

    private static func trimDiskCacheIfNeeded() {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: diskCacheDirectory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return }
        var entries = files.compactMap { url -> (URL, Int, Date)? in
            guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }
        var total = entries.reduce(0) { $0 + $1.1 }
        guard total > diskCacheLimit else { return }
        entries.sort { $0.2 < $1.2 }
        for entry in entries where total > diskCacheLimit {
            try? FileManager.default.removeItem(at: entry.0)
            total -= entry.1
        }
    }
}

@MainActor
private final class CoCoverImageLoader: ObservableObject {

    @Published private(set) var image: UIImage?
    @Published private(set) var didFail = false
    private var task: Task<Void, Never>?
    private var loadedURL: URL?
    private var cacheLookupURL: URL?

    /// SwiftUI may keep this StateObject alive while a row changes songs. Never
    /// render the previous request's bitmap during that handoff.
    func image(for url: URL?) -> UIImage? {
        loadedURL == url ? image : nil
    }

    func load(url: URL?) {
        if loadedURL == url {
            // `onAppear` can fire repeatedly for a recycled LazyVStack row.
            // Never clear a valid bitmap or start a second request for the
            // same URL in that case.
            if image != nil || task != nil || cacheLookupURL == url || didFail {
                return
            }
        } else {
            task?.cancel()
            cacheLookupURL = nil
            loadedURL = url
            image = nil
            didFail = false
        }

        guard let url else {
            image = nil
            return
        }

        if let cachedImage = CoCoverImageStore.memoryImage(for: url) {
            image = cachedImage
            return
        }

        cacheLookupURL = url
        CoCoverImageStore.loadCachedImage(for: url) { [weak self] cachedImage in
            guard let self, self.loadedURL == url else { return }
            self.cacheLookupURL = nil
            if let cachedImage {
                self.image = cachedImage
                return
            }
            if url.isFileURL {
                self.didFail = true
                return
            }
            self.task = Task { [weak self] in
                do {
                    var request = URLRequest(url: url)
                    request.cachePolicy = .returnCacheDataElseLoad
                    let (data, response) = try await CoCoverImageStore.session.data(for: request)
                    guard !Task.isCancelled, let self, self.loadedURL == url else { return }
                    guard let http = response as? HTTPURLResponse,
                          200..<300 ~= http.statusCode,
                          let image = UIImage(data: data) else {
                        self.didFail = true
                        return
                    }
                    CoCoverImageStore.session.configuration.urlCache?.storeCachedResponse(
                        CachedURLResponse(response: response, data: data),
                        for: request
                    )
                    CoCoverImageStore.persist(data: data, for: url)
                    CoCoverImageStore.memoryCache.setObject(image, forKey: url as NSURL)
                    self.image = image
                    self.task = nil
                } catch {
                    guard !Task.isCancelled, let self, self.loadedURL == url else { return }
                    self.didFail = true
                    self.task = nil
                }
            }
        }
    }

    deinit { task?.cancel() }
}

// MARK: - 会员标识小标（SVIP 金色 / VIP 红色）

struct VIPBadgeView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(CoFont.appFont(9, .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(text == "SVIP" ? Color(red: 0.85, green: 0.62, blue: 0.18) : Color.coThemeRed))
    }
}

// MARK: - 玻璃图标按钮（清透 + 按压动效）

struct GlassIconButton: View {
    @EnvironmentObject private var theme: ThemeStore
    @AppStorage("co.uiStyle") private var uiStyleRaw = CoUIStyle.liquid.rawValue
    let systemName: String
    var size: CGFloat = 44
    var active = false
    var forceLiquid = false
    let action: () -> Void

    private var isNativeClean: Bool {
        CoUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    var body: some View {
        let _ = theme.accent
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * (isNativeClean ? 0.42 : 0.38), weight: .semibold))
                .foregroundStyle(active ? Color.coAmber : (isNativeClean ? Color.primary : Color.coLabel))
                .frame(width: size, height: size)
                .background {
                    if isNativeClean && !forceLiquid {
                        Circle().fill(active ? Color.coAmber.opacity(0.12) : .clear)
                    } else {
                        CoGlass(shape: Circle())
                    }
                }
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(GlassPressButtonStyle())
    }
}

// MARK: - 玻璃按钮（清透 + 按压动效）

struct GlassButton: View {
    @EnvironmentObject private var theme: ThemeStore
    @AppStorage("co.uiStyle") private var uiStyleRaw = CoUIStyle.liquid.rawValue
    let title: String
    var systemName: String?
    var prominent = false
    var forceLiquid = false
    var expandsHorizontally = false
    let action: () -> Void

    private var isNativeClean: Bool {
        CoUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    var body: some View {
        let _ = theme.accent
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemName {
                    Image(systemName: systemName)
                }
                Text(LocalizedStringKey(title))
            }
            .font(CoFont.appFont(15, .semibold))
            .foregroundStyle(prominent ? Color.white : Color.coLabel)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: expandsHorizontally ? .infinity : nil)
            .background {
                if prominent {
                    ZStack {
                        CoGlass(shape: Capsule(), forceLiquid: true)
                        Capsule().fill(Color.coAmber.opacity(0.78))
                    }
                } else if forceLiquid {
                    CoGlass(shape: Capsule(), forceLiquid: true)
                } else if isNativeClean {
                    Capsule().fill(Color.primary.opacity(0.055))
                } else {
                    Capsule().fill(.thinMaterial)
                }
            }
            .overlay {
                if isNativeClean && !prominent && !forceLiquid {
                    Capsule().strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.7)
                }
            }
            .clipShape(Capsule())
        }
        .buttonStyle(GlassPressButtonStyle())
    }
}

// MARK: - 区块标题

struct SectionHeader: View {
    @AppStorage("co.uiStyle") private var uiStyleRaw = CoUIStyle.liquid.rawValue
    let title: String
    var trailing: String?
    var titleColor: Color = Color.coLabel
    var trailingColor: Color = Color.coComment
    var onTrailingTap: (() -> Void)?

    private var isNativeClean: Bool {
        CoUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(LocalizedStringKey(title))
                .font(CoFont.appFont(isNativeClean ? 26 : 21, .bold))
                .foregroundStyle(titleColor)
            Spacer()
            if let trailing {
                Button {
                    onTrailingTap?()
                } label: {
                    HStack(spacing: 3) {
                        Text(LocalizedStringKey(trailing))
                            .font(CoFont.appFont(13, .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(trailingColor)
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.9))
            }
        }
    }
}

// MARK: - 空态 / 错误 / 加载

struct EmptyStateView: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.coComment)
            Text(LocalizedStringKey(text))
                .font(CoFont.appFont(14))
                .foregroundStyle(Color.coComment)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void
    /// 强制深色页专用（与 SongCell.forceDarkText 同理）：默认 false，其他页不动。
    var forceDarkText = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(forceDarkText ? .white.opacity(0.6) : Color.coComment)
            Text(message)
                .font(CoFont.appFont(14))
                .foregroundStyle(forceDarkText ? .white.opacity(0.6) : Color.coComment)
                .multilineTextAlignment(.center)
            GlassButton(title: "重试", systemName: "arrow.clockwise", action: retry)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct LoadingStateView: View {
    @EnvironmentObject private var theme: ThemeStore

    var body: some View {
        let _ = theme.accent
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                CoShimmerSkeleton(cornerRadius: 8)
                    .frame(width: 128, height: 22)
                Spacer(minLength: 0)
                CoShimmerSkeleton(cornerRadius: 8)
                    .frame(width: 72, height: 22)
            }

            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        CoShimmerSkeleton(cornerRadius: 14)
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                        CoShimmerSkeleton(cornerRadius: 5)
                            .frame(height: 12)
                            .frame(maxWidth: index == 2 ? 74 : 116, alignment: .leading)
                    }
                }
            }

            ForEach(0..<3, id: \.self) { index in
                HStack(spacing: 12) {
                    CoShimmerSkeleton(cornerRadius: 10)
                        .frame(width: 54, height: 54)
                    VStack(alignment: .leading, spacing: 8) {
                        CoShimmerSkeleton(cornerRadius: 5)
                            .frame(height: 12)
                            .frame(maxWidth: index == 1 ? 170 : 230, alignment: .leading)
                        CoShimmerSkeleton(cornerRadius: 5)
                            .frame(width: 112, height: 10)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 28)
    }
}

struct CoSongRowsLoadingState: View {
    var rowCount = 8
    var coverSize: CGFloat = 46
    var showsRank = false
    var horizontalPadding: CGFloat = 20

    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(0..<rowCount, id: \.self) { index in
                HStack(spacing: 12) {
                    if showsRank {
                        CoShimmerSkeleton(cornerRadius: 5)
                            .frame(width: 24, height: 18)
                    }
                    CoShimmerSkeleton(cornerRadius: coverSize / 5)
                        .frame(width: coverSize, height: coverSize)
                    VStack(alignment: .leading, spacing: 8) {
                        CoShimmerSkeleton(cornerRadius: 5)
                            .frame(height: 13)
                            .frame(maxWidth: index.isMultiple(of: 3) ? 210 : 150, alignment: .leading)
                        CoShimmerSkeleton(cornerRadius: 5)
                            .frame(width: index.isMultiple(of: 2) ? 128 : 86, height: 10)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, horizontalPadding)
    }
}

struct CoDetailSongsLoadingState: View {
    var coverSize: CGFloat = 92
    var rowCount = 9
    var showsRank = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    CoShimmerSkeleton(cornerRadius: 16)
                        .frame(width: coverSize, height: coverSize)
                    VStack(alignment: .leading, spacing: 9) {
                        CoShimmerSkeleton(cornerRadius: 6)
                            .frame(height: 18)
                            .frame(maxWidth: 220, alignment: .leading)
                        CoShimmerSkeleton(cornerRadius: 5)
                            .frame(width: 130, height: 12)
                        CoShimmerSkeleton(cornerRadius: 5)
                            .frame(width: 84, height: 11)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    CoShimmerSkeleton(cornerRadius: 16)
                        .frame(height: 42)
                    CoShimmerSkeleton(cornerRadius: 16)
                        .frame(height: 42)
                }
                .padding(.horizontal, 16)

                CoSongRowsLoadingState(rowCount: rowCount, coverSize: 46, showsRank: showsRank, horizontalPadding: 16)
            }
            .padding(.top, 8)
            .padding(.bottom, 170)
        }
        .coScrollIndicatorsHidden()
    }
}

struct CoLongDescriptionSheet: View {
    let title: String
    let text: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CoNavigationStack {
            ScrollView {
                Text(text)
                    .font(CoFont.appFont(15))
                    .foregroundStyle(Color.coLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
            }
            .coScrollIndicatorsHidden()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(CoFont.appFont(15, .semibold))
                }
            }
        }
    }
}

// MARK: - 二维码

struct QRCodeView: View {
    let text: String
    var size: CGFloat = 220

    var body: some View {
        if let image = Self.generateQR(from: text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            EmptyView()
        }
    }

    private static func generateQR(from text: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - 当前播放指示（均衡器动效）

struct NowPlayingIndicator: View {
    @EnvironmentObject private var theme: ThemeStore
    @State private var animating = false

    private let barScales: [CGFloat] = [0.62, 1.0, 0.78]

    var body: some View {
        let _ = theme.accent
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Color.coAmber)
                    // Keep the layout box fixed. Animating the frame height
                    // made legacy SwiftUI re-layout a detail row while it was
                    // being reused, which looked like a floating waveform.
                    .frame(width: 3, height: 14)
                    .scaleEffect(
                        y: animating ? barScales[index] : 0.36,
                        anchor: .bottom
                    )
                    .animation(
                        .easeInOut(duration: 0.35)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.12),
                        value: animating
                    )
            }
        }
        .frame(height: 16)
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}


// MARK: - 板块进入动画（首页错落渐入，纯视觉不影响布局）

struct SectionEntrance: ViewModifier {
    @State private var appeared = false
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    /// 页面内板块错落渐入：opacity + 轻微上移，不影响布局
    func sectionEntrance(delay: Double = 0) -> some View {
        modifier(SectionEntrance(delay: delay))
    }
}

// MARK: - 全局轻提示（Toast，收藏/歌单等操作反馈用）

@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    @Published var message: String?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ text: String, duration: Double = 2.2) {
        dismissTask?.cancel()
        message = text
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }
}

struct ToastView: View {
    @ObservedObject var center: ToastCenter
    @EnvironmentObject private var theme: ThemeStore

    var body: some View {
        let _ = theme.accent
        Group {
            if let message = center.message {
                Text(message)
                    .font(CoFont.appFont(14, .medium))
                    .foregroundStyle(Color.coLabel)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.8)
                            }
                    }
                    .clipShape(Capsule())
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        .padding(.horizontal, 30)
        .padding(.bottom, 92)
        .opacity(center.message == nil ? 0 : 1)
        .offset(y: center.message == nil ? 16 : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: center.message)
        .allowsHitTesting(false)
    }
}


// 横屏底部涟漪：借用 GitHub 上 SwiftUI 版 Siri 波形（noahchalifour/swiftui-siri-waveform-view，
// 源自经典 SCSiriWaveformView）的做法，改成 Co 的一条线形式。
// 一条线、不是三条杠：线是 3 条正弦曲线之和（振幅/频率/相位各不相同），
// 每条曲线再乘一个中间高、两边低的包络（Siri 的 g 函数），所以波浪中间起伏大、两边收拢，
// 像水面涟漪，不是一条通栏的杠；整体高度由音频 tap 的真实电平定（起快落慢，暂停归平静），
// 安静时有保底高度，不会塌成直线。颜色自适应背景（调用方传本页的主色）。
struct CoLandscapeRippleView: View {
    var isPlaying: Bool
    var color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedLevel = 0.0
    @State private var phase = 0.0

    var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                Canvas { ctx, size in
                    let width = size.width, height = size.height
                    let midX = width / 2
                    // Siri 的保底：安静时也有波形，不塌成直线；音乐越响越高（最高约 19pt，不出 44pt 的框）。
                    let amp = (0.35 + displayedLevel) * 14
                    var path = Path()
                    var x: CGFloat = 0
                    var first = true
                    while x <= width {
                        // Siri 的横轴缩放：把 [-midX, midX] 映射到 [-9, 9]，再算正弦与包络。
                        let scaledX = Double((x - midX) / (midX / 9))
                        var wave = 0.0
                        // 3 条曲线之和（Siri 的做法）：振幅 A、频率 k、相位速度各不相同，振幅和为 1，波形不会超出框。
                        for (a, k, speed, offset) in [(0.5, 0.7, 1.0, 0.0), (0.3, 0.8, 1.6, 1.3), (0.2, 0.65, 0.7, 2.1)] {
                            let t = phase * speed + offset
                            let sine = a * sin(k * scaledX - t)
                            // Siri 的包络 g：中间高、两边低，K=4，中心比正弦相位晚 π/2。
                            let d = k * scaledX - (t - .pi / 2)
                            let g = pow(4 / (4 + d * d), 4)
                            wave += sine * g
                        }
                        let y = height - 19 - CGFloat(wave * amp)
                        if first {
                            path.move(to: CGPoint(x: x, y: y))
                            first = false
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        x += 3
                    }
                    let opacity = min(0.75, 0.35 + displayedLevel * 0.4)
                    ctx.stroke(path, with: .color(color.opacity(opacity)), lineWidth: 1.5)
                }
                .onChange(of: context.date) { _, _ in
                    phase += 0.05
                    let raw = CoEqualizer.shared.audioLevel()
                    if raw > displayedLevel {
                        displayedLevel = raw
                    } else {
                        displayedLevel *= isPlaying ? 0.88 : 0.78
                    }
                }
            }
            .frame(height: 44)
            .allowsHitTesting(false)
        }
    }
}
