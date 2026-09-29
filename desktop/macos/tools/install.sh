#!/bin/bash
# Build Selene, copy it to ~/Applications and (re)load LaunchAgent com.pavel.selene.
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL=com.pavel.selene
DEST="$HOME/Applications/Selene.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/selene.log"

tools/build.sh

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
rm -rf "$DEST"
cp -R build/Selene.app "$DEST"

sed -e "s|__BIN__|$DEST/Contents/MacOS/selene|" -e "s|__LOG__|$LOG|" \
  "launchd/$LABEL.plist.in" > "$PLIST"
plutil -lint "$PLIST" >/dev/null
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "installed $DEST, log $LOG"
