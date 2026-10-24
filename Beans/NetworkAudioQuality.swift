import Foundation

/// 酷狗选档只读统一键 beans.audioQuality；分网络逻辑已由一次性迁移接管，
/// 不再参与选档。Downloads keep their existing independent quality setting.
enum NetworkAudioQuality {
    static let connectionAwareKey = "co.audioQuality.connectionAware"
    static let wifiOfficialKey = "co.audioQuality.wifi"
    static let cellularOfficialKey = "co.audioQuality.cellular"

    /// 统一音质键是唯一写入/读取路径（2026-10-24 音质移播放页后）：
    /// 不再按 Wi-Fi/蜂窝分键选档，旧的分网络逻辑只在迁移里用一次。
    static var officialPreferred: CoAudioQuality {
        let raw = UserDefaults.standard.string(forKey: "co.audioQuality") ?? CoAudioQuality.hires.rawValue
        return CoAudioQuality(rawValue: raw) ?? .hires
    }

    /// 一次性迁移：已开按网络选择的用户，统一键取他原来的 Wi-Fi 档位，
    /// 然后把 connectionAware 关掉；之后 officialPreferred 只读统一键，
    /// 不会悄悄还走分网络逻辑。只在 PlayerManager 初始化时调用一次。
    static func migrateConnectionAwareIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: connectionAwareKey) else { return }
        if let wifiRaw = defaults.string(forKey: wifiOfficialKey),
           CoAudioQuality(rawValue: wifiRaw) != nil {
            defaults.set(wifiRaw, forKey: "co.audioQuality")
        }
        defaults.set(false, forKey: connectionAwareKey)
    }

}
