#!/usr/bin/env bash
# Builds Kumquat.app (universal: Apple Silicon + Intel) into ./build.
#   scripts/build-app.sh            → build/Kumquat.app
#   scripts/build-app.sh --dmg      → also build/Kumquat-<version>.dmg
#   VERSION=1.2.0 scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)}"
VERSION="${VERSION:-1.0.0}"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
APP="build/Kumquat.app"

ARCHS=(--arch arm64 --arch x86_64)
if [[ "${UNIVERSAL:-1}" == "0" ]]; then ARCHS=(); fi

echo "→ Compiling Kumquat $VERSION ($BUILD)"
swift build -c release ${ARCHS[@]+"${ARCHS[@]}"}
BIN="$(swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)/Kumquat"

echo "→ Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Kumquat"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"
for lang in en es; do mkdir -p "$APP/Contents/Resources/$lang.lproj"; done

# Ad-hoc signature so macOS runs it locally. Set SIGN_ID to use a Developer ID.
codesign --force --deep --options runtime --entitlements Resources/Kumquat.entitlements --sign "${SIGN_ID:--}" "$APP"
echo "✓ $APP"

if [[ "${1:-}" == "--dmg" ]]; then
  DMG="build/Kumquat-$VERSION.dmg"
  STAGE="$(mktemp -d)"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  rm -f "$DMG"
  hdiutil create -volname "Kumquat" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$STAGE"
  echo "✓ $DMG"
fi
