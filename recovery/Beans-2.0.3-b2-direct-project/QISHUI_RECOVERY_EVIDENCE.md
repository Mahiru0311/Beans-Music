# Qishui API — direct Beans 2.0.3 build 2 recovery

Updated 2026-10-21. This replaces the earlier string-only assessment: exact ARM64 entry points, Swift async continuations, static arrays and callers have now been analyzed. The implementation base is the supplied 2.0.3 build 2 executable. No 1.8.1 source body was used for these Qishui changes.

## Input identity

- Original IPA: `Beans-2.0.3-b2-WebDAV-unsigned.ipa`, 18,517,546 bytes; SHA-256 `659099fc47f922299f2f35b7d4183c08b463917679e234305f8f666ea671f34e`.
- Main executable: `Payload/Beans.app/Beans`, 12,271,448 bytes; SHA-256 `535bb38e2d628352892ec02c5af116c9d5385dd23b08d6713129b2a13600b778`.
- The extracted executable hash was compared with a fresh hash of the same ZIP entry. These two hashes agree. The executable hash is not the IPA archive hash.
- Source-path literal `Beans/QishuiAPI.swift` is at file offset `0x7b3a60`. Nominal descriptors remain `QishuiCacheBox` at file offset `0x7c982c`, `QishuiAPI` at `0x7c987c`, `QishuiPlaylistDetails` at `0x7c98b8`, and `QishuiAPIError` at `0x7c98e0`.

## Implemented behavior and binary anchors

Addresses below are virtual addresses, not file offsets. Async rows name representative state-machine entries rather than claiming one C function equals one Swift method.

| Reconstructed behavior | Binary anchors | Preserved details |
| --- | --- | --- |
| Session/cache initialization | `0x10056a5d0` | Request/resource timeouts 20/30 seconds; reload-ignore-cache policy; cache count limits 40/40/8/24. |
| Request, HTTP/JSON envelope, errors | `0x100571838`, `0x100571e50`, `0x10056adf4`, `0x1005678c0` | URL configuration, query/body encoding, JSON headers, versioned user agent, 15/20-second per-path timeouts, HTTP gate before JSON, data envelope and server messages. |
| Catalog keys and cache age | `0x10056a6e4`, `0x10056a9a8`, `0x10056aafc`, `0x10056cdc0` | Normalized query key, base URL and limit in key, strict age comparisons, fresh/stale distinction. |
| Songs/playlists and stable identifier | `0x10056b350`, `0x10056d19c`, `0x100564e54`, `0x10056af88`, `0x10056cfac` | Wrapper/key precedence, artist/album fields, duration, payment flags, original string IDs; hash seed is `0x14650fb0739d0383`, not the standard FNV offset basis. |
| Artwork URL extraction | `0x100567b94`, `0x100568a48`, `0x100568e64`, `0x1005691d0` | Recursive shapes, depth gate, scheme-relative URLs, ordered cover keys and Douyin image template handling. |
| Playlist search/recommendations | `0x1005654d0`, `0x100565708`, `0x10056598c`, `0x10056726c`, `0x10056743c`, `0x1005676bc` | Count clamped to 1–50, respective endpoint and key, stale fallback, cancellation propagation. |
| Lyrics | `0x100564870`, `0x100564990` | `/lyric`, track_id, ordered lyric/lyrics/content/lrc values; missing identifier returns nil. |
| Playback URL | `0x100566e9c`, `0x100566ff4`, `0x1005671b8`, `0x10057065c` | `/song/detail` then `/audio/info` only after a successful response without a URL; transport errors propagate; parser differs from artwork parser. |
| Comments | `0x100564fd8`, `0x100565048`, `0x1005651dc`, `0x100570f78` | `/comment`, count clamped to 1–50, alternate keys, fallback identity/name, timestamp seconds/milliseconds, mapped total and empty hot array. |
| Song search | `0x100565a28` through its continuations, `0x1005699a0`, `0x100569c30`, `0x100569cfc`, `0x100569ff0` | 1–200 results, 10 rounds, 100 per request, mixed-search empty mapping fallback, ID dedup, advancing offsets, main-actor growth callbacks, partial/stale error behavior. |
| Playlist details and songs projection | `0x10056e530` and continuations, `0x100567750`, `0x10056784c` | 1–1000 results, 20 rounds, fixed page count, session and cursor propagation, repeat-cursor termination, force-refresh fallback and cached-progress behavior. |
| Artist songs | `0x100564a10`, `0x100564ad0`, `0x1005704f0`, `0x10056db1c` | Search at least 100 requested candidates, split credited artists, normalize accents/case/whitespace/punctuation, mutual substring matching, unfiltered fallback and original prefix limit. |
| Artist albums | `0x100564d38`, `0x100564d58`, `0x100564e1c`, `0x10056de7c`, `0x1005725bc`, `0x1005653d8`, `0x10057467c` | Search max(limit × 4, 160), group normalized album and full artist text, preserve first song metadata, synthesize album identity, natural localized name ordering then prefix. |

## Important branch distinctions

- Song search uses literal fresh/stale ages of 300/172800 seconds. Playlist details uses 1800/604800 seconds. Mutating the corresponding exposed reconstruction TTL field does not change these literal call sites.
- Search metadata checks root, upstream, upstream.data, then the chosen pagination dictionary. First-present keys, including null/invalid values, block later keys. Unknown boolean text is not equivalent to true.
- Search errors return uncached partial results before stale cache; detail errors return cached details or throw, even after uncached partial pages. Cancellation is not hidden by fallback.
- Detail progress is emitted for cached data and duplicate-only pages. Search progress is emitted only when the result grows and is not emitted on a fresh cache hit.
- Detail session ID is retained from the first nonempty session_id/sessionId. Cursor repetition terminates traversal; has_more is not the detail loop gate.
- Artist normalization uses current-locale case/diacritic folding, lowercasing, then Character isWhitespace/isPunctuation filtering. Separators are `/／,，、&＆+＋|｜;；` (27 UTF-8 bytes at file offset `0x79a400`).
- Album grouping uses the normalized entire artist string, not a set of artist names. Album display strings and the `qishui-album-` stable hash use the first song's original strings; later cover URLs do not replace a missing first cover. Equal-name album order is unspecified because group dictionary enumeration has no extra tie breaker.

## Reconstruction boundaries

These are readable Swift behavior reconstructions, not recovered original source text. Public spelling, visibility, file organization, dependency injection, test fixtures, generic cache wrappers and extracted helper APIs are reconstruction choices. Ghidra-generated C often misidentifies Swift registers, return values or async parameters; disassembly and callers are the evidence for branch interpretation.

Defensive deviations are explicitly marked in source: non-finite/out-of-range numeric conversions return an error or omit a mapped object instead of reproducing the binary trap; search cursor overflow throws invalidResponse. Artist prefix limits retain Swift's nonnegative precondition, and album overfetch multiplication retains checked Int arithmetic. No claim is made about previously unobserved malformed recursive object graphs or deterministic dictionary traversal.

Tests use offline URLProtocol responses; no live backend availability, real-account behavior, player audio output, full UI navigation or installed-app equivalence has been validated. The complete app is still unfinished. PlayerManager, main-page composition, several provider workflows and many framework workers still have metadata-only models or unresolved bodies.

## Reproducible records

The following paths are relative to the local delivery Evidence directory. The Git validation mirror retains this note, while large disassembly exports and binary catalogs remain in the local delivery.

- `Beans-2.0.3-b2-qishui-arm64-manifest.json`: input hashes and per-file raw evidence hashes.
- `QishuiARM64/*.txt`: exact-entry Ghidra decompilation and ARM64 disassembly. Included function count measures evidence exports, not completed recovered methods.
- `QishuiARM64/LC_FUNCTION_STARTS.json`: original function-start inventory. Non-entry/stale failed exports are excluded and listed in the manifest.
- `QishuiARM64/RecoverExactFunctions.java`: exporter for an already imported Ghidra program; args are output directory followed by verified function-start addresses.
- `QishuiARM64/decode-qishui-static-arrays.cjs`, `QishuiARM64/qishui-search-constants.cjs`: static key arrays, separator bytes and TTL constants; run from the recovery workspace using their recorded input paths.
- `20261021-direct-mirror-sync.json`: complete Package.swift/Sources/Tests hash inventory and source commit.
- `Beans-2.0.3-b2-qishui-validation.json`: build run, exact tested source commit, test count and boundary statement.
- `RECOVERY_STATUS.md` in the package root: current validation and unfinished work.
