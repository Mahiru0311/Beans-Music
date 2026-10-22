import Foundation

/// 通用网络/解析错误（原 NetEaseError 改名，酷狗 API 共用，无网易云网络代码）。
enum CocoError: LocalizedError {
    case network
    case httpStatus(Int, String)
    case decoding(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .network: return "网络连接失败，请检查网络"
        case .httpStatus(let code, let snippet):
            return snippet.isEmpty ? "服务器响应异常（\(code)）" : "服务器响应异常（\(code)）\(snippet)"
        case .decoding(let snippet):
            return snippet.isEmpty ? "数据解析失败" : "数据解析失败：\(snippet)"
        case .unknown(let message): return message
        }
    }
}
