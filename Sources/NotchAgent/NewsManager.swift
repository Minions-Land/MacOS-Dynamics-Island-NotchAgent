import Foundation
import UserNotifications

@MainActor
class NewsManager: Sendable {
    private var timer: Timer?
    private let store = NewsStore.shared
    private let refreshInterval: TimeInterval = 3600
    private static let processTimeout: TimeInterval = 300

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

        // Step 1: Fetch news
        let items = await Task.detached {
            await Self.fetchNews(keywords: keywords)
        }.value

        if !items.isEmpty {
            // Step 2: Generate tech-focused summary with sonnet
            let summaryText = await Task.detached {
                await Self.summarizeNews(items: items)
            }.value

            let fetch = NewsFetch(summary: summaryText, items: items, fetchedAt: Date())
            store.items = items
            store.summary = summaryText
            store.lastUpdated = Date()
            store.commitKeywordChanges()
            store.saveToDisk(fetch: fetch)

            // Step 3: Save hourly report and push to GitHub
            await Task.detached {
                await Self.saveAndPushHourly(fetch: fetch)
            }.value

            // Step 4: Check if we need to generate daily/weekly/monthly reports
            await Task.detached {
                await Self.checkAndGenerateRollups()
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

    // MARK: - Fetch (Sonnet — quality + detail)

    private static func fetchNews(keywords: [String]) async -> [NewsItem] {
        let keywordStr = keywords.joined(separator: ", ")
        let prompt = """
        You are a technical research aggregator. Use WebSearch to find the latest technical developments (last 24h) about: \(keywordStr).

        Focus on: new techniques, frameworks, papers, tools. NOT social news.
        Search arXiv (cs.AI, cs.MA, cs.CL), GitHub trending, HN (hn.algolia.com/api/v1/search?query=AI+agent&tags=story).

        Return ONLY a JSON array (no markdown) with up to 8 items:
        [{"id":"unique","title":"...","summary":"1-2句中文概述","detail":"中文技术细节(5-8句)：包含具体方法、关键结果数据、核心公式或算法思路、与现有方案的对比。要有实质内容，不要空话。","url":"https://...","source":"arxiv|github|hackernews|blog","keywords":["matching"],"timestamp":"ISO8601"}]

        For the "detail" field:
        - Papers: include method name, key formula/algorithm idea, benchmark results (numbers)
        - GitHub repos: include architecture approach, key features, performance claims
        - Blog posts: include the core technical insight and concrete examples
        - STRUCTURE: split into 2-3 short paragraphs separated by \n\n. Each paragraph should focus on one aspect (e.g. background, method, results).
        - FORMULAS: wrap math in LaTeX delimiters. Use $...$ for inline math, $$...$$ for IMPORTANT standalone formulas that deserve their own centered line.
          Example: "核心损失函数定义为：\n\n$$L(\\theta) = \\mathbb{E}[R(y^+) - R(y^-)] \\cdot \\nabla \\log \\pi_\\theta(a)$$\n\n其中 $R$ 是奖励函数..."
        Keep detail substantive but readable — aim for 3-5 sentences per paragraph max.

        Rules: summary and detail in Chinese, urls must be real, focus on TECHNICAL content.
        """
        return await invokeClaudeCode(prompt: prompt, model: "sonnet")
    }

    // MARK: - Summarize (Sonnet) — tech-focused

    private static func summarizeNews(items: [NewsItem]) async -> String {
        let details = items.map { "- [\($0.source)] \($0.title): \($0.summary)" }.joined(separator: "\n")
        let prompt = """
        你是一位AI技术分析师。基于以下本小时抓取的AI/Agent技术动态，撰写一段技术聚焦的中文总结（4-6句）。

        要求：
        1. 聚焦于出现了哪些新技术、新方法、新框架
        2. 这些技术产生了什么新效果或突破
        3. 对技术发展趋势的简要判断
        4. 不要写社会新闻或商业动态，只关注技术本身

        本小时技术动态：
        \(details)

        直接输出中文总结，不要任何前缀或格式标记。
        """
        return await invokeSonnet(prompt: prompt)
    }

    // MARK: - Data Management & GitHub Push

    private static let repoPath: String = {
        FileManager.default.homeDirectoryForCurrentUser.path + "/Projects/NotchAgent"
    }()

    private static func saveAndPushHourly(fetch: NewsFetch) async {
        let cal = Calendar.current
        let date = fetch.fetchedAt
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)

        let dateStr = String(format: "%04d-%02d-%02d", year, month, day)
        let timeStr = String(format: "%02d-%02d", cal.component(.hour, from: date), cal.component(.minute, from: date))

        let dirPath = "\(repoPath)/data/\(year)/\(String(format: "%02d", month))/\(String(format: "%02d", day))"
        let fileName = "\(dateStr)_\(timeStr)_hourly.json"
        let filePath = "\(dirPath)/\(fileName)"

        try? FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let jsonData = try? encoder.encode(fetch) else { return }
        try? jsonData.write(to: URL(fileURLWithPath: filePath))

        gitCommitAndPush(
            files: ["data/\(year)/\(String(format: "%02d", month))/\(String(format: "%02d", day))/\(fileName)"],
            message: "data(hourly): \(dateStr) \(timeStr) — \(fetch.items.count) items"
        )
    }

    // MARK: - Tiered Report Generation

    private static func checkAndGenerateRollups() async {
        let cal = Calendar.current
        let now = Date()
        let yearNow = cal.component(.year, from: now)
        let monthNow = cal.component(.month, from: now)
        let dayNow = cal.component(.day, from: now)
        let hourNow = cal.component(.hour, from: now)
        let weekOfYearNow = cal.component(.weekOfYear, from: now)
        let yearForWeekNow = cal.component(.yearForWeekOfYear, from: now)
        let curQuarter = (monthNow - 1) / 3 + 1

        let dataRoot = "\(repoPath)/data"
        var budget = 5

        let years = (try? FileManager.default.contentsOfDirectory(atPath: dataRoot))?
            .filter { Int($0) != nil }.sorted() ?? []

        // 1. DAILY backfill — every past day with hourly files but no daily report
        for yearStr in years {
            if budget <= 0 { return }
            let yearDir = "\(dataRoot)/\(yearStr)"
            let months = (try? FileManager.default.contentsOfDirectory(atPath: yearDir))?
                .filter { $0.count == 2 && Int($0) != nil }.sorted() ?? []
            for monthStr in months {
                if budget <= 0 { return }
                let monthDir = "\(yearDir)/\(monthStr)"
                let days = (try? FileManager.default.contentsOfDirectory(atPath: monthDir))?
                    .filter { $0.count == 2 && Int($0) != nil }.sorted() ?? []
                for dayStr in days {
                    if budget <= 0 { return }
                    let y = Int(yearStr)!, m = Int(monthStr)!, d = Int(dayStr)!
                    let isToday = (y == yearNow && m == monthNow && d == dayNow)
                    let isPast = (y < yearNow)
                        || (y == yearNow && m < monthNow)
                        || (y == yearNow && m == monthNow && d < dayNow)
                    guard isPast || (isToday && hourNow >= 23) else { continue }

                    let dayDir = "\(monthDir)/\(dayStr)"
                    let dateStr = "\(yearStr)-\(monthStr)-\(dayStr)"
                    let dailyPath = "\(dayDir)/\(dateStr)_daily.json"
                    if FileManager.default.fileExists(atPath: dailyPath) { continue }

                    let entries = (try? FileManager.default.contentsOfDirectory(atPath: dayDir)) ?? []
                    let hasHourly = entries.contains(where: { $0.contains("_hourly.json") })
                    guard hasHourly else { continue }

                    await generateDailyReport(year: yearStr, month: monthStr, day: dayStr, date: dateStr)
                    budget -= 1
                }
            }
        }

        // 2. WEEKLY backfill — any past completed (yearForWeekOfYear, weekOfYear)
        var weekKeys: Set<String> = []
        for yearStr in years {
            let yearDir = "\(dataRoot)/\(yearStr)"
            let months = (try? FileManager.default.contentsOfDirectory(atPath: yearDir))?
                .filter { $0.count == 2 && Int($0) != nil } ?? []
            for monthStr in months {
                let monthDir = "\(yearDir)/\(monthStr)"
                let days = (try? FileManager.default.contentsOfDirectory(atPath: monthDir))?
                    .filter { $0.count == 2 && Int($0) != nil } ?? []
                for dayStr in days {
                    guard let y = Int(yearStr), let m = Int(monthStr), let d = Int(dayStr),
                          let date = cal.date(from: DateComponents(year: y, month: m, day: d)) else { continue }
                    let wy = cal.component(.yearForWeekOfYear, from: date)
                    let woy = cal.component(.weekOfYear, from: date)
                    weekKeys.insert("\(wy)|\(String(format: "%02d", woy))|\(monthStr)")
                }
            }
        }
        for key in weekKeys.sorted() {
            if budget <= 0 { return }
            let parts = key.split(separator: "|").map(String.init)
            guard parts.count == 3, let wy = Int(parts[0]), let woy = Int(parts[1]) else { continue }
            let wkStr = "W\(parts[1])"
            let monthStr = parts[2]
            let isPast = (wy < yearForWeekNow) || (wy == yearForWeekNow && woy < weekOfYearNow)
            guard isPast else { continue }
            let weeklyPath = "\(dataRoot)/\(parts[0])/\(monthStr)/\(wkStr)/\(parts[0])-\(wkStr)_weekly.json"
            if FileManager.default.fileExists(atPath: weeklyPath) { continue }
            await generateWeeklyReport(year: parts[0], month: monthStr, week: wkStr)
            budget -= 1
        }

        // 3. MONTHLY backfill — every past completed month with any data
        for yearStr in years {
            if budget <= 0 { return }
            let yearDir = "\(dataRoot)/\(yearStr)"
            let months = (try? FileManager.default.contentsOfDirectory(atPath: yearDir))?
                .filter { $0.count == 2 && Int($0) != nil }.sorted() ?? []
            for monthStr in months {
                if budget <= 0 { return }
                guard let y = Int(yearStr), let m = Int(monthStr) else { continue }
                let isPast = (y < yearNow) || (y == yearNow && m < monthNow)
                guard isPast else { continue }
                let monthlyPath = "\(yearDir)/\(monthStr)/\(yearStr)-\(monthStr)_monthly.json"
                if FileManager.default.fileExists(atPath: monthlyPath) { continue }
                let monthDir = "\(yearDir)/\(monthStr)"
                let hasContent = ((try? FileManager.default.contentsOfDirectory(atPath: monthDir))?.isEmpty == false)
                guard hasContent else { continue }
                await generateMonthlyReport(year: yearStr, month: monthStr)
                budget -= 1
            }
        }

        // 4. QUARTERLY backfill — every past completed quarter with any monthly
        for yearStr in years {
            if budget <= 0 { return }
            guard let y = Int(yearStr) else { continue }
            for q in 1...4 {
                if budget <= 0 { return }
                let isPast = (y < yearNow) || (y == yearNow && q < curQuarter)
                guard isPast else { continue }
                let qStr = "Q\(q)"
                let qPath = "\(dataRoot)/\(yearStr)/\(qStr)/\(yearStr)-\(qStr)_quarterly.json"
                if FileManager.default.fileExists(atPath: qPath) { continue }
                var hasMonthly = false
                for m in ((q - 1) * 3 + 1)...(q * 3) {
                    let mStr = String(format: "%02d", m)
                    if FileManager.default.fileExists(atPath: "\(dataRoot)/\(yearStr)/\(mStr)/\(yearStr)-\(mStr)_monthly.json") {
                        hasMonthly = true; break
                    }
                }
                guard hasMonthly else { continue }
                await generateQuarterlyReport(year: yearStr, quarter: qStr)
                budget -= 1
            }
        }

        // 5. YEARLY backfill — every past year with any quarterly
        for yearStr in years {
            if budget <= 0 { return }
            guard let y = Int(yearStr), y < yearNow else { continue }
            let yPath = "\(dataRoot)/\(yearStr)/\(yearStr)_yearly.json"
            if FileManager.default.fileExists(atPath: yPath) { continue }
            var hasQ = false
            for q in 1...4 {
                if FileManager.default.fileExists(atPath: "\(dataRoot)/\(yearStr)/Q\(q)/\(yearStr)-Q\(q)_quarterly.json") {
                    hasQ = true; break
                }
            }
            guard hasQ else { continue }
            await generateYearlyReport(year: yearStr)
            budget -= 1
        }
    }

    private static func generateDailyReport(year: String, month: String, day: String, date: String) async {
        let dayDir = "\(repoPath)/data/\(year)/\(month)/\(day)"
        let hourlyFiles = (try? FileManager.default.contentsOfDirectory(atPath: dayDir))?
            .filter { $0.contains("_hourly.json") }.sorted() ?? []
        guard !hourlyFiles.isEmpty else { return }

        var allItems: [NewsItem] = []
        var hourlySummaries: [String] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for file in hourlyFiles {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: "\(dayDir)/\(file)")),
                  let fetch = try? decoder.decode(NewsFetch.self, from: data) else { continue }
            allItems.append(contentsOf: fetch.items)
            if !fetch.summary.isEmpty { hourlySummaries.append(fetch.summary) }
        }
        guard !allItems.isEmpty else { return }

        let summary = await invokeSonnet(prompt: buildRollupPrompt(
            level: "日报", period: date, items: allItems, subSummaries: hourlySummaries,
            instruction: "生成技术日报。聚焦今天出现的新技术、新方法及其效果。按技术领域分类，每领域2-3句。最后给出技术趋势判断。"))
        let report = NewsFetch(summary: summary, items: dedup(allItems), fetchedAt: Date())
        saveReport(report, to: "\(dayDir)/\(date)_daily.json")
        gitCommitAndPush(files: ["data/\(year)/\(month)/\(day)/\(date)_daily.json"],
                         message: "data(daily): \(date) — tech digest")
    }

    private static func generateWeeklyReport(year: String, month: String, week: String) async {
        let monthDir = "\(repoPath)/data/\(year)/\(month)"
        guard let days = try? FileManager.default.contentsOfDirectory(atPath: monthDir) else { return }
        var summaries: [String] = []
        var allItems: [NewsItem] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for day in days.sorted().suffix(7) {
            let dayPath = "\(monthDir)/\(day)"
            let files = (try? FileManager.default.contentsOfDirectory(atPath: dayPath)) ?? []
            for file in files where file.contains("_daily.json") || file.contains("_hourly.json") {
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: "\(dayPath)/\(file)")),
                      let fetch = try? decoder.decode(NewsFetch.self, from: data) else { continue }
                if file.contains("_daily") { summaries.append(fetch.summary) }
                allItems.append(contentsOf: fetch.items)
            }
        }
        guard !allItems.isEmpty else { return }

        let summary = await invokeSonnet(prompt: buildRollupPrompt(
            level: "周报", period: "\(year)-\(week)", items: allItems, subSummaries: summaries,
            instruction: "生成技术周报。总结本周最重要的技术突破和趋势。按重要性排序，突出创新点和潜在影响。"))
        let report = NewsFetch(summary: summary, items: Array(dedup(allItems).prefix(20)), fetchedAt: Date())
        let weekDir = "\(repoPath)/data/\(year)/\(month)/\(week)"
        try? FileManager.default.createDirectory(atPath: weekDir, withIntermediateDirectories: true)
        saveReport(report, to: "\(weekDir)/\(year)-\(week)_weekly.json")
        gitCommitAndPush(files: ["data/\(year)/\(month)/\(week)/\(year)-\(week)_weekly.json"],
                         message: "data(weekly): \(year)-\(week) — tech weekly")
    }

    private static func generateMonthlyReport(year: String, month: String) async {
        let monthDir = "\(repoPath)/data/\(year)/\(month)"
        var summaries: [String] = []
        var allItems: [NewsItem] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let contents = try? FileManager.default.contentsOfDirectory(atPath: monthDir) {
            for entry in contents.sorted() {
                let entryPath = "\(monthDir)/\(entry)"
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: entryPath, isDirectory: &isDir)
                guard isDir.boolValue else { continue }
                for file in (try? FileManager.default.contentsOfDirectory(atPath: entryPath)) ?? [] {
                    guard (file.contains("_weekly.json") || file.contains("_daily.json")),
                          let data = try? Data(contentsOf: URL(fileURLWithPath: "\(entryPath)/\(file)")),
                          let fetch = try? decoder.decode(NewsFetch.self, from: data) else { continue }
                    if file.contains("_weekly") { summaries.append(fetch.summary) }
                    allItems.append(contentsOf: fetch.items)
                }
            }
        }
        guard !allItems.isEmpty else { return }

        let summary = await invokeSonnet(prompt: buildRollupPrompt(
            level: "月报", period: "\(year)-\(month)", items: allItems, subSummaries: summaries,
            instruction: "生成技术月报。总结本月AI Agent领域最重要的技术进展。分析演进方向，评估哪些新技术可能产生长期影响。"))
        let report = NewsFetch(summary: summary, items: Array(dedup(allItems).prefix(30)), fetchedAt: Date())
        saveReport(report, to: "\(monthDir)/\(year)-\(month)_monthly.json")
        gitCommitAndPush(files: ["data/\(year)/\(month)/\(year)-\(month)_monthly.json"],
                         message: "data(monthly): \(year)-\(month) — tech monthly")
    }

    private static func generateQuarterlyReport(year: String, quarter: String) async {
        let quarterNum = Int(quarter.dropFirst())!
        var summaries: [String] = []
        var allItems: [NewsItem] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for m in ((quarterNum - 1) * 3 + 1)...(quarterNum * 3) {
            let mStr = String(format: "%02d", m)
            let path = "\(repoPath)/data/\(year)/\(mStr)/\(year)-\(mStr)_monthly.json"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let fetch = try? decoder.decode(NewsFetch.self, from: data) else { continue }
            summaries.append(fetch.summary)
            allItems.append(contentsOf: fetch.items)
        }
        guard !summaries.isEmpty else { return }

        let summary = await invokeSonnet(prompt: buildRollupPrompt(
            level: "季度报", period: "\(year)-\(quarter)", items: allItems, subSummaries: summaries,
            instruction: "生成季度技术报告。深度分析本季度AI Agent技术重大突破和演进趋势。评估技术成熟度变化，预判下季度方向。"))
        let report = NewsFetch(summary: summary, items: Array(dedup(allItems).prefix(50)), fetchedAt: Date())
        let qDir = "\(repoPath)/data/\(year)/\(quarter)"
        try? FileManager.default.createDirectory(atPath: qDir, withIntermediateDirectories: true)
        saveReport(report, to: "\(qDir)/\(year)-\(quarter)_quarterly.json")
        gitCommitAndPush(files: ["data/\(year)/\(quarter)/\(year)-\(quarter)_quarterly.json"],
                         message: "data(quarterly): \(year)-\(quarter) — tech quarterly")
    }

    private static func generateYearlyReport(year: String) async {
        var summaries: [String] = []
        var allItems: [NewsItem] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for q in 1...4 {
            let path = "\(repoPath)/data/\(year)/Q\(q)/\(year)-Q\(q)_quarterly.json"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let fetch = try? decoder.decode(NewsFetch.self, from: data) else { continue }
            summaries.append(fetch.summary)
            allItems.append(contentsOf: fetch.items)
        }
        guard !summaries.isEmpty else { return }

        let summary = await invokeSonnet(prompt: buildRollupPrompt(
            level: "年报", period: year, items: allItems, subSummaries: summaries,
            instruction: "生成年度技术报告。全面回顾本年度AI Agent技术重大里程碑。分析技术范式转变，评估哪些技术从实验走向生产。展望下一年方向。"))
        let report = NewsFetch(summary: summary, items: Array(dedup(allItems).prefix(100)), fetchedAt: Date())
        saveReport(report, to: "\(repoPath)/data/\(year)/\(year)_yearly.json")
        gitCommitAndPush(files: ["data/\(year)/\(year)_yearly.json"],
                         message: "data(yearly): \(year) — tech annual")
    }

    // MARK: - Helpers

    private static func buildRollupPrompt(level: String, period: String, items: [NewsItem], subSummaries: [String], instruction: String) -> String {
        let summaryCtx = subSummaries.isEmpty ? "" : "\n下级报告摘要:\n" + subSummaries.enumerated().map { "\($0.offset+1). \(String($0.element.prefix(200)))" }.joined(separator: "\n")
        let titles = dedup(items).prefix(15).map { "- [\($0.source)] \($0.title)" }.joined(separator: "\n")
        return """
        你是资深AI技术分析师，撰写\(period)的\(level)。
        \(instruction)
        \(summaryCtx)

        关键技术条目：
        \(titles)

        直接输出中文\(level)内容。
        """
    }

    private static func invokeSonnet(prompt: String) async -> String {
        guard let claudePath = findClaudeCodePath() else { return "" }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = ["--print", "--permission-mode", "bypassPermissions", "--model", "sonnet", prompt]
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
            runWithTimeout(process)
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch { return "" }
    }

    private static func dedup(_ items: [NewsItem]) -> [NewsItem] {
        var seen = Set<String>()
        return items.filter { item in
            let key = item.url.isEmpty ? item.id : item.url
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private static func saveReport(_ report: NewsFetch, to path: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(report) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }

    // MARK: - Git Operations

    private static func gitCommitAndPush(files: [String], message: String) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fileArgs = files.map { "\"\($0)\"" }.joined(separator: " ")
        let commands = """
        cd "\(repoPath)" && \
        git add \(fileArgs) && \
        git commit -m "\(message.replacingOccurrences(of: "\"", with: "\\\""))" && \
        git push origin main
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", commands]
        process.environment = ProcessInfo.processInfo.environment.merging([
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
            "HOME": home,
            "GIT_SSH_COMMAND": "ssh -o StrictHostKeyChecking=no"
        ]) { _, new in new }
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            runWithTimeout(process, timeout: 60)
        } catch {}
    }

    // MARK: - Claude Code Invocation

    private static func invokeClaudeCode(prompt: String, model: String) async -> [NewsItem] {
        guard let claudePath = findClaudeCodePath() else { return [] }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = ["--print", "--permission-mode", "bypassPermissions", "--model", model, prompt]
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
            runWithTimeout(process)
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            return parseNewsItems(from: output)
        } catch { return [] }
    }

    private static func runWithTimeout(_ process: Process, timeout: TimeInterval = processTimeout) {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.5)
        }
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
    }

    private static func findClaudeCodePath() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for path in ["/opt/homebrew/bin/claude", "/usr/local/bin/claude", "\(home)/.claude/bin/claude"] {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }

    private static func parseNewsItems(from output: String) -> [NewsItem] {
        guard let s = output.firstIndex(of: "["), let e = output.lastIndex(of: "]") else { return [] }
        guard let data = String(output[s...e]).data(using: .utf8) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([NewsItem].self, from: data)) ?? []
    }
}
