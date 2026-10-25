import Foundation

/// 酷狗专版通用错误（通用错误类型）。
enum CoError: LocalizedError {
    case network
    case decoding(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .network: return "网络连接失败，请检查网络"
        case .decoding(let snippet):
            return snippet.isEmpty ? "数据解析失败" : "数据解析失败：\(snippet)"
        case .unknown(let message): return message
        }
    }
}
