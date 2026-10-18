# Beans 2.0.3 build 2 direct recovery scaffold

This Swift Package is a compile-oriented reconstruction from the supplied `Beans-2.0.3-b2-WebDAV-unsigned.ipa` only. It is not copied from 1.8.1 or any other release.

Targets:

- `Beans203RecoveredCore`: WebDAV requests/parser/backup structures and direct field-based API/store/main-state scaffolds.
- `CiliCiliKitRecovered`: focused runtime, HLS, playback, and video state field reconstruction from the embedded framework.
- `Beans203RecoveredUI`: SwiftUI WebDAV page reconstruction.
- `BeansLiveActivityRecovered`: Live Activity model reconstruction.
- `Beans203ReflectionEvidence`: compileable, descriptor-prefixed field scaffold for the main `Beans` binary.
- `CiliCiliKitReflectionEvidence`: compileable, descriptor-prefixed field scaffold for the embedded CiliCiliKit binary.
- `Beans203RecoveredNominalCatalog`: descriptor-keyed nominal declarations for all 678 main-binary Swift nominal records, retaining readable nominal names and field encodings.
- `CiliCiliKitRecoveredNominalCatalog`: descriptor-keyed nominal declarations for all 2,195 embedded-framework Swift nominal records, retaining readable nominal names and field encodings.
- `Beans203RecoveredCore/EndpointCatalogReconstruction.swift`: the 16 URL literals whose values and Mach-O addresses were directly located in the 2.0.3 build 2 executable.
- `Beans203RecoveredCore/Resources/{en,zh-Hans}.lproj/Localizable.strings`: byte-for-byte localized string tables from the supplied IPA, processed as SwiftPM resources; resource key/value counts and hashes are in `Evidence/Beans-2.0.3-b2-localization-resource-evidence.json`.

The `Evidence` directory contains the direct field catalogs, module inventory, and address-level WebDAV evidence. Unknown Swift generic arguments, opaque result types, framework payloads, and some enum payloads remain explicit `Any` or evidence comments because an encrypted-free IPA still does not retain the original source-level context.

The reflection targets are evidence scaffolds keyed by descriptor offsets; their `Any` fields preserve unresolved metadata without claiming source-level types.

The CiliCiliKit target also includes direct public runtime signatures recovered from a separate Ghidra analysis of the embedded framework (`CiliCiliRuntime.listenSource`, cache APIs, playback controls, and legacy-session synchronization). Private worker bodies remain explicitly marked where the stripped binary does not retain source-level context.

The two nominal-catalog targets are metadata catalogs rather than claims that the original source bodies survived. They preserve every nominal descriptor and field record from the supplied IPA under descriptor-unique names, so unresolved payloads remain inspectable without colliding with the focused reconstruction types.

The catalog generator preserves Swift array and dictionary types separately (`SaySSG` is `[String]`) and emits enum associated values where field encodings resolve them, including labeled download-state cases. `Evidence/validate-nominal-catalogs.js` checks descriptor counts, duplicate enum cases, and collection default literal shape; this structural check is not a substitute for Apple SDK type-checking.

The Evidence directory also contains a reproducible decoder for the embedded framework's relative `__swift5_typeref` records. It resolves 8,567 of 10,303 field references from this IPA and leaves unresolved symbolic targets explicit.




The current Windows analysis host has no Swift compiler, so an Xcode/macOS build was not run here; the package structure, duplicate-definition scan, brace balance, and a fifteen-file Swift grammar syntax pass were checked locally. The syntax-pass details are in `Evidence/Beans-2.0.3-b2-source-syntax-audit.json`. The successful GitHub run listed in `Evidence/Beans-2.0.3-b2-github-build-scope.json` built a separate existing Xcode project and does not verify these SwiftPM targets.

The package keeps one canonical CiliCiliKit source file; an earlier duplicate filename is an empty compatibility placeholder to avoid duplicate type definitions.
