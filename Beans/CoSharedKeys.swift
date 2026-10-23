import Foundation

/// 仅保留已存设置键与共用小类型；仅保留已存设置键与共用小类型。
enum BeansBackendSettings {
    static let downloadUnlockKey = "beans.downloadFeatureUnlocked"
    static let downloadGlobalUnlockKey = "beans.downloadGlobalFeatureEnabled"
    static let blockedKey = "beans.backend.userBlocked"
    static let exclusiveIDKey = "beans.backend.exclusiveID"
    static let exclusiveIDBadgeStyleKey = "beans.backend.exclusiveIDBadgeStyle"
    static let publicIDRevisionKey = "beans.backend.publicIDRevision"
}

enum BeansExclusiveIDBadgeStyle: String, CaseIterable, Codable {
    case blackPurpleGold = "black_purple_gold"
    case classicGold = "classic_gold"

    var displayName: String {
        switch self {
        case .blackPurpleGold: return "黑紫金"
        case .classicGold: return "经典金色"
        }
    }
}

enum BeansWindowLayoutPolicy {
    static func usesSidebar(isPad: Bool, window: CGSize, proposed: CGSize) -> Bool {
        let size = window.width > 0 && window.height > 0 ? window : proposed
        return isPad && size.width > size.height
    }
}
