import Foundation

/// 仅保留已存设置键与共用小类型；仅保留已存设置键与共用小类型。
enum CoBackendSettings {
    static let blockedKey = "co.backend.userBlocked"
}

enum CoWindowLayoutPolicy {
    static func usesSidebar(isPad: Bool, window: CGSize, proposed: CGSize) -> Bool {
        let size = window.width > 0 && window.height > 0 ? window : proposed
        return isPad && size.width > size.height
    }
}
