import SwiftUI

struct NewsItem: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let summary: String
    let detail: String
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        summary = try c.decode(String.self, forKey: .summary)
        detail = try c.decodeIfPresent(String.self, forKey: .detail) ?? ""
        url = try c.decode(String.self, forKey: .url)
        source = try c.decode(String.self, forKey: .source)
        keywords = try c.decode([String].self, forKey: .keywords)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
    }
}

struct NewsFetch: Codable, Sendable {
    let summary: String
    let items: [NewsItem]
    let fetchedAt: Date
}

@MainActor
@Observable
class NewsStore {
    var items: [NewsItem] = []
    var summary: String?
    var isLoading = false
    var lastUpdated: Date?
    var keywords: [String] = NewsStore.defaultKeywords
    var newlyAddedKeywords: Set<String> = []
    var pendingDeletionKeywords: Set<String> = []

    var capturedKeywords: Set<String> {
        Set(items.flatMap { $0.keywords }.map { $0.lowercased() })
    }

    func isCaptured(_ kw: String) -> Bool {
        let lower = kw.lowercased()
        if capturedKeywords.contains(lower) { return true }
        return items.contains { item in
            let hay = (item.title + " " + item.summary + " " + item.detail).lowercased()
            return hay.contains(lower)
        }
    }

    func addKeyword(_ raw: String) {
        let kw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty,
              !keywords.contains(where: { $0.caseInsensitiveCompare(kw) == .orderedSame }) else { return }
        keywords.append(kw)
        newlyAddedKeywords.insert(kw)
        pendingDeletionKeywords.remove(kw)
        saveKeywords()
    }

    func removeKeyword(_ kw: String) {
        if newlyAddedKeywords.contains(kw) {
            keywords.removeAll { $0 == kw }
            newlyAddedKeywords.remove(kw)
        } else {
            pendingDeletionKeywords.insert(kw)
        }
        saveKeywords()
    }

    func undoRemoveKeyword(_ kw: String) {
        pendingDeletionKeywords.remove(kw)
        saveKeywords()
    }

    func commitKeywordChanges() {
        keywords.removeAll { pendingDeletionKeywords.contains($0) }
        pendingDeletionKeywords.removeAll()
        newlyAddedKeywords.removeAll()
        saveKeywords()
    }

    private static let maxItems = 10

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
        let file = storePath.appendingPathComponent("latest.json")
        guard let data = try? Data(contentsOf: file) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let fetch = try? decoder.decode(NewsFetch.self, from: data) else { return }
        items = Array(fetch.items.prefix(Self.maxItems))
        summary = fetch.summary
        lastUpdated = fetch.fetchedAt
    }

    func saveToDisk(fetch: NewsFetch) {
        let file = storePath.appendingPathComponent("latest.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(fetch) else { return }
        try? data.write(to: file, options: .atomic)
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
        try? data.write(to: file, options: .atomic)
    }
}
