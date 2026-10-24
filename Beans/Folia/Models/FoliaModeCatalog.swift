import Foundation

// Folia 舞台效果表（2026-10-25 重构后）：只留 8 个全部有原生渲染器的效果，
// 待移植的空壳项已全部拿掉，设置页不再出现“待移植”。
enum FoliaVisualizerMode: String, CaseIterable, Codable, Identifiable {
    case sonnet, tempera, classic, cadenza, partita, fume, diorama, still, rise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sonnet: return "商籁"
        case .tempera: return "凝彩"
        case .classic: return "流光"
        case .cadenza: return "心象"
        case .partita: return "云阶"
        case .fume: return "浮名"
        case .diorama: return "镜台"
        case .still: return "静止"
        case .rise: return "涌现"
        }
    }

    var order: Int {
        switch self {
        case .sonnet: return 10
        case .tempera: return 20
        case .classic: return 30
        case .cadenza: return 40
        case .partita: return 50
        case .fume: return 60
        case .diorama: return 70
        case .still: return 80
        case .rise: return 90
        }
    }

    /// 重构后全部效果都有原生渲染器，不再有待移植项。
    var hasNativeRenderer: Bool { true }

    static var ordered: [Self] { allCases.sorted { $0.order < $1.order } }
}
