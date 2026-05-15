import SwiftUI

private func md(_ str: String) -> AttributedString {
    (try? AttributedString(markdown: str, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(str)
}

struct NotchView: View {
    @State private var isExpanded = false
    @State private var selectedItem: NewsItem?
    @State private var collapseTask: Task<Void, Never>?
    @State private var detailHeight: CGFloat = 100
    @State private var keywordsEditMode = false
    @State private var newKeywordInput = ""
    private let store = NewsStore.shared
    @Bindable private var settings = AppSettings.shared

    private var notchHeight: CGFloat {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })?.safeAreaInsets.top ?? 33
    }

    var body: some View {
        ZStack(alignment: .top) {
            if isExpanded {
                expandedView
            } else {
                collapsedView
            }
        }
        .onHover { hovering in
            collapseTask?.cancel()
            collapseTask = nil
            if hovering {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    isExpanded = true
                }
                updateWindowSize(expanded: true)
            } else {
                collapseTask = Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            isExpanded = false
                            selectedItem = nil
                            detailHeight = 100
                            keywordsEditMode = false
                        }
                        updateWindowSize(expanded: false)
                    }
                }
            }
        }
    }

    private var collapsedView: some View {
        Color.clear
            .frame(width: 300, height: notchHeight)
    }

    private var expandedView: some View {
        VStack(spacing: 0) {
            notchHeader
                .frame(height: notchHeight)

            VStack(alignment: .leading, spacing: 0) {
                if let item = selectedItem {
                    detailView(item: item)
                } else {
                    summaryAndListView
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 420 * settings.fontScale, height: 520 * settings.fontScale)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(.black.opacity(0.95))
                .clipShape(ExpandedShape())
        )
        .foregroundColor(.white)
    }

    private var notchHeader: some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                MinionIconView(size: 12)
                Text("NotchAgent")
                    .font(.system(size: settings.scaled(12), weight: .semibold))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 8)

            Color.clear
                .frame(width: 180)

            HStack(spacing: 5) {
                Text(Date(), format: .dateTime.hour().minute())
                    .font(.system(size: settings.scaled(12), weight: .medium))
                    .monospacedDigit()
                if store.isLoading {
                    ProgressView()
                        .scaleEffect(0.4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 8)
        }
        .foregroundColor(.white.opacity(0.8))
    }

    private var summaryAndListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let summary = store.summary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: settings.scaled(12)))
                                .foregroundColor(.yellow)
                            Text("Overview")
                                .font(.system(size: settings.scaled(13), weight: .semibold))
                                .foregroundColor(.yellow)
                        }

                        Text(md(summary))
                            .font(.system(size: settings.scaled(13)))
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.yellow.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(.yellow.opacity(0.15), lineWidth: 0.5)
                            )
                    )
                }

                keywordsModule

                if !store.items.isEmpty {
                    Text("本小时技术动态")
                        .font(.system(size: settings.scaled(12), weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 4)

                    ForEach(store.items.prefix(6)) { item in
                        NewsRowView(item: item)
                            .onTapGesture {
                                detailHeight = 100
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedItem = item
                                }
                            }
                    }

                    Divider().background(Color.white.opacity(0.1))
                        .padding(.vertical, 6)

                    reportEntries
                } else if store.isLoading {
                    VStack(spacing: 8) {
                        MinionIconView(size: 32)
                            .opacity(0.4)
                        Text("Searching...")
                            .font(.system(size: settings.scaled(13)))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private var keywordsModule: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "tag")
                    .font(.system(size: settings.scaled(11)))
                    .foregroundColor(.white.opacity(0.5))
                Text("Keywords")
                    .font(.system(size: settings.scaled(12), weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        keywordsEditMode.toggle()
                        newKeywordInput = ""
                    }
                }) {
                    Image(systemName: keywordsEditMode ? "checkmark.circle.fill" : "pencil.circle")
                        .font(.system(size: settings.scaled(13)))
                        .foregroundColor(.yellow.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            FlowLayout(spacing: 5) {
                ForEach(store.keywords, id: \.self) { kw in
                    keywordChip(kw)
                }
            }

            if keywordsEditMode {
                HStack(spacing: 6) {
                    TextField("Add keyword...", text: $newKeywordInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: settings.scaled(11)))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.08)))
                        .foregroundColor(.white)
                        .onSubmit { commitNewKeyword() }
                    Button(action: commitNewKeyword) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: settings.scaled(14)))
                            .foregroundColor(.yellow.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .disabled(newKeywordInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }

    private func keywordChip(_ kw: String) -> some View {
        let pendingDeletion = store.pendingDeletionKeywords.contains(kw)
        let newlyAdded = store.newlyAddedKeywords.contains(kw)
        let captured = store.isCaptured(kw)

        let (bg, fg, ringColor, ringWidth): (Color, Color, Color, CGFloat) = {
            if pendingDeletion {
                return (.white.opacity(0.05), .white.opacity(0.3), .clear, 0)
            } else if newlyAdded {
                return (.black.opacity(0.6), .white.opacity(0.85), .white.opacity(0.2), 0.5)
            } else if captured {
                return (.yellow.opacity(0.12), .yellow.opacity(0.95), .yellow.opacity(0.85), 1.2)
            } else {
                return (.white.opacity(0.06), .white.opacity(0.7), .white.opacity(0.15), 0.5)
            }
        }()

        return HStack(spacing: 4) {
            Text(kw)
                .font(.system(size: settings.scaled(11)))
                .strikethrough(pendingDeletion, color: .white.opacity(0.4))
            if keywordsEditMode {
                Button(action: {
                    if pendingDeletion {
                        store.undoRemoveKeyword(kw)
                    } else {
                        store.removeKeyword(kw)
                    }
                }) {
                    Image(systemName: pendingDeletion ? "arrow.uturn.backward.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: settings.scaled(11)))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(bg)
                .overlay(Capsule().stroke(ringColor, lineWidth: ringWidth))
        )
        .foregroundColor(fg)
    }

    private func commitNewKeyword() {
        let kw = newKeywordInput.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty else { return }
        store.addKeyword(kw)
        newKeywordInput = ""
    }

    private var reportEntries: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reports")
                .font(.system(size: settings.scaled(11), weight: .medium))
                .foregroundColor(.white.opacity(0.3))

            HStack(spacing: 8) {
                ReportButton(icon: "calendar", label: "日报")
                ReportButton(icon: "calendar.badge.clock", label: "周报")
                ReportButton(icon: "chart.bar", label: "月报")
            }
        }
    }

    private func detailView(item: NewsItem) -> some View {
        let currentIndex = store.items.firstIndex(where: { $0.id == item.id }) ?? 0
        let total = store.items.count
        let hasPrev = currentIndex > 0
        let hasNext = currentIndex < total - 1

        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button(action: { withAnimation { selectedItem = nil } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: settings.scaled(12)))
                            Text("Back")
                                .font(.system(size: settings.scaled(13)))
                        }
                        .foregroundColor(.yellow.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("\(currentIndex + 1) / \(total)")
                        .font(.system(size: settings.scaled(11)))
                        .foregroundColor(.white.opacity(0.4))
                }

                Text(md(item.title))
                    .font(.system(size: settings.scaled(15), weight: .semibold))
                    .lineLimit(3)

                Text(md(item.summary))
                    .font(.system(size: settings.scaled(13), weight: .medium))
                    .foregroundColor(.white.opacity(0.9))

                if !item.detail.isEmpty {
                    if item.detail.contains("$") || item.detail.contains("\\(") || item.detail.contains("\\[") {
                        MathTextView(
                            text: item.detail,
                            fontSize: settings.scaled(13),
                            textColor: "rgba(255,255,255,0.78)",
                            measuredHeight: $detailHeight
                        )
                        .frame(height: detailHeight)
                        .id(item.id)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(splitIntoParagraphs(item.detail), id: \.self) { para in
                                Text(md(para))
                                    .font(.system(size: settings.scaled(12.5)))
                                    .foregroundColor(.white.opacity(0.78))
                                    .lineSpacing(4.5)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: item.sourceIcon)
                        .font(.system(size: settings.scaled(12)))
                        .foregroundColor(.yellow.opacity(0.7))
                    Text(item.source.uppercased())
                        .font(.system(size: settings.scaled(11), weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Button("Open") {
                        if let url = URL(string: item.url) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: settings.scaled(13), weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.yellow.opacity(0.15)))
                }

                FlowLayout(spacing: 4) {
                    ForEach(item.keywords, id: \.self) { kw in
                        Text(kw)
                            .font(.system(size: settings.scaled(11)))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.yellow.opacity(0.12)))
                            .foregroundColor(.yellow.opacity(0.9))
                    }
                }

                Divider().background(Color.white.opacity(0.1))
                    .padding(.vertical, 4)

                HStack {
                    Button(action: { navigateDetail(offset: -1) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: settings.scaled(15)))
                            Text("上一篇")
                                .font(.system(size: settings.scaled(12)))
                        }
                        .foregroundColor(hasPrev ? .yellow.opacity(0.85) : .white.opacity(0.2))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasPrev)

                    Spacer()

                    Button(action: { navigateDetail(offset: 1) }) {
                        HStack(spacing: 4) {
                            Text("下一篇")
                                .font(.system(size: settings.scaled(12)))
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: settings.scaled(15)))
                        }
                        .foregroundColor(hasNext ? .yellow.opacity(0.85) : .white.opacity(0.2))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasNext)
                }
            }
            .padding(14)
        }
    }

    private func navigateDetail(offset: Int) {
        guard let cur = selectedItem,
              let idx = store.items.firstIndex(where: { $0.id == cur.id }) else { return }
        let next = idx + offset
        guard next >= 0, next < store.items.count else { return }
        detailHeight = 100
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedItem = store.items[next]
        }
    }

    private func splitIntoParagraphs(_ raw: String) -> [String] {
        let normalized = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
        let explicit = normalized.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if explicit.count > 1 { return explicit }

        let sentences = normalized.components(separatedBy: "。")
        guard sentences.count > 3 else { return [raw] }
        var out: [String] = []
        var cur = ""
        for (i, s) in sentences.enumerated() {
            let t = s.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { continue }
            cur += t + (i < sentences.count - 1 ? "。" : "")
            if cur.count > 80 || i == sentences.count - 1 {
                out.append(cur)
                cur = ""
            }
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    private func updateWindowSize(expanded: Bool) {
        guard let window = NSApp.windows.first(where: { $0 is NSPanel }) else { return }
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main!

        let screenFrame = screen.frame
        let notchH = max(screen.safeAreaInsets.top, 33)

        let scale = AppSettings.shared.fontScale
        let width: CGFloat = expanded ? 420 * scale : 300
        let height: CGFloat = expanded ? 520 * scale : notchH
        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - height

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        }
    }
}

struct ExpandedShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 16
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                          control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
