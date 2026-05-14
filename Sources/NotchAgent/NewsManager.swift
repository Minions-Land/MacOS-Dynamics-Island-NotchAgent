import Foundation
import UserNotifications

@MainActor
class NewsManager: Sendable {
    private var timer: Timer?
    private let store = NewsStore.shared
    private let refreshInterval: TimeInterval = 3600

    func fetchInitial() async {
        store.loadFromDisk()
        if store.items.isEmpty || isStale() {
            await refresh()
        }
        startTimer()
    }

    func refresh() async {
        guard !store.isLoading else { return }
        store.isLoading = true

        let keywords = store.keywords
        let items = await Task.detached {
            await Self.invokeClaudeCode(keywords: keywords)
        }.value

        if !items.isEmpty {
            let isNew = store.items.first?.id != items.first?.id
            store.items = items
            store.saveToDisk()
            store.lastUpdated = Date()

            if isNew, let first = items.first {
                sendNotification(title: "NotchAgent", body: first.title)
            }
        }
        store.isLoading = false
    }

    private func isStale() -> Bool {
        guard let last = store.lastUpdated else { return true }
        return Date().timeIntervalSince(last) > refreshInterval
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    private func sendNotification(title: String, body: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static func invokeClaudeCode(keywords: [String]) async -> [NewsItem] {
        let keywordStr = keywords.joined(separator: ", ")
        let prompt = """
        You are a news aggregator. Use the mcp__codex-bridge__codex tool to delegate this task to Codex GPT-5.5:

        Task for Codex: "Search the web for the latest AI news (last 24 hours) about these topics: \(keywordStr). \
        Check arXiv (cs.AI, cs.MA, cs.CL), GitHub trending repos, Hacker News (hn.algolia.com/api/v1/search?query=AI+agent&tags=story), \
        and tech blogs. Return ONLY a JSON array with up to 10 items: \
        [{\"id\":\"unique\",\"title\":\"...\",\"summary\":\"2-3句中文摘要\",\"url\":\"https://...\",\"source\":\"arxiv|github|hackernews|blog\",\"keywords\":[\"matching\"],\"timestamp\":\"ISO8601\"}]. \
        Summary must be in Chinese. URLs must be real."

        Use cwd: "/tmp" and sandbox: "read-only" for the codex call.

        If the codex tool is unavailable, fall back to using WebSearch and WebFetch tools yourself to find the content.

        After getting results, output ONLY the JSON array. No markdown fences, no explanation.
        """

        guard let claudePath = findClaudeCodePath() else { return [] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = [
            "--print",
            "--permission-mode", "bypassPermissions",
            "--model", "sonnet",
            prompt
        ]

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        process.environment = ProcessInfo.processInfo.environment.merging([
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:\(home)/.claude/bin",
            "HOME": home
        ]) { _, new in new }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            return parseNewsItems(from: output)
        } catch {
            print("Claude Code invocation failed: \(error)")
            return []
        }
    }

    private static func findClaudeCodePath() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(home)/.claude/bin/claude"
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    private static func parseNewsItems(from output: String) -> [NewsItem] {
        guard let startIdx = output.firstIndex(of: "["),
              let endIdx = output.lastIndex(of: "]") else { return [] }

        let jsonString = String(output[startIdx...endIdx])
        guard let data = jsonString.data(using: .utf8) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode([NewsItem].self, from: data)
        } catch {
            print("JSON parse error: \(error)")
            return []
        }
    }
}
