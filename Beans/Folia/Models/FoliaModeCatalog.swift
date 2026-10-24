import Foundation

// Folia 舞台效果表：15 个 folia-major 原版（按原版 order 排）+ 涌现（QQ 音乐式，Co 自加，放最后）。
// 设置页按 order 排序显示；rawValue 是存档身份，order 只管排序，改 order 不影响已存偏好。
enum FoliaVisualizerMode: String, CaseIterable, Codable, Identifiable {
    case sonnet, tempera, lumiere, hanabi, classic, cadenza, partita, fume,
         tilt, claddagh, monet, pendolo, cappella, diorama, still, rise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sonnet: return "商籁"
        case .tempera: return "凝彩"
        case .lumiere: return "绘光"
        case .hanabi: return "花火"
        case .classic: return "流光"
        case .cadenza: return "心象"
        case .partita: return "云阶"
        case .fume: return "浮名"
        case .tilt: return "倾诉"
        case .claddagh: return "回环"
        case .monet: return "莫奈"
        case .pendolo: return "时计"
        case .cappella: return "群唱"
        case .diorama: return "镜台"
        case .still: return "静止"
        case .rise: return "涌现"
        }
    }

    var order: Int {
        switch self {
        case .sonnet: return 10
        case .tempera: return 20
        case .lumiere: return 25
        case .hanabi: return 26
        case .classic: return 30
        case .cadenza: return 40
        case .partita: return 50
        case .fume: return 60
        case .tilt: return 70
        case .claddagh: return 80
        case .monet: return 90
        case .pendolo: return 100
        case .cappella: return 110
        case .diorama: return 120
        case .still: return 130
        case .rise: return 140
        }
    }

    /// 重构后全部效果都有原生渲染器，不再有待移植项。
    var hasNativeRenderer: Bool { true }

    static var ordered: [Self] { allCases.sorted { $0.order < $1.order } }
}
