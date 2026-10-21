# Beans 2.0.3 build 2 direct recovery package

This isolated Swift Package mirrors the source files reconstructed directly from the supplied `Beans-2.0.3-b2-WebDAV-unsigned.ipa`; no 1.8.1 or other-version source files are used as its implementation base.

Current source validation and remaining work are recorded in [RECOVERY_STATUS.md](RECOVERY_STATUS.md); Qishui binary anchors and behavioral boundaries are recorded in [QISHUI_RECOVERY_EVIDENCE.md](QISHUI_RECOVERY_EVIDENCE.md). Lyrics parser/cache anchors are in [LYRICS_RECOVERY_EVIDENCE.md](LYRICS_RECOVERY_EVIDENCE.md). The workflow compiles all eight library targets with the iPhoneOS SDK for the arm64-apple-ios16.1 deployment target and runs offline XCTest on macOS. It does not build or upload an IPA and does not create a Release. A successful package build is not proof of a fully reconstructed app.

Playback statistics and synchronization anchors are recorded in [PLAYBACK_RECOVERY_EVIDENCE.md](PLAYBACK_RECOVERY_EVIDENCE.md).

The complete reverse-engineering catalogs, binary-address evidence, decoders, and resource hashes are retained with the local recovery package's `Evidence/` directory. This mirror contains only the package manifest, compilable sources, localized resources, and focused XCTest target needed for the build check.

The nominal catalogs remain metadata reconstructions; unresolved source-level generic arguments, SwiftUI opaque types, closure contexts, and framework payloads are marked `Any` or documented in the evidence package.

The focused `CiliCiliRuntime.listenSource(for:)` path now follows the recovered
ARM64 control flow: it seeds a new source with the first request, reuses a
source when the request's BVID String matches, and starts a fresh source for a
different BVID. `CiliCiliListenSourceTests` covers those three cases, including
an AID change. The identity rule is deliberately limited to the first two
request words compared by the binary; AID, title, cover, duration, and playback
URL are not guessed as identity fields.
