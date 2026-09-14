#!/usr/bin/env bash
#
# ssot-capture-setup.sh — install what `sync.mjs capture` needs to drive the
# booted iOS simulator: the idb client (pipx) and the idb companion (Facebook's
# prebuilt binary, verified against its published sha256). Everything lands
# under ~/.local; nothing needs sudo and nothing touches Homebrew's taps
# (facebook/fb fails to tap on current Homebrew and its companion formula wants
# newer Command Line Tools than Xcode ships).
#
#   scripts/ssot-capture-setup.sh            # install or update
#   node docs/ssot/decisions/_page/sync.mjs capture --check    # then confirm
#
set -euo pipefail

VERSION="${IDB_VERSION:-1.5.7}"
BASE="https://github.com/facebook/idb/releases/download/v${VERSION}"
DEST="$HOME/.local/idb-companion"
BIN="$HOME/.local/bin"
mkdir -p "$BIN"

command -v pipx >/dev/null || { echo "✗ pipx is missing: brew install pipx"; exit 1; }
command -v xcrun >/dev/null || { echo "✗ xcrun is missing: install Xcode"; exit 1; }

echo "→ idb client ${VERSION} (pipx)"
pipx install "fb-idb==${VERSION}" >/dev/null 2>&1 || pipx upgrade fb-idb >/dev/null 2>&1 || true
[ -x "$BIN/idb" ] || { echo "✗ pipx did not put idb in $BIN"; exit 1; }

echo "→ idb companion ${VERSION} (prebuilt)"
TMP="$(mktemp -d)"
curl -sSL -o "$TMP/companion.tar.gz" "$BASE/idb-companion.macos-arm64.tar.gz"
curl -sSL -o "$TMP/companion.sha256" "$BASE/idb-companion.macos-arm64.tar.gz.sha256"
WANT="$(awk '{print $1}' "$TMP/companion.sha256")"
HAVE="$(shasum -a 256 "$TMP/companion.tar.gz" | awk '{print $1}')"
[ "$WANT" = "$HAVE" ] || { echo "✗ companion tarball hash mismatch (want $WANT, have $HAVE)"; exit 1; }
rm -rf "$DEST" && mkdir -p "$DEST" && tar xzf "$TMP/companion.tar.gz" -C "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
ln -sf "$DEST/idb_companion" "$BIN/idb_companion"
rm -rf "$TMP"

echo "✓ $("$BIN/idb_companion" --version 2>/dev/null | head -1)"
echo "✓ idb at $BIN/idb"
case ":$PATH:" in *":$BIN:"*) ;; *) echo "  add $BIN to PATH for the shell; capture.mjs looks there on its own";; esac
echo "Next: node docs/ssot/decisions/_page/sync.mjs capture --check"
