#!/bin/bash
# Run the checks, build Selene.app into build/ and sign it.
set -euo pipefail
cd "$(dirname "$0")/.."

swift run -c release selene-check
swift build -c release --product selene
BIN="$(swift build -c release --show-bin-path)/selene"

APP=build/Selene.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp bundle/Info.plist "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/selene"

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
