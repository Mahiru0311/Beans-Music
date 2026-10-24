import Foundation

// Folia v0.7.16 registry identities. Entries describe separate renderers, never aliases.
enum FoliaPortStatus: String, Codable {
    case pending
    case draft
    case verified
}

enum FoliaVisualizerMode: String, CaseIterable, Codable, Identifiable {
    case cadenza, cappella, claddagh, classic, diorama, fume, lumiere
    case monet, partita, pendolo, sonnet, still, tempera, tilt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cadenza: return "心象"
        case .cappella: return "群唱"
        case .claddagh: return "回环"
        case .classic: return "流光"
        case .diorama: return "镜台"
        case .fume: return "浮名"
        case .lumiere: return "绘光"
        case .monet: return "莫奈"
        case .partita: return "云阶"
        case .pendolo: return "时计"
        case .sonnet: return "商籁"
        case .still: return "静止"
        case .tempera: return "凝彩"
        case .tilt: return "倾诉"
        }
    }

    var order: Int {
        switch self {
        case .sonnet: return 10
        case .tempera: return 20
        case .lumiere: return 25
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
        }
    }

    var portStatus: FoliaPortStatus { hasNativeRenderer ? .draft : .pending }
    var hasNativeRenderer: Bool { self == .still || self == .classic }
    var sourcePath: String { "src/components/visualizer/\(rawValue)/entry.tsx" }

    static var ordered: [Self] { allCases.sorted { $0.order < $1.order } }
}

