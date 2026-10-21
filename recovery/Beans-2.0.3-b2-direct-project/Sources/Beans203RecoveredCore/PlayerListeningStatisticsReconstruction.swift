import Foundation

extension PlayerManager_2_0_3 {
    // Names and injectable defaults are reconstruction seams. The executable
    // uses UserDefaults.standard and does not mutate instance published state here.
    private static let listeningDurationKey = "beans.playback.listeningDuration.v1"
    private static let listeningPlayCountOffsetKey = "beans.playback.listeningPlayCountOffset.v1"
    private static let persistedPlayCountsKey = "beans.playcounts"

    /// 0x100376684: negative and NaN values select zero; positive infinity survives.
    public static func storedListeningDuration(in defaults: UserDefaults = .standard) -> Double {
        let value = defaults.double(forKey: listeningDurationKey)
        return value >= 0 ? value : 0
    }

    /// 0x1003766ec / 0x100379174: sum JSON counts, then add the nonnegative offset.
    /// Malformed or absent JSON contributes zero. Individual counts are not clamped.
    public static func storedListeningPlayCount(in defaults: UserDefaults = .standard) -> Int {
        let base: Int
        if let data = defaults.data(forKey: persistedPlayCountsKey),
           let counts = try? JSONDecoder().decode([String: Int].self, from: data) {
            base = counts.values.reduce(0, +)
        } else {
            base = 0
        }
        return base + max(0, defaults.integer(forKey: listeningPlayCountOffsetKey))
    }

    /// 0x100376758: only higher remote totals are persisted. The per-song count
    /// dictionary remains intact; a separate offset absorbs the remote difference.
    /// Swift's checked Int arithmetic/conversion preserves the executable's traps.
    public static func mergeListeningStatistics(
        listeningSeconds: Int?, listeningPlayCount: Int?,
        defaults: UserDefaults = .standard
    ) {
        if let listeningSeconds,
           listeningSeconds > Int(storedListeningDuration(in: defaults).rounded(.down)) {
            defaults.set(Double(listeningSeconds), forKey: listeningDurationKey)
        }
        if let listeningPlayCount, storedListeningPlayCount(in: defaults) < listeningPlayCount {
            // The binary reads the total again before subtracting. Preserve that
            // ordering instead of caching across potentially concurrent changes.
            let difference = listeningPlayCount - storedListeningPlayCount(in: defaults)
            let offset = max(0, defaults.integer(forKey: listeningPlayCountOffsetKey))
            defaults.set(offset + difference, forKey: listeningPlayCountOffsetKey)
        }
    }
}
