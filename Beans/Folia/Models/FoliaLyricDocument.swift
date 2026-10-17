import Foundation

// Native timing contract: preserve real word timing and fullText independently.
struct FoliaWord: Identifiable, Codable, Hashable {
    let id: String
    let text: String
    let startTime: Double
    let endTime: Double
}

struct FoliaLine: Identifiable, Codable, Hashable {
    let id: String
    let startTime: Double
    let endTime: Double
    let fullText: String
    let translation: String?
    let romanization: String?
    let words: [FoliaWord]
}

struct FoliaLyricDocument: Codable, Hashable {
    let trackIdentity: String
    let lines: [FoliaLine]
}
