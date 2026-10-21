# Lyrics — direct Beans 2.0.3 build 2 recovery

Updated 2026-10-21. The implementation is reconstructed from the supplied 2.0.3 build 2 executable, not from a previous app version. Function names, API spelling, file organization and test seams are reconstruction choices; the original source text is not recoverable from these records.

## Input and evidence

- Original IPA SHA-256: `659099fc47f922299f2f35b7d4183c08b463917679e234305f8f666ea671f34e`.
- Main executable SHA-256: `535bb38e2d628352892ec02c5af116c9d5385dd23b08d6713129b2a13600b778`.
- Local delivery: `Evidence/Beans-2.0.3-b2-lyrics-arm64-manifest.json` and `Evidence/LyricsARM64/`. The Git validation mirror retains this document; the large raw evidence files remain in the local delivery.
- Function addresses below are virtual addresses. Constant locations are explicitly labeled file offsets. Each exported entry is checked against LC_FUNCTION_STARTS. Ghidra C is a hypothesis; ARM64, raw literals and callers determine the interpretation.

## Implemented paths

| Path | Binary evidence | Preserved behavior |
| --- | --- | --- |
| Plain LRC | `0x100331fac`, callback thunk `0x100339908` to shared body `0x1003339f8`, caller `0x100327ed0` | Multiple tags per line, fractional seconds with dot/colon, metadata rejection, tag removal and trimming, first offset tag, nonnegative line time, ascending timestamps. |
| Translation | `0x1003335d0` | Nearest timestamp, strictly less than 0.35 seconds, first candidate wins ties, empty nearest text blocks replacement, translations can be reused. |
| Karaoke | `0x100332514` | Millisecond line headers and word tags, absolute and relative word times, automatic postfix detection, original text spans, minimum 1 ms word duration, blank-line behavior. |
| Combined matching | `0x100327ed0`, whitespace predicate `0x10033b594` | Keep original LRC text/time, strip only whitespace for text matching, nearest equal-text candidate within the strict tolerance, consume each candidate once, use karaoke alone if LRC is absent, then apply translation. |
| Line/word models | LyricLine descriptor file offset `0x7c7fb4`, LyricWord `0x7c819c`, UUID construction `0x1003323cc` | UUID identity, optional word array, Double timestamps/durations, optional translation. |
| Persistent cache read | `0x10031b010` | Percent-encoded key, UserDefaults Data, JSON decode, strict 14-day age, content-presence gate, no removal of stale/corrupt entries. |
| Persistent cache write | `0x10031b3ac` | Nonempty lyric or nonempty timed text plus format, default JSONEncoder, save current Date, rejected/failed writes leave existing entries intact. |
| Cache JSON model | Entry descriptor file offset `0x7c7d9c`, CodingKeys `0x7c7dc4`, decode `0x10031a7f8`, encode `0x10031ada0` | Required lyric and savedAt; optional translation, wordTiming and wordFormat; default deferred Date representation. |
| Format raw values | File offsets `0x77a4d8` / `0x77a4f8`; `0x100328908` / `0x100329428` | Tags 0/1/2 map to neteaseYRC/qqQRC/kugouKRC; tag 3 is optional nil; unknown cached values become nil. |

## Exact constants and edge cases

Raw regex bytes, decoded double constants and raw enum string words are recorded in `Evidence/LyricsARM64/constants.json`. Plain timestamp patterns come from file offsets `0x79a050`, `0x7aa290`, `0x7aa2c0`; word patterns from `0x7aa250`, `0x7aa270`. The karaoke header is a Swift small string assembled in instructions.

- The tolerance is 0.35 at file offset `0x768690`; equality is rejected.
- The cache age literal is 1,209,600 seconds at `0x77a518`, also present in the static cache object at `0xb3d258`. The optimized load path reads the literal, not the exposed maxAge field.
- The original cache prefix is `beans.lyrics.cache.v1.`. It is appended to a key encoded with CharacterSet.alphanumerics. Empty keys are not rejected.
- Cache reads accept future dates. Reads do not delete expired/corrupt data. Nonempty whitespace counts as content.
- Empty plain lyric can load when raw wordFormat is non-nil and wordTiming is nonempty, even if the raw format is unknown and subsequently decodes to nil. This is distinct from the save gate, which accepts only the typed optional format.
- Negative karaoke word starts are retained; only line time is clamped to zero. Word text uses UTF-16 regex spans, preserving emoji and whitespace. No timing tags means the line is skipped. Empty joined text with positive header duration becomes one space with nil words.
- The three descriptive KaraokeSyntax case names remain reconstruction names; cache raw values provide the verified provider identity.

## Playback identity and stale-result gate

- Provider names are recovered from 0x100326ba4 and the eight-entry jump table at file offset 0x77abb0.
- Playback identity at 0x100326c48 uses numeric ID for NetEase, QQ, Kugou, Kuwo and Migu; Qishui/Bilibili use their optional provider ID with numeric fallback. Empty optional strings remain present. WebDAV uses accountKey or UUID, followed by the original relativePath; a missing track uses webdav-missing-ID.
- The lyric loader at 0x1003b59b0 constructs a different colon-separated cache key: QQ MID, Kugou hash, Qishui ID and Bilibili ID take precedence; absent values fall back to the full playback key. WebDAV exits this path before cache lookup.
- 0x100375e68 returns the current queue element only for a valid nonnegative index. 0x10040cca4 applies parsed lines only when the current playback key equals the request key and the result array is nonempty. Rejected results leave displayed lyrics unchanged. No generation-token check is added to this observed gate.
- PlayerView descriptor 0x7c89bc is confirmed through metadata accessor 0x100421924. The recovered application policy is extracted into a testable helper; diagnostics and native SwiftUI state wiring are still separate work.

## Validation and remaining scope

See `RECOVERY_STATUS.md` for the exact tested commit and completed GitHub run. Focused tests cover ordinary and boundary behavior, malformed data, cache persistence, raw format mapping, timing, translations and UTF-16 spans. The tests are offline and exercise reconstructed Swift; they do not execute the original executable as an oracle. Compilation and passing tests therefore do not establish complete installed-app equivalence.

Lyrics retrieval for all providers, decompression/decryption of provider payloads, player request cancellation/state changes, full scrolling/highlighting UI, audio playback and end-to-end device comparison remain separate work. Global cache-manager functions at `0x1000533c0`, `0x1000544e4` and `0x100054bbc` were inspected but are not counted as recovered LyricsCache implementations.
