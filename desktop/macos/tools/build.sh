#!/bin/bash
# Run the checks, build Selene.app into build/ and sign it.
set -euo pipefail
cd "$(dirname "$0")/.."

swift run -c release selene-check
swift build -c release --product selene
BIN="$(swift build -c release --show-bin-path)/selene"

APP=build/Selene.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/LaunchAgents"
cp bundle/Info.plist "$APP/Contents/Info.plist"
# Inside the bundle, the LaunchAgent belongs to the app, so Login Items shows the app's name and
# icon. A plist in ~/Library/LaunchAgents is matched to the app only by a shared Team ID.
cp bundle/com.pavel.selene.plist "$APP/Contents/Library/LaunchAgents/"

# The icon changes only with its generator, so a build reuses the last one.
if [ ! -f build/AppIcon.icns ] || [ tools/make-icon.swift -nt build/AppIcon.icns ]; then
  ICONSET=build/AppIcon.iconset
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  swift tools/make-icon.swift build/AppIcon.png
  for px in 16 32 128 256 512; do
    sips -z $px $px build/AppIcon.png --out "$ICONSET/icon_${px}x${px}.png" >/dev/null
    sips -z $((px * 2)) $((px * 2)) build/AppIcon.png --out "$ICONSET/icon_${px}x${px}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp "$BIN" "$APP/Contents/MacOS/Selene"

# Screen Recording is granted to the designated requirement. An ad-hoc signature pins it to the
# build's hash, so every rebuild loses the grant. A certificate pins it to the certificate.
IDENTITY="${SELENE_SIGN_IDENTITY:-Selene Local Signing}"
if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
  codesign --force --sign "$IDENTITY" --identifier com.pavel.selene "$APP"
  echo "built $APP, signed by $IDENTITY"
else
  codesign --force --sign - --identifier com.pavel.selene "$APP"
  echo "built $APP, signed ad hoc; each rebuild needs Screen Recording granted again"
fi
