import QuartzCore
import SwiftUI
import UIKit

/// 全局高刷新率保持器，配合 Info.plist 请求设备支持的最高刷新率。
final class HighRefreshKeeper {
    static let shared = HighRefreshKeeper()
    static let defaultsKey = "beans.enableHighRefresh"

    private var displayLink: CADisplayLink?

    private init() {}

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [defaultsKey: false])
        // Co 省电：默认关闭高刷新常驻，不再强制 120Hz 空转；动画需要时由调用方临时开启
    }

    func configureFromDefaults() {
        configure(enabled: UserDefaults.standard.bool(forKey: Self.defaultsKey))
    }

    func configure(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.defaultsKey)
        if enabled {
            start()
        } else {
            stop()
        }
    }

    func attach(to view: UIView) {
        // Co 省电：底栏配置器不再自动启动 CADisplayLink 常驻；
        // 需要高刷的过渡动画由系统自身处理，不靠空转 DisplayLink 保频。
        _ = view
    }

    private func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        if #available(iOS 15.0, *) {
            let maximum = Float(min(120, max(60, UIScreen.main.maximumFramesPerSecond)))
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: maximum >= 120 ? 120 : maximum,
                maximum: maximum,
                preferred: maximum
            )
        } else {
            link.preferredFramesPerSecond = 120
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {}
}

struct HighRefreshConfigurator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        HighRefreshKeeper.shared.attach(to: uiView)
    }
}
