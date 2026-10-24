import SwiftUI

// Folia 舞台特效（2026-10-25 重写）：歌词之外的氛围层，放在封面背景与歌词之间。
// 雨滴按真实配方重写（Geoff Blair 落雨丝 + TeenageProgrammer 落地飞溅 + 标准涟漪圈，三者拼起来）：
// 落雨丝——一滴的位置、速度、丝长、透明度由同一个 0–1 scale 联动（越快越长越不透明，远近分层），
// 风速所有滴共用，丝沿速度方向拉（速度向量归一化后反向乘丝长），开场 y 铺满屏幕、对象复用不重建；
// 落地反应——滴触底那一刻、在那一个 x 处同步生成，绝不同步错位：飞溅粒子向上抛物线（重力回落、收缩消失）
// 加涟漪圈（扩散 + 淡出 0.9s，下半被舞台底边裁掉，只留上半弧）。
// 上一版的问题正是涟漪用独立定时生成，雨和涟漪各下各的，看着假；这一版改成有状态粒子引擎，
// 滴、飞溅、涟漪全是同一套状态，30fps 驱动，数量克制，省电；开启减动效时整层不渲染。
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
    @State private var engine = FXEngine()
    @State private var lastDate = Date()

    var body: some View {
        if fx != .none && !reduceMotion {
            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    Canvas { ctx, _ in engine.draw(ctx: &ctx, size: geo.size, fx: fx) }
                        .onChange(of: context.date) { _, date in
                            let dt = min(0.1, max(0, date.timeIntervalSince(lastDate)))
                            lastDate = date
                            engine.step(fx: fx, size: geo.size, dt: dt)
                        }
                        .onAppear { engine.reset(fx: fx, size: geo.size); lastDate = Date() }
                        .onChange(of: fx) { _, _ in engine.reset(fx: fx, size: geo.size) }
                        .onChange(of: geo.size) { _, size in engine.reset(fx: fx, size: size) }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// 一套粒子引擎管全部四种特效：雨滴（丝 + 落地飞溅 + 涟漪）与飘雪/星尘/气泡（共用一种 mote）。
private struct FXEngine {
    // 雨滴：速度、丝长、透明度、线宽全由 scale 联动。
    struct Drop { var x, y, vx, vy, length, opacity, width: Double }
    // 落地飞溅：向上抛，重力拉回，半径与透明度随年龄衰减。
    struct SplashDot { var x, y, vx, vy, radius, age, life: Double }
    // 涟漪圈：扩散 + 淡出。
    struct Ripple { var x, age, life: Double }
    // 飘雪/星尘/气泡：baseX + 正弦摆动定横坐标，纵向单向走、到头换边；气泡用 distance 长大。
    struct Mote {
        var baseX, y, speed, phase, size, opacity, swayAmp, swayFreq, direction, distance: Double
    }

    var drops: [Drop] = []
    var splashDots: [SplashDot] = []
    var ripples: [Ripple] = []
    var motes: [Mote] = []
    var elapsed = 0.0

    /// 所有雨滴共用的横向风速（纵向速度的零头，丝因此微微斜）。
    private let wind = 18.0

    mutating func reset(fx: FoliaStageFX, size: CGSize) {
        drops = []; splashDots = []; ripples = []; motes = []; elapsed = 0
        let width = max(1, size.width), height = max(1, size.height)
        switch fx {
        case .rain:
            // 开场 y 铺满屏幕，不从顶部齐刷刷下来。
            drops = (0..<24).map { _ in makeDrop(width: width, height: height, initialY: Double.random(in: 0...height)) }
        case .snow:
            motes = (0..<48).map { _ in
                Mote(baseX: Double.random(in: 0...width), y: Double.random(in: 0...height),
                     speed: Double.random(in: 30...80), phase: Double.random(in: 0...6.28),
                     size: Double.random(in: 1.5...5), opacity: Double.random(in: 0.4...0.9),
                     swayAmp: 18, swayFreq: Double.random(in: 0.6...1.4), direction: 1, distance: 0)
            }
        case .stardust:
            motes = (0..<40).map { _ in
                Mote(baseX: Double.random(in: 0...width), y: Double.random(in: 0...height),
                     speed: Double.random(in: 14...40), phase: Double.random(in: 0...6.28),
                     size: Double.random(in: 1.5...3.5), opacity: 1,
                     swayAmp: 10, swayFreq: 0.8, direction: -1, distance: 0)
            }
        case .bubbles:
            motes = (0..<22).map { _ in
                Mote(baseX: Double.random(in: 0...width), y: Double.random(in: 0...height),
                     speed: Double.random(in: 24...60), phase: Double.random(in: 0...6.28),
                     size: Double.random(in: 3...8), opacity: 0.35,
                     swayAmp: 14, swayFreq: 0.7, direction: -1, distance: 0)
            }
        case .none:
            break
        }
    }

    private func makeDrop(width: Double, height: Double, initialY: Double) -> Drop {
        let scale = Double.random(in: 0...1)
        let vy = 620 + scale * 380
        return Drop(x: Double.random(in: -20...width + 20), y: initialY, vx: wind, vy: vy,
                    length: vy * 0.045, opacity: 0.25 + scale * 0.35, width: 1 + scale * 1.2)
    }

    mutating func step(fx: FoliaStageFX, size: CGSize, dt: Double) {
        guard dt > 0 else { return }
        elapsed += dt
        let width = max(1, size.width), height = max(1, size.height)
        switch fx {
        case .rain:
            for i in drops.indices {
                drops[i].x += drops[i].vx * dt
                drops[i].y += drops[i].vy * dt
                if drops[i].y > height {
                    // 落地同步反应：飞溅 8 粒 + 涟漪 1 圈，都在落点 x 处。
                    let x = drops[i].x
                    for _ in 0..<8 {
                        let life = Double.random(in: 0.3...0.8)
                        splashDots.append(SplashDot(x: x, y: height, vx: Double.random(in: -70...70),
                                                    vy: Double.random(in: -260 ... -80),
                                                    radius: Double.random(in: 2...5), age: 0, life: life))
                    }
                    ripples.append(Ripple(x: x, age: 0, life: 0.9))
                    drops[i] = makeDrop(width: width, height: height,
                                        initialY: -drops[i].length - Double.random(in: 0...100))
                }
            }
            splashDots = splashDots.compactMap { dot in
                var dot = dot
                dot.age += dt
                guard dot.age < dot.life else { return nil }
                dot.vy += 900 * dt
                dot.x += dot.vx * dt
                dot.y += dot.vy * dt
                return dot
            }
            ripples = ripples.compactMap { ripple in
                var ripple = ripple
                ripple.age += dt
                return ripple.age < ripple.life ? ripple : nil
            }
        case .snow, .stardust, .bubbles:
            for i in motes.indices {
                motes[i].y += motes[i].direction * motes[i].speed * dt
                motes[i].distance += motes[i].speed * dt
                if motes[i].direction > 0 && motes[i].y > height + 20 {
                    motes[i].y = -10; motes[i].baseX = Double.random(in: 0...width); motes[i].distance = 0
                } else if motes[i].direction < 0 && motes[i].y < -20 {
                    motes[i].y = height + 20; motes[i].baseX = Double.random(in: 0...width); motes[i].distance = 0
                }
            }
        case .none:
            break
        }
    }

    func draw(ctx: inout GraphicsContext, size: CGSize, fx: FoliaStageFX) {
        switch fx {
        case .rain:
            for drop in drops {
                let v = max(1, (drop.vx * drop.vx + drop.vy * drop.vy).squareRoot())
                var path = Path()
                path.move(to: CGPoint(x: drop.x, y: drop.y))
                path.addLine(to: CGPoint(x: drop.x - drop.vx / v * drop.length,
                                         y: drop.y - drop.vy / v * drop.length))
                ctx.stroke(path, with: .color(.white.opacity(drop.opacity)), lineWidth: drop.width)
            }
            for dot in splashDots {
                let progress = dot.age / dot.life
                let r = dot.radius * (1 - progress)
                guard r > 0.2 else { continue }
                let circle = Path(ellipseIn: CGRect(x: dot.x - r, y: dot.y - r, width: r * 2, height: r * 2))
                ctx.fill(circle, with: .color(.white.opacity((1 - progress) * 0.8)))
            }
            for ripple in ripples {
                let progress = ripple.age / ripple.life
                let radius = 6 + progress * 140
                let circle = Path(ellipseIn: CGRect(x: ripple.x - radius, y: size.height - radius,
                                                    width: radius * 2, height: radius * 2))
                ctx.stroke(circle, with: .color(.white.opacity((1 - progress) * 0.5)), lineWidth: 1.5)
            }
        case .snow:
            for mote in motes {
                let x = mote.baseX + sin(elapsed * mote.swayFreq + mote.phase) * mote.swayAmp
                let circle = Path(ellipseIn: CGRect(x: x - mote.size, y: mote.y - mote.size,
                                                    width: mote.size * 2, height: mote.size * 2))
                ctx.fill(circle, with: .color(.white.opacity(mote.opacity)))
            }
        case .stardust:
            for mote in motes {
                let x = mote.baseX + sin(elapsed * mote.swayFreq + mote.phase) * mote.swayAmp
                let twinkle = 0.5 + 0.5 * sin(elapsed * (1.5 + mote.phase * 0.4) + mote.phase)
                let r = mote.size
                var diamond = Path()
                diamond.move(to: CGPoint(x: x, y: mote.y - r * 1.6))
                diamond.addLine(to: CGPoint(x: x + r, y: mote.y))
                diamond.addLine(to: CGPoint(x: x, y: mote.y + r * 1.6))
                diamond.addLine(to: CGPoint(x: x - r, y: mote.y))
                diamond.closeSubpath()
                ctx.fill(diamond, with: .color(.white.opacity(0.15 + twinkle * 0.7)))
            }
        case .bubbles:
            for mote in motes {
                let x = mote.baseX + sin(elapsed * mote.swayFreq + mote.phase) * mote.swayAmp
                let r = mote.size + mote.distance * 0.02
                let circle = Path(ellipseIn: CGRect(x: x - r, y: mote.y - r, width: r * 2, height: r * 2))
                ctx.stroke(circle, with: .color(.white.opacity(mote.opacity)), lineWidth: 1)
            }
        case .none:
            break
        }
    }
}
