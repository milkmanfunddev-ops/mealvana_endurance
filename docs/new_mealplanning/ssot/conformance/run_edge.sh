#!/usr/bin/env bash
# Meal-planning SSOT conformance — EDGE-FUNCTION arm. Runs edge_vectors_test.ts under Deno against the
# app's supabase/functions/_shared/vana/ (the Deno twin). Read-only. Exit code is the gate.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
find_workspace() { local d="$1"; while [ "$d" != "/" ]; do [ -f "$d/workspace.env" ] && { echo "$d"; return; }; d="$(dirname "$d")"; done; }
MV_ROOT="$(find_workspace "$SCRIPT_DIR")"; [ -n "$MV_ROOT" ] || { echo "ABORT: workspace.env not found above $SCRIPT_DIR"; exit 1; }
# shellcheck disable=SC1091
source "$MV_ROOT/workspace.env"
SHARED="$APP_ROOT/supabase/functions/_shared/vana"
[ -d "$SHARED" ] || { echo "ABORT: edge twin not found: $SHARED"; exit 1; }
command -v deno >/dev/null || { echo "ABORT: deno is not installed"; exit 1; }
VECTORS="$SCRIPT_DIR/../vectors"
echo "== meal-planning SSOT conformance: edge arm =="; echo "   shared:  $SHARED"; echo "   vectors: $VECTORS"
SSOT_VECTORS="$VECTORS" VANA_SHARED="$SHARED" deno test -A --no-check "$SCRIPT_DIR/edge_vectors_test.ts" "$@"
