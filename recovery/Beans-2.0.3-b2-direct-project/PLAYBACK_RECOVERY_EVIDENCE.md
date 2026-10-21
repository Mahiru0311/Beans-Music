# Playback — direct Beans 2.0.3 build 2 recovery

Updated 2026-10-21. These behaviors are recovered from the supplied unencrypted 2.0.3 build 2 executable. Previous-version sources are not the implementation base. Descriptive method names, injectable dependencies and file boundaries are reconstruction choices. Ghidra's pseudocode alone is not authoritative: ARM64 instructions and callers resolve Swift ABI and error handling.

## Persisted listening statistics

| Function | Recovered behavior |
| --- | --- |
| `0x100376684` | Reads a Double from `beans.playback.listeningDuration.v1`. ARM64 `fcmp`/`fcsel ... ge` preserves nonnegative values, including positive infinity; negative and NaN values select zero. It does not repair storage. |
| `0x100379174` | Reads Data under `beans.playcounts`, decodes `[String: Int]`, and sums values with checked addition. Missing Data or a JSON decoding error yields zero. Negative entries remain signed. The Swift error-register branch at `0x100379284` is essential: Ghidra initially labels the actual error path unreachable. |
| `0x1003766ec` | Adds `max(0, integer(forKey: beans.playback.listeningPlayCountOffset.v1))` to that JSON sum. The final sum is not clamped. |
| `0x100376758` | Independently merges two optional Int totals. Duration writes only when incoming seconds exceed the floored current duration. Count writes only when incoming total exceeds the stored total; it rereads the total, computes the difference and adds it to the nonnegative stored offset. It leaves the per-song JSON intact. |

`0x100174cd8` passes the account response's optional statistics fields to the merge routine. `0x100172c04` uses the two getters when constructing the outgoing device/account payload. Those callers establish context; their entire network and notification paths are not claimed implemented.

The duration merge uses checked Double-to-Int conversion after flooring. An infinite or out-of-Int-range current value traps when a non-nil duration is merged, as does overflowing Int arithmetic. The reconstruction retains normal Swift checked arithmetic rather than adding undocumented saturating behavior. The focused XCTest suite does not deliberately crash its runner to test traps.

The original routines use `UserDefaults.standard`; the recovered static methods on PlayerManager accept an explicit defaults instance for isolated tests and default to `.standard`. These routines do not update the in-memory published statistics fields. Notification registration remains separate work.

## Listening session accumulation

- `0x10037ff28` samples `ProcessInfo.systemUptime` only if `listeningSegmentStartedUptime` is nil. Repeated starts preserve the existing timestamp.
- `0x10037f99c` returns immediately if no segment exists. Otherwise it adds a strictly positive uptime delta to `pendingListeningDuration`, clears the segment, then calls `0x10037cf18` even if that delta was nonpositive. NaN deltas fail the comparison.
- `0x10037cf18` returns unless pending duration is strictly positive. It adds pending duration to the in-memory listening duration, resets pending to zero, persists a nonnegative/NaN-to-zero view of the updated total using the instance's defaults, then samples uptime for `lastListeningPublishUptime`. The in-memory total itself is not clamped.
- `0x1003921fc` requires both the manager's playing flag and AVPlayer time-control status 2. Otherwise it ends the segment and clears `lastListeningProgress`/`lastListeningSongKey` through `0x10037fa4c`. While playing it begins a segment if needed, accumulates each positive delta, advances the segment start only for a positive delta, and flushes when a separately sampled uptime is at least 15 seconds past the last publication. The assembly's `b.ge` rejects an unordered/NaN threshold comparison.
- The paths use elapsed system uptime, not the song position or playback rate. Testable clock closures preserve separate begin/delta/threshold/publication samples. Tests cover exact 15-second equality, pause gaps, repeated starts, skipped flushes and persisted-versus-in-memory clamping.

The original Combine storage key path at `0x10077f550` points to the field-offset slot `0x100b3a110`; its wrapped-property path at `0x10077f830` names getter `0x1003787e4`. The reconstruction currently restores state and storage behavior on the metadata-derived PlayerManager; its full ObservableObject publication and audio callback registration are not yet reconstructed.

An exploratory export at `0x10037cb00` was inside a function and is excluded. The correct LC_FUNCTION_STARTS entry is `0x10037caec`; its weak-self notification callback refreshes duration against persisted duration and sends objectWillChange. The Ghidra database boundary was repaired and the exact function was exported. That callback is evidence, not an implemented notification path.

## Validation and evidence

`PlayerListeningStatisticsRecoveryTests` covers missing storage, fractional duration, negative/NaN/infinite getter behavior, JSON decoding failure, signed counts, negative offsets, nil inputs, monotonic synchronization, repeated sync, continued local counting and independent remote fields.

The local delivery contains `Evidence/PlayerARM64/` and `Evidence/Beans-2.0.3-b2-player-arm64-manifest.json`, with executable identity, LC_FUNCTION_STARTS checks, raw constants and export hashes. Exported investigative functions are not counts of implemented behavior. The current verified commit/test checkpoint is recorded separately in `RECOVERY_STATUS.md`. No device-level equivalence or complete playable app is claimed.
