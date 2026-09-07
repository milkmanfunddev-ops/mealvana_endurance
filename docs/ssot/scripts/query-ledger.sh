#!/usr/bin/env bash
#
# query-ledger.sh — pull `plan_generation_log` rows (targets vs delivered vs
# shortfalls) from the dev and/or prod Supabase projects into /tmp for analysis.
#
# ─── SECURITY MODEL ──────────────────────────────────────────────────────────
#   • Service-role keys live ONLY in $MV_ROOT/secrets/supabase_service_role_keys.md
#     (outside every git repo; chmod 600). This script reads them and sends them
#     straight to the Supabase REST API over HTTPS. Keys are never printed,
#     echoed, logged, or written anywhere else.
#   • Blast radius is deliberately narrow: READ-ONLY, one fixed table
#     (plan_generation_log), a fixed column list that EXCLUDES device_id
#     (rates, not identities). Widening any of that requires editing this
#     script — visible in git review.
#
# ─── HOW TO RUN ──────────────────────────────────────────────────────────────
#   You:    ! scripts/query-ledger.sh [dev|prod|all] [limit]
#           ! scripts/query-ledger.sh catalog [dev|prod|all]   # template_foods +
#             pre_workout_templates snapshots -> /tmp/catalog_<table>_<env>.json
#           ! scripts/query-ledger.sh funnel [dev|prod|all]    # face-resolution funnel
#             (generation-path shares) from plan_generation_log
#   Claude: needs a permission rule → Bash(scripts/query-ledger.sh:*)
#           (the auto-mode classifier blocks unauthorized secrets reads by default.)
#
#   Output: /tmp/plan_ledger_<env>.json ; stdout shows row counts only.
#
set -euo pipefail

find_workspace() { local d="$1"; while [ "$d" != "/" ]; do
  [ -f "$d/workspace.env" ] && { echo "$d"; return; }; d="$(dirname "$d")"; done; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MV_ROOT="$(find_workspace "$SCRIPT_DIR")"
[ -n "$MV_ROOT" ] || { echo "✗ workspace.env not found above $SCRIPT_DIR"; exit 1; }

SECRETS="$MV_ROOT/secrets/supabase_service_role_keys.md"
[ -f "$SECRETS" ] || { echo "✗ secrets file missing: $SECRETS"; exit 1; }

MODE="ledger"
if [ "${1:-}" = "catalog" ]; then MODE="catalog"; shift; fi
if [ "${1:-}" = "funnel" ]; then MODE="funnel"; shift; fi
ENVSEL="${1:-all}"
LIMIT="${2:-1000}"

python3 - "$SECRETS" "$ENVSEL" "$LIMIT" "$MODE" <<'PY'
import re, json, sys, urllib.request
secrets, envsel, limit, mode = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
text = open(secrets).read()
sections = re.findall(r'##\s*(\w+)\s*[—-]+\s*([a-z0-9]{15,25})\s*\n+\s*(\S{30,})', text)
if not sections:
    sys.exit("✗ no '## <env> — <project-ref>' + key sections found in secrets file")
# Fixed, privacy-trimmed select: no device_id.
sel = ("select=created_at,activity_type,duration_minutes,gut_training_level,"
       f"during_path,targets,delivered,shortfalls,warnings&order=created_at.desc&limit={limit}")
CATALOG_QUERIES = {
    # read-only catalog snapshots; no user data in these tables at all
    "template_foods": "select=*&order=name&limit=500",
    "pre_workout_templates": "select=*&order=name&limit=200",
}
for label, ref, key in sections:
    if envsel != "all" and label != envsel:
        continue
    if mode == "funnel":
        url = f"https://{ref}.supabase.co/rest/v1/plan_generation_log?select=during_path,pin_decision,created_at&order=created_at.desc&limit={limit}"
        req = urllib.request.Request(url, headers={"apikey": key, "Authorization": "Bearer " + key})
        try:
            rows = json.loads(urllib.request.urlopen(req, timeout=30).read())
        except Exception as e:
            print(f"{label}: ERROR {str(e)[:160]}"); continue
        from collections import Counter
        def step(r):
            p = r.get("during_path"); pd = (r.get("pin_decision") or {}).get("during") or {}
            if p == "personal_formula": return "step1-personal-formula"
            if p == "template":
                return "step2-pinned-template" if pd.get("used_pin") and not pd.get("ephemeral") else "step3-default-template"
            if p in ("rule", "empty"): return "step4-" + p
            return {"brick": "brick", "swimming": "n/a-swim"}.get(p, p)
        c = Counter(step(r) for r in rows)
        n = len(rows) or 1
        print(f"{label} ({ref}) — during-phase funnel over {len(rows)} plans "
              f"({rows[-1]['created_at'][:10]} → {rows[0]['created_at'][:10]}):" if rows else f"{label}: 0 rows")
        for k, v in c.most_common():
            print(f"   {k:24s} {v:5d}  {100*v/n:5.1f}%")
        continue
    if mode == "catalog":
        for table, q in CATALOG_QUERIES.items():
            url = f"https://{ref}.supabase.co/rest/v1/{table}?{q}"
            req = urllib.request.Request(url, headers={"apikey": key, "Authorization": "Bearer " + key})
            try:
                data = urllib.request.urlopen(req, timeout=30).read()
            except Exception as e:
                print(f"{label} {table}: ERROR {str(e)[:160]}"); continue
            out = f"/tmp/catalog_{table}_{label}.json"
            open(out, "wb").write(data)
            try:
                d = json.loads(data)
                print(f"{label} {table}: {len(d) if isinstance(d, list) else d} rows -> {out}")
            except Exception:
                print(f"{label} {table}: non-JSON ({len(data)} bytes) -> {out}")
        continue
    url = f"https://{ref}.supabase.co/rest/v1/plan_generation_log?{sel}"
    req = urllib.request.Request(url, headers={"apikey": key, "Authorization": "Bearer " + key})
    try:
        data = urllib.request.urlopen(req, timeout=30).read()
    except Exception as e:
        print(f"{label} ({ref}): ERROR {str(e)[:160]}")
        continue
    out = f"/tmp/plan_ledger_{label}.json"
    open(out, "wb").write(data)
    try:
        d = json.loads(data)
        print(f"{label} ({ref}): {len(d) if isinstance(d, list) else d} rows -> {out}")
    except Exception:
        print(f"{label} ({ref}): non-JSON response ({len(data)} bytes) -> {out}")
PY
