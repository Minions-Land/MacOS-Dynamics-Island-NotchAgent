#!/bin/bash
# NotchAgent - Build and Install Script

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="NotchAgent"
BUILD_DIR="$SCRIPT_DIR/.build/release"
INSTALL_DIR="$HOME/Applications"

echo "🧠 Building NotchAgent..."
cd "$SCRIPT_DIR"
swift build -c release

echo "📦 Creating app bundle..."
APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "Sources/NotchAgent/Info.plist" "$APP_BUNDLE/Contents/"

echo "📁 Creating data directory..."
mkdir -p "$HOME/.notchagent"

echo "✅ NotchAgent installed to $APP_BUNDLE"
echo ""
echo "To run: open $APP_BUNDLE"
echo "To auto-start: add NotchAgent to Login Items in System Settings"
