import Foundation

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
        defer { store.isLoading = false }

        let items = await invokeClaudeCode()
        if !items.isEmpty {
            store.items = items
            store.saveToDisk()
            store.lastUpdated = Date()
        }
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

    private func invokeClaudeCode() async -> [NewsItem] {
        let keywords = store.keywords.joined(separator: ", ")
        let prompt = """
        You are a news aggregator agent. Find the latest content (last 24h) about: \(keywords).

        Use these sources:
        1. arXiv RSS: https://export.arxiv.org/rss/cs.AI, cs.MA, cs.CL
        2. GitHub: search repos with topics agent-system, multi-agent, agent-framework, autonomous-agents
        3. Hacker News: https://hn.algolia.com/api/v1/search?query=agent+AI&tags=story
        4. Papers with Code, tech blogs

        Return ONLY a JSON array (no markdown, no explanation) with up to 10 objects:
        [{"id":"unique-id","title":"...","summary":"2-3句中文摘要","url":"https://...","source":"arxiv|github|hackernews|blog","keywords":["matching","keywords"],"timestamp":"2024-01-01T00:00:00Z"}]

        Rules:
        - summary MUST be in Chinese (中文)
        - url must be a real, valid link
        - Prioritize newest and most relevant content
        - Include arXiv paper links, GitHub repo links, or blog URLs
        """

        let claudePath = findClaudeCodePath()
        guard let path = claudePath else { return [] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--print", "--model", "sonnet", prompt]

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

    private func findClaudeCodePath() -> String? {
        let candidates = [
            "/usr/local/bin/claude",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.claude/bin/claude",
            "/opt/homebrew/bin/claude"
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["claude"]
        let whichPipe = Pipe()
        whichProcess.standardOutput = whichPipe
        try? whichProcess.run()
        whichProcess.waitUntilExit()

        let whichData = whichPipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: whichData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return path
        }

        return nil
    }

    private func parseNewsItems(from output: String) -> [NewsItem] {
        let jsonPattern = output
            .components(separatedBy: "\n")
            .drop(while: { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("[") })
            .joined(separator: "\n")

        guard let startIdx = jsonPattern.firstIndex(of: "["),
              let endIdx = jsonPattern.lastIndex(of: "]") else { return [] }

        let jsonString = String(jsonPattern[startIdx...endIdx])
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
