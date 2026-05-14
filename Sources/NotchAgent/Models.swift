import SwiftUI

struct NewsItem: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let summary: String
    let url: String
    let source: String
    let keywords: [String]
    let timestamp: Date

    var sourceIcon: String {
        switch source.lowercased() {
        case "arxiv": return "doc.text"
        case "github": return "chevron.left.forwardslash.chevron.right"
        case "hackernews": return "flame"
        default: return "globe"
        }
    }
}

@MainActor
@Observable
class NewsStore {
    var items: [NewsItem] = []
    var isLoading = false
    var lastUpdated: Date?
    var keywords: [String] = NewsStore.defaultKeywords

    static let defaultKeywords = [
        "Agent System",
        "Multi-Agent System",
        "Autonomous Scientific Discovery",
        "Agent Memory",
        "Agent Skill",
        "Claude Code",
        "Codex",
        "MCP Server",
        "Tool Use AI",
        "LLM Agent"
    ]

    static let shared = NewsStore()

    private let storePath: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".notchagent")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    init() {
        loadFromDisk()
        loadKeywords()
    }

    func loadFromDisk() {
        let file = storePath.appendingPathComponent("news.json")
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode([NewsItem].self, from: data) else { return }
        items = decoded
        lastUpdated = try? FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date
    }

    func saveToDisk() {
        let file = storePath.appendingPathComponent("news.json")
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: file)
    }

    func loadKeywords() {
        let file = storePath.appendingPathComponent("keywords.json")
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else { return }
        keywords = decoded
    }

    func saveKeywords() {
        let file = storePath.appendingPathComponent("keywords.json")
        guard let data = try? JSONEncoder().encode(keywords) else { return }
        try? data.write(to: file)
    }
}
