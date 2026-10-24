import SwiftUI
import UIKit

/// 新版详情页共用件：滚动 + 上滑跟走复用 PlaylistView（每日推荐 / 用户歌单 / 榜单
/// 三种模式同用、已在真机上验证过）那套单路几何读数，只改名、不改算法；
/// 但封面放大按我的页（ProfileView.coFixedHeaderWallpaper）逻辑，不按歌单页的顶部锚点：
/// 先定框、再中心缩放、再裁剪——图从中间向两边放大，不是顶部钉住、只往下展开。
/// 对应关系：pull = coverPull、pullActive = coverPullActive、
/// startedAtTop = coverPullStartedAtTop、scrollOffset = playlistScrollOffset、
/// restOffset = playlistScrollRestOffset、scrollUp = playlistContentScrollUp。
/// 固定封面层在 ScrollView 之外、顶边钉在 0、下拉只缩放、上滑跟走单路读数；
/// 封面底部 120pt 遮罩淡出 + 虚化底深色罩从 0 起步、重叠 120pt 交叉淡化、封面底边无横线；
/// 歌名 28pt、占位 = 封面高 − 60pt；控制排胶囊 168×50pt、圆键 48×48pt、间距 12pt；
/// 下拉放慢：封顶 120pt、系数 pull/600、框高半速、回弹 response 0.9 / damping 1.0、
/// 拖动最小距离 8pt、门控只在手势开始时定一次（scrollOffset <= 20）。
/// 专辑页、歌手页用本文件全套；本地歌单页是 List 结构（swipeActions / 多选只在 List 里有），
/// 不能照搬 ScrollView 固定层，见 LocalPlaylistDetailSheet 里的等价实现说明。
/// 沉浸开关（beans.immersiveDetail.enabled）对这些页不再起分叉作用，body 永远走统一布局；
/// 设置页“沉浸详情界面”开关本身不动（只是页不再读它）。

/// 取色 helper 的回落深色底（旧统一深褐底的同一数值，不跟随系统深浅）。
/// 只在没拿到图时作回落，不再是所有页统一的底色。
let coDetailDarkBackground = Color(red: 0.14, green: 0.10, blue: 0.08)

/// 封面取色共用 helper（五页唯一取色入口，PlaylistView 与共用件都调它，不给各页各写一套）：
/// 把同一张虚化图下采样到 1×1 取平均 RGB，再与黑色按 65% 混合（各通道 × 0.35）。
/// 压暗系数选 0.35 的理由：白字系列（歌名、副标题、控制排）必须压在深色上才可读，
/// 原平均色直接作底会太亮；0.35 后亮封面也落在深色区，色相家族仍保留
/// （蓝封面 → 深蓝系、红封面 → 深红系），不是换一个固定色。没图时回落旧深褐底，
/// 图到了根部底色与虚化层最后一步同时变 tint，过渡处不产生新硬边。
func coCoverTint(from image: UIImage?) -> Color {
    guard let cgImage = image?.cgImage else { return coDetailDarkBackground }
    var pixel = [UInt8](repeating: 0, count: 4)
    guard let context = CGContext(
        data: &pixel,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return coDetailDarkBackground }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    let darken: CGFloat = 0.35
    return Color(
        red: CGFloat(pixel[0]) / 255 * darken,
        green: CGFloat(pixel[1]) / 255 * darken,
        blue: CGFloat(pixel[2]) / 255 * darken
    )
}

/// PlaylistView 滚动 + 下拉状态的逐字复用（只改名）：
/// 上滑量 = max(0, scrollOffset − restOffset)，restOffset 首帧定一次、之后不再重定；
/// 下拉门控只在手势开始时定一次（scrollOffset <= 20），不在顶部则 pull = 0。
final class CoDetailScrollState: ObservableObject {
    @Published var pull: CGFloat = 0
    private var pullActive = false
    private var startedAtTop = false
    @Published var scrollOffset: CGFloat = 0
    @Published var restOffset: CGFloat?

    var scrollUp: CGFloat {
        guard let rest = restOffset else { return 0 }
        return max(0, scrollOffset - rest)
    }

    func geometryChanged(_ value: CGFloat) {
        if restOffset == nil { restOffset = value }
        scrollOffset = value
    }

    func dragChanged(_ translation: CGSize) {
        if !pullActive {
            pullActive = true
            startedAtTop = scrollOffset <= 20
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

/// 滚动内容里的封面占位区：PlaylistView 的 playlistCoverSpacer 的逐字复用，
/// 高度是固定封面基线高（屏宽正方形）减 60pt，标题块整体往上压到封面底部
/// 渐变淡出段里，标题顶边比封面底边高 60pt。不上报任何全局坐标、不参与滚动读数。
struct CoDetailCoverSpacer: View {
    var body: some View {
        Color.clear
            .frame(height: UIScreen.main.bounds.width - 60)
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
                        .font(CoFont.appFont(16))
                        .foregroundStyle(.white.opacity(0.6))
                        .allowsHitTesting(false)
                }
                TextField("", text: $text)
                    .font(CoFont.appFont(16))
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
    /// 调用方根部底色：图层拿到虚化图时同步写成同一 tint，调用方不用另起下载取色；
    /// 不传时调用方根部仍回落旧值（本轮歌手、专辑两页都传）。
    var pageTint: Binding<Color>? = nil

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
                                .init(color: coCoverTint(from: image), location: 1),
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
            setBlurImage(nil)
            blurRetried = false
            refreshBlurImage()
        }
    }

    /// 封面放大按我的页同款写法（coFixedHeaderWallpaper），不要再用顶部锚点：
    /// 先定框（屏宽方形 + pull/2），再 .scaleEffect(zoom, anchor: .center)，
    /// 再 .clipped()，再外框顶部对齐 + 忽略顶部安全区，再整体上滑偏移。
    /// 中心缩放时：402pt 宽、pull=120 时框高 462、zoom 1.2，方形图在框里居中、
    /// 渲染高 482、框中心 231pt，渲染顶边 -10、底边 472，裁到框里后图从中间
    /// 向上下两边同时展开；旧的顶部锚点写法是渲染顶边钉在 0、全部扩张往下走，
    /// 向上的一半根本不存在，看起来就是把整个图片往下拉，不是放大。
    /// 方形图在 taller 框里居中：pull=0 时框高 = 图高，无缝隙；pull>0 时渲染高
    /// = 宽 × (1 + pull/600)，恒大于框高（宽 402 时每 pt 下拉多 0.17pt），
    /// 缩放后上下无空隙，不会露出底色带。
    private var fixedCover: some View {
        let width = UIScreen.main.bounds.width
        let height = width + pull / 2
        let zoom = 1 + pull / 600
        let fadeStart = max(0, (height - 120) / height)
        return ZStack {
            CoverImage(url: coverURL, size: width, cornerRadius: 0)
        }
        .frame(width: width, height: height)
        .scaleEffect(zoom, anchor: .center)
        .clipped()
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

    private func setBlurImage(_ image: UIImage?) {
        blurImage = image
        pageTint?.wrappedValue = coCoverTint(from: image)
    }

    private func refreshBlurImage() {
        let url = CustomSongCoverStore.shared.resolvedURL(for: coverURL) ?? coverURL
        guard let url else { setBlurImage(nil); return }
        if let image = CoCoverImageStore.memoryImage(for: url) {
            setBlurImage(image)
            return
        }
        CoCoverImageStore.loadCachedImage(for: url) { image in
            if let image {
                setBlurImage(image)
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
    @AppStorage("co.disableLiquidGlass") private var disableLiquidGlass = false

    var body: some View {
        Button {
            CoHaptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text(title)
            }
            .font(CoFont.appFont(18, .semibold))
            .foregroundStyle(.black)
            .frame(width: 168, height: 50)
            .background {
                if !disableLiquidGlass {
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
