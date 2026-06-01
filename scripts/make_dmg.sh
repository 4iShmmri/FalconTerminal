#!/bin/bash
# Build Falcon Terminal and package it into a distributable .dmg.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# 1. Build the .app (this also regenerates the icon).
"$ROOT/scripts/make_app.sh" release

APP="$ROOT/build/FalconTerminal.app"
DMG="$ROOT/build/FalconTerminal.dmg"
STAGE="$ROOT/build/dmg-stage"
VOLNAME="Falcon Terminal"

echo "▸ Staging DMG contents…"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/FalconTerminal.app"
ln -s /Applications "$STAGE/Applications"

# Use the app icon as the disk-volume icon.
cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE/.VolumeIcon.icns"
SetFile -a C "$STAGE" 2>/dev/null || true

echo "▸ Creating compressed disk image…"
hdiutil create \
    -volname "$VOLNAME" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG" >/dev/null

rm -rf "$STAGE"

SIZE="$(du -h "$DMG" | cut -f1)"
echo "▸ Done: $DMG ($SIZE)"
