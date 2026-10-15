#!/bin/bash
# Stop Selene and remove the app, the LaunchAgent and its Screen Recording grant.
set -euo pipefail

LABEL=com.pavel.selene
DEST="$HOME/Applications/Selene.app"
if [ -f "$DEST/Contents/Library/LaunchAgents/$LABEL.plist" ]; then
  "$DEST/Contents/MacOS/Selene" --unregister || true
fi
rm -rf "$DEST"
tccutil reset ScreenCapture "$LABEL" >/dev/null 2>&1 || true

echo "uninstalled; log left at ~/Library/Logs/selene.log"
