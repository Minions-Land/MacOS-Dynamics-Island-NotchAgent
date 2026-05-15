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
        // Step 1: Fetch news with haiku (cheap, fast)
        let items = await Task.detached {
            await Self.fetchNews(keywords: keywords)
        }.value

        if !items.isEmpty {
            // Step 2: Summarize with sonnet (better quality)
            let summaryText = await Task.detached {
                await Self.summarizeNews(items: items)
            }.value

            let fetch = NewsFetch(summary: summaryText, items: items, fetchedAt: Date())
            store.items = items
            store.summary = summaryText
            store.lastUpdated = Date()
            store.saveToDisk(fetch: fetch)

            // Step 3: Push historical data to GitHub
            await Task.detached {
                await Self.pushToGitHub(fetch: fetch)
            }.value

            if let first = items.first {
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

    // MARK: - Step 1: Fetch with Haiku (cheap)

    private static func fetchNews(keywords: [String]) async -> [NewsItem] {
        let keywordStr = keywords.joined(separator: ", ")
        let prompt = """
        You are a news aggregator. Use WebSearch to find the latest AI news (last 24h) about: \(keywordStr).

        Search arXiv (cs.AI, cs.MA, cs.CL), GitHub trending, Hacker News (hn.algolia.com/api/v1/search?query=AI+agent&tags=story), and tech blogs.

        Return ONLY a JSON array (no markdown, no explanation) with up to 10 items:
        [{"id":"unique-id","title":"...","summary":"2-3句中文摘要","url":"https://...","source":"arxiv|github|hackernews|blog","keywords":["matching"],"timestamp":"ISO8601"}]

        Rules: summary in Chinese, urls must be real, prioritize newest content.
        """

        return await invokeClaudeCode(prompt: prompt, model: "haiku")
    }

    // MARK: - Step 2: Summarize with Sonnet (quality)

    private static func summarizeNews(items: [NewsItem]) async -> String {
        let titles = items.map { "- [\($0.source)] \($0.title)" }.joined(separator: "\n")
        let prompt = """
        Based on these AI/Agent news items from the last hour, write a concise overview summary in Chinese (3-5 sentences). Highlight the key trends and most important developments:

        \(titles)

        Return ONLY the summary text in Chinese. No JSON, no markdown, no explanation.
        """

        guard let claudePath = findClaudeCodePath() else { return "" }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = ["--print", "--model", "sonnet", prompt]

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
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }

    // MARK: - Step 3: Push to GitHub

    private static func pushToGitHub(fetch: NewsFetch) async {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let repoPath = "\(home)/Projects/NotchAgent"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: fetch.fetchedAt)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH-mm"
        let timeStr = timeFormatter.string(from: fetch.fetchedAt)

        // Save to data/YYYY-MM-DD/HH-mm.json
        let dataDir = "\(repoPath)/data/\(dateStr)"
        try? FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let jsonData = try? encoder.encode(fetch) else { return }

        let filePath = "\(dataDir)/\(timeStr).json"
        try? jsonData.write(to: URL(fileURLWithPath: filePath))

        // Git add, commit, push
        let commands = """
        cd "\(repoPath)" && \
        git add "data/\(dateStr)/\(timeStr).json" && \
        git commit -m "data: fetch \(dateStr) \(timeStr)

        \(fetch.items.count) items, sources: \(Set(fetch.items.map(\.source)).sorted().joined(separator: ", "))" && \
        git push origin main 2>/dev/null || git push origin main
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", commands]
        process.environment = ProcessInfo.processInfo.environment.merging([
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:\(home)/.ssh",
            "HOME": home,
            "GIT_SSH_COMMAND": "ssh -o StrictHostKeyChecking=no"
        ]) { _, new in new }
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Claude Code Invocation

    private static func invokeClaudeCode(prompt: String, model: String) async -> [NewsItem] {
        guard let claudePath = findClaudeCodePath() else { return [] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = [
            "--print",
            "--permission-mode", "bypassPermissions",
            "--model", model,
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
