# NotchAgent

macOS Dynamic Island-style AI news aggregator for Apple Silicon MacBooks.

## Architecture

- **UI Layer**: SwiftUI + AppKit (NSPanel positioned at notch)
- **Backend**: Claude Code CLI invoked via Process (--print mode, sonnet model)
- **Data**: JSON files in ~/.notchagent/
- **Refresh**: Timer-based, every 60 minutes

## Build & Run

```bash
swift build -c release
./install.sh          # creates ~/Applications/NotchAgent.app
open ~/Applications/NotchAgent.app
```

## Key Files

- `App.swift` — Entry point, SwiftUI App with NSApplicationDelegateAdaptor
- `AppDelegate.swift` — Window setup, menu bar, notch panel creation
- `NotchView.swift` — Collapsed/expanded notch UI with hover detection
- `NewsManager.swift` — Claude Code invocation + JSON parsing
- `Models.swift` — NewsItem model + NewsStore (Observable singleton)
- `SettingsView.swift` — Keyword management UI

## How It Works

1. App launches as accessory (no Dock icon), shows in menu bar
2. NSPanel positioned at screen top-center (notch area)
3. Collapsed: shows latest headline in a pill shape
4. Hover: expands to 380x420 panel with scrollable news list
5. Every hour: invokes `claude --print --model sonnet <prompt>` to fetch news
6. Claude searches arXiv, GitHub, HN for keyword-matched content
7. Results stored as JSON, displayed with Chinese summaries
