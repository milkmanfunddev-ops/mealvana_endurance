#!/usr/bin/env bash
#
# tp-payload-probe.sh — ONE-SHOT: what does TrainingPeaks actually send us?
#
# Answers the Q-INT29 / DI-13c question that nothing in our stores can answer, because TP raw
# payloads are not retained (`training-peaks.md` TP-2): does the live
# `GET /v2/workouts/{start}/{end}` response carry `IFPlanned` / `TSSPlanned` / `Structure` for
# OUR (basic) athlete, and under which casing?
#
# ─── SECURITY MODEL ──────────────────────────────────────────────────────────
#   • Reads the prod service-role key from $MV_ROOT/secrets/supabase_service_role_keys.md
#     (same custody as query-ledger.sh) and the TP access token from the `integrations` row
#     ($ integrations is the sole token custodian, Q-INT8). **Neither secret is ever printed,
#     logged or written to disk** — the token is used in one Authorization header and dropped.
#   • READ-ONLY on both sides: one SELECT, one GET. No writes, no refresh, no deauthorize.
#   • Output is a FIELD AUDIT, not a payload dump: per workout it prints the key set, the
#     presence/casing of the load fields, and the Structure's unit strings. `AthleteId` is
#     redacted; titles are ours (the QA probe workouts).
#   • This is a probe, not infrastructure: it does not persist anything. Retaining payloads is
#     Q-INT1's corpus question (`intake/2026-09-14-real-payload-test-corpus.md`), deliberately
#     not pre-empted here.
#
# ─── HOW TO RUN ──────────────────────────────────────────────────────────────
#   You:    ! scripts/tp-payload-probe.sh [startDate] [endDate] [workoutId ...]
#           defaults: today, today+1; ids are fetched via /v2/workouts/id/{id} (returns Structure)
#   Claude: does NOT run this — the token read stays in your shell by design.
#
set -euo pipefail

find_workspace() { local d="$1"; while [ "$d" != "/" ]; do
  [ -f "$d/workspace.env" ] && { echo "$d"; return; }; d="$(dirname "$d")"; done; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MV_ROOT="$(find_workspace "$SCRIPT_DIR")"
[ -n "$MV_ROOT" ] || { echo "✗ workspace.env not found above $SCRIPT_DIR"; exit 1; }

SECRETS="$MV_ROOT/secrets/supabase_service_role_keys.md"
[ -f "$SECRETS" ] || { echo "✗ secrets file missing: $SECRETS"; exit 1; }

START="${1:-$(date +%F)}"
END="${2:-$(date -v+1d +%F 2>/dev/null || date -d '+1 day' +%F)}"

shift 2 2>/dev/null || true
python3 - "$SECRETS" "$START" "$END" "$@" <<'PY'
import re, sys, json, urllib.request, urllib.error

secrets, start, end = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(secrets).read()
sections = dict((l, (r, k)) for l, r, k in
                re.findall(r'##\s*(\w+)\s*[—-]+\s*([a-z0-9]{15,25})\s*\n+\s*(\S{30,})', text))
if 'prod' not in sections:
    sys.exit("✗ no '## prod — <ref>' section in the secrets file")
ref, key = sections['prod']

# 1 · ALL TP integration rows — tokens NEVER printed. Probe ids may be passed as $4..$n
url = (f"https://{ref}.supabase.co/rest/v1/integrations"
       f"?select=access_token,updated_at,last_sync_status,is_active,provider_athlete_id"
       f"&provider=eq.training_peaks&order=updated_at.desc&limit=10")
req = urllib.request.Request(url, headers={"apikey": key, "Authorization": "Bearer " + key})
rows = json.loads(urllib.request.urlopen(req, timeout=30).read())
if not rows:
    sys.exit("✗ no training_peaks rows in prod integrations")
print(f"training_peaks integration rows: {len(rows)}")
for i, row in enumerate(rows):
    print(f"  [{i}] updated_at={row.get('updated_at')} status={row.get('last_sync_status')} "
          f"active={row.get('is_active')} athlete={row.get('provider_athlete_id')} "
          f"token={'present' if row.get('access_token') else 'NULL'}")

LOAD_KEYS = ["IFPlanned", "IfPlanned", "ifPlanned", "IF", "TSSPlanned", "TssPlanned",
             "tssPlanned", "TssActual", "TSSActual", "IFActual", "IfActual"]
PROBE_IDS = sys.argv[4:]

def audit(w, indent="  "):
    if not isinstance(w, dict):
        return
    print(f"\n{indent}--- workout")
    print(f"{indent}Title            {w.get('Title')!r}")
    print(f"{indent}WorkoutType      {w.get('WorkoutType')!r}   Id {w.get('Id')!r}")
    print(f"{indent}TotalTimePlanned {w.get('TotalTimePlanned')!r}   DistancePlanned {w.get('DistancePlanned')!r}")
    present = {k: w[k] for k in LOAD_KEYS if k in w}
    print(f"{indent}LOAD FIELDS      {present if present else 'NONE OF THE 11 CASING VARIANTS PRESENT'}")
    keys = sorted(k for k in w if k != "AthleteId")
    print(f"{indent}key set ({len(keys)})   {', '.join(keys)}")
    s = w.get("Structure")
    if s is None:
        print(f"{indent}Structure        ABSENT")
        return
    if isinstance(s, str):
        try:
            s = json.loads(s)
        except Exception:
            print(f"{indent}Structure        unparseable string, first 120 chars: {str(s)[:120]!r}")
            return
    units = set()
    def walk(steps):
        for st in steps if isinstance(steps, list) else []:
            L, I = st.get("Length") or {}, st.get("IntensityTarget") or {}
            if L.get("Unit"): units.add(f"Length:{L['Unit']}")
            if I.get("Unit"): units.add(f"Intensity:{I['Unit']}")
            for f in ("Min", "Max", "Value"):
                if f in I: units.add(f"IntensityField:{f}")
            walk(st.get("Steps"))
    walk(s)
    print(f"{indent}Structure        PRESENT, {len(s) if isinstance(s, list) else '?'} top-level steps")
    print(f"{indent}unit strings     {', '.join(sorted(units)) or 'none found'}")
    print(f"{indent}raw (first 600)  {json.dumps(s)[:600]}")

def get(token, path):
    r = urllib.request.Request(path, headers={"Authorization": "Bearer " + token,
                                              "Accept": "application/json"})
    with urllib.request.urlopen(r, timeout=30) as resp:
        return json.loads(resp.read())

# 2 · per row: the list window, then each probe id by /v2/workouts/id/{id} (docs: returns Structure).
#      Probe ids are attempted even when the list call fails, and on every row — an access token is
#      scoped to ONE athlete, so 403 means "not this athlete's workout" and 401 means "expired".
for i, row in enumerate(rows):
    token = row.get("access_token")
    if not token:
        continue
    athlete = row.get("provider_athlete_id")
    print(f"\n=== row [{i}] athlete {athlete} ===")
    listed = False
    for base in ("https://api.trainingpeaks.com", "https://api.sandbox.trainingpeaks.com"):
        if not listed:
            try:
                payload = get(token, f"{base}/v2/workouts/{start}/{end}?includeDescription=true")
                print(f"  host {base}: HTTP 200, {len(payload)} workouts in {start}..{end}")
                for w in payload:
                    audit(w)
                listed = True
            except urllib.error.HTTPError as e:
                print(f"  host {base}: list HTTP {e.code} {e.reason}")
            except Exception as e:
                print(f"  host {base}: list ERROR {str(e)[:100]}")
        for pid in PROBE_IDS:
            try:
                one = get(token, f"{base}/v2/workouts/id/{pid}?includeDescription=true")
            except urllib.error.HTTPError as e:
                print(f"  probe id {pid} @ {base.split('//')[1]}: HTTP {e.code} {e.reason}"
                      f"{'  (wrong athlete)' if e.code == 403 else ''}")
                continue
            except Exception as e:
                print(f"  probe id {pid}: ERROR {str(e)[:100]}")
                continue
            print(f"\n  *** probe id {pid}: HTTP 200 on athlete {athlete} — BY-ID payload ***")
            audit(one if isinstance(one, dict) else (one[0] if one else {}), indent="    ")
            # STRUCTURE HUNT: the summary shapes carry no `Structure`. Try the documented
            # per-workout file export (`WorkoutFileFormats` lists json) and the plan endpoint,
            # to establish whether the structure is reachable by our OAuth app AT ALL.
            for label, path in (
                ("wod/file json", f"{base}/v2/workouts/wod/file/{pid}/?format=json"),
                ("wod/file mrc ", f"{base}/v2/workouts/wod/file/{pid}/?format=mrc"),
                ("plan          ", f"{base}/v2/workouts/plan/{pid}"),
            ):
                try:
                    body = get(token, path)
                except urllib.error.HTTPError as e:
                    print(f"    structure hunt {label}: HTTP {e.code} {e.reason}")
                    continue
                except Exception as e:
                    print(f"    structure hunt {label}: ERROR {str(e)[:90]}")
                    continue
                blob = json.dumps(body)
                hits = [k for k in ("Structure", "IntensityTarget", "IntensityClass", "Length",
                                    "RepeatCount", "PercentOfThresholdPace", "PercentOfFtp")
                        if k in blob]
                print(f"    structure hunt {label}: HTTP 200, {len(blob)} chars, "
                      f"structure markers: {hits or 'NONE'}")
                print(f"      first 500: {blob[:500]}")
        if listed:
            # PREMIUM SURFACE SWEEP (C2 context + C7 zones + C8 events + metrics scope check).
            # Runs once, on the first working token. Field-audit discipline: key sets, types
            # and array cardinality only — never scalar values. Two exceptions, both
            # tier/shape facts, not personal data: BOOLEAN/NUMERIC tier flags only
            # (IsPremium and friends). String-valued matches are redacted to
            # "<str present>" — a key like CoachName would otherwise print a person.
            def shape(o):
                if isinstance(o, dict):
                    return {k: shape(v) for k, v in sorted(o.items())}
                if isinstance(o, list):
                    return [f"<{len(o)} items>"] + ([shape(o[0])] if o else [])
                return "null" if o is None else type(o).__name__
            def sweep(label, path):
                try:
                    body = get(token, path)
                except urllib.error.HTTPError as e:
                    print(f"  sweep {label}: HTTP {e.code} {e.reason}"
                          f"{'  (scope refusal? token just worked on /v2/workouts)' if e.code == 401 else ''}")
                    return None
                except Exception as e:
                    print(f"  sweep {label}: ERROR {str(e)[:90]}")
                    return None
                print(f"  sweep {label}: HTTP 200 — shape (keys/types/cardinality, no values):")
                print(f"    {json.dumps(shape(body))[:1200]}")
                return body
            prof = sweep("athlete profile ", f"{base}/v1/athlete/profile")
            if isinstance(prof, dict):
                tier = {}
                for k, v in prof.items():
                    if 'premium' not in k.lower() and 'coach' not in k.lower():
                        continue
                    tier[k] = v if isinstance(v, (bool, int, float)) and not isinstance(v, str) \
                        else ("<null>" if v is None else "<str present>")
                print(f"    tier flags: {tier or 'no premium/coach keys present'}")
            sweep("athlete zones   ", f"{base}/v1/athlete/profile/zones")            # C7
            ev = sweep("events next     ", f"{base}/v2/events/next")                 # C8
            sweep("metrics window  ", f"{base}/v2/metrics/{start}/{end}")            # scope metrics:read
            # EVENTS-BY-DATE TYPE AUDIT (2026-09-18): /v2/events/next returned an OBJECT on
            # one athlete and a BARE STRING on another. The app's LIVE path reads
            # /v2/events/{date} and assumes a JSON list (`jsonDecode(body) as List`,
            # getEventsForDate) — never yet observed. Establish that endpoint's top-level
            # type for BOTH cases: a date that holds an event (derived in-script from the
            # /events/next body; the date itself is never printed) and a no-event control.
            ev_date = (ev.get("EventDate") or "")[:10] if isinstance(ev, dict) else None
            for label, d in (("event date   ", ev_date), ("no-event ctrl", end)):
                if not d:
                    print(f"  events/{{date}} {label}: skipped (no event on this athlete)")
                    continue
                try:
                    body = get(token, f"{base}/v2/events/{d}")
                except urllib.error.HTTPError as e:
                    print(f"  events/{{date}} {label}: HTTP {e.code} {e.reason}")
                    continue
                except Exception as e:
                    print(f"  events/{{date}} {label}: ERROR {str(e)[:90]}")
                    continue
                t = type(body).__name__
                extra = f", shape={json.dumps(shape(body))[:400]}" if isinstance(body, (dict, list)) else f", len={len(body)}" if isinstance(body, str) else ""
                print(f"  events/{{date}} {label}: HTTP 200, top-level JSON type={t}{extra}")
            break

PY
