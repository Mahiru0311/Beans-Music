import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - 工具

func beansSongCountText(_ count: Int) -> String {
    beansLocalized("\(count) 首", "\(count) songs")
}

func beansLocalSongCountText(_ count: Int) -> String {
    beansLocalized("\(count) 首 · 本机", "\(count) songs · On device")
}

func beansTimeString(_ seconds: Double) -> String {
    let total = max(0, Int(seconds))
    return String(format: "%d:%02d", total / 60, total % 60)
}

// MARK: - 触感反馈（复用生成器实例，避免每次点击创建新对象造成额外开销/发热）

enum BeansHaptics {
    static let enabledKey = "beans.haptics.enabled"

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
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
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

    private var uiStyle: BeansUIStyle {
        uiStyleRaw == "outline" ? .clear : (BeansUIStyle(rawValue: uiStyleRaw) ?? .liquid)
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
                LinearGradient.beansBackdrop
            }
            if uiStyle != .nativeClean {
                Circle()
                    .fill(Color.beansAmber.opacity(0.14))
                    .frame(width: 340, height: 340)
                    .blur(radius: 100)
                    .offset(x: 150, y: -300)
                Circle()
                    .fill(Color.beansSage.opacity(0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 110)
                    .offset(x: -160, y: 340)
            }
        }
        .ignoresSafeArea()
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

struct BeansGlass<S: Shape>: View {
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue

    let shape: S
    var forceLiquid = false

    private var uiStyle: BeansUIStyle {
        uiStyleRaw == "outline" ? .clear : (BeansUIStyle(rawValue: uiStyleRaw) ?? .liquid)
    }

    private var isLiquid: Bool {
        forceLiquid || uiStyle == .liquid || uiStyle == .nativeClean
    }

    var body: some View {
        if isLiquid {
            if #available(iOS 26, *) {
                GlassEffectContainer {
                    shape
                        .fill(.clear)
                        .glassEffect(.clear, in: shape)
                }
            } else {
                shape
                    .fill(.ultraThinMaterial)
            }
        } else {
            switch uiStyle {
            case .clear, .liquid:
                shape
                    .fill(.ultraThinMaterial)
            case .compact:
                shape
                    .fill(Color.beansGlassFill.opacity(0.74))
            case .nativeClean:
                shape
                    .fill(Color.beansGlassFill.opacity(0.62))
            }
        }
    }
}

/// 统一表面容器：Apple 简洁样式使用低存在感的平面底色，
/// 其他样式继续沿用原有的玻璃材质，避免页面局部出现不同质感。
struct BeansSurface<S: Shape>: View {
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue

    let shape: S

    private var uiStyle: BeansUIStyle {
        uiStyleRaw == "outline" ? .clear : (BeansUIStyle(rawValue: uiStyleRaw) ?? .liquid)
    }

    var body: some View {
        BeansGlass(shape: shape)
    }
}

// MARK: - 通用卡片（跟随全局 UI 样式）

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 24
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    @ViewBuilder var content: () -> Content

    private var uiStyle: BeansUIStyle {
        uiStyleRaw == "outline" ? .clear : (BeansUIStyle(rawValue: uiStyleRaw) ?? .liquid)
    }

    private var isLiquid: Bool {
        uiStyle == .liquid || uiStyle == .nativeClean
    }

    private var resolvedCornerRadius: CGFloat {
        if uiStyle == .compact { return min(cornerRadius, 16) }
        if uiStyle == .nativeClean { return min(cornerRadius, 18) }
        return cornerRadius
    }

    private var resolvedPadding: CGFloat {
        if uiStyle == .compact { return 12 }
        if uiStyle == .nativeClean { return 13 }
        return 16
    }

    var body: some View {
        if isLiquid {
            if #available(iOS 26, *) {
                GlassEffectContainer {
                    content()
                        .padding(resolvedPadding)
                        .glassEffect(.clear, in: .rect(cornerRadius: resolvedCornerRadius))
                }
                .beansCardShadow(radius: 9, y: 3)
            } else {
                content()
                    .padding(resolvedPadding)
                    .background(RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous).fill(.ultraThinMaterial))
                    .clipShape(RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous))
                    .beansCardShadow(radius: 9, y: 3)
            }
        } else {
            content()
                .padding(resolvedPadding)
                .background {
                    RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous)
                        .fill(uiStyle == .compact ? Color.beansGlassFill.opacity(0.72) : Color.clear)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous))
                }
                .clipShape(RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous))
                .beansCardShadow(radius: 9, y: 3)
        }
    }
}

/// 播放/暂停图标切换过渡：iOS 17+ 使用符号替换动画，低版本回退透明度过渡
struct BeansSymbolReplace: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content.contentTransition(.symbolEffect(.replace))
        } else if #available(iOS 16, *) {
            content.contentTransition(.opacity)
        } else {
            content
        }
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


// MARK: - iOS 15 兼容包装（低版本自动降级）

/// iOS 16+ 使用 NavigationStack，iOS 15 回退 NavigationView（堆栈样式）
struct BeansNavigationStack<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 16, *) {
            NavigationStack { content() }
        } else {
            NavigationView { content() }.navigationViewStyle(.stack)
        }
    }
}

/// 带可编程路径的导航堆栈，用于从卡片点击进入统一的详情页。
struct BeansNavigationStackWithPath<Route: Hashable, Content: View>: View {
    @Binding var path: [Route]
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 16, *) {
            NavigationStack(path: $path) { content() }
        } else {
            NavigationView { content() }.navigationViewStyle(.stack)
        }
    }
}

extension View {
    /// iOS 16+ 的类型化导航目的地，低版本保持原有页面结构。
    @ViewBuilder
    func beansNavigationDestination<Route: Hashable, Destination: View>(
        for route: Route.Type,
        @ViewBuilder destination: @escaping (Route) -> Destination
    ) -> some View {
        if #available(iOS 16, *) {
            navigationDestination(for: route, destination: destination)
        } else {
            self
        }
    }
}

/// 弹窗尺寸（自定义枚举，避免在低版本引用 iOS 16 类型）
enum BeansDetent {
    case medium
    case large
    case fraction(CGFloat)
    case height(CGFloat)
}

/// 弹窗尺寸与拖拽指示条：iOS 16+ 生效，低版本全屏展示
struct BeansSheetModifier: ViewModifier {
    let detents: [BeansDetent]
    var dragIndicator: Bool?

    @available(iOS 16, *)
    private static func makeDetents(_ detents: [BeansDetent]) -> Set<PresentationDetent> {
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
        if #available(iOS 16, *) {
            if let dragIndicator {
                content
                    .presentationDetents(Self.makeDetents(detents))
                    .presentationDragIndicator(dragIndicator ? .visible : .hidden)
            } else {
                content
                    .presentationDetents(Self.makeDetents(detents))
            }
        } else {
            content
        }
    }
}

extension View {
    /// iOS 16+ 隐藏滚动条，低版本保持默认
    @ViewBuilder
    func beansScrollIndicatorsHidden() -> some View {
        if #available(iOS 16, *) { self.scrollIndicators(.hidden) } else { self }
    }

    /// iOS 16+ 滚动时收起键盘，低版本保持默认
    @ViewBuilder
    func beansScrollDismissesKeyboard() -> some View {
        if #available(iOS 16, *) { self.scrollDismissesKeyboard(.interactively) } else { self }
    }

    /// iOS 16+ 隐藏滚动内容默认背景，低版本保持默认
    @ViewBuilder
    func beansScrollContentBackgroundHidden() -> some View {
        if #available(iOS 16, *) { self.scrollContentBackground(.hidden) } else { self }
    }
}

// MARK: - 封面图

struct CoverImage: View {
    let url: URL?
    var size: CGFloat
    var cornerRadius: CGFloat = 12
    /// 封面未加载时的提示文字（播放器大封面用：等待开始播放）；nil 显示中性图标
    var emptyHint: String? = nil

    // 布局尺寸完全由外层固定容器决定；AsyncImage 只放在 overlay 中渲染，
    // 图片加载完成与否都不会改变任何布局尺寸（根治"封面加载后错乱"）。
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.beansGlassFill)
            .frame(width: size, height: size)
            .overlay {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(width: size, height: size)
                            .clipped()
                    case .failure:
                        placeholderIcon
                    case .empty:
                        if url == nil {
                            // 封面地址为空时：直接显示占位图标，避免一直转圈
                            placeholderIcon
                        } else {
                            ZStack {
                                placeholderIcon
                                ProgressView().tint(Color.beansAmber)
                            }
                        }
                    @unknown default:
                        placeholderIcon
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholderIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.beansGlassFill)
            if let emptyHint {
                Text(emptyHint)
                    .font(BeansFont.appFont(max(11, min(size * 0.09, 15)), .medium))
                    .foregroundStyle(Color.beansComment)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            } else {
                // 中性等待图标（不再使用音乐音符）
                Image(systemName: "waveform")
                    .font(.system(size: size * 0.28, weight: .medium))
                    .foregroundStyle(Color.beansComment)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 会员标识小标（SVIP 金色 / VIP 红色）

struct VIPBadgeView: View {
    let text: String
    /// Co 自有轻动效：仅“我的”页传入 true 时开启；其他调用点默认静态，不耗电。
    /// 动效为 2.8 秒一次的细微扫光（白光带横过徽标），无常驻定时器，视图消失即停，
    /// 并遵循系统“减弱动态效果”设置；过期/无 VIP 时不传入 true，故不显示动态。
    var animated: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerOn = false

    var body: some View {
        Text(text)
            .font(BeansFont.appFont(9, .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(text == "SVIP" ? Color(red: 0.85, green: 0.62, blue: 0.18) : Color(red: 0.93, green: 0.25, blue: 0.22)))
            .overlay {
                if animated && !reduceMotion {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.35), .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: 14)
                        .offset(x: shimmerOn ? 14 : -14)
                        .clipShape(Capsule())
                        .opacity(shimmerOn ? 1 : 0)
                }
            }
            .clipShape(Capsule())
            .onAppear {
                guard animated && !reduceMotion else { return }
                shimmerOn = false
                withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
                    shimmerOn = true
                }
            }
            .onDisappear { shimmerOn = false }
    }
}

// MARK: - Co VIP 自动徽标（wy.dwkc.cn 黑金徽标的 Co 自绘版，不抄其 webp/png 素材）
// 自动切换只看酷狗登录态：已登录且 vipType>0 → 黑底金字 + 2.8 秒扫光自动播；
// 已登录但无 VIP → 灰色静态（表示当前无 VIP，含过期情形；酷狗登录态无过期日期字段，
// 故不写“已过期”字样、不编造等级 v0-v7）；未登录 → 不显示。动效只在“我的”页可见时跑，
// 视图消失即停，遵循减弱动态效果，无常驻定时器。
// 1.8.6 发烫优化：默认徽标改为静态黑金/灰色，不再 2.8 秒循环扫光；动效只在用户选了动效款且页面可见时由动图本身播。
struct CoVIPAutoBadge: View {
    let isVIP: Bool
    let isLoggedIn: Bool

    var body: some View {
        Group {
            if isLoggedIn && isVIP {
                Text("VIP")
                    .font(BeansFont.appFont(10, .bold))
                    .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.32))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(Color.black))
                    .overlay(Capsule().stroke(Color(red: 0.85, green: 0.62, blue: 0.18).opacity(0.6), lineWidth: 0.8))
                    .clipShape(Capsule())
            } else if isLoggedIn {
                Text("VIP")
                    .font(BeansFont.appFont(10, .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(Color.white.opacity(0.16)))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Co VIP 图标目录（wy.dwkc.cn 面板分组，站主本人授权可用）
// 该站是用户自己的网站，前端面板分组为：VIP（普通/动效/已过期/特殊、v0-v7）、
// SVIP（金色）、长条形。面板里 VIP 组的 29 条链接经页面文本逐条核对，见下；
// SVIP 与长条形组的 CDN 链接未在页面文本中公开，故不编造链接，改用 Co 自绘金色/长条款。
// 重要：这些图文件多托管在 music.126.net CDN 上，该站只是引用链接，CDN 随时可能撤图
// 或拦请求；因此 Co 不把任何一款打包进 IPA，也不预下载全部款式——只在用户选定后按需
// 下载当前一款、只缓存当前一款（单文件 caches/CoVIPIcon/current），选新款时先删旧文件。
// 下载失败（网络/CDN/解码任一环节）时一律回落 Co 自绘徽标，绝不出现破图或空白。
// 徽标外观不影响播放权益：播放仍以 KugouMusicAuth.hasMembership 为准，不绕 VIP。
struct CoVIPIconItem: Identifiable {
    let id: String
    let group: String
    let label: String
    let url: URL?
    let isAnimated: Bool
    var isSelfDrawn: Bool { url == nil }
}

enum CoVIPIconCatalog {
    static let vipRemote: [CoVIPIconItem] = [
        // 普通 v0-v7
        CoVIPIconItem(id: "vip-normal-v0", group: "普通", label: "v0", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582124119/201b/4a2b/636c/1d1dbc6b0766e867f992f24974bd9e8d.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-normal-v1", group: "普通", label: "v1", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582186486/9f31/5cfe/207c/2846c11ce0bd05aae1754aed7e63ca58.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-normal-v2", group: "普通", label: "v2", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582188103/1854/6c02/1504/df5815d7c9784ad27e150a951f70ec39.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-normal-v3", group: "普通", label: "v3", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582188099/3419/2b65/d241/bd664461c263a2dfdbf631bb9848ee3e.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-normal-v4", group: "普通", label: "v4", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582187192/1052/507f/a9f6/37b6f5c7730daf96a992accb35092511.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-normal-v5", group: "普通", label: "v5", url: URL(string: "https://p5.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582188100/ca7f/f3f7/f591/a142a567c050a4a860ee77765270db57.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-normal-v6", group: "普通", label: "v6", url: URL(string: "https://p5.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582187196/ecde/1b79/d752/ec1b8f20854d06bba52ed022d28871d6.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-normal-v7", group: "普通", label: "v7", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582185437/838c/3e35/26c7/1483dd70f2bbbf601f095dff56c603b8.png"), isAnimated: false),
        // 动效 v0-v7（webp，加载后自动连续播放）
        CoVIPIconItem(id: "vip-animated-v0", group: "动效", label: "v0", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32141379825/38a5/43a5/79d3/b71cbffe50f3bd5d21fea4fee0f28433.webp"), isAnimated: true),
        CoVIPIconItem(id: "vip-animated-v1", group: "动效", label: "v1", url: URL(string: "https://p5.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32141387354/ccf7/52e6/a3c7/edcb0a1bddc423b8efd23a55e70ecff1.webp"), isAnimated: true),
        CoVIPIconItem(id: "vip-animated-v2", group: "动效", label: "v2", url: URL(string: "https://p5.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32141390014/d816/86b3/2db8/631f4468ca344af5caad8d1875d0453e.webp"), isAnimated: true),
        CoVIPIconItem(id: "vip-animated-v3", group: "动效", label: "v3", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32141390012/8f22/7796/8597/3c4e43ad7036268bd80ec4a4d7623d61.webp"), isAnimated: true),
        CoVIPIconItem(id: "vip-animated-v4", group: "动效", label: "v4", url: URL(string: "https://p5.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32141385845/1920/a68a/ee92/8f89aff7cbc6122eeb7c2d78e0b7c5fc.webp"), isAnimated: true),
        CoVIPIconItem(id: "vip-animated-v5", group: "动效", label: "v5", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32141386672/0d87/87cf/93f7/7ec3aad495032568774a84f964806303.webp"), isAnimated: true),
        CoVIPIconItem(id: "vip-animated-v6", group: "动效", label: "v6", url: URL(string: "https://p5.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32141388259/2ff9/0285/5c0d/67aabccc4753db74b7f3aee9e485bf7d.webp"), isAnimated: true),
        CoVIPIconItem(id: "vip-animated-v7", group: "动效", label: "v7", url: URL(string: "https://p5.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32141388261/a2e9/3284/e98d/937112ec4f5a78553946211a9794eb21.webp"), isAnimated: true),
        // 已过期 v0-v7
        CoVIPIconItem(id: "vip-expired-v0", group: "已过期", label: "v0", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582124120/b2ca/664a/8d3a/90703110665d55efcb57c11c16c9c86b.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-expired-v1", group: "已过期", label: "v1", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582187194/7a26/f253/f690/47da2b91bced041709bbcdb68cd0867f.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-expired-v2", group: "已过期", label: "v2", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582185439/97ed/0a50/4c47/6ee6d3bba90d6e558fd947e717b02a88.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-expired-v3", group: "已过期", label: "v3", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582188101/3e49/6a48/39f3/c4124c59baca58313e16a62c5577808b.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-expired-v4", group: "已过期", label: "v4", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582187195/0a19/d6c8/b3bb/9777d57b1f0de3b66da0dc88abdee9f4.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-expired-v5", group: "已过期", label: "v5", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582184693/655f/84e0/a623/2e928f20e362646d3792777f9fd1175d.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-expired-v6", group: "已过期", label: "v6", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582186487/aa2a/18d4/0ed0/831633c5a44e742024caee7cd25ac2f2.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-expired-v7", group: "已过期", label: "v7", url: URL(string: "https://p5.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582187193/4554/a47b/6007/128beedac6aba996237d0fbff16ec44a.png"), isAnimated: false),
        // 特殊 5 张
        CoVIPIconItem(id: "vip-special-expiring", group: "特殊", label: "即将过期", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582124121/4a10/4688/42a4/75f2deca258ec6e9d4ee39d2bc977a43.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-special-renew", group: "特殊", label: "续费", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582120545/0427/dad3/8730/40ec47262e2e68719217b5e357220228.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-special-open", group: "特殊", label: "开通", url: URL(string: "https://p5.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582122379/9fc8/330a/c33d/75e75cf340078f94b395aacb89f56c32.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-special-free", group: "特殊", label: "限免", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582121501/716e/a8fc/18c0/91d296e4135822e84b1bfa3a3eb86cd5.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-special-cancel", group: "特殊", label: "注销", url: URL(string: "https://p5.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582121499/7199/edef/2bc2/270062e6ffd9299d160fdb5c1d1f9764.png"), isAnimated: false),
    ]
    /// 1.8.6 精简款：VIP 档各组只取代表款，不把 v0-v7 全部铺开（普通 v0 / 动效 v0 / 已过期 v0 / 特殊即将过期）。
    static let vipCore: [CoVIPIconItem] = [
        CoVIPIconItem(id: "vip-normal-v0", group: "普通", label: "普通 v0", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582124119/201b/4a2b/636c/1d1dbc6b0766e867f992f24974bd9e8d.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-animated-v0", group: "动效", label: "动效 v0", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32141379825/38a5/43a5/79d3/b71cbffe50f3bd5d21fea4fee0f28433.webp"), isAnimated: true),
        CoVIPIconItem(id: "vip-expired-v0", group: "已过期", label: "已过期 v0", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582124120/b2ca/664a/8d3a/90703110665d55efcb57c11c16c9c86b.png"), isAnimated: false),
        CoVIPIconItem(id: "vip-special-expiring", group: "特殊", label: "即将过期", url: URL(string: "https://p6.music.126.net/obj/wonDlsKUwrLClGjCm8Kx/32582124121/4a10/4688/42a4/75f2deca258ec6e9d4ee39d2bc977a43.png"), isAnimated: false),
    ]
    // SVIP 与长条形：CDN 链接未在页面文本中公开，不编造，Co 自绘（矢量，无位图缓存）。
    static let svipSelfDrawn: [CoVIPIconItem] = [
        CoVIPIconItem(id: "svip-normal", group: "SVIP普通", label: "SVIP", url: nil, isAnimated: false),
        CoVIPIconItem(id: "svip-animated", group: "SVIP动效", label: "SVIP", url: nil, isAnimated: true),
        CoVIPIconItem(id: "svip-expired", group: "SVIP已过期", label: "SVIP", url: nil, isAnimated: false),
        CoVIPIconItem(id: "svip-special", group: "SVIP特殊", label: "SVIP", url: nil, isAnimated: false),
    ]
    static let longSelfDrawn: [CoVIPIconItem] = [
        CoVIPIconItem(id: "long-light", group: "长条形", label: "浅色", url: nil, isAnimated: false),
        CoVIPIconItem(id: "long-dark", group: "长条形", label: "深色", url: nil, isAnimated: false),
        CoVIPIconItem(id: "long-text-light", group: "长条形", label: "带文字浅色", url: nil, isAnimated: false),
        CoVIPIconItem(id: "long-text-dark", group: "长条形", label: "带文字深色", url: nil, isAnimated: false),
    ]
    static var all: [CoVIPIconItem] { vipRemote + svipSelfDrawn + longSelfDrawn }
    static func item(id: String) -> CoVIPIconItem? { all.first { $0.id == id } }

    // 单款缓存：整个 App 只有一个 VIP 图标缓存文件，选新款先删旧文件再下载。
    static let cachedItemIdKey = "beans.vipIconCachedId"
    static func cacheFileURL() -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CoVIPIcon", isDirectory: true)
        return dir.appendingPathComponent("current")
    }
    static func deleteCachedIcon() {
        try? FileManager.default.removeItem(at: cacheFileURL())
        UserDefaults.standard.removeObject(forKey: cachedItemIdKey)
    }
    static func cachedImage() -> UIImage? {
        guard let data = try? Data(contentsOf: cacheFileURL()), !data.isEmpty else { return nil }
        return CoAnimatedImageDecoder.animatedImage(from: data)
    }
    static func isDecodable(_ data: Data) -> Bool {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceGetCount(src) > 0
    }
}

// 1.8.8：远程 VIP 图按原图比例显示：只定高度 26pt，宽度 = 高度 × 原图宽高比
// （上限 180pt），scaledToFit、不裁剪、不压扁。旧 84×20 硬框 + clipped()
// 会把唱片圆上下左右裁掉、只剩红点 + VIP 字（1.8.7 截图实锤）。
// 1.9.0：只改数字不够——SwiftUI 的 .frame() 本身不裁剪，CoAnimatedImage 的
// UIImageView 又是 clipsToBounds=false，UIImageView 按图片内在尺寸（1.8.9 截图量出
// 约 97×53pt）居中画在 26pt 的帧外，左沿向左溢出约 25pt，正好盖住昵称的“见”字。
// 因此这里必须结构性堵死：动图改纯 SwiftUI 逐帧播放（布局尺寸即帧尺寸，
// 不再有 UIImageView 内在尺寸溢出）、帧外加 .clipped()、解码按屏幕 scale
// 换算回点尺寸、长条款宽上限由 180 收紧到 120（昵称约 60 + 间距 8 +
// 图标 120 = 188 < 320 行宽，正常昵称绝不被挤、被盖）。
struct CoVIPRemoteImage: View {
    let image: UIImage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var width: CGFloat {
        let h = image.size.height
        guard h > 0 else { return 78 }
        return min(26 * image.size.width / h, 120)
    }
    var body: some View {
        if image.images != nil {
            // 1.9.0 修复后：动图不再走 UIImageView（见下 CoAnimatedFramesView 的说明）。
            CoAnimatedFramesView(image: image, animated: !reduceMotion)
                .frame(width: width, height: 26)
                .clipped()
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: width, height: 26)
                .clipped()
        }
    }
}

// 1.8.9 动效解码：UIImage(data:) 对动图经常只剩首帧（webp 动效款实测风险点），
// 故用 CGImageSource 逐帧抽帧：多帧时按每帧时长展开成 UIImage.animatedImage，
// 单帧/解码失败时回落 UIImage(data:)；帧数上限 150、展开后上限 300，避免爆内存。
enum CoAnimatedImageDecoder {
    static func animatedImage(from data: Data) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return UIImage(data: data) }
        let count = CGImageSourceGetCount(src)
        guard count > 1 else { return UIImage(data: data) }
        var frames: [UIImage] = []
        var durations: [TimeInterval] = []
        for i in 0..<min(count, 150) {
            guard let cg = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            // 1.9.0：UIImage(cgImage:) 默认 scale=1 会把像素尺寸当成点尺寸
            // （如 194×106px 报成 194×106pt），宽高比计算与内在尺寸全错；
            // 按屏幕 scale 换算回点尺寸，image.size 才与 26pt 帧口径一致。
            frames.append(UIImage(cgImage: cg, scale: UIScreen.main.scale, orientation: .up))
            durations.append(frameDuration(src: src, index: i))
        }
        guard frames.count > 1 else { return UIImage(data: data) }
        // UIImage.animatedImage 只有总时长、没有逐帧时长：按最短帧为单位重复展开，近似还原逐帧时长。
        let unit = max(durations.min() ?? 0.1, 0.02)
        var expanded: [UIImage] = []
        for (frame, d) in zip(frames, durations) {
            let repeats = max(1, min(5, Int((d / unit).rounded())))
            expanded.append(contentsOf: Array(repeating: frame, count: repeats))
            if expanded.count >= 300 { break }
        }
        let total = durations.reduce(0, +)
        return UIImage.animatedImage(with: expanded, duration: total) ?? UIImage(data: data)
    }

    private static func frameDuration(src: CGImageSource, index: Int) -> TimeInterval {
        guard let props = CGImageSourceCopyPropertiesAtIndex(src, index, nil) as? [String: Any] else { return 0.1 }
        if let d = findDelay(in: props), d > 0 { return d < 0.02 ? 0.1 : d }
        return 0.1
    }

    private static func findDelay(in dict: [String: Any]) -> TimeInterval? {
        for (key, value) in dict {
            if key == "UnclampedDelayTime" || key == "DelayTime", let d = value as? Double { return d }
            if let sub = value as? [String: Any], let d = findDelay(in: sub) { return d }
        }
        return nil
    }
}

// 1.9.0：动图不再走 UIImageView。根因复盘：上一版 CoAnimatedImage 是
// UIViewRepresentable，UIImageView 按图片内在尺寸布局（截图量出约 97×53pt，
// 而帧只有 26pt 高），外层 SwiftUI .frame() 不裁剪、且 makeUIView 设了
// clipsToBounds=false，图居中画在帧外、左沿溢出盖住昵称的“见”字；补
// sizeThatFits 又是 iOS 16+ API，主 App 部署目标是 iOS 15、编不过（本轮
// run 39893654682 的 Build (unsigned) 失败即卡在这里）。彻底解法是纯
// SwiftUI 逐帧播放：解码器已把动图展开成帧数组，TimelineView 按帧间隔
// 轮换 Image(resizable+scaledToFit)，布局尺寸就是外层 .frame() 的尺寸，
// 不可能再溢出；视图不在屏时 TimelineView 停摆，不常驻耗电；减弱动态
// 效果时只显示首帧静态。
struct CoAnimatedFramesView: View {
    let image: UIImage
    var animated: Bool = true
    private var frames: [UIImage] { image.images ?? [image] }
    private var interval: TimeInterval {
        let count = max(frames.count, 1)
        let d = image.duration / Double(count)
        return d > 0 ? d : 0.1
    }
    var body: some View {
        if !animated || frames.count <= 1 {
            Image(uiImage: frames.first ?? image)
                .resizable()
                .scaledToFit()
        } else {
            TimelineView(.periodic(from: Date(), by: interval)) { timeline in
                let index = Int(timeline.date.timeIntervalSince1970 / interval) % frames.count
                Image(uiImage: frames[index])
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}

// Co 自绘 SVIP / 长条款（矢量，无位图、无缓存；动效款仅 VIP 时扫光）。
struct CoVIPSelfDrawnBadge: View {
    let itemId: String
    let isVIP: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerOn = false
    var body: some View {
        Group {
            switch itemId {
            case "svip-animated":
                if isVIP && !reduceMotion {
                    Text("SVIP").font(BeansFont.appFont(10, .bold)).foregroundStyle(.black)
                        .padding(.horizontal, 8).padding(.vertical, 2.5)
                        .background(Capsule().fill(Color(red: 0.85, green: 0.62, blue: 0.18)))
                        .overlay(Capsule().fill(LinearGradient(colors: [.clear, .white.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing)).frame(width: 14).offset(x: shimmerOn ? 18 : -18).clipShape(Capsule()).opacity(shimmerOn ? 1 : 0))
                        .clipShape(Capsule())
                        .onAppear { shimmerOn = false; withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) { shimmerOn = true } }
                        .onDisappear { shimmerOn = false }
                } else {
                    Text("SVIP").font(BeansFont.appFont(10, .bold)).foregroundStyle(.black)
                        .padding(.horizontal, 8).padding(.vertical, 2.5)
                        .background(Capsule().fill(Color(red: 0.85, green: 0.62, blue: 0.18))).clipShape(Capsule())
                }
            case "svip-expired":
                Text("SVIP").font(BeansFont.appFont(10, .bold)).foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 8).padding(.vertical, 2.5)
                    .background(Capsule().fill(Color.gray.opacity(0.3))).clipShape(Capsule())
            case "long-light":
                Label("VIP", systemImage: "crown.fill").font(BeansFont.appFont(10, .bold)).foregroundStyle(Color(red: 0.93, green: 0.25, blue: 0.22))
                    .padding(.horizontal, 12).padding(.vertical, 3)
                    .background(Capsule().fill(Color.white)).overlay(Capsule().stroke(Color(red: 0.93, green: 0.25, blue: 0.22).opacity(0.5), lineWidth: 0.8)).clipShape(Capsule())
            case "long-dark":
                Label("VIP", systemImage: "crown.fill").font(BeansFont.appFont(10, .bold)).foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.32))
                    .padding(.horizontal, 12).padding(.vertical, 3)
                    .background(Capsule().fill(Color.black)).overlay(Capsule().stroke(Color(red: 0.85, green: 0.62, blue: 0.18).opacity(0.6), lineWidth: 0.8)).clipShape(Capsule())
            case "long-text-light":
                Label("VIP 会员", systemImage: "crown.fill").font(BeansFont.appFont(10, .bold)).foregroundStyle(Color(red: 0.93, green: 0.25, blue: 0.22))
                    .padding(.horizontal, 12).padding(.vertical, 3)
                    .background(Capsule().fill(Color.white)).overlay(Capsule().stroke(Color(red: 0.93, green: 0.25, blue: 0.22).opacity(0.5), lineWidth: 0.8)).clipShape(Capsule())
            case "long-text-dark":
                Label("VIP 会员", systemImage: "crown.fill").font(BeansFont.appFont(10, .bold)).foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.32))
                    .padding(.horizontal, 12).padding(.vertical, 3)
                    .background(Capsule().fill(Color.black)).overlay(Capsule().stroke(Color(red: 0.85, green: 0.62, blue: 0.18).opacity(0.6), lineWidth: 0.8)).clipShape(Capsule())
            default: // svip-normal 及其余自绘款：金色静态
                Text("SVIP").font(BeansFont.appFont(10, .bold)).foregroundStyle(.black)
                    .padding(.horizontal, 8).padding(.vertical, 2.5)
                    .background(Capsule().fill(Color(red: 0.85, green: 0.62, blue: 0.18))).clipShape(Capsule())
            }
        }
    }
}

// MARK: - 歌单星标（1.8.8，仅本地标记，不同步到酷狗账号）
// 歌单详情页截图布局里的收藏星没有酷狗侧接口可接，故只做本地星标：
// 点星填充、再点取消，状态持久化在本地，详情页内可见即是全部效果，不假装同步。
struct CoStarredPlaylists {
    static func key() -> String { "beans.starredPlaylists" }
    static func isStarred(id: Int) -> Bool {
        (UserDefaults.standard.array(forKey: key()) as? [Int] ?? []).contains(id)
    }
    static func setStarred(id: Int, starred: Bool) {
        var ids = UserDefaults.standard.array(forKey: key()) as? [Int] ?? []
        if starred { if !ids.contains(id) { ids.append(id) } }
        else { ids.removeAll { $0 == id } }
        UserDefaults.standard.set(ids, forKey: key())
    }
}

// MARK: - 主页状态（1.8.6，本地短文本，按酷狗账号区分存，不同步到酷狗账号）
struct CoUserStatus {
    static func key(userId: String) -> String { "beans.userStatus.\(userId.isEmpty ? "local" : userId)" }
    static func load(userId: String) -> String { UserDefaults.standard.string(forKey: key(userId: userId)) ?? "" }
    static func save(userId: String, text: String) { UserDefaults.standard.set(text, forKey: key(userId: userId)) }
}

// MARK: - 我的页隐藏歌单存储（1.8.5，只藏显示、不删歌单）
// 按酷狗账号 userId 区分键：beans.hiddenPlaylists.<userId>，未登录时为 "local"。
// 每条存 "id|name"（恢复入口靠名字展示，靠 id 恢复），换号后各号的隐藏互不串。
struct CoHiddenPlaylists {
    static func key(userId: String) -> String {
        "beans.hiddenPlaylists.\(userId.isEmpty ? "local" : userId)"
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
            .filter { $0.hasPrefix("beans.hiddenPlaylists.") }
            .sorted()
            .map { (userId: String($0.dropFirst("beans.hiddenPlaylists.".count)), entries: load(userId: String($0.dropFirst("beans.hiddenPlaylists.".count)))) }
            .filter { !$0.entries.isEmpty }
    }
}

// MARK: - 玻璃图标按钮（清透 + 按压动效）

struct GlassIconButton: View {
    @EnvironmentObject private var theme: ThemeStore
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    let systemName: String
    var size: CGFloat = 44
    var active = false
    var forceLiquid = false
    let action: () -> Void

    private var isNativeClean: Bool {
        BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    var body: some View {
        let _ = theme.accent
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * (isNativeClean ? 0.42 : 0.38), weight: .semibold))
                .foregroundStyle(active ? Color.beansAmber : (isNativeClean ? Color.primary : Color.beansLabel))
                .frame(width: size, height: size)
                .background {
                    if isNativeClean && !forceLiquid {
                        Circle().fill(active ? Color.beansAmber.opacity(0.12) : .clear)
                    } else {
                        BeansGlass(shape: Circle())
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
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    let title: String
    var systemName: String?
    var prominent = false
    let action: () -> Void

    private var isNativeClean: Bool {
        BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean
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
            .font(BeansFont.appFont(15, .semibold))
            .foregroundStyle(prominent ? Color.white : Color.beansLabel)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                if prominent {
                    ZStack {
                        BeansGlass(shape: Capsule(), forceLiquid: true)
                        Capsule().fill(Color.beansAmber.opacity(0.78))
                    }
                } else if isNativeClean {
                    Capsule().fill(Color.primary.opacity(0.055))
                } else {
                    Capsule().fill(.thinMaterial)
                }
            }
            .overlay {
                if isNativeClean && !prominent {
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
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    let title: String
    var trailing: String?
    var titleColor: Color = Color.beansLabel
    var trailingColor: Color = Color.beansComment
    var onTrailingTap: (() -> Void)?

    private var isNativeClean: Bool {
        BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(LocalizedStringKey(title))
                .font(BeansFont.appFont(isNativeClean ? 26 : 21, .bold))
                .foregroundStyle(titleColor)
            Spacer()
            if let trailing {
                Button {
                    onTrailingTap?()
                } label: {
                    HStack(spacing: 3) {
                        Text(LocalizedStringKey(trailing))
                            .font(BeansFont.appFont(13, .medium))
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
                .foregroundStyle(Color.beansComment)
            Text(LocalizedStringKey(text))
                .font(BeansFont.appFont(14))
                .foregroundStyle(Color.beansComment)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.beansComment)
            Text(message)
                .font(BeansFont.appFont(14))
                .foregroundStyle(Color.beansComment)
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
        ProgressView()
            .controlSize(.large)
            .tint(Color.beansAmber)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
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

    var body: some View {
        let _ = theme.accent
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Color.beansAmber)
                    .frame(width: 3, height: animating ? 14 : 5)
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

// MARK: - 播放进度线（迷你播放器用）

struct ProgressLine: View {
    @EnvironmentObject private var theme: ThemeStore
    let progress: Double
    let duration: Double

    private var ratio: Double {
        guard duration > 0.001 else { return 0 }
        return min(max(progress / duration, 0), 1)
    }

    var body: some View {
        let _ = theme.accent
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.beansComment.opacity(0.25))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.beansAmber, Color.beansAmber.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(geo.size.width * ratio, 6))
                    .shadow(color: Color.beansAmber.opacity(0.5), radius: 3, y: 1)
                    .overlay(alignment: .trailing) {
                        ZStack {
                            // 柔圆光晕（替代生硬方边阴影）
                            Circle()
                                .fill(Color.beansAmber.opacity(0.45))
                                .blur(radius: 4)
                                .frame(width: 14, height: 14)
                            Circle()
                                .fill(Color.beansAmber)
                                .frame(width: 5, height: 5)
                                .shadow(color: Color.beansAmber.opacity(0.8), radius: 2)
                        }
                    }
            }
        }
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
        Text(center.message ?? "")
            .font(BeansFont.appFont(14, .medium))
            .foregroundStyle(Color.beansLabel)
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
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
            .padding(.horizontal, 30)
            .padding(.bottom, 92)
            .opacity(center.message == nil ? 0 : 1)
            .offset(y: center.message == nil ? 16 : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: center.message)
            .allowsHitTesting(false)
    }
}
