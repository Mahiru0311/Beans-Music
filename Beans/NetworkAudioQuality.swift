import Foundation

/// 酷狗选档只读统一键 beans.audioQuality；分网络逻辑已由一次性迁移接管，
/// 不再参与选档。Downloads keep their existing independent quality setting.
enum NetworkAudioQuality {
    static let connectionAwareKey = "beans.audioQuality.connectionAware"
    static let wifiOfficialKey = "beans.audioQuality.wifi"
    static let cellularOfficialKey = "beans.audioQuality.cellular"
    static let wifiThirdPartyKey = "beans.thirdPartyAudioQuality.wifi"
    static let cellularThirdPartyKey = "beans.thirdPartyAudioQuality.cellular"

    /// 统一音质键是唯一写入/读取路径（2026-10-24 音质移播放页后）：
    /// 不再按 Wi-Fi/蜂窝分键选档，旧的分网络逻辑只在迁移里用一次。
    static var officialPreferred: BeansAudioQuality {
        let raw = UserDefaults.standard.string(forKey: "beans.audioQuality") ?? BeansAudioQuality.hires.rawValue
        return BeansAudioQuality(rawValue: raw) ?? .hires
    }

    /// 一次性迁移：已开按网络选择的用户，统一键取他原来的 Wi-Fi 档位，
    /// 然后把 connectionAware 关掉；之后 officialPreferred 只读统一键，
    /// 不会悄悄还走分网络逻辑。只在 PlayerManager 初始化时调用一次。
    static func migrateConnectionAwareIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: connectionAwareKey) else { return }
        if let wifiRaw = defaults.string(forKey: wifiOfficialKey),
           BeansAudioQuality(rawValue: wifiRaw) != nil {
            defaults.set(wifiRaw, forKey: "beans.audioQuality")
        }
        defaults.set(false, forKey: connectionAwareKey)
    }

    static var thirdPartyPreferred: ThirdPartyAudioQuality {
        if let raw = selectedValue(
            wifiKey: wifiThirdPartyKey,
            cellularKey: cellularThirdPartyKey,
            fallbackKey: ThirdPartyAudioQuality.storageKey
        ), let quality = ThirdPartyAudioQuality(sourceValue: raw) {
            return quality
        }
        return .kb320
    }

    private static func selectedValue(wifiKey: String, cellularKey: String, fallbackKey: String) -> String? {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: connectionAwareKey) else {
            return defaults.string(forKey: fallbackKey)
        }

        switch BeansNetworkStatus.shared.connectionKind {
        case .wifi:
            return defaults.string(forKey: wifiKey) ?? defaults.string(forKey: fallbackKey)
        case .cellular:
            return defaults.string(forKey: cellularKey) ?? defaults.string(forKey: fallbackKey)
        case .other, .unavailable:
            return defaults.string(forKey: fallbackKey)
        }
    }
}
