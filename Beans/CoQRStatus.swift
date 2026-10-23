import Foundation
import CommonCrypto

/// 通用扫码登录状态（原在已删的网易云登录文件里，酷狗登录页仍在用）。
enum QRStatus: Equatable {
    case loading
    case waiting
    case scanned
    case success
    case expired
    case error(String)
}

extension Data {
    /// MD5 十六进制（酷狗签名用，原在已删的加密文件里）。
    func md5Hex() -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = withUnsafeBytes { CC_MD5($0.baseAddress, CC_LONG(count), &digest) }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
