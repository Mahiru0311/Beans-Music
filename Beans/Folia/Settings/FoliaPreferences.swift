import Foundation

// Separate namespaced settings coexist with Beans' original wallpaper, glass, and lyric preferences.
enum FoliaPreferences {
    static let enabledKey = "beans.folia.stage.enabled"
    static let modeKey = "beans.folia.stage.mode"
    static let fontScaleKey = "beans.folia.lyrics.fontScale"
    static let subtitleScaleKey = "beans.folia.lyrics.subtitleScale"
    static let translationKey = "beans.folia.lyrics.showTranslation"
    static let primaryColorKey = "beans.folia.theme.primary"
    static let secondaryColorKey = "beans.folia.theme.secondary"
    static let daylightKey = "beans.folia.theme.daylight"
    static let showTextKey = "beans.folia.lyrics.showText"
    static let accentColorKey = "beans.folia.theme.accent"
    static let classicIntensityKey = "beans.folia.classic.intensity"
    static let classicRotationKey = "beans.folia.classic.enableWordRotation"
    static let classicBreathingKey = "beans.folia.classic.breathingFloatMultiplier"
    static let classicLegacyLayoutKey = "beans.folia.classic.useLegacyLayout"
    static let classicSpacingKey = "beans.folia.classic.wordSpacing"

    static func availableMode(rawValue: String) -> FoliaVisualizerMode? {
        guard let mode = FoliaVisualizerMode(rawValue: rawValue), mode.hasNativeRenderer else { return nil }
        return mode
    }
}
