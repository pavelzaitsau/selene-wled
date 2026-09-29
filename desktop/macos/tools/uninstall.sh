#!/bin/bash
# Stop Selene and remove the app, the LaunchAgent and its Screen Recording grant.
set -euo pipefail

LABEL=com.pavel.selene
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Applications/Selene.app"
tccutil reset ScreenCapture "$LABEL" >/dev/null 2>&1 || true

echo "uninstalled; log left at ~/Library/Logs/selene.log"
