#!/usr/bin/env bash
# corpus-weekly.sh — the standing weekly corpus heartbeat (Xuan, 2026-09-20: weekly,
# release-independent). Runs corpus-export against dev, LEAK-SWEEPS anything novel, and
# only if clean commits it to a dated review branch and pushes — NEVER to main, NEVER
# unswept. Novel-but-dirty refuses to commit and screams. Designed for cron; also safe
# to run by hand. Cadence is ops practice (runbook), not spec contract.
# Uses a dedicated worktree so the shared checkout is never touched.
# EXPECTED HALT, not a failure: when a NEW source material appears on dev (a second FS
# athlete, a new tester), its rows carry no provenance stamp and the export REFUSES
# fail-closed. A Monday failure notification therefore usually means "a provenance
# decision is waiting" (one line in corpus-export's SOURCE_MATERIAL once someone decides
# what the material is) — read it as a decision request, not a broken job.
set -euo pipefail
find_workspace() { local d="$1"; while [ "$d" != "/" ]; do
  [ -f "$d/workspace.env" ] && { echo "$d"; return; }; d="$(dirname "$d")"; done; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MV_ROOT="$(find_workspace "$SCRIPT_DIR")"
QA="$MV_ROOT/qa"; WT="$MV_ROOT/.qa-corpus-weekly"; LOG="$MV_ROOT/.qa-corpus-weekly.log"
BR="corpus/weekly-$(date +%F)"
note() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
notify() { osascript -e "display notification \"$2\" with title \"$1\"" 2>/dev/null || true; }
# token: sanctioned secrets path (chmod 600, outside git) — same custody as the supabase keys
if [ -z "${CORPUS_EXPORT_TOKEN:-}" ] && [ -f "$MV_ROOT/secrets/corpus_export_token" ]; then
  export CORPUS_EXPORT_TOKEN="$(cat "$MV_ROOT/secrets/corpus_export_token")"
fi
[ -n "${CORPUS_EXPORT_TOKEN:-}" ] || { note "token not provisioned ($MV_ROOT/secrets/corpus_export_token)"; notify "Corpus weekly" "export token not provisioned"; exit 1; }
git -C "$QA" fetch -q origin
[ -d "$WT" ] || git -C "$QA" worktree add "$WT" -B "$BR" origin/main >/dev/null
git -C "$WT" checkout -q -B "$BR" origin/main
( cd "$WT" && scripts/corpus-export.sh dev ) >>"$LOG" 2>&1 || { note "export FAILED"; notify "Corpus weekly" "export FAILED — see log"; exit 1; }
NEW=$(git -C "$WT" status --porcelain vectors/integrations/samples/ | wc -l | tr -d ' ')
if [ "$NEW" = "0" ]; then note "novel 0 — corpus converged this week"; exit 0; fi
python3 - "$WT" <<'PY' >>"$LOG" 2>&1 || { note "LEAK SCAN DIRTY on $NEW novel exemplar(s) — NOT committed"; notify "Corpus weekly" "DIRTY exemplar refused — review the log"; exit 1; }
import json,re,glob,sys
bad=[]
for p in glob.glob(sys.argv[1]+'/vectors/integrations/samples/*/*.json'):
    s=json.dumps(json.load(open(p)))
    if re.search(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',s,re.I) \
       or re.search(r'https?://(?!placeholder)',s) or re.search(r'[?&](user|athlete|workout|key)=',s) \
       or re.search(r'"(\w*(?:athlete|user|account)id)"\s*:\s*(?!null)[^,}]*[0-9]{5,}',s,re.I):
        bad.append(p)
assert not bad, bad
print("scan clean")
PY
git -C "$WT" add vectors/integrations/samples/ && git -C "$WT" commit -q -m "corpus: weekly export — $NEW novel exemplar(s), leak-swept clean (automated heartbeat)" && git -C "$WT" push -q -u origin "$BR"
note "$NEW novel exemplar(s) pushed on $BR for QA review"
notify "Corpus weekly" "$NEW new shape(s) on $BR — review & merge"
