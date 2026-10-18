// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Beans203Recovered",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "Beans203RecoveredCore", targets: ["Beans203RecoveredCore"]),
        .library(name: "CiliCiliKitRecovered", targets: ["CiliCiliKitRecovered"]),
        .library(name: "Beans203RecoveredUI", targets: ["Beans203RecoveredUI"]),
        .library(name: "BeansLiveActivityRecovered", targets: ["BeansLiveActivityRecovered"]),
        .library(name: "Beans203ReflectionEvidence", targets: ["Beans203ReflectionEvidence"]),
        .library(name: "CiliCiliKitReflectionEvidence", targets: ["CiliCiliKitReflectionEvidence"]),
        .library(name: "Beans203RecoveredNominalCatalog", targets: ["Beans203RecoveredNominalCatalog"]),
        .library(name: "CiliCiliKitRecoveredNominalCatalog", targets: ["CiliCiliKitRecoveredNominalCatalog"])
    ],
    targets: [
        .target(name: "Beans203RecoveredCore", resources: [.process("Resources")]),
        .target(name: "CiliCiliKitRecovered"),
        .target(name: "Beans203RecoveredUI", dependencies: ["Beans203RecoveredCore"]),
        .target(name: "BeansLiveActivityRecovered"),
        .target(name: "Beans203ReflectionEvidence"),
        .target(name: "CiliCiliKitReflectionEvidence"),
        .target(name: "Beans203RecoveredNominalCatalog"),
        .target(name: "CiliCiliKitRecoveredNominalCatalog")
    ]
)
