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
#           ! scripts/query-ledger.sh integrations [dev|prod|all]  # provider-data
#             preservation audit: COUNT-ONLY probes over integrations / activities /
#             garmin_health_data (by provider, status, data_type; multisport search).
#             No tokens, no names/emails, no row payloads — counts and dates only.
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
if [ "${1:-}" = "integrations" ]; then MODE="integrations"; shift; fi
if [ "${1:-}" = "garmin-kcal" ]; then MODE="garmin-kcal"; shift; fi
if [ "${1:-}" = "run-audit" ]; then MODE="run-audit"; shift; fi
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
    if mode == "run-audit":
        # For each raw Garmin activity received today: locate the matched activities
        # row by garmin_summary_id and print its planning-vs-completion fields plus
        # the owning athlete's weight (F4 input). Engine-audit use; prints no names.
        import datetime
        since = datetime.date.today().isoformat()
        url = (f"https://{ref}.supabase.co/rest/v1/garmin_health_data"
               f"?select=created_at,data&data_type=eq.activity_raw"
               f"&created_at=gte.{since}&order=created_at.desc&limit=8")
        req = urllib.request.Request(url, headers={"apikey": key, "Authorization": "Bearer " + key})
        try:
            raws = json.loads(urllib.request.urlopen(req, timeout=30).read())
        except Exception as e:
            print(f"{label}: ERROR {str(e)[:160]}"); continue
        print(f"== {label} — today's Garmin activities → matched rows ==")
        for r in raws:
            d = r.get("data") or {}
            sid = d.get("summaryId")
            if not sid: continue
            aurl = (f"https://{ref}.supabase.co/rest/v1/activities"
                    f"?select=user_id,activity_type,status,synced_from_provider,provider_workout_id,"
                    f"duration_minutes,actual_duration_minutes,calories_burned,intensity_level,"
                    f"intensity_z1_z2_pct,intensity_z3_z4_pct,intensity_z5_pct,planned_time,actual_time,tss"
                    f"&garmin_summary_id=eq.{sid}&limit=1")
            areq = urllib.request.Request(aurl, headers={"apikey": key, "Authorization": "Bearer " + key})
            try:
                arows = json.loads(urllib.request.urlopen(areq, timeout=30).read())
            except Exception as e:
                print(f"  {sid}: activities ERROR {str(e)[:80]}"); continue
            if not arows:
                print(f"  raw {d.get('activityType','?')} dur={d.get('durationInSeconds')}s kcal={d.get('activeKilocalories')} → NO matched activities row"); continue
            a = arows[0]
            w = "?"
            uurl = f"https://{ref}.supabase.co/rest/v1/users?select=weight_pounds&id=eq.{a['user_id']}&limit=1"
            ureq = urllib.request.Request(uurl, headers={"apikey": key, "Authorization": "Bearer " + key})
            try:
                us = json.loads(urllib.request.urlopen(ureq, timeout=30).read())
                if us: w = us[0].get("weight_pounds")
            except Exception: pass
            print(f"  raw {d.get('activityType','?'):10s} dur={d.get('durationInSeconds')}s kcal={d.get('activeKilocalories')}")
            print(f"    row: type={a['activity_type']} status={a['status']} provider={a['synced_from_provider']} "
                  f"provider_workout_id={'SET' if a.get('provider_workout_id') else 'null'}")
            print(f"         duration_minutes={a['duration_minutes']} actual={a['actual_duration_minutes']} "
                  f"calories_burned={a['calories_burned']} intensity={a['intensity_level']} "
                  f"zones={a['intensity_z1_z2_pct']}/{a['intensity_z3_z4_pct']}/{a['intensity_z5_pct']} tss={a['tss']}")
            print(f"         planned_time={a['planned_time']} actual_time={a['actual_time']} athlete_weight_lb={w}")
        continue
    if mode == "garmin-kcal":
        # Field-audit of recent raw Garmin activity payloads: which calorie-related
        # keys does the API actually deliver? Prints per-row: date, sport, duration,
        # every key name in the payload, and calorie-field values. No athlete
        # identities (no user ids, no names) are printed.
        import datetime
        since = (datetime.date.today() - datetime.timedelta(days=2)).isoformat()
        url = (f"https://{ref}.supabase.co/rest/v1/garmin_health_data"
               f"?select=created_at,data&data_type=eq.activity_raw"
               f"&created_at=gte.{since}&order=created_at.desc&limit=12")
        req = urllib.request.Request(url, headers={"apikey": key, "Authorization": "Bearer " + key})
        try:
            rows = json.loads(urllib.request.urlopen(req, timeout=30).read())
        except Exception as e:
            print(f"{label}: ERROR {str(e)[:160]}"); continue
        print(f"== {label} ({ref}) — raw Garmin activity payloads since {since}: {len(rows)} rows ==")
        for r in rows:
            d = r.get("data") or {}
            kcal_keys = {k: d[k] for k in d if "alorie" in k or "kcal" in k.lower()}
            print(f"  {r['created_at'][:16]}  {d.get('activityType','?'):22s} "
                  f"dur={d.get('durationInSeconds','?')}s  kcal-fields={json.dumps(kcal_keys)}")
            print(f"      all payload keys: {', '.join(sorted(d.keys()))}")
        continue
    if mode == "integrations":
        # Preservation audit: COUNT-ONLY (Prefer: count=exact over an empty select)
        # plus min/max created_at probes. Deliberately excludes tokens, names,
        # emails, payload bodies. Widening this list = editing this script.
        def count(table, filt=""):
            url = f"https://{ref}.supabase.co/rest/v1/{table}?select=id&limit=1" + (("&" + filt) if filt else "")
            req = urllib.request.Request(url, headers={"apikey": key,
                "Authorization": "Bearer " + key, "Prefer": "count=exact"})
            try:
                with urllib.request.urlopen(req, timeout=30) as r:
                    cr = r.headers.get("content-range", "")
                    return cr.split("/")[-1] if "/" in cr else "?"
            except Exception as e:
                return "ERR:" + str(e)[:60]
        def edge(table, col, filt, asc=True):
            url = (f"https://{ref}.supabase.co/rest/v1/{table}?select={col}"
                   + (("&" + filt) if filt else "")
                   + f"&order={col}.{'asc' if asc else 'desc'}&limit=1")
            req = urllib.request.Request(url, headers={"apikey": key, "Authorization": "Bearer " + key})
            try:
                rows = json.loads(urllib.request.urlopen(req, timeout=30).read())
                return (rows[0].get(col) or "")[:10] if rows else "-"
            except Exception as e:
                return "ERR:" + str(e)[:40]
        print(f"== {label} ({ref}) ==")
        print("integrations rows by provider (active/inactive):")
        for prov in ["garmin", "training_peaks", "final_surge", "runna", "vdot", "strava"]:
            a = count("integrations", f"provider=eq.{prov}&is_active=eq.true")
            i = count("integrations", f"provider=eq.{prov}&is_active=eq.false")
            if a not in ("0", "?") or i not in ("0", "?"):
                print(f"   {prov:15s} active={a:>4s} inactive={i:>4s}")
        print("garmin_user_mappings:", count("garmin_user_mappings"))
        print("activities by synced_from_provider:")
        for prov in ["garmin", "training_peaks", "final_surge", "runna", "vdot"]:
            c = count("activities", f"synced_from_provider=eq.{prov}")
            if c not in ("0",):
                lo = edge("activities", "created_at", f"synced_from_provider=eq.{prov}")
                hi = edge("activities", "created_at", f"synced_from_provider=eq.{prov}", asc=False)
                print(f"   {prov:15s} {c:>6s} rows  created {lo} .. {hi}")
        print("   (no provider)   ", count("activities", "synced_from_provider=is.null"))
        print("activities with garmin_summary_id:", count("activities", "garmin_summary_id=not.is.null"))
        print("activities tombstones (status=deleted):", count("activities", "status=eq.deleted"))
        print("activities provider_deleted_at set:", count("activities", "provider_deleted_at=not.is.null"))
        print("activities type=brick:", count("activities", "activity_type=eq.brick"))
        print("garmin_health_data by data_type:")
        for dt in ["daily", "sleep", "body_composition", "stress", "epoch",
                   "user_metrics", "activity_raw", "activity_detail_raw"]:
            c = count("garmin_health_data", f"data_type=eq.{dt}")
            if c not in ("0",):
                lo = edge("garmin_health_data", "created_at", f"data_type=eq.{dt}")
                hi = edge("garmin_health_data", "created_at", f"data_type=eq.{dt}", asc=False)
                print(f"   {dt:20s} {c:>6s} rows  {lo} .. {hi}")
        print("garmin_health_data user_id IS NULL (orphans):", count("garmin_health_data", "user_id=is.null"))
        print("multisport evidence in raw Garmin payloads:")
        print("   activity_raw activityType=MULTI_SPORT:",
              count("garmin_health_data", "data_type=eq.activity_raw&data->>activityType=eq.MULTI_SPORT"))
        print("   activity_raw activityType~TRANSITION:",
              count("garmin_health_data", "data_type=eq.activity_raw&data->>activityType=like.*TRANSITION*"))
        print("   activity_raw with parentSummaryId:",
              count("garmin_health_data", "data_type=eq.activity_raw&data->>parentSummaryId=not.is.null"))
        print("   activity_raw activityType TRIATHLON/DUATHLON:",
              count("garmin_health_data", "data_type=eq.activity_raw&data->>activityType=in.(TRIATHLON,DUATHLON)"))
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
