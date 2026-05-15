# NotchAgent

macOS Dynamic Island-style AI news aggregator for Apple Silicon MacBooks.

## Architecture

- **UI Layer**: SwiftUI + AppKit (NSPanel hidden behind physical notch)
- **Backend**: Claude Code CLI — haiku for fetching, sonnet for summarizing
- **Data**: `~/.notchagent/latest.json` (current), `data/` dir (historical, git-tracked)
- **Refresh**: Timer-based, every 60 minutes
- **GitHub Sync**: Auto-commits each fetch to `data/YYYY-MM-DD/HH-mm.json` and pushes

## Build & Run

```bash
swift build -c release
./install.sh          # creates ~/Applications/NotchAgent.app
open ~/Applications/NotchAgent.app
```

## Key Files

- `App.swift` — Entry point, SwiftUI App with NSApplicationDelegateAdaptor
- `AppDelegate.swift` — Window setup, menu bar, notch panel creation
- `NotchView.swift` — Collapsed (invisible) / expanded (summary + list) UI
- `NewsManager.swift` — Two-model pipeline: haiku fetch → sonnet summarize → git push
- `Models.swift` — NewsItem, NewsFetch, NewsStore
- `SettingsView.swift` — Keyword management UI
- `MinionIcon.swift` / `MinionIconView.swift` — Custom Minion-style icon

## How It Works

1. App launches as accessory (no Dock icon), shows Minion icon in menu bar
2. NSPanel positioned exactly behind the physical notch (invisible when collapsed)
3. Hover over notch area → panel expands from top with summary-first layout
4. Expanded header: "NotchAgent" left of notch, time right of notch
5. Every hour: haiku fetches 10 news items, sonnet writes Chinese summary
6. Data auto-pushed to GitHub (Minions-Land/MacOS-Dynamics-Island-NotchAgent)
7. Local only keeps latest fetch; all history lives in git

## Data Flow

```
Timer (1h) → claude --print --model haiku (fetch news)
           → claude --print --model sonnet (summarize)
           → save ~/.notchagent/latest.json
           → git commit + push data/YYYY-MM-DD/HH-mm.json
```
