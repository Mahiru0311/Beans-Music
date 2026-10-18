# Beans 2.0.3 build 2 direct recovery package

This isolated Swift Package mirrors the source files reconstructed directly from the supplied `Beans-2.0.3-b2-WebDAV-unsigned.ipa`; no 1.8.1 or other-version source files are used as its implementation base.

GitHub Actions run [39127451228](https://github.com/XIaodou0416/Beans-Music/actions/runs/39127451228) compiled all eight package targets against the iOS 16.1 SDK and ran three WebDAV parser tests on macOS. All checks passed. The workflow does not build or upload an IPA and does not create a Release.

The complete reverse-engineering catalogs, binary-address evidence, decoders, and resource hashes are retained with the local recovery package's `Evidence/` directory. This mirror contains only the package manifest, compilable sources, localized resources, and focused XCTest target needed for the build check.

The nominal catalogs remain metadata reconstructions; unresolved source-level generic arguments, SwiftUI opaque types, closure contexts, and framework payloads are marked `Any` or documented in the evidence package.

The focused `CiliCiliRuntime.listenSource(for:)` path now follows the recovered
ARM64 control flow: it seeds a new source with the first request, reuses a
source only when its BVID/AID identity matches, and starts a fresh source for a
different identity. `CiliCiliListenSourceTests` covers those three cases. The
identity rule is deliberately limited to the two request words compared by the
binary; title, cover, duration, and playback URL are not guessed as identity
fields.
