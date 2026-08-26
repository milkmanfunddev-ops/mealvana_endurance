#!/usr/bin/env bash
# Design-library tripwire — enforces the CLAUDE.md principle "design-bearing components live in
# the library, and trace to their spec". Run from the repo root; exit 1 on any violation.
#
#   1. Every docs/ssot/spec/design/components/<name>.md has a widget in lib/shared/widgets/kyle_design/
#      whose file cites that spec path.
#   2. Exactly one token registry: no `class *Tokens`/`*Colors` outside lib/theme/.
#   3. No `Color(0x…)` literals and no chromatic Material `Colors.*` outside lib/theme/.
#
# Usage: scripts/design-library-check.sh [--warn]   (--warn reports without failing)
set -u
cd "$(git rev-parse --show-toplevel)"
fail=0; mode=${1:-}
say() { printf '%s\n' "$*"; }
viol() { say "✗ $*"; fail=1; }

say "== 1 · spec components → library widgets"
for spec in docs/ssot/spec/design/components/*.md; do
  [ -e "$spec" ] || continue
  name=$(basename "$spec" .md)                      # e.g. workout-card
  rel=${spec#docs/ssot/}                            # spec/design/components/workout-card.md
  hit=$(grep -rlF "$rel" lib/shared/widgets/kyle_design --include='*.dart' 2>/dev/null | head -1)
  if [ -n "$hit" ]; then say "  ✓ $name → $hit"
  else
    stray=$(grep -rlF "$rel" lib --include='*.dart' 2>/dev/null | head -1)
    if [ -n "$stray" ]; then viol "$name is implemented OUTSIDE the library: $stray"
    else viol "$name has no widget citing $rel (expected under lib/shared/widgets/kyle_design/)"; fi
  fi
done

say "== 2 · one token registry"
grep -rnE "^(abstract final |final )?class [A-Za-z]*(Tokens|Colors|Palette)\b" lib --include='*.dart' \
  | grep -v '^lib/theme/' | while IFS= read -r l; do viol "second token registry: $l"; done

say "== 3 · no raw colors outside lib/theme"
n_hex=$(grep -rlE 'Color\(0x[0-9A-Fa-f]{8}\)' lib --include='*.dart' | grep -v '^lib/theme/' | wc -l | tr -d ' ')
n_mat=$(grep -rlE '(^|[^A-Za-z_])Colors\.(red|green|blue|amber|yellow|orange|purple|pink|teal|cyan|lime|indigo|deepOrange|deepPurple|lightBlue|lightGreen|brown)\b' lib --include='*.dart' | grep -v '^lib/theme/' | wc -l | tr -d ' ')
[ "$n_hex" = 0 ] || viol "$n_hex file(s) with Color(0x…) literals outside lib/theme (grep -rlE 'Color\\(0x' lib)"
[ "$n_mat" = 0 ] || viol "$n_mat file(s) using chromatic Material Colors.* outside lib/theme"

# Subshell scoping: re-derive fail for §2 (piped while runs in a subshell)
if grep -rqE "^(abstract final |final )?class [A-Za-z]*(Tokens|Colors|Palette)\b" lib --include='*.dart' --exclude-dir=theme 2>/dev/null; then fail=1; fi

if [ "$fail" = 1 ]; then
  [ "$mode" = "--warn" ] && { say "design-library-check: violations (warn mode)"; exit 0; }
  say "design-library-check: FAILED"; exit 1
fi
say "design-library-check: clean"
