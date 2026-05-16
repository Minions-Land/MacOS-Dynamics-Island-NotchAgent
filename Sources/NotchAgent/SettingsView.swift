import SwiftUI

struct SettingsView: View {
    @State private var store = NewsStore.shared
    @State private var newKeyword = ""

    var body: some View {
        TabView {
            keywordsTab
                .tabItem { Label("Keywords", systemImage: "tag") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 450, height: 320)
    }

    private var keywordsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tracked Keywords").font(.headline)
            Text("NotchAgent searches for news matching these keywords every hour.")
                .font(.caption).foregroundColor(.secondary)

            List {
                ForEach(store.keywords, id: \.self) { kw in
                    HStack {
                        Text(kw)
                        Spacer()
                        Button(action: { store.removeKeyword(kw) }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.red.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 160)

            HStack {
                TextField("Add keyword...", text: $newKeyword)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addKeyword() }
                Button("Add") { addKeyword() }.disabled(newKeyword.isEmpty)
            }

            Button("Reset to Defaults") {
                store.keywords = NewsStore.defaultKeywords
                store.newlyAddedKeywords = []
                store.pendingDeletionKeywords = []
                store.saveKeywords()
            }
            .font(.caption)
        }
        .padding()
    }

    private var aboutTab: some View {
        VStack(spacing: 12) {
            MinionIconView(size: 48)
            Text("NotchAgent").font(.title2.bold())
            Text("v1.0.0").font(.caption).foregroundColor(.secondary)
            Text("AI news aggregator powered by Claude Code.\nDisplays in your MacBook's notch area.")
                .font(.caption).multilineTextAlignment(.center).foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }

    private func addKeyword() {
        store.addKeyword(newKeyword)
        newKeyword = ""
    }
}
