# Beans 2.0.3 build 2 — recovery status

Updated 2026-10-21. This is an independently reconstructed Swift Package based on the supplied unencrypted IPA. It is not yet the complete runnable application and is not the desktop Beans-2.0.3-unsigned.ipa. Original source comments, exact file organization and unrecoverable compiler-erased details are not claimed as restored.

## Verified source checkpoint

- Source commit: bcb92f8fd9426606024a8f600efbe5b1e3825fc1.
- GitHub Actions run: 39556162533; completed 2026-10-21T06:35:32Z; success.
- Eight library targets compiled with the iPhoneOS SDK for arm64-apple-ios16.1.
- Offline macOS XCTest: 204 tests, 0 failures.
- Workflow: .github/workflows/validate-direct-reconstruction.yml. It runs package description, compilation and tests; no IPA packaging, signing, upload or Release.
- Local evidence: Evidence/Beans-2.0.3-b2-recovery-validation.json and Evidence/Validation/ contain exact revisions, run metadata, logs and log hashes. Documentation commits after this checkpoint do not imply a new source test.

## Executable recovery completed so far

- WebDAV request construction, XML listing parsing and backup-related structures; focused CiliCili listen-source identity.
- Qishui request/response handling, cache policies, artwork parsing, song/playlist mapping, search pagination, playlist details, playback URL, lyrics, comments, artist filtering and album grouping.
- LRC timestamps and offsets, translation matching, three karaoke formats, word-to-line matching, concrete LyricLine and LyricWord models.
- LyricsCache JSON persistence, percent-encoded storage keys, strict 14-day expiry and the original empty-content gates.
- Song playback identity, provider-specific lyric cache keys, current-song lookup and the stale lyric application guard.
- Mini-player lyric binary search, offset/clamping, artist fallback and focused SwiftUI text styling.
- Persisted listening duration/count reads and monotonic remote-total merge. This addition has 17 new focused tests and awaits its own Apple CI checkpoint.
- Byte-for-byte localization resources from the IPA; original type/field metadata retained separately.

See QISHUI_RECOVERY_EVIDENCE.md, LYRICS_RECOVERY_EVIDENCE.md and PLAYBACK_RECOVERY_EVIDENCE.md for function addresses, exact constants, preserved edge cases and explicitly marked reconstruction choices. Public API names and dependency-injection seams are not claimed to be original source spelling.

## Still incomplete

- Full PlayerView and home-page composition, navigation, interaction, settings and lyric scrolling/highlighting.
- PlayerManager audio lifecycle, playback queue transitions, cancellation, background controls and interruption handling.
- Remaining provider workflows, account authentication, payload decoding and private CiliCiliKit workers.
- A runnable reconstructed app target, device-level behavior comparison and visual equivalence verification.

The 678 main-app and 2,195 framework nominal catalogs are metadata inventories, not counts of implemented classes or methods. Passing reconstructed-source tests does not establish complete behavior equivalence with the original executable. No overall completion percentage is claimed.

## Validation history

| Source commit | Run ID | Tests passed | Failures |
| --- | --- | ---: | ---: |
| ef58392 | 39551584729 | 113 | 0 |
| 3810915 | 39552069654 | 126 | 0 |
| c3d1ca6 | 39552265457 | 134 | 0 |
| 21b3b40 | 39552610697 | 150 | 0 |
| 658c7f2 | 39553657725 | 166 | 0 |
| 6f98206 | 39554434399 | 182 | 0 |
| f45f066 | 39555100145 | 192 | 0 |
| bcb92f8 | 39556162533 | 204 | 0 |

## Input identity

- Original IPA SHA-256: 659099fc47f922299f2f35b7d4183c08b463917679e234305f8f666ea671f34e.
- Extracted Beans executable SHA-256: 535bb38e2d628352892ec02c5af116c9d5385dd23b08d6713129b2a13600b778.
- These identify different files. A fresh hash of the executable ZIP entry matches the extracted executable.

The original IPA and the older desktop build were not overwritten. The earlier desktop app build is not evidence for this isolated source checkpoint.
