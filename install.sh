#!/bin/bash
# NotchAgent - Build and Install Script
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="NotchAgent"
INSTALL_DIR="$HOME/Applications"
APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"

echo "🧠 Building NotchAgent (release)..."
cd "$SCRIPT_DIR"
swift build -c release

echo "📦 Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "Sources/NotchAgent/Info.plist" "$APP_BUNDLE/Contents/"

echo "📁 Ensuring data directory..."
mkdir -p "$HOME/.notchagent"

# Kill existing instance if running
pkill -f "$APP_NAME.app" 2>/dev/null || true
sleep 2

echo "🚀 Launching NotchAgent..."
open "$APP_BUNDLE"

echo ""
echo "✅ NotchAgent installed and running!"
echo "   App: $APP_BUNDLE"
echo "   Data: ~/.notchagent/"
echo "   Menu bar: look for the Minion icon"
echo ""
echo "   The notch overlay appears at the top center of your screen."
echo "   Hover over it to expand and see AI news."
echo ""
echo "   To auto-start at login:"
echo "   cp com.notchagent.app.plist ~/Library/LaunchAgents/"
echo "   launchctl load ~/Library/LaunchAgents/com.notchagent.app.plist"
