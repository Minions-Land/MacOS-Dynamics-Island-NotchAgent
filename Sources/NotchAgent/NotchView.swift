import SwiftUI

struct NotchView: View {
    @State private var isExpanded = false
    @State private var isHovering = false
    @State private var selectedItem: NewsItem?
    @State private var minionBounce = false
    private let store = NewsStore.shared

    var body: some View {
        ZStack(alignment: .top) {
            if isExpanded {
                expandedView
            } else {
                collapsedView
            }
        }
        .onHover { hovering in
            isHovering = hovering
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded = hovering
            }
            if hovering {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    minionBounce = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    minionBounce = false
                }
            }
            updateWindowSize(expanded: hovering)
        }
    }

    private var collapsedView: some View {
        HStack(spacing: 6) {
            if store.isLoading {
                MinionIconView(size: 14)
                    .rotationEffect(.degrees(minionBounce ? 10 : 0))
                    .opacity(0.6)
            } else {
                MinionIconView(size: 14)
                    .scaleEffect(minionBounce ? 1.2 : 1.0)
            }

            if let latest = store.items.first {
                Text(latest.title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Text("NotchAgent")
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(width: 200, height: 32)
        .background(
            Capsule()
                .fill(.black.opacity(0.85))
        )
        .foregroundColor(.white)
    }

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            Divider().background(
                LinearGradient(colors: [.yellow.opacity(0.4), .orange.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
            )

            if let item = selectedItem {
                detailView(item: item)
            } else if store.items.isEmpty {
                emptyStateView
            } else {
                listView
            }
        }
        .frame(width: 380, height: 420)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.92))
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.yellow.opacity(0.2), .orange.opacity(0.1), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
        )
        .foregroundColor(.white)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            MinionIconView(size: 48)
                .opacity(0.5)
            Text(store.isLoading ? "Minion is searching..." : "No news yet")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
            if store.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            MinionIconView(size: 16)
                .scaleEffect(minionBounce ? 1.15 : 1.0)

            Text("NotchAgent")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            if store.isLoading {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("fetching...")
                        .font(.system(size: 9))
                        .foregroundColor(.yellow.opacity(0.7))
                }
            }

            if let date = store.lastUpdated {
                Text(date, style: .relative)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(store.items) { item in
                    NewsRowView(item: item)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedItem = item
                            }
                        }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func detailView(item: NewsItem) -> some View {
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
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(3)

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: item.sourceIcon)
                    .font(.system(size: 10))
                    .foregroundColor(.yellow.opacity(0.7))
                Text(item.source.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                Button("Open Link") {
                    if let url = URL(string: item.url) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(
                        LinearGradient(colors: [.yellow.opacity(0.2), .orange.opacity(0.15)], startPoint: .leading, endPoint: .trailing)
                    )
                )
            }

            FlowLayout(spacing: 4) {
                ForEach(item.keywords, id: \.self) { kw in
                    Text(kw)
                        .font(.system(size: 9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.yellow.opacity(0.15)))
                        .foregroundColor(.yellow.opacity(0.9))
                }
            }
        }
        .padding(16)
    }

    private func updateWindowSize(expanded: Bool) {
        guard let window = NSApp.windows.first(where: { $0 is NSPanel }) else { return }
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.frame
        let width: CGFloat = expanded ? 380 : 200
        let height: CGFloat = expanded ? 420 : 32

        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - height

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        }
    }
}
