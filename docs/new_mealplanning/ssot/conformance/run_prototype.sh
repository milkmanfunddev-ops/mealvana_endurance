#!/usr/bin/env bash
# Meal-planning SSOT conformance — PROTOTYPE arm. Copies prototype_vectors.test.ts into the prototype
# package (so its `@/` alias resolves) and runs it with vitest against the REAL prototype functions.
# Read-only on the prototype except the ephemeral temp test file, always removed. Exit code is the gate.
#   ./run_prototype.sh            # PROTO_ROOT defaults to <workspace>/mealplanning-prototype
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
find_workspace() { local d="$1"; while [ "$d" != "/" ]; do [ -f "$d/workspace.env" ] && { echo "$d"; return; }; d="$(dirname "$d")"; done; }
MV_ROOT="$(find_workspace "$SCRIPT_DIR")"; [ -n "$MV_ROOT" ] || { echo "ABORT: workspace.env not found above $SCRIPT_DIR"; exit 1; }
# shellcheck disable=SC1091
source "$MV_ROOT/workspace.env"
PROTO_ROOT="${PROTO_ROOT:-$MV_ROOT/mealplanning-prototype}"
PKG="$PROTO_ROOT/packages/web"
[ -d "$PKG" ] || { echo "ABORT: prototype package not found: $PKG (set PROTO_ROOT)"; exit 1; }
VECTORS="$SCRIPT_DIR/../vectors"
DEST="$PKG/tests/_ssot_vectors_tmp.test.ts"
echo "== meal-planning SSOT conformance: prototype arm =="; echo "   prototype: $PKG"; echo "   vectors:   $VECTORS"
cp "$SCRIPT_DIR/prototype_vectors.test.ts" "$DEST"
trap 'rm -f "$DEST"' EXIT
cd "$PKG"
SSOT_VECTORS="$VECTORS" npx vitest run tests/_ssot_vectors_tmp.test.ts "$@"
