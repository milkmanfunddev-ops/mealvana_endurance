#!/bin/bash
# =============================================================================
# Edge Function Test Runner (auto-discovery)
# =============================================================================
#
# Discovers and runs EVERY *.test.ts under supabase/functions/ (except
# `_archived/`) — a new test file is picked up with zero edits to this script.
# There is no hand-curated test list; if you add a test, it runs.
#
# Usage:
#   ./supabase/functions/run-algorithm-tests.sh              # Local tests only
#   ./supabase/functions/run-algorithm-tests.sh --e2e        # Local + remote E2E
#
# Remote/E2E classification (mechanical — see is_remote()):
#   A test is REMOTE iff either
#     (a) its filename matches *e2e* or *integration*, OR
#     (b) it reads SUPABASE_ANON_KEY from env (Deno.env.get('SUPABASE_ANON_KEY'))
#         to call a deployed functions/v1 endpoint.
#   Remote tests run ONLY in the --e2e section and require:
#     export SUPABASE_URL=https://<project-ref>.supabase.co
#     export SUPABASE_ANON_KEY=<anon-key>
#   Everything else runs locally in Section 1.
#   (Note: a bare grep for 'functions/v1' is NOT the rule — local fetch-stub
#   tests like ai-coach/index.test.ts mention that path in comments.)
#
# Permissions: local tests all run with one safe superset —
#   --allow-read --allow-write --allow-env --node-modules-dir=none
# No local test currently needs --allow-net (the AI-function tests stub
# globalThis.fetch). If one ever genuinely does, add it to NET_ALLOWED below
# with a comment saying why.
#
# The script exits non-zero if any discovered test fails, and prints
# discovered/run/quarantined counts so a silently-dropped file is impossible.
#
# =============================================================================

set -o pipefail

DENO="${DENO:-deno}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ─── Quarantine ──────────────────────────────────────────────────────────────
# Known-broken tests, excluded from the run but counted and printed every time
# so the debt stays visible. Format: "relative/path|one-line reason".
# Fix the test, then delete its entry.
QUARANTINE=(
)

# ─── Local tests that genuinely need --allow-net ────────────────────────────
# Empty today: every local test stubs fetch. Add "relative/path" entries here
# (with a comment why) if a test ever needs real network access locally.
NET_ALLOWED=(
)

LOCAL_FLAGS=(--allow-read --allow-write --allow-env --node-modules-dir=none)
E2E_FLAGS=(--allow-net --allow-env --allow-read --node-modules-dir=none)

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0
RESULTS=()   # "PASS path" / "FAIL path" lines for the per-file summary
START_TIME=$SECONDS

# is_remote <file> — the mechanical remote/E2E rule documented in the header.
is_remote() {
  local f="$1" base
  base="$(basename "$f")"
  case "$base" in
    *e2e*|*integration*) return 0 ;;
  esac
  grep -Eq "Deno\.env\.get\(['\"]SUPABASE_ANON_KEY" "$f"
}

# is_quarantined <file> — echoes the reason and returns 0 if quarantined.
is_quarantined() {
  local f="$1" entry
  for entry in "${QUARANTINE[@]:-}"; do
    [ -z "$entry" ] && continue
    if [ "${entry%%|*}" = "$f" ]; then
      echo "${entry#*|}"
      return 0
    fi
  done
  return 1
}

needs_net() {
  local f="$1" entry
  for entry in "${NET_ALLOWED[@]:-}"; do
    [ "$entry" = "$f" ] && return 0
  done
  return 1
}

run_test() {
  local file="$1"
  shift
  local flags=("$@")

  echo ""
  echo -e "${BLUE}━━━ $file ━━━${NC}"
  if $DENO test "${flags[@]}" "$file" 2>&1; then
    echo -e "${GREEN}  PASSED${NC}"
    PASSED=$((PASSED + 1))
    RESULTS+=("PASS $file")
  else
    echo -e "${RED}  FAILED${NC}"
    FAILED=$((FAILED + 1))
    RESULTS+=("FAIL $file")
  fi
}

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Mealvana Endurance — Edge Function Tests             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"

# ─── Discovery ───────────────────────────────────────────────────────────────

ALL_FILES=()
while IFS= read -r f; do
  ALL_FILES+=("$f")
#
# `_archived/` is pruned: retired tests are moved to the repo-root
# `_archived/supabase/functions/...` mirror (same convention as the Flutter
# `_archived/test/...`), which is already outside this script's `cd`. The
# prune below is belt-and-braces for anyone who archives in place instead —
# without it, moving a test to `_archived/` would keep running it.
done < <(find . -path './_archived' -prune -o -name '*.test.ts' -type f -print | sed 's|^\./||' | sort)

LOCAL_FILES=()
REMOTE_FILES=()
QUARANTINED_LOCAL=()
QUARANTINED_REMOTE=()
QUARANTINE_NOTES=()

for f in "${ALL_FILES[@]}"; do
  if reason="$(is_quarantined "$f")"; then
    QUARANTINE_NOTES+=("$f — $reason")
    if is_remote "$f"; then QUARANTINED_REMOTE+=("$f"); else QUARANTINED_LOCAL+=("$f"); fi
    continue
  fi
  if is_remote "$f"; then
    REMOTE_FILES+=("$f")
  else
    LOCAL_FILES+=("$f")
  fi
done

N_ALL=${#ALL_FILES[@]}
N_LOCAL=${#LOCAL_FILES[@]}
N_REMOTE=${#REMOTE_FILES[@]}
N_QUAR=$(( ${#QUARANTINED_LOCAL[@]} + ${#QUARANTINED_REMOTE[@]} ))

echo ""
echo -e "Discovered ${BLUE}$N_ALL${NC} test files: ${BLUE}$N_LOCAL${NC} local, ${BLUE}$N_REMOTE${NC} remote (--e2e only), ${YELLOW}$N_QUAR${NC} quarantined"

# Silent-drop guard: every discovered file must be accounted for.
if [ $((N_LOCAL + N_REMOTE + N_QUAR)) -ne "$N_ALL" ]; then
  echo -e "${RED}INTERNAL ERROR: discovery bucket counts don't add up — refusing to run${NC}"
  exit 1
fi

# ─── Section 1: Local tests ──────────────────────────────────────────────────

echo ""
echo -e "${YELLOW}▶ SECTION 1: Local Tests ($N_LOCAL files)${NC}"

for f in "${LOCAL_FILES[@]}"; do
  if needs_net "$f"; then
    run_test "$f" "${LOCAL_FLAGS[@]}" --allow-net
  else
    run_test "$f" "${LOCAL_FLAGS[@]}"
  fi
done

# ─── Section 2: Remote E2E tests (--e2e) ─────────────────────────────────────

E2E_RUN=0
if [ "${1:-}" = "--e2e" ]; then
  echo ""
  echo -e "${YELLOW}▶ SECTION 2: Remote E2E Tests ($N_REMOTE files)${NC}"

  if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
    echo -e "${RED}  ERROR: SUPABASE_URL and SUPABASE_ANON_KEY must be set for E2E tests${NC}"
    echo "  Run:"
    echo "    export SUPABASE_URL=https://<project-ref>.supabase.co"
    echo "    export SUPABASE_ANON_KEY=<your-anon-key>"
    FAILED=$((FAILED + 1))
    RESULTS+=("FAIL (e2e requested but env not set — $N_REMOTE remote files not run)")
  else
    E2E_RUN=$N_REMOTE
    for f in "${REMOTE_FILES[@]}"; do
      run_test "$f" "${E2E_FLAGS[@]}"
    done
  fi
else
  echo ""
  echo -e "${YELLOW}▶ SECTION 2: Remote E2E Tests — SKIPPED ($N_REMOTE files; use --e2e)${NC}"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

ELAPSED=$((SECONDS - START_TIME))

echo ""
echo -e "${BLUE}══════════════════ PER-FILE RESULTS ══════════════════${NC}"
for line in "${RESULTS[@]:-}"; do
  case "$line" in
    PASS*) echo -e "  ${GREEN}${line}${NC}" ;;
    *)     echo -e "  ${RED}${line}${NC}" ;;
  esac
done

if [ "$N_QUAR" -gt 0 ]; then
  echo ""
  echo -e "${YELLOW}$N_QUAR quarantined (excluded from run — fix and remove from QUARANTINE):${NC}"
  for note in "${QUARANTINE_NOTES[@]}"; do
    echo -e "  ${YELLOW}QUAR $note${NC}"
  done
fi

echo ""
echo -e "${BLUE}════════════════════ TEST SUMMARY ════════════════════${NC}"
echo -e "  Discovered: $N_ALL files ($N_LOCAL local, $N_REMOTE remote, $N_QUAR quarantined)"
echo -e "  Ran:        $((PASSED + FAILED)) files (local $N_LOCAL$( [ "$E2E_RUN" -gt 0 ] && echo ", e2e $E2E_RUN" ))"
echo -e "  ${GREEN}Passed:     $PASSED${NC}"
echo -e "  ${RED}Failed:     $FAILED${NC}"
echo -e "  Elapsed:    ${ELAPSED}s"
echo ""

if [ "$FAILED" -gt 0 ]; then
  echo -e "${RED}Some tests FAILED!${NC}"
  exit 1
else
  echo -e "${GREEN}All discovered tests passed ($PASSED/$((N_ALL - N_QUAR - (N_REMOTE - E2E_RUN)))).${NC}"
  exit 0
fi
