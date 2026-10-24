import SwiftUI

// Folia 舞台特效（2026-10-25）：歌词之外的氛围层，放在封面背景与歌词之间。
// 雨滴落下 + 底部涟漪是用户指定的做法（雨丝按速度拉长、落地泛开涟漪）；
// 星尘借自 Folia 开源项目的星屑（闪烁星点）；飘雪、气泡是同类轻量粒子做法。
// 全部共用一套无状态粒子算法：位置只由时间与序号算出，不攒状态、不逐帧改数据，
// 30fps 驱动、数量克制，省电；开启减动效时整层不渲染。
enum FoliaStageFX: String, CaseIterable, Identifiable {
    case none, rain, snow, stardust, bubbles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "无"
        case .rain: return "雨滴"
        case .snow: return "飘雪"
        case .stardust: return "星尘"
        case .bubbles: return "气泡"
        }
    }
}

struct FoliaStageFXView: View {
    let fx: FoliaStageFX
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if fx != .none && !reduceMotion {
            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    Canvas { ctx, _ in
                        draw(ctx: &ctx, size: geo.size,
                             time: context.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    /// 确定性伪随机：同一序号永远得到同一组参数，画面不抖。
    private func hash(_ index: Int, _ salt: Int) -> Double {
        let value = sin(Double(index * 127 + salt * 311) * 0.7) * 43758.5453
        return value - floor(value)
    }

    private func draw(ctx: inout GraphicsContext, size: CGSize, time: Double) {
        switch fx {
        case .rain: drawRain(ctx: &ctx, size: size, time: time)
        case .snow: drawSnow(ctx: &ctx, size: size, time: time)
        case .stardust: drawStardust(ctx: &ctx, size: size, time: time)
        case .bubbles: drawBubbles(ctx: &ctx, size: size, time: time)
        case .none: break
        }
    }

    // 雨滴：雨丝从顶上落到底下，速度越快丝越长（大滴落得更快）；落地处定时泛开涟漪。
    private func drawRain(ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let width = max(1, size.width), height = max(1, size.height)
        for i in 0..<36 {
            let speed = 620 + hash(i, 1) * 380
            let length = speed * 0.045
            let span = height + length
            let y = (hash(i, 4) * span + speed * time).truncatingRemainder(dividingBy: span) - length
            let x = hash(i, 0) * width + (max(0, y) / height) * 18
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x - 3, y: y - length))
            ctx.stroke(path, with: .color(.white.opacity(0.25 + hash(i, 3) * 0.35)),
                       lineWidth: 1 + hash(i, 2) * 1.2)
        }
        // 涟漪：每 0.18 秒在随机横坐标泛开一圈，0.9 秒内扩散淡出。
        for j in 0..<24 {
            let age = (time - Double(j) * 0.18).truncatingRemainder(dividingBy: 24 * 0.18)
            let life = 0.9
            guard age >= 0 && age < life else { continue }
            let progress = age / life
            let x = hash(j, 7) * width
            let radius = 6 + progress * 130
            let circle = Path(ellipseIn: CGRect(x: x - radius, y: height - radius,
                                                width: radius * 2, height: radius * 2))
            ctx.stroke(circle, with: .color(.white.opacity((1 - progress) * 0.5)), lineWidth: 1.5)
        }
    }

    // 飘雪：小雪片慢速下落，左右轻摆。
    private func drawSnow(ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let width = max(1, size.width), height = max(1, size.height)
        for i in 0..<48 {
            let speed = 30 + hash(i, 1) * 50
            let span = height + 20
            let y = (hash(i, 4) * span + speed * time).truncatingRemainder(dividingBy: span) - 10
            let x = hash(i, 0) * width + sin(time * (0.6 + hash(i, 2) * 0.8) + hash(i, 3) * 6.28) * 18
            let r = 1.5 + hash(i, 5) * 3.5
            let circle = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            ctx.fill(circle, with: .color(.white.opacity(0.4 + hash(i, 6) * 0.5)))
        }
    }

    // 星尘：小星点缓缓上升，亮度闪烁。
    private func drawStardust(ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let width = max(1, size.width), height = max(1, size.height)
        for i in 0..<40 {
            let speed = 14 + hash(i, 1) * 26
            let span = height + 20
            let y = height - (hash(i, 4) * span + speed * time).truncatingRemainder(dividingBy: span) + 10
            let x = hash(i, 0) * width + sin(time * 0.8 + hash(i, 2) * 6.28) * 10
            let twinkle = 0.5 + 0.5 * sin(time * (1.5 + hash(i, 3) * 2.5) + hash(i, 5) * 6.28)
            let r = 1.5 + hash(i, 6) * 2
            var diamond = Path()
            diamond.move(to: CGPoint(x: x, y: y - r * 1.6))
            diamond.addLine(to: CGPoint(x: x + r, y: y))
            diamond.addLine(to: CGPoint(x: x, y: y + r * 1.6))
            diamond.addLine(to: CGPoint(x: x - r, y: y))
            diamond.closeSubpath()
            ctx.fill(diamond, with: .color(.white.opacity(0.15 + twinkle * 0.7)))
        }
    }

    // 气泡：空心圆泡上升，越升越大，到顶消失。
    private func drawBubbles(ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let width = max(1, size.width), height = max(1, size.height)
        for i in 0..<22 {
            let speed = 24 + hash(i, 1) * 36
            let span = height + 40
            let risen = (hash(i, 4) * span + speed * time).truncatingRemainder(dividingBy: span)
            let y = height - risen + 20
            let x = hash(i, 0) * width + sin(time * 0.7 + hash(i, 2) * 6.28) * 14
            let r = 3 + hash(i, 3) * 5 + risen * 0.02
            let circle = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            ctx.stroke(circle, with: .color(.white.opacity(0.35)), lineWidth: 1)
        }
    }
}
