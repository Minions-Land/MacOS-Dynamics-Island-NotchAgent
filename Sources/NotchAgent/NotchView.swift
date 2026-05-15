import SwiftUI

struct NotchView: View {
    @State private var isExpanded = false
    @State private var selectedItem: NewsItem?
    @State private var collapseTask: Task<Void, Never>?
    private let store = NewsStore.shared

    private var notchHeight: CGFloat {
        NSScreen.main?.safeAreaInsets.top ?? 33
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
                        }
                        updateWindowSize(expanded: false)
                    }
                }
            }
        }
    }

    // COLLAPSED: completely hidden behind the notch
    private var collapsedView: some View {
        Color.clear
            .frame(width: 300, height: notchHeight)
    }

    // EXPANDED: starts from top of screen, notch area has title + time
    private var expandedView: some View {
        VStack(spacing: 0) {
            // Notch-flanking header (left: title, right: time)
            notchHeader
                .frame(height: notchHeight)

            // Main content area below the notch
            VStack(alignment: .leading, spacing: 0) {
                if let item = selectedItem {
                    detailView(item: item)
                } else {
                    summaryAndListView
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 420, height: 520)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(.black.opacity(0.95))
                .clipShape(ExpandedShape())
        )
        .foregroundColor(.white)
    }

    // Header that flanks the notch: [NotchAgent ...notch... time]
    private var notchHeader: some View {
        HStack(spacing: 0) {
            // Left side of notch
            HStack(spacing: 5) {
                MinionIconView(size: 12)
                Text("NotchAgent")
                    .font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 8)

            // Notch gap (approximately 180pt wide on MacBook Air)
            Color.clear
                .frame(width: 180)

            // Right side of notch
            HStack(spacing: 5) {
                Text(Date(), format: .dateTime.hour().minute())
                    .font(.system(size: 10, weight: .medium))
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
                // Summary section
                if let summary = store.summary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text("Overview")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.yellow)
                        }

                        Text(summary)
                            .font(.system(size: 11))
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

                // News list (hourly — main content)
                if !store.items.isEmpty {
                    Text("本小时技术动态")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 4)

                    ForEach(store.items.prefix(6)) { item in
                        NewsRowView(item: item)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedItem = item
                                }
                            }
                    }

                    // Report entry points
                    Divider().background(Color.white.opacity(0.1))
                        .padding(.vertical, 6)

                    reportEntries
                } else if store.isLoading {
                    VStack(spacing: 8) {
                        MinionIconView(size: 32)
                            .opacity(0.4)
                        Text("Searching...")
                            .font(.system(size: 11))
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

    private var reportEntries: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reports")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.3))

            HStack(spacing: 8) {
                ReportButton(icon: "calendar", label: "日报")
                ReportButton(icon: "calendar.badge.clock", label: "周报")
                ReportButton(icon: "chart.bar", label: "月报")
            }
        }
    }

    private func detailView(item: NewsItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Button(action: { withAnimation { selectedItem = nil } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10))
                        Text("Back")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.yellow.opacity(0.8))
                }
                .buttonStyle(.plain)

                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(3)

                Text(item.summary)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))

                if !item.detail.isEmpty {
                    if item.detail.contains("$") || item.detail.contains("\\(") || item.detail.contains("\\[") {
                        MathTextView(
                            text: item.detail,
                            fontSize: 11,
                            textColor: "rgba(255,255,255,0.75)"
                        )
                        .frame(minHeight: 80, maxHeight: 300)
                    } else {
                        Text(item.detail)
                            .font(.system(size: 10.5))
                            .foregroundColor(.white.opacity(0.75))
                            .lineSpacing(3.5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: item.sourceIcon)
                        .font(.system(size: 10))
                        .foregroundColor(.yellow.opacity(0.7))
                    Text(item.source.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Button("Open") {
                        if let url = URL(string: item.url) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.yellow.opacity(0.15)))
                }

                FlowLayout(spacing: 4) {
                    ForEach(item.keywords, id: \.self) { kw in
                        Text(kw)
                            .font(.system(size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.yellow.opacity(0.12)))
                            .foregroundColor(.yellow.opacity(0.9))
                    }
                }
            }
            .padding(14)
        }
    }

    private func updateWindowSize(expanded: Bool) {
        guard let window = NSApp.windows.first(where: { $0 is NSPanel }) else { return }
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main!

        let screenFrame = screen.frame
        let notchH = max(screen.safeAreaInsets.top, 33)

        let width: CGFloat = expanded ? 420 : 300
        let height: CGFloat = expanded ? 520 : notchH
        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - height

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        }
    }
}

// Custom shape: rectangle with top corners squared (flush with screen top)
// and bottom corners rounded
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
