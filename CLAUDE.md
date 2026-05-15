# NotchAgent

macOS Dynamic Island-style AI 技术动态聚合器，适用于 Apple Silicon MacBook。

## Architecture

- **UI Layer**: SwiftUI + AppKit (NSPanel 隐藏在物理 notch 后方)
- **Backend**: Claude Code CLI — sonnet 抓取+总结，含技术细节和 LaTeX 公式
- **Data**: `~/.notchagent/latest.json` (本地仅保留最新一次), `data/` (历史全部在 GitHub)
- **Refresh**: Timer, 每 60 分钟
- **GitHub Sync**: 自动 commit + push 到 Minions-Land/MacOS-Dynamics-Island-NotchAgent
- **Formula Rendering**: KaTeX via WKWebView, 支持 `$...$` 和 `$$...$$`

## Build & Run

```bash
swift build -c release
./install.sh          # creates ~/Applications/NotchAgent.app
open ~/Applications/NotchAgent.app
```

## Key Files

- `App.swift` — 入口, SwiftUI App + NSApplicationDelegateAdaptor
- `AppDelegate.swift` — 窗口管理, menu bar, notch panel
- `NotchView.swift` — 收起(不可见) / 展开(总结+列表+详情) UI
- `NewsManager.swift` — sonnet 抓取 → sonnet 总结 → git push → 分层报告生成
- `Models.swift` — NewsItem(含 detail 字段), NewsFetch, NewsStore
- `MathTextView.swift` — WKWebView + KaTeX 公式渲染
- `MinionIcon.swift` / `MinionIconView.swift` — 小黄人描边图标
- `SettingsView.swift` — 关键词管理

## How It Works

1. App 以 accessory 模式启动(无 Dock 图标), menu bar 显示小黄人图标
2. NSPanel 定位在物理 notch 正后方, 收起时完全不可见
3. 鼠标悬停 notch 区域 → 面板从顶部展开, 总结优先展示
4. 展开 header: notch 左侧 "NotchAgent", 右侧当前时间
5. 每小时: sonnet 抓取 8 条技术动态(含方法/公式/数据), sonnet 生成技术总结
6. 点击条目 → 详情页展示技术细节, 公式通过 KaTeX 正式渲染
7. 数据自动 push 到 GitHub; 本地仅保留最新一次抓取

## Data Structure (GitHub)

```
data/
  YYYY/
    MM/
      DD/
        YYYY-MM-DD_HH-mm_hourly.json   ← 小时报
        YYYY-MM-DD_daily.json           ← 日报 (23:00 生成)
      WXX/
        YYYY-WXX_weekly.json            ← 周报 (周日生成)
      YYYY-MM_monthly.json              ← 月报 (月末生成)
    QX/
      YYYY-QX_quarterly.json            ← 季度报
    YYYY_yearly.json                    ← 年报
```

## Data Flow

```
Timer (1h) → claude --print --model sonnet (fetch 8 items with detail)
           → claude --print --model sonnet (tech-focused summary)
           → save ~/.notchagent/latest.json
           → git commit + push data/YYYY/MM/DD/YYYY-MM-DD_HH-mm_hourly.json
           → check rollups (daily/weekly/monthly/quarterly/yearly)
```

## Performance

- Idle: ~74MB RAM, 0% CPU, 34 FDs, 6 threads
- Process timeout: 5 min (claude), 60s (git)
- WKWebView: nonPersistent storage, no disk cache growth
- Atomic file writes, items capped at 10
