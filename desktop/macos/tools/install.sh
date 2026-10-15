#!/bin/bash
# Build Selene, copy it to ~/Applications and register its LaunchAgent com.pavel.selene.
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL=com.pavel.selene
DEST="$HOME/Applications/Selene.app"

tools/build.sh

SERVICE="gui/$(id -u)/$LABEL"
# Polls for up to 10 s until `launchctl print` output matches the extended regex in $1.
wait_for() {
  for _ in $(seq 20); do
    launchctl print "$SERVICE" 2>&1 | grep -Eq "$1" && return 0
    sleep 0.5
  done
  return 1
}

# Unregister the installed copy first, so launchd never runs a deleted bundle. A register that
# follows before launchd has dropped the old job gets an empty launch constraint, and every spawn
# then fails with EX_CONFIG.
if [ -f "$DEST/Contents/Library/LaunchAgents/$LABEL.plist" ]; then
  "$DEST/Contents/MacOS/Selene" --unregister || true
  wait_for "Could not find service" || true
fi

mkdir -p "$HOME/Applications" "$HOME/Library/Logs"
rm -rf "$DEST"
cp -R build/Selene.app "$DEST"
"$DEST/Contents/MacOS/Selene" --register
if ! wait_for "^[[:space:]]state = running"; then
  echo "LaunchAgent did not start, registering again"
  "$DEST/Contents/MacOS/Selene" --unregister || true
  wait_for "Could not find service" || true
  sleep 3
  "$DEST/Contents/MacOS/Selene" --register
  wait_for "^[[:space:]]state = running" || { echo "LaunchAgent did not start; see Troubleshooting in the README"; exit 1; }
fi

echo "installed $DEST, log ~/Library/Logs/selene.log"
