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
#           ! scripts/query-ledger.sh zones-audit [dev|prod|all]  # COUNT-ONLY: per-provider
#             counts of activities rows carrying a zone split / if_planned / tss_planned
#             (Q-INT29 blast radius). No row payloads, no ids, no names — integers only.
#           ! scripts/query-ledger.sh retention [dev|prod|all]  # size-audit + liveness:
#             raw_retention_audit newest rows (sizes, counts, alerts, sweep freshness vs the
#             48h dead-man threshold) + expected_flows arming state. Aggregates only —
#             the audit table carries no per-athlete data by design (L-7 item 4).
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
if [ "${1:-}" = "zones-audit" ]; then MODE="zones-audit"; shift; fi
if [ "${1:-}" = "tp-probe" ]; then MODE="tp-probe"; shift; fi
if [ "${1:-}" = "retention" ]; then MODE="retention"; shift; fi
if [ "${1:-}" = "fs-echo" ]; then MODE="fs-echo"; shift; fi
if [ "${1:-}" = "day-audit" ]; then MODE="day-audit"; DAY="${2:-}"; shift 2; fi
if [ "${1:-}" = "payload-detail" ]; then MODE="payload-detail"; DAY="${2:-}"; shift 2; fi
ENVSEL="${1:-all}"
LIMIT="${2:-1000}"

python3 - "$SECRETS" "$ENVSEL" "$LIMIT" "$MODE" "${DAY:-}" <<'PY'
import re, json, sys, urllib.request
secrets, envsel, limit, mode = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
DAY = sys.argv[5] if len(sys.argv) > 5 else ""
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
    if mode == "payload-detail":
        # Field-level audit of BOTH providers for one date: prints key names and NON-TEXT values
        # (numbers, booleans, times). Free-text fields are shown as <text> — never their content.
        base=f"https://{ref}.supabase.co/rest/v1"; hdr={"apikey":key,"Authorization":"Bearer "+key}
        TEXTY=("title","name","description","comment","note","url","key","id")
        def show(d, tag):
            out=[]
            for k,v in sorted(d.items()):
                if v is None: continue
                if isinstance(v,(dict,list)): out.append(f"{k}=<{type(v).__name__}:{len(v)}>"); continue
                if isinstance(v,str) and any(t in k.lower() for t in TEXTY): out.append(f"{k}=<text>"); continue
                out.append(f"{k}={v}")
            print(f"   [{tag}] {' '.join(out)[:1000]}")
        try:
            fs=json.loads(urllib.request.urlopen(urllib.request.Request(
                base+f"/provider_raw_payloads?select=data,fetched_at&provider=eq.final_surge&order=fetched_at.desc&limit=60",headers=hdr),timeout=30).read())
        except Exception as e:
            fs=[]; print(f"  FS unreadable: {str(e)[:80]}")
        print(f"== {label} — FINAL SURGE payloads mentioning {DAY} ==")
        for r in fs:
            d=r.get("data") or {}
            if DAY in json.dumps(d): show(d, f"fetched {str(r.get('fetched_at'))[5:16]}")
        try:
            g=json.loads(urllib.request.urlopen(urllib.request.Request(
                base+f"/garmin_health_data?select=data,created_at&data_type=eq.activity_raw&created_at=gte.{DAY}&order=created_at.desc&limit=12",headers=hdr),timeout=30).read())
        except Exception as e:
            g=[]; print(f"  Garmin unreadable: {str(e)[:80]}")
        print(f"== {label} — GARMIN activity_raw created {DAY}+ ==")
        for r in g:
            d=r.get("data") or {}
            show({k:v for k,v in d.items() if k in ("activityType","durationInSeconds","activeKilocalories","startTimeInSeconds","startTimeOffsetInSeconds","summaryId","averageHeartRateInBeatsPerMinute","isParent","manual")}, f"created {str(r.get('created_at'))[5:16]}")
        continue
    if mode == "day-audit":
        # One day's activities, field audit only (no titles, no ids, no user_ids): provenance,
        # status, planned-vs-actual pair, provider-key presence. For adjudicating duplicate cards.
        base=f"https://{ref}.supabase.co/rest/v1"; hdr={"apikey":key,"Authorization":"Bearer "+key}
        # ACCOUNT DISCRIMINATOR (added 2026-09-21 after a false positive): rows are printed with
        # a short stable HASH of user_id — never the id itself. Without it, one workout held by
        # three test accounts reads as one account importing it three times, which is exactly the
        # wrong conclusion this arm produced on first use.
        import hashlib
        sel=("select=user_id,activity_type,status,synced_from_provider,provider_workout_id,garmin_summary_id,"
             "duration_minutes,actual_duration_minutes,distance_miles,planned_time,actual_time,"
             "scheduled_date_time,created_at,workout_subtype")
        url=f"{base}/activities?{sel}&scheduled_date_time=gte.{DAY}T00:00&scheduled_date_time=lt.{DAY}T23:59&order=created_at"
        try:
            rows=json.loads(urllib.request.urlopen(urllib.request.Request(url,headers=hdr),timeout=30).read())
        except Exception as e:
            print(f"{label}: ERROR {str(e)[:100]}"); continue
        import hashlib as _h
        naccts = len({str(r.get('user_id')) for r in rows})
        print(f"== {label} — activities scheduled {DAY} ({len(rows)} rows across {naccts} account(s)) ==")
        for r in rows:
            acct = hashlib.sha256(str(r.get('user_id')).encode()).hexdigest()[:4]
            print(f"   acct:{acct} {str(r['activity_type'])[:10]:10s} status={str(r['status'])[:9]:9s} src={str(r['synced_from_provider'])[:12]:12s} "
                  f"pkey={'Y' if r.get('provider_workout_id') else 'n'} gsid={'Y' if r.get('garmin_summary_id') else 'n'} "
                  f"dur={str(r['duration_minutes'])[:6]:6s} actual={str(r['actual_duration_minutes'])[:6]:6s} "
                  f"mi={str(r['distance_miles'])[:7]:7s} planned_t={str(r['planned_time'])[11:16] if r.get('planned_time') else '--':5s} "
                  f"actual_t={str(r['actual_time'])[11:16] if r.get('actual_time') else '--':5s} created={str(r['created_at'])[5:16]}")
        continue
    if mode == "fs-echo":
        # FS completion-echo audit (2026-09-21). Reads provider_raw_payloads FS rows and prints
        # a FIELD AUDIT ONLY: sport, date, completion flag, presence of actuals, and whether the
        # provider key is already known to `activities`. NEVER prints titles, keys, ids or names.
        base = f"https://{ref}.supabase.co/rest/v1"; hdr = {"apikey": key, "Authorization": "Bearer " + key}
        try:
            req = urllib.request.Request(base + "/provider_raw_payloads?select=provider_workout_id,fetched_at,data&provider=eq.final_surge&order=fetched_at.desc&limit=40", headers=hdr)
            rows = json.loads(urllib.request.urlopen(req, timeout=30).read())
        except Exception as e:
            print(f"{label}: not readable ({str(e)[:90]})"); continue
        print(f"== {label} — FS raw payloads: completion-echo audit ({len(rows)} rows) ==")
        comp = 0
        for r in rows:
            d = r.get("data") or {}
            wc = d.get("WorkoutCompleted")
            has_at = d.get("ActualTime") is not None
            has_ad = d.get("ActualDistanceMeters") is not None
            if wc is True or has_at or has_ad: comp += 1
            pk = r.get("provider_workout_id")
            known = "?"
            try:
                kreq = urllib.request.Request(base + f"/activities?select=status,synced_from_provider&provider_workout_id=eq.{pk}&limit=1", headers=hdr)
                krows = json.loads(urllib.request.urlopen(kreq, timeout=20).read())
                known = (krows[0].get("status") if krows else "NO-ROW")
            except Exception: pass
            print(f"   {str(d.get('WorkoutTypeName'))[:16]:16s} date={str(d.get('WorkoutDate'))[:10]:10s} "
                  f"completed={str(wc):5s} ActualTime={'Y' if has_at else 'n'} ActualDist={'Y' if has_ad else 'n'} "
                  f"planned_secs={str(d.get('PlannedTime'))[:6]:6s} -> our row: {known}")
        print(f"   SUMMARY: {comp}/{len(rows)} FS payloads carry a completion signal")
        continue
    if mode == "retention":
        # L-7 item 4 read side (RULED 2026-09-20): size-audit + liveness. Aggregates only.
        import datetime
        base = f"https://{ref}.supabase.co/rest/v1"
        hdr = {"apikey": key, "Authorization": "Bearer " + key}
        print(f"== {label} — raw_retention_audit (newest 5) ==")
        try:
            req = urllib.request.Request(base + "/raw_retention_audit?select=swept_at,purged,row_counts,raw_total_bytes,db_total_bytes,oversize_alert,underarrival_alerts&order=swept_at.desc&limit=5", headers=hdr)
            rows = json.loads(urllib.request.urlopen(req, timeout=30).read())
        except Exception as e:
            print(f"  not readable ({str(e)[:90]}) — sweep migration not deployed here?"); continue
        if not rows:
            print("  NO AUDIT ROWS — sweep has never run here (dead-man condition if deployed)")
        else:
            newest = rows[0]["swept_at"]
            try:
                age_h = (datetime.datetime.now(datetime.timezone.utc)
                         - datetime.datetime.fromisoformat(newest.replace("Z", "+00:00"))).total_seconds() / 3600
                flag = "OK" if age_h <= 48 else "STALE — DEAD-MAN THRESHOLD EXCEEDED"
                print(f"  liveness: newest sweep {age_h:.1f}h ago [{flag}]")
            except Exception:
                print(f"  liveness: newest sweep at {newest}")
            for r in rows:
                al = []
                if r.get("oversize_alert"): al.append("OVERSIZE")
                ua = r.get("underarrival_alerts") or []
                if ua: al.append("UNDER-ARRIVAL:" + ",".join(ua))
                print(f"  {r['swept_at']}  raw={int(r.get('raw_total_bytes') or 0)//1024}KB "
                      f"db={int(r.get('db_total_bytes') or 0)//1048576}MB counts={r.get('row_counts')} "
                      f"purged={r.get('purged')} alerts={al or 'none'}")
        print(f"== {label} — expected_flows arming ==")
        try:
            req = urllib.request.Request(base + "/expected_flows?select=flow,precondition,min_rows,window_interval,armed_at&order=flow", headers=hdr)
            fl = json.loads(urllib.request.urlopen(req, timeout=30).read())
            if not fl:
                print("  no flows seeded (W8: seeding is the LAST deploy step)")
            for f in fl:
                print(f"  {f['flow']:32s} armed={'yes ' + str(f['armed_at'])[:10] if f.get('armed_at') else 'NO (never alerts)'} "
                      f"min={f.get('min_rows')}/{f.get('window_interval')} pre={f.get('precondition')}")
        except Exception as e:
            print(f"  expected_flows not readable ({str(e)[:80]})")
        continue
    if mode == "tp-probe":
        # Q-INT29 producer probe: the two 'QA zone probe' structured workouts built in TP's own
        # builder on 2026-09-17. Fetches the row, then prints only a whitelist of non-identifying
        # fields (never user_id, device ids, tokens) so the shape can be read without identities.
        SHOW = ["title", "activity_type", "status", "synced_from_provider", "provider_workout_id",
                "scheduled_date_time", "planned_time", "actual_time", "duration_minutes",
                "actual_duration_minutes", "distance_miles", "distance_meters",
                "actual_distance_miles", "intensity_level", "intensity_z1_z2_pct",
                "intensity_z3_z4_pct", "intensity_z5_pct", "tss", "tss_planned", "tss_actual",
                "if_planned", "if_actual", "workout_subtype", "pace_target_minutes_per_mile",
                "calories_burned", "notes", "created_at", "updated_at"]
        url = (f"https://{ref}.supabase.co/rest/v1/activities?select=*"
               f"&title=ilike.*QA%20zone%20probe*&order=created_at.desc&limit=10")
        req = urllib.request.Request(url, headers={"apikey": key, "Authorization": "Bearer " + key})
        try:
            rows = json.loads(urllib.request.urlopen(req, timeout=30).read())
        except Exception as e:
            print(f"{label}: ERROR {str(e)[:200]}"); continue
        print(f"== {label} — 'QA zone probe' rows: {len(rows)} ==")
        for r in rows:
            print("  ---")
            for k in SHOW:
                if k in r:
                    print(f"  {k:32s} {r[k]}")
            extra = [k for k, v in r.items() if k not in SHOW and v not in (None, "", [], {})
                     and k not in ("id", "user_id", "created_by", "device_id")]
            print(f"  (other non-null columns: {', '.join(sorted(extra))})")
        continue
    if mode == "zones-audit":
        # COUNT-ONLY probe for Q-INT29 / DI-17: how many activities rows actually carry a
        # persisted zone split, and how many carry the captured load metrics. Uses HEAD +
        # Prefer: count=exact — no rows, no ids, no names ever leave the API.
        def count(q):
            url = f"https://{ref}.supabase.co/rest/v1/activities?{q}&limit=1"
            req = urllib.request.Request(url, headers={
                "apikey": key, "Authorization": "Bearer " + key,
                "Prefer": "count=exact", "Range-Unit": "items", "Range": "0-0"})
            try:
                with urllib.request.urlopen(req, timeout=30) as r:
                    cr = r.headers.get("Content-Range", "")
                return int(cr.split("/")[-1]) if "/" in cr else -1
            except Exception as e:
                print(f"  ERROR {str(e)[:100]}"); return -1
        print(f"== {label} — activities: zone split / load-metric capture (counts only) ==")
        providers = ["training_peaks", "final_surge", "garmin", "runna", "vdot_o2"]
        base = "select=id"
        print(f"  all rows: {count(base)}   "
              f"zones non-null: {count(base + '&intensity_z1_z2_pct=not.is.null')}   "
              f"if_planned non-null: {count(base + '&if_planned=not.is.null')}   "
              f"tss_planned non-null: {count(base + '&tss_planned=not.is.null')}   "
              f"if_actual non-null: {count(base + '&if_actual=not.is.null')}   "
              f"tss_actual non-null: {count(base + '&tss_actual=not.is.null')}")
        for prov in providers:
            f = f"{base}&synced_from_provider=eq.{prov}"
            n = count(f)
            if n == 0: 
                print(f"  {prov:15s} rows=0")
                continue
            print(f"  {prov:15s} rows={n:5d}  zones={count(f + '&intensity_z1_z2_pct=not.is.null'):5d}  "
                  f"if_planned={count(f + '&if_planned=not.is.null'):5d}  "
                  f"tss_planned={count(f + '&tss_planned=not.is.null'):5d}  "
                  f"if_actual={count(f + '&if_actual=not.is.null'):5d}  "
                  f"tss_actual={count(f + '&tss_actual=not.is.null'):5d}")
        # Recency split: distinguish "no provider syncs since the capture migration" from
        # "the capture columns are never written". Cutoff = the Stage A capture deploy.
        for prov in ["training_peaks", "final_surge"]:
            f = f"{base}&synced_from_provider=eq.{prov}&created_at=gte.2026-09-12"
            n = count(f)
            print(f"  since 2026-09-12  {prov:15s} rows={n:5d}  "
                  f"if_planned={count(f + '&if_planned=not.is.null'):5d}  "
                  f"tss_planned={count(f + '&tss_planned=not.is.null'):5d}  "
                  f"zones={count(f + '&intensity_z1_z2_pct=not.is.null'):5d}")
        manual = f"{base}&synced_from_provider=is.null"
        print(f"  {'manual/none':15s} rows={count(manual):5d}  zones={count(manual + '&intensity_z1_z2_pct=not.is.null'):5d}")
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
        # TP tier-flag census (2026-09-18): provider_is_premium is captured at CONNECT and
        # PROVEN UNRELIABLE (a premium-featured trial reads IsPremium=false on the wire), so
        # true = lower bound of load-exposed athletes, never the population. Counts only.
        print("training_peaks provider_is_premium (connect-time flag; true = LOWER BOUND):")
        for label, filt in (("true ", "eq.true"), ("false", "eq.false"), ("null ", "is.null")):
            c = count("integrations", f"provider=eq.training_peaks&provider_is_premium={filt}")
            print(f"   is_premium={label} {c:>4s}")
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
