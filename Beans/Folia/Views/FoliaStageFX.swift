import SwiftUI

// Folia 舞台特效（2026-10-25 第二次重做）：歌词之外的氛围层，放在封面背景与歌词之间。
// 上一版在真机上看着“一个没改”，所以这一版四个特效全部按别的开源项目重做，不再只调参数：
// 雨滴——Geoff Blair 落雨丝（速度/丝长/透明度同 scale 联动、共用风速、丝沿速度方向拉）
//   + TeenageProgrammer 落地飞溅（触底同步生成、向上抛物线、重力回落）+ 标准涟漪圈；
//   这一版加了两层远近（远滴小而淡而慢、近滴大而亮而快）与双圈涟漪（第二圈晚 0.15s），一眼能看出雨；
// 飘雪——react-snowfall（cahilfoley，602 星）：半径 0.5–3.0、速度 1.0–3.0、风 −0.5–2.0（每帧），
//   每 200 帧（约 3.3 秒）风速与落速重新随机、向新值平滑过渡（阵风感），这里按手机尺寸 ×2 缩放、
//   数量降到 60 颗省电，另加一点半径相关的正弦飘摆（手机上更易看清）；
// 星尘——grok-shooting-stars（UsmanDevCraft）：闪烁公式 0.4 + |sin(t×1.5 + 相位)| × 0.5、
//   尺寸 0.6–2.2（手机 ×2），尘埃缓慢下沉不再上飘，另加一颗罕见流星（每 8–15 秒一颗斜划过去）；
// 气泡——mauveweb 气泡物理 + CodePen 气泡动画：上升越久越快（浮力随体积长大）、
//   半径随上升长大（水压减小）、摆动幅度按尺寸缩放的正弦摆动、到水面（顶部 10%）淡出消失。
// 30fps 驱动，数量克制；开启减动效时整层不渲染。
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

// 一套粒子引擎管全部四种特效：雨滴（丝 + 落地飞溅 + 双圈涟漪）、飘雪（阵风）、
// 星尘（闪烁 + 流星）、气泡（加速 + 长大 + 淡出）。
private struct FXEngine {
    // 雨滴：速度、丝长、透明度、线宽全由 scale 联动。
    struct Drop { var x, y, vx, vy, length, opacity, width: Double }
    // 落地飞溅：向上抛，重力拉回，半径与透明度随年龄衰减。
    struct SplashDot { var x, y, vx, vy, radius, age, life: Double }
    // 涟漪圈：扩散 + 淡出；delay 让第二圈晚一点出现。
    struct Ripple { var x, age, life, delay, maxRadius, opacity, lineWidth: Double }
    // 飘雪：落速与风速向随机新值平滑过渡（react-snowfall 的阵风）。
    struct Flake { var x, y, radius, speed, wind, nextSpeed, nextWind, changeTimer, phase, swayFreq: Double }
    // 星尘：闪烁相位 + 缓慢下沉。
    struct Star { var x, y, size, phase, drift: Double }
    // 流星：斜向划过的亮 streak，带尾巴。
    struct ShootingStar { var x, y, vx, vy, age, life: Double }
    // 气泡：上升距离 distance 决定加速、长大、淡出。
    struct Bubble { var baseX, y, baseSpeed, size, coeff, phase, freq, alpha, distance: Double }

    var drops: [Drop] = []
    var splashDots: [SplashDot] = []
    var ripples: [Ripple] = []
    var flakes: [Flake] = []
    var stars: [Star] = []
    var shooting: ShootingStar?
    var shootTimer = 10.0
    var bubbles: [Bubble] = []
    var elapsed = 0.0

    /// 所有雨滴共用的横向风速（纵向速度的零头，丝因此微微斜）。
    private let wind = 18.0

    mutating func reset(fx: FoliaStageFX, size: CGSize) {
        drops = []; splashDots = []; ripples = []; flakes = []; stars = []
        shooting = nil; shootTimer = Double.random(in: 8...15); bubbles = []; elapsed = 0
        let width = max(1, size.width), height = max(1, size.height)
        switch fx {
        case .rain:
            // 两层远近：远滴 16 颗（scale 0–0.4，小而淡而慢），近滴 16 颗（scale 0.6–1，大而亮而快）。
            // 开场 y 铺满屏幕，不从顶部齐刷刷下来。
            drops = (0..<16).map { _ in makeDrop(width: width, height: height, scale: Double.random(in: 0...0.4),
                                                 initialY: Double.random(in: 0...height)) }
                + (0..<16).map { _ in makeDrop(width: width, height: height, scale: Double.random(in: 0.6...1),
                                               initialY: Double.random(in: 0...height)) }
        case .snow:
            // react-snowfall 默认值 ×2（手机尺寸）：半径 1–6、落速 60–180/秒、风 −30–120/秒。
            flakes = (0..<60).map { _ in
                let speed = Double.random(in: 60...180)
                let windSpeed = Double.random(in: -30...120)
                return Flake(x: Double.random(in: 0...width), y: Double.random(in: 0...height),
                             radius: Double.random(in: 1...6), speed: speed, wind: windSpeed,
                             nextSpeed: speed, nextWind: windSpeed,
                             changeTimer: Double.random(in: 2.5...4),
                             phase: Double.random(in: 0...6.28), swayFreq: Double.random(in: 0.5...1.2))
            }
        case .stardust:
            // grok 尺寸 0.6–2.2 ×2；尘埃缓慢下沉（不再上飘），到头换回顶部。
            stars = (0..<40).map { _ in
                Star(x: Double.random(in: 0...width), y: Double.random(in: 0...height),
                     size: Double.random(in: 1.2...4.4), phase: Double.random(in: 0...6.28),
                     drift: Double.random(in: 8...20))
            }
        case .bubbles:
            bubbles = (0..<24).map { _ in
                Bubble(baseX: Double.random(in: 0...width), y: Double.random(in: 0...height),
                       baseSpeed: Double.random(in: 24...60), size: Double.random(in: 3...8),
                       coeff: Double.random(in: -1...1), phase: Double.random(in: 0...6.28),
                       freq: Double.random(in: 0.6...1.4), alpha: Double.random(in: 0.2...0.7), distance: 0)
            }
        case .none:
            break
        }
    }

    private func makeDrop(width: Double, height: Double, scale: Double, initialY: Double) -> Drop {
        let vy = 550 + scale * 550
        return Drop(x: Double.random(in: -20...width + 20), y: initialY, vx: wind, vy: vy,
                    length: vy * 0.045, opacity: 0.3 + scale * 0.6, width: 1 + scale * 1)
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
                    // 落地同步反应：飞溅 10 粒 + 双圈涟漪（第二圈晚 0.15s），都在落点 x 处。
                    let x = drops[i].x
                    for _ in 0..<10 {
                        let life = Double.random(in: 0.5...1.0)
                        splashDots.append(SplashDot(x: x, y: height, vx: Double.random(in: -90...90),
                                                    vy: Double.random(in: -300 ... -100),
                                                    radius: Double.random(in: 3...7), age: 0, life: life))
                    }
                    ripples.append(Ripple(x: x, age: 0, life: 0.9, delay: 0,
                                          maxRadius: 140, opacity: 0.7, lineWidth: 2))
                    ripples.append(Ripple(x: x, age: -0.15, life: 0.9, delay: 0.15,
                                          maxRadius: 90, opacity: 0.5, lineWidth: 1.5))
                    // 远近分层：重生时保持原来的远近（由落速反推 scale，不重新随机，避免忽远忽近）。
                    let scale = min(1, max(0, (drops[i].vy - 550) / 550))
                    drops[i] = makeDrop(width: width, height: height, scale: scale,
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
        case .snow:
            for i in flakes.indices {
                // 阵风：落速与风速向随机新值平滑过渡；约 3 秒换一次新值。
                flakes[i].changeTimer -= dt
                if flakes[i].changeTimer <= 0 {
                    flakes[i].nextSpeed = Double.random(in: 60...180)
                    flakes[i].nextWind = Double.random(in: -30...120)
                    flakes[i].changeTimer = Double.random(in: 2.5...4)
                }
                let lerp = min(1, dt * 2)
                flakes[i].speed += (flakes[i].nextSpeed - flakes[i].speed) * lerp
                flakes[i].wind += (flakes[i].nextWind - flakes[i].wind) * lerp
                flakes[i].x += flakes[i].wind * dt
                    + sin(elapsed * flakes[i].swayFreq + flakes[i].phase) * flakes[i].radius * 1.5 * dt
                flakes[i].y += flakes[i].speed * dt
                if flakes[i].y > height + 10 {
                    flakes[i].y = -10; flakes[i].x = Double.random(in: 0...width)
                }
                if flakes[i].x < -10 { flakes[i].x = width + 10 }
                if flakes[i].x > width + 10 { flakes[i].x = -10 }
            }
        case .stardust:
            for i in stars.indices {
                stars[i].y += stars[i].drift * dt
                if stars[i].y > height + 10 {
                    stars[i].y = -10; stars[i].x = Double.random(in: 0...width)
                }
            }
            // 罕见流星：一次只一颗，划完等 8–15 秒再来。
            if shooting == nil {
                shootTimer -= dt
                if shootTimer <= 0 {
                    shooting = ShootingStar(x: Double.random(in: 0...width * 0.5), y: Double.random(in: 0...height * 0.4),
                                            vx: Double.random(in: 600...900), vy: Double.random(in: 200...400),
                                            age: 0, life: 0.8)
                }
            } else if var star = shooting {
                star.age += dt
                if star.age >= star.life || star.x > width + 100 || star.y > height + 100 {
                    shooting = nil; shootTimer = Double.random(in: 8...15)
                } else {
                    star.x += star.vx * dt; star.y += star.vy * dt
                    shooting = star
                }
            }
        case .bubbles:
            for i in bubbles.indices {
                // 浮力：上升越久越快；水压：半径随上升长大；到水面（顶部 10%）淡出。
                let progress = min(1, bubbles[i].distance / height)
                let speed = bubbles[i].baseSpeed * (1 + progress * 1.5)
                bubbles[i].y -= speed * dt
                bubbles[i].distance += speed * dt
                if bubbles[i].y < -20 {
                    bubbles[i].y = height + 20; bubbles[i].baseX = Double.random(in: 0...width); bubbles[i].distance = 0
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
                guard ripple.age >= 0 else { continue }
                let progress = ripple.age / ripple.life
                let radius = 6 + progress * ripple.maxRadius
                let circle = Path(ellipseIn: CGRect(x: ripple.x - radius, y: size.height - radius,
                                                    width: radius * 2, height: radius * 2))
                ctx.stroke(circle, with: .color(.white.opacity((1 - progress) * ripple.opacity)),
                           lineWidth: ripple.lineWidth)
            }
        case .snow:
            for flake in flakes {
                let circle = Path(ellipseIn: CGRect(x: flake.x - flake.radius, y: flake.y - flake.radius,
                                                    width: flake.radius * 2, height: flake.radius * 2))
                ctx.fill(circle, with: .color(.white.opacity(0.5 + flake.radius / 6 * 0.5)))
            }
        case .stardust:
            for star in stars {
                // grok 闪烁：0.4 + |sin(t×1.5 + 相位)| × 0.5。
                let flicker = 0.4 + abs(sin(elapsed * 1.5 + star.phase)) * 0.5
                let r = star.size
                var diamond = Path()
                diamond.move(to: CGPoint(x: star.x, y: star.y - r * 1.6))
                diamond.addLine(to: CGPoint(x: star.x + r, y: star.y))
                diamond.addLine(to: CGPoint(x: star.x, y: star.y + r * 1.6))
                diamond.addLine(to: CGPoint(x: star.x - r, y: star.y))
                diamond.closeSubpath()
                ctx.fill(diamond, with: .color(.white.opacity(flicker)))
            }
            if let star = shooting {
                let progress = star.age / star.life
                let opacity = (1 - progress) * 0.9
                var path = Path()
                path.move(to: CGPoint(x: star.x, y: star.y))
                path.addLine(to: CGPoint(x: star.x - star.vx * 0.15, y: star.y - star.vy * 0.15))
                ctx.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: 2)
                let head = Path(ellipseIn: CGRect(x: star.x - 2, y: star.y - 2, width: 4, height: 4))
                ctx.fill(head, with: .color(.white.opacity(opacity)))
            }
        case .bubbles:
            for bubble in bubbles {
                let progress = min(1, bubble.distance / max(1, size.height))
                // 到水面（顶部 10%）平滑淡出。
                let fade = progress < 0.9 ? 1.0 : 1.0 - (progress - 0.9) / 0.1
                let x = bubble.baseX + sin(elapsed * bubble.freq + bubble.phase) * bubble.size * 0.5 * bubble.coeff
                let r = bubble.size * (1 + progress * 0.6)
                let circle = Path(ellipseIn: CGRect(x: x - r, y: bubble.y - r, width: r * 2, height: r * 2))
                ctx.fill(circle, with: .color(.white.opacity(0.12 * fade)))
                ctx.stroke(circle, with: .color(.white.opacity(bubble.alpha * fade)), lineWidth: 1)
            }
        case .none:
            break
        }
    }
}
