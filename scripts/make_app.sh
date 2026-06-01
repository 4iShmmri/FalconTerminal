#!/bin/bash
# Build FalconTerminal and assemble a runnable macOS .app bundle.
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "▸ Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/FalconTerminal"
APP="$ROOT/build/FalconTerminal.app"

echo "▸ Assembling app bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/FalconTerminal"
cp "$ROOT/scripts/Info.plist" "$APP/Contents/Info.plist"

echo "▸ Generating app icon…"
rm -rf "$ROOT/build/AppIcon.iconset"
swift "$ROOT/scripts/IconGenerator.swift" "$ROOT/build/AppIcon.iconset" >/dev/null
iconutil -c icns "$ROOT/build/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc sign so macOS will launch it without Gatekeeper complaints locally.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "▸ Done: $APP"
