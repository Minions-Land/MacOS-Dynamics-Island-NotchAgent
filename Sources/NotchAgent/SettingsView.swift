import SwiftUI

struct SettingsView: View {
    @State private var store = NewsStore.shared
    @State private var newKeyword = ""
    @State private var refreshInterval = 60

    var body: some View {
        TabView {
            keywordsTab
                .tabItem { Label("Keywords", systemImage: "tag") }

            generalTab
                .tabItem { Label("General", systemImage: "gear") }

            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 450, height: 350)
    }

    private var keywordsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tracked Keywords")
                .font(.headline)

            Text("NotchAgent will search for news matching these keywords every hour.")
                .font(.caption)
                .foregroundColor(.secondary)

            List {
                ForEach(store.keywords, id: \.self) { keyword in
                    HStack {
                        Text(keyword)
                        Spacer()
                        Button(action: {
                            store.keywords.removeAll { $0 == keyword }
                            store.saveKeywords()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 180)

            HStack {
                TextField("Add keyword...", text: $newKeyword)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addKeyword() }

                Button("Add") { addKeyword() }
                    .disabled(newKeyword.isEmpty)
            }

            Button("Reset to Defaults") {
                store.keywords = NewsStore.defaultKeywords
                store.saveKeywords()
            }
            .font(.caption)
        }
        .padding()
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General Settings")
                .font(.headline)

            HStack {
                Text("Refresh interval:")
                Picker("", selection: $refreshInterval) {
                    Text("30 min").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                    Text("4 hours").tag(240)
                }
                .frame(width: 120)
            }

            Toggle("Launch at login", isOn: .constant(false))

            Toggle("Show in menu bar", isOn: .constant(true))

            Spacer()
        }
        .padding()
    }

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("NotchAgent")
                .font(.title2.bold())

            Text("v1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("AI News aggregator powered by Claude Code.\nDisplays in your MacBook's notch area.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
    }

    private func addKeyword() {
        let trimmed = newKeyword.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !store.keywords.contains(trimmed) else { return }
        store.keywords.append(trimmed)
        store.saveKeywords()
        newKeyword = ""
    }
}
