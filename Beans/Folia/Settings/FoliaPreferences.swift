import Foundation

// Separate namespaced settings coexist with Beans' original wallpaper, glass, and lyric preferences.
enum FoliaPreferences {
    static let modeKey = "co.folia.stage.mode"
    static let fxKey = "co.folia.stage.fx"
    static let fontScaleKey = "co.folia.lyrics.fontScale"
    static let subtitleScaleKey = "co.folia.lyrics.subtitleScale"
    static let translationKey = "co.folia.lyrics.showTranslation"
    static let primaryColorKey = "co.folia.theme.primary"
    static let secondaryColorKey = "co.folia.theme.secondary"
    static let daylightKey = "co.folia.theme.daylight"
    static let showTextKey = "co.folia.lyrics.showText"
    static let accentColorKey = "co.folia.theme.accent"
    static let classicIntensityKey = "co.folia.classic.intensity"
    static let classicRotationKey = "co.folia.classic.enableWordRotation"
    static let classicBreathingKey = "co.folia.classic.breathingFloatMultiplier"
    static let classicLegacyLayoutKey = "co.folia.classic.useLegacyLayout"
    static let classicSpacingKey = "co.folia.classic.wordSpacing"

    /// 重构后全部保留的效果都有渲染器；旧存档里已删的效果名回落到静止，不再出现空壳提示。
    static func availableMode(rawValue: String) -> FoliaVisualizerMode {
        FoliaVisualizerMode(rawValue: rawValue) ?? .still
    }
}
