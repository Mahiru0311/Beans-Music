import Foundation

// Folia 舞台效果表（2026-10-25 精简后）：只留 5 个——绘光、流光、云阶、浮名、静止，
// 其余 11 个（商籁、凝彩、花火、心象、倾诉、回环、莫奈、时计、群唱、镜台、涌现）已删，
// 存档里已删的效果名由 availableMode 回落到静止，不会崩。
enum FoliaVisualizerMode: String, CaseIterable, Codable, Identifiable {
    case lumiere, classic, partita, fume, still

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lumiere: return "绘光"
        case .classic: return "流光"
        case .partita: return "云阶"
        case .fume: return "浮名"
        case .still: return "静止"
        }
    }

    var order: Int {
        switch self {
        case .lumiere: return 25
        case .classic: return 30
        case .partita: return 50
        case .fume: return 60
        case .still: return 130
        }
    }

    static var ordered: [Self] { allCases.sorted { $0.order < $1.order } }
}
