import SwiftUI
import UIKit

/// 新版详情页共用件（以 PlaylistView 为准，不另起一套数值）：
/// 固定封面层在 ScrollView 之外、顶边钉在 0、下拉只缩放、上滑跟走单路读数；
/// 封面底部 120pt 遮罩淡出 + 虚化底深色罩从 0 起步、重叠 120pt 交叉淡化、封面底边无横线；
/// 歌名 28pt、占位 = 封面高 − 60pt；控制排胶囊 168×50pt、圆键 48×48pt、间距 12pt；
/// 下拉放慢：封顶 120pt、系数 pull/600、框高半速、回弹 response 0.9 / damping 1.0、
/// 拖动最小距离 8pt、门控只在页面顶部开始时放大。
/// 专辑页、歌手页用本文件全套；本地歌单页是 List 结构（swipeActions / 多选只在 List 里有），
/// 不能照搬 ScrollView 固定层，见 LocalPlaylistDetailSheet 里的等价实现说明。
/// 沉浸开关（beans.immersiveDetail.enabled）对这些页不再起分叉作用，body 永远走统一布局；
/// 设置页“沉浸详情界面”开关本身不动（只是页不再读它）。

/// 歌单页同款深色底（PlaylistView.darkBackground 的同一数值，不跟随系统深浅）。
let coDetailDarkBackground = Color(red: 0.14, green: 0.10, blue: 0.08)

/// 详情页滚动 + 下拉共用状态：上滑量只用滚动几何这一路读数（内容偏移 − 首帧基线，钳为 >=0），
/// 不搞两路取大值；下拉门控只在手势开始时定一次。
final class CoDetailScrollState: ObservableObject {
    @Published var scrollOffset: CGFloat = 0
    @Published var restOffset: CGFloat?
    @Published var pull: CGFloat = 0
    private var pullActive = false
    private var startedAtTop = false
    // 视觉锁定：封面占位区在全局坐标里的顶边（首帧即静止顶边）。
    // 上滑量优先用占位区实际位移算（静止顶边 − 当前顶边），定义上就不可能比内容多跑；
    // contentOffset 只做占位区尚未上报时的兜底。导航栏/搜索栏高度变化、内容异步加载
    // 都会让 contentOffset 的首帧基线失准，这就是上滑封面单独顶上去的成因。
    @Published private(set) var spacerTop: CGFloat?
    @Published private(set) var spacerTopAtRest: CGFloat?

    var scrollUp: CGFloat {
        if let rest = spacerTopAtRest, let top = spacerTop {
            return max(0, rest - top)
        }
        guard let rest = restOffset else { return 0 }
        return max(0, scrollOffset - rest)
    }

    func geometryChanged(_ value: CGFloat) {
        if restOffset == nil { restOffset = value }
        scrollOffset = value
    }

    func spacerTopChanged(_ value: CGFloat) {
        if spacerTopAtRest == nil { spacerTopAtRest = value }
        spacerTop = value
    }

    func dragChanged(_ translation: CGSize) {
        if !pullActive {
            pullActive = true
            startedAtTop = scrollUp <= 20
        }
        guard startedAtTop else {
            pull = 0
            return
        }
        pull = min(max(0, translation.height), 120)
    }

    func dragEnded() {
        pullActive = false
        startedAtTop = false
        withAnimation(.spring(response: 0.9, dampingFraction: 1.0)) {
            pull = 0
        }
    }
}

extension View {
    /// 挂在详情页 ScrollView 上：滚动几何读数 + 下拉放大手势（与 PlaylistView 同款参数）。
    func coDetailScroll(_ state: CoDetailScrollState) -> some View {
        self
            .scrollBounceBehavior(.always, axes: .vertical)
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { _, newValue in
                state.geometryChanged(newValue)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in state.dragChanged(value.translation) }
                    .onEnded { _ in state.dragEnded() }
            )
    }
}

/// 滚动内容里的封面占位区：固定封面基线高（屏宽正方形）减 60pt，
/// 标题块整体往上压到封面底部渐变淡出段里，标题顶边比封面底边高 60pt。
/// 同时上报占位区全局顶边给滚动状态（视觉锁定，见 CoDetailScrollState），
/// 上滑量就等于占位区的实际位移，封面与内容定义上一起动。
struct CoDetailCoverSpacer: View {
    var scrollState: CoDetailScrollState?

    var body: some View {
        Color.clear
            .frame(height: UIScreen.main.bounds.width - 60)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onChange(of: geo.frame(in: .global).minY, initial: true) { _, newValue in
                            scrollState?.spacerTopChanged(newValue)
                        }
                }
            }
    }
}

/// 详情页内搜索行（歌单页 unifiedSearchRow 同款样式，不另起一套）：
/// 提示白 0.6、输入后纯白、放大镜白 0.6、清除叉白 0.6、不加玻璃；
/// 是 ScrollView 内容的一部分，随内容一起滚动，不固定在顶部抽屉里。
struct CoDetailSearchRow: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(prompt)
                        .font(BeansFont.appFont(16))
                        .foregroundStyle(.white.opacity(0.6))
                        .allowsHitTesting(false)
                }
                TextField("", text: $text)
                    .font(BeansFont.appFont(16))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
            }
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }
}

/// 固定封面层 + 虚化底（PlaylistView 的 blurredCoverUnderlayer / fixedPlaylistCover 同款实现，
/// 只是抽成共用件）：虚化图只从缓存读、不另起下载，没拿到时虚化层不画、下面是深色底兜底。
struct CoUnifiedDetailCoverLayers: View {
    let coverURL: URL?
    let scrollUp: CGFloat
    let pull: CGFloat

    @State private var blurImage: UIImage?
    @State private var blurRetried = false

    var body: some View {
        ZStack {
            blurredUnderlayer
            fixedCover
        }
    }

    private var blurredUnderlayer: some View {
        Group {
            if let image = blurImage {
                let width = UIScreen.main.bounds.width
                let total = width + 520
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: total)
                    .blur(radius: 28)
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .clear, location: max(0, (width - 120) / total)),
                                .init(color: .black.opacity(0.25), location: width / total),
                                .init(color: .black.opacity(0.7), location: 0.85),
                                .init(color: coDetailDarkBackground, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipped()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
                    .offset(y: -scrollUp)
                    .allowsHitTesting(false)
            }
        }
        .task(id: coverURL) {
            blurImage = nil
            blurRetried = false
            refreshBlurImage()
        }
    }

    private var fixedCover: some View {
        let width = UIScreen.main.bounds.width
        let height = width + pull / 2
        let zoom = 1 + pull / 600
        let fadeStart = max(0, (height - 120) / height)
        return ZStack(alignment: .top) {
            CoverImage(url: coverURL, size: width, cornerRadius: 0)
                .scaleEffect(zoom, anchor: .top)
        }
        .frame(width: width, height: height)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: fadeStart),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .offset(y: -scrollUp)
        .allowsHitTesting(false)
    }

    private func refreshBlurImage() {
        let url = CustomSongCoverStore.shared.resolvedURL(for: coverURL) ?? coverURL
        guard let url else { blurImage = nil; return }
        if let image = BeansCoverImageStore.memoryImage(for: url) {
            blurImage = image
            return
        }
        BeansCoverImageStore.loadCachedImage(for: url) { image in
            if let image {
                blurImage = image
            } else if !blurRetried {
                blurRetried = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { refreshBlurImage() }
            }
        }
    }
}

/// 歌单页同款播放胶囊：168×50pt，黑字黑图标在白色液态玻璃上面。
struct CoDetailPlayCapsule: View {
    let title: String
    let action: () -> Void
    @AppStorage("beans.disableLiquidGlass") private var disableLiquidGlass = false

    var body: some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text(title)
            }
            .font(BeansFont.appFont(18, .semibold))
            .foregroundStyle(.black)
            .frame(width: 168, height: 50)
            .background {
                if #available(iOS 26, *), !disableLiquidGlass {
                    Capsule()
                        .fill(.clear)
                        .glassEffect(.regular.tint(.white.opacity(0.92)), in: Capsule())
                } else {
                    Capsule().fill(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// 歌单页同款圆键：48×48pt。
struct CoDetailCircleButton: View {
    let systemName: String
    let action: () -> Void
    @AppStorage("beans.disableLiquidGlass") private var disableLiquidGlass = false

    var body: some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background {
                    if #available(iOS 26, *), !disableLiquidGlass {
                        Circle()
                            .fill(.clear)
                            .glassEffect(.regular, in: Circle())
                    } else {
                        Circle().fill(.white.opacity(0.15))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

/// 歌单页同款控制排上下内边距：上 20pt、下 12pt，内容居中、间距 12pt。
struct CoDetailControlsRow<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        HStack(spacing: 12) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
}
