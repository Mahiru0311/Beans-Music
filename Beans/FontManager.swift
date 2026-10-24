import SwiftUI

/// 字体入口：全局字体功能已删，永远用系统字体（不再读用户上传的字体）。
enum CoFont {
    static func appFont(_ size: CGFloat, _ weight: Font.Weight = .regular, _ design: Font.Design = .default) -> Font {
        .system(size: size, weight: weight, design: design)
    }

    static func greetingFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        appFont(size, weight)
    }

    /// UIKit 版字体（UITextField 等 SwiftUI 不覆盖的控件用）
    static func appUIFont(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        .systemFont(ofSize: size, weight: weight)
    }
}
