#!/usr/bin/env bash
# Installs or updates Kumquat from the latest GitHub release.
#   curl -fsSL https://raw.githubusercontent.com/iandifilippo/Kumquat/main/install.sh | bash
set -euo pipefail

REPO="iandifilippo/Kumquat"
DEST="/Applications"
[[ -w "$DEST" ]] || DEST="$HOME/Applications"

echo "🍊 Installing Kumquat…"
URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -o '"browser_download_url": *"[^"]*Kumquat[^"]*\.zip"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')"
if [[ -z "$URL" ]]; then
  echo "Couldn't find a release to download. See https://github.com/$REPO/releases" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "$URL" -o "$TMP/Kumquat.zip"
ditto -x -k "$TMP/Kumquat.zip" "$TMP"

# Quit a running copy before replacing it.
osascript -e 'quit app "Kumquat"' >/dev/null 2>&1 || true
mkdir -p "$DEST"
rm -rf "$DEST/Kumquat.app"
ditto "$TMP/Kumquat.app" "$DEST/Kumquat.app"
# Downloaded with curl, so there is no quarantine flag; clear it anyway in case.
xattr -dr com.apple.quarantine "$DEST/Kumquat.app" 2>/dev/null || true

# The `kumquat` command, in the first folder on PATH we can write to.
for BIN in /opt/homebrew/bin /usr/local/bin; do
  if [[ -d "$BIN" && -w "$BIN" ]]; then
    ln -sf "$DEST/Kumquat.app/Contents/MacOS/Kumquat" "$BIN/kumquat"
    echo "✓ Added the kumquat command ($BIN/kumquat)"
    break
  fi
done

open "$DEST/Kumquat.app"
echo "✓ Kumquat is in $DEST and running in your menu bar."
echo "  Grab a file, move it a little, tap ⇧ Shift, and drop it on the ring."
