import Foundation

/// 仅保留已存设置键与共用小类型；仅保留已存设置键与共用小类型。
enum CoBackendSettings {
    static let blockedKey = "co.backend.userBlocked"
    static let exclusiveIDKey = "co.backend.exclusiveID"
    static let exclusiveIDBadgeStyleKey = "co.backend.exclusiveIDBadgeStyle"
    static let publicIDRevisionKey = "co.backend.publicIDRevision"
}

enum CoExclusiveIDBadgeStyle: String, CaseIterable, Codable {
    case blackPurpleGold = "black_purple_gold"
    case classicGold = "classic_gold"

    var displayName: String {
        switch self {
        case .blackPurpleGold: return "黑紫金"
        case .classicGold: return "经典金色"
        }
    }
}

enum CoWindowLayoutPolicy {
    static func usesSidebar(isPad: Bool, window: CGSize, proposed: CGSize) -> Bool {
        let size = window.width > 0 && window.height > 0 ? window : proposed
        return isPad && size.width > size.height
    }
}
