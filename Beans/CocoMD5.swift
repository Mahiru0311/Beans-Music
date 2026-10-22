import Foundation
import CryptoKit

/// Data MD5（原实现随已删的 NetEaseCrypto 一起被删，酷狗签名仍依赖它；改用 CryptoKit，不引 CommonCrypto）。
extension Data {
    func md5Hex() -> String {
        Insecure.MD5.hash(data: self).map { String(format: "%02x", $0) }.joined()
    }
}
