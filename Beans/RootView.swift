import SwiftUI
import UIKit

enum RootTab: String, CaseIterable, Identifiable {
    case discover
    case search
    case library
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discover: return "主页"
        case .search: return "搜索"
        case .library: return "音乐库"
        case .profile: return "我的"
        }
    }

    var icon: String {
        switch self {
        case .discover: return "house.fill"
        case .search: return "magnifyingglass"
        case .library: return "music.note.list"
        case .profile: return "person.crop.circle"
        }
    }
}
struct RootView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var favorites: FavoritesStore
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var platformPrefs = PlatformPreferenceStore.shared
    @AppStorage("beans.themeMode") private var themeModeRaw = BeansThemeMode.system.rawValue

    @State private var selection: RootTab = .discover
    @State private var showPlayer = false
    @Namespace private var nowPlayingTransition
    @AppStorage("beans.disclaimerAccepted") private var disclaimerAccepted = false
    /// 底栏是否显示文字（关闭后只显示图标）
    @AppStorage("beans.tabLabelsVisible") private var tabLabelsVisible = true
    @AppStorage("beans.homeSource") private var homeSourceRaw = SearchProvider.netease.rawValue
    /// 强制高刷新率：用于修复部分页面被系统稳定在 60Hz 的问题。
    @AppStorage("beans.enableHighRefresh") private var enableHighRefresh = false
    @AppStorage("beans.legacyTabCornerRadius") private var legacyTabCornerRadius = 32.0
    @AppStorage("beans.legacyTabWidth") private var legacyTabWidth = 356.0
    @AppStorage("beans.legacyTabOffsetX") private var legacyTabOffsetX = 0.0
    @AppStorage("beans.legacyTabOffsetY") private var legacyTabOffsetY = 0.0
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    @State private var showWhatsNew = false
    @State private var showUpdateDownloadError = false
    @State private var showHomePlatformMenu = false
    private var themeMode: BeansThemeMode {
        BeansThemeMode(rawValue: themeModeRaw) ?? .system
    }

    private var usesSystemFloatingTabBar: Bool {
        if #available(iOS 26, *) { return true }
        return false
    }

    private var legacyTabResolvedWidth: CGFloat {
        min(CGFloat(legacyTabWidth), max(300, UIScreen.main.bounds.width - 28))
    }

    private var isNativeClean: Bool {
        BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    private var usesSystemPlayerDismissal: Bool {
        if #available(iOS 18.0, *) { return true }
        return false
    }

    var body: some View {
        let _ = theme.accent
        let rootTabs = TabView(selection: $selection) {
            DiscoverView()
                .tabItem { Label(tabLabelsVisible ? "主页" : "", systemImage: "house.fill") }
                .tag(RootTab.discover)
            SearchView()
                .tabItem { Label(tabLabelsVisible ? "搜索" : "", systemImage: "magnifyingglass") }
                .tag(RootTab.search)
            LibraryView()
                .tabItem { Label(tabLabelsVisible ? "音乐库" : "", systemImage: "music.note.list") }
                .tag(RootTab.library)
            ProfileView()
                .tabItem { Label(tabLabelsVisible ? "我的" : "", systemImage: "person.crop.circle") }
                .tag(RootTab.profile)
        }
        .tint(Color.beansAmber)
        // Co 底栏动画（参照 2.0.3 RootView:723/773，但只取行为不抄样式）：
        // iOS 26+ 系统悬浮标签栏下滑缩小、上滑恢复；有歌在播才生效，无歌不缩小。
        // 选中的标签色仍走 Co 的主题强调色（默认红），底栏样式本身是系统悬浮栏，Co 不另做一套。
        .modifier(CoTabBarMinimizeModifier(enabled: player.currentSong != nil))
        .background {
            TabBarAppearanceConfigurator(
                hidesSystemTabBarOnLegacy: !usesSystemFloatingTabBar,
                onHomeLongPress: { showHomePlatformMenu = true }
            )
        }

        ZStack {
            // iOS 26 用系统 tab accessory，把迷你播放器缩进底栏槽位；旧系统走自绘胶囊底栏。
            if #available(iOS 26.0, *) {
                rootTabs
                    .modifier(
                        MiniPlayerAccessoryModifier(
                            isActive: player.currentSong != nil,
                            showPlayer: $showPlayer,
                            clock: player.clock,
                            colorScheme: colorScheme,
                            transitionNamespace: nowPlayingTransition
                        )
                    )
            } else {
                rootTabs
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        legacyFloatingTabBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
            }
        }
        // 窗口级保险：强制 TabView 内容区占满窗口高、顶对齐，不让上层容器把内容压矮或居中
        // （1.7.0 黑空的主因是主 App 丢了启动屏导致的系统级黑边，本行只是防 SwiftUI 层再被压矮，不单独起效）。
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            HighRefreshConfigurator()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
        .preferredColorScheme(themeMode.colorScheme)
        .confirmationDialog("主页平台", isPresented: $showHomePlatformMenu, titleVisibility: .visible) {
            platformSelectionMenu
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if #available(iOS 18.0, *) {
                playerPresentation
                    .navigationTransition(
                        .zoom(
                            sourceID: BeansNowPlayingTransitionID.surface,
                            in: nowPlayingTransition
                        )
                    )
            } else if #available(iOS 16.4, *) {
                playerPresentation
            } else {
                playerPresentation
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: player.currentSong?.id)
        .animation(.easeInOut(duration: 0.22), value: selection)
        .overlay(alignment: .bottom) {
            ToastView(center: ToastCenter.shared)
        }
        .onAppear {
            // 启动已完成：标记本次启动正常（供下次启动检测闪退）
            CrashReporter.shared.markLaunchCompleted()
            if disclaimerAccepted, ChangelogStore.shouldShowWhatsNew {
                showWhatsNew = true
            }
            // Co 省电：不再强制开启高刷新
            HighRefreshKeeper.shared.configure(enabled: false)
        }
        .onChange(of: enableHighRefresh) { _ in
            HighRefreshKeeper.shared.configure(enabled: enableHighRefresh)
        }
        .onChange(of: disclaimerAccepted) { accepted in
            if accepted, ChangelogStore.shouldShowWhatsNew {
                showWhatsNew = true
            }
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewSheet()
        }
        .task(id: disclaimerAccepted) {
            // Co：启动更新检查已删（原 UpdateChecker 已删）。
            guard disclaimerAccepted else { return }
        }
    }

    private var legacyFloatingTabBar: some View {
        VStack(spacing: 8) {
            if player.currentSong != nil {
                MiniPlayerView(
                    showPlayer: $showPlayer,
                    presentation: .dock,
                    transitionNamespace: nowPlayingTransition
                )
                    .environmentObject(player.clock)
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            KumoneGlassTabBar(
                items: RootTab.allCases.map {
                    KumoneGlassTabBar.Item(tab: $0, title: $0.title, icon: $0.icon)
                },
                selection: $selection,
                labelsVisible: tabLabelsVisible,
                accentIsNativeClean: isNativeClean,
                onHomeLongPress: { showHomePlatformMenu = true }
            ) { tab in
                guard selection != tab else { return }
                BeansHaptics.select()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    selection = tab
                }
            }
            .frame(width: legacyTabResolvedWidth)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
        .offset(x: CGFloat(legacyTabOffsetX), y: CGFloat(legacyTabOffsetY))
    }

    @ViewBuilder
    private var platformSelectionMenu: some View {
        let current = SearchProvider(rawValue: homeSourceRaw) ?? platformPrefs.enabledSearchProviders.first ?? .netease
        Text("主页平台")
        ForEach(platformPrefs.enabledSearchProviders) { provider in
            Button {
                BeansHaptics.select()
                homeSourceRaw = provider.rawValue
            } label: {
                Label(LocalizedStringKey(provider.rawValue), systemImage: provider == current ? "checkmark" : provider.icon)
            }
        }
    }

    @ViewBuilder
    private var playerPresentation: some View {
        BeansNowPlayingPresentation(
            isPresented: $showPlayer,
            usesSystemInteractiveDismissal: usesSystemPlayerDismissal
        ) {
            PlayerView(isPresented: $showPlayer)
                .environmentObject(favorites)
                .environmentObject(player)
                .environmentObject(player.clock)
                .environmentObject(auth)
        }
    }
}
private enum BeansNowPlayingPresentationMetrics {
    static let indicatorTopSpacing: CGFloat = 6
    static let indicatorWidth: CGFloat = 52
    static let indicatorHeight: CGFloat = 5
    static let indicatorHitWidth: CGFloat = 180
    static let indicatorHitHeight: CGFloat = 82
    static let dismissDistance: CGFloat = 110
    static let dismissPrediction: CGFloat = 190
    static let dismissAnimation = Animation.spring(
        response: 0.52,
        dampingFraction: 0.90,
        blendDuration: 0.10
    )
}

struct BeansNowPlayingPresentation<Content: View>: View {
    @Binding var isPresented: Bool
    let usesSystemInteractiveDismissal: Bool
    let content: Content
    @ObservedObject private var appleLayout = AppleMusicLayoutStore.shared
    @State private var dragOffset: CGFloat = 0

    init(
        isPresented: Binding<Bool>,
        usesSystemInteractiveDismissal: Bool,
        @ViewBuilder content: () -> Content
    ) {
        _isPresented = isPresented
        self.usesSystemInteractiveDismissal = usesSystemInteractiveDismissal
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let isPhone = proxy.size.width < 720
            ZStack(alignment: .top) {
                content

                if isPhone {
                    dragIndicator(safeAreaTop: proxy.safeAreaInsets.top)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .offset(y: usesSystemInteractiveDismissal ? 0 : dragOffset)
        }
        .onAppear { dragOffset = 0 }
    }

    @ViewBuilder
    private func dragIndicator(safeAreaTop: CGFloat) -> some View {
        let surface = ZStack(alignment: .top) {
            Color.clear
            Capsule()
                // Keep the indicator's hit area and gesture, but hide the visual
                // handle so the player uses a clean full-screen surface.
                .fill(.clear)
                .frame(
                    width: BeansNowPlayingPresentationMetrics.indicatorWidth,
                    height: BeansNowPlayingPresentationMetrics.indicatorHeight
                )
                .padding(.top, BeansNowPlayingPresentationMetrics.indicatorTopSpacing)
        }
        .frame(
            width: BeansNowPlayingPresentationMetrics.indicatorHitWidth,
            height: BeansNowPlayingPresentationMetrics.indicatorHitHeight
        )
        .modifier(AppleMusicLayoutTransform(entry: appleLayout.entry(for: .top)))
        .contentShape(Rectangle())
        .accessibilityLabel("下拉关闭播放页")

        if usesSystemInteractiveDismissal {
            surface
                .padding(.top, safeAreaTop)
        } else {
            surface
                .padding(.top, safeAreaTop)
                .gesture(dismissGesture)
        }
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { value in
                dragOffset = max(value.translation.height, 0)
            }
            .onEnded { value in
                let translation = max(value.translation.height, 0)
                let prediction = max(value.predictedEndTranslation.height, 0)
                if translation > BeansNowPlayingPresentationMetrics.dismissDistance
                    || prediction > BeansNowPlayingPresentationMetrics.dismissPrediction {
                    BeansHaptics.medium()
                    withAnimation(BeansNowPlayingPresentationMetrics.dismissAnimation) {
                        isPresented = false
                    }
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

struct PlatformPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let current: SearchProvider
    let providers: [SearchProvider]
    let onSelect: (SearchProvider) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("选择主页平台")
                .font(BeansFont.appFont(19, .bold))
                .foregroundStyle(Color.beansLabel)
            ForEach(providers) { provider in
                Button {
                    onSelect(provider)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: provider == current ? "checkmark.circle.fill" : provider.icon)
                            .foregroundStyle(provider == current ? Color.beansAmber : Color.beansComment)
                        Text(LocalizedStringKey(provider.rawValue))
                            .font(BeansFont.appFont(15, .medium))
                            .foregroundStyle(Color.beansLabel)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)) }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color.clear)
        .modifier(PlatformPickerPresentation(providersCount: providers.count))
    }
}

private struct ClearSheetBackground: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationBackground(.clear)
        } else {
            content
        }
    }
}

/// iOS 26+ 系统标签栏滚动缩小：部署目标低于 26 时用 #available 守住，旧系统直接原样透传。
private struct CoTabBarMinimizeModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(enabled ? .onScrollDown : .never)
        } else {
            content
        }
    }
}

@available(iOS 26.0, *)
private struct MiniPlayerAccessoryModifier: ViewModifier {
    let isActive: Bool
    @Binding var showPlayer: Bool
    let clock: PlaybackClock
    let colorScheme: ColorScheme
    let transitionNamespace: Namespace.ID

    @ViewBuilder
    func body(content: Content) -> some View {
        if isActive {
            content.tabViewBottomAccessory {
                MiniPlayerView(
                    showPlayer: $showPlayer,
                    presentation: .accessory,
                    transitionNamespace: transitionNamespace
                )
                    .padding(.horizontal, 12)
                    .environmentObject(clock)
                    .environment(\.colorScheme, colorScheme)
            }
        } else {
            content
        }
    }
}

private struct KumoneGlassTabBar: View {
    struct Item: Identifiable {
        let tab: RootTab
        let title: String
        let icon: String
        var id: RootTab { tab }
    }

    let items: [Item]
    @Binding var selection: RootTab
    var labelsVisible: Bool
    var accentIsNativeClean: Bool
    var onHomeLongPress: (() -> Void)?
    var onSelect: (RootTab) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var dragX: CGFloat?
    @State private var isDragging = false

    private let innerInset: CGFloat = 4
    private let contentHeight: CGFloat = 56
    private let settle = Animation.spring(response: 0.35, dampingFraction: 0.82)

    var body: some View {
        GeometryReader { geo in
            let count = max(items.count, 1)
            let cellW = geo.size.width / CGFloat(count)
            let selectedIndex = items.firstIndex(where: { $0.tab == selection }) ?? 0
            let restX = cellW * (CGFloat(selectedIndex) + 0.5)
            let pillX = isDragging
                ? min(max(dragX ?? restX, cellW / 2), geo.size.width - cellW / 2)
                : restX

            ZStack(alignment: .leading) {
                selectionPill
                    .frame(width: cellW - 8, height: contentHeight)
                    .position(x: pillX, y: geo.size.height / 2)

                HStack(spacing: 0) {
                    ForEach(items) { item in
                        itemLabel(item)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(cellW: cellW, count: count))
        }
        .frame(height: contentHeight)
        .padding(innerInset)
        .background { Capsule().fill(.regularMaterial) }
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(colorScheme == .dark ? 0.08 : 0.20), lineWidth: 0.5)
        }
        .clipShape(Capsule())
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.26 : 0.12), radius: 12, y: 4)
        .padding(.horizontal, 12)
    }

    private func itemLabel(_ item: Item) -> some View {
        let isSelected = selection == item.tab
        return VStack(spacing: 3) {
            Image(systemName: item.icon)
                .font(.system(size: 23, weight: .semibold))
                .symbolVariant(.fill)
            if labelsVisible {
                Text(item.title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(isSelected
                         ? AnyShapeStyle(accentIsNativeClean ? Color.red : Color.beansAmber)
                         : AnyShapeStyle(Color.primary.opacity(0.8)))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in
            guard item.tab == .discover else { return }
            BeansHaptics.select()
            onHomeLongPress?()
        })
    }

    private var selectionPill: some View {
        Capsule(style: .continuous)
            .fill(colorScheme == .dark
                  ? Color.white.opacity(0.10)
                  : Color.black.opacity(0.075))
    }

    private func index(for x: CGFloat, cellW: CGFloat, count: Int) -> Int {
        min(max(Int(x / cellW), 0), count - 1)
    }

    private func dragGesture(cellW: CGFloat, count: Int) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging && abs(value.translation.width) < 8 { return }
                isDragging = true
                dragX = value.location.x
                let tab = items[index(for: value.location.x, cellW: cellW, count: count)].tab
                if tab != selection {
                    selection = tab
                    onSelect(tab)
                }
            }
            .onEnded { value in
                let tab = items[index(for: value.location.x, cellW: cellW, count: count)].tab
                withAnimation(settle) {
                    selection = tab
                    onSelect(tab)
                    dragX = nil
                }
                isDragging = false
            }
    }
}

private struct PlatformPickerPresentation: ViewModifier {
    let providersCount: Int

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .modifier(ClearSheetBackground())
                .presentationDetents([.height(CGFloat(116 + providersCount * 60))])
                .presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}

private struct VisualEffectBlur: UIViewRepresentable {
    var style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

struct TabBarAppearanceConfigurator: UIViewControllerRepresentable {
    var hidesSystemTabBarOnLegacy = true
    var onHomeLongPress: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onHomeLongPress: onHomeLongPress)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        // 纯外观配置视图：禁止拦截触摸，避免透明全屏视图吃掉页面按钮点击
        controller.view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            Self.apply(
                from: controller,
                hidesSystemTabBarOnLegacy: hidesSystemTabBarOnLegacy,
                coordinator: context.coordinator
            )
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.onHomeLongPress = onHomeLongPress
        DispatchQueue.main.async {
            Self.apply(
                from: uiViewController,
                hidesSystemTabBarOnLegacy: hidesSystemTabBarOnLegacy,
                coordinator: context.coordinator
            )
        }
    }

    /// 固定清透风格：全透明背景、无阴影；选中态用主题色，
    /// 材质与模糊完全交给系统对底层页面内容的渲染，不再支持手动调节透明度
    private static func apply(
        from controller: UIViewController,
        hidesSystemTabBarOnLegacy: Bool,
        coordinator: Coordinator
    ) {
        guard let tabBar = controller.tabBarController?.tabBar else { return }
        installHomeLongPress(on: tabBar, coordinator: coordinator)
        if #available(iOS 26, *) {
            tabBar.isHidden = false
        } else if hidesSystemTabBarOnLegacy {
            tabBar.isHidden = true
            tabBar.isTranslucent = true
            return
        } else {
            tabBar.isHidden = false
        }
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        // 超薄材质模糊：与迷你播放器一致的清透玻璃透明度
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = UIColor.beansAmber
        tabBar.isTranslucent = true
    }

    private static func installHomeLongPress(on tabBar: UITabBar, coordinator: Coordinator) {
        let controls = tabBar.subviews
            .flatMap { descendants(of: $0) }
            .compactMap { $0 as? UIControl }
            .filter { !$0.isHidden && $0.alpha > 0 && $0.bounds.width > 0 }
            .sorted { $0.frame.minX < $1.frame.minX }
        guard let homeButton = controls.first else { return }
        guard homeButton.gestureRecognizers?.contains(where: { $0.name == Coordinator.gestureName }) != true else { return }

        let gesture = UILongPressGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleHomeLongPress(_:)))
        gesture.name = Coordinator.gestureName
        gesture.minimumPressDuration = 0.45
        gesture.cancelsTouchesInView = true
        homeButton.addGestureRecognizer(gesture)
    }

    private static func descendants(of view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap { descendants(of: $0) }
    }

    final class Coordinator: NSObject {
        static let gestureName = "beans.homePlatformLongPress"
        var onHomeLongPress: (() -> Void)?

        init(onHomeLongPress: (() -> Void)?) {
            self.onHomeLongPress = onHomeLongPress
        }

        @objc func handleHomeLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            BeansHaptics.select()
            onHomeLongPress?()
        }
    }
}

