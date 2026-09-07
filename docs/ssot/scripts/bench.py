import json, sys, time, urllib.request, os, datetime
from collections import Counter

MV_ROOT, QA_ROOT, ENV_SEL, LABEL = sys.argv[1:5]
envfile = f"{MV_ROOT}/app/.env.{'dev' if ENV_SEL=='dev' else 'prod'}.local"
cfg = {}
for line in open(envfile):
    if "=" in line and not line.strip().startswith("#"):
        k, v = line.split("=", 1); cfg[k.strip()] = v.strip().strip('"')
URL = cfg.get("SUPABASE_URL"); KEY = cfg.get("SUPABASE_ANON_KEY") or cfg.get("SUPABASE_CLIENT_KEY")
if not URL or not KEY: sys.exit("missing SUPABASE_URL / anon key in " + envfile)

def post(fn, body):
    req = urllib.request.Request(f"{URL}/functions/v1/{fn}",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "apikey": KEY,
                 "Authorization": "Bearer " + KEY, "x-mealvana-test": "bench"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())

def step_of(path, pin):
    pin = pin or {}
    if path == "personal_formula": return "step1-personal-formula"
    if path == "template":
        return "step2-pinned-template" if (pin.get("used_pin") and not pin.get("ephemeral")) else "step3-default-template"
    if path in ("rule", "empty", "greedy"): return "step4-" + path
    if path in ("swimming",): return "n-a-swim"
    return path or "unknown"

scen = json.load(open(f"{QA_ROOT}/bench/scenarios.json"))["scenarios"]
results, funnel = [], Counter()
for s in scen:
    dev_id = f"BENCH-{s['id']}"
    m = {"device_id": dev_id, "weight": s["weight_kg"], "weight_unit": "kg",
         "hours_before": s["hours_before"], "is_fasted": False,
         "activity_type": s["sport"], "gut_training": s.get("gut", "moderate"),
         "diet": s.get("diet") or "none", "allergies": s.get("allergies", []),
         "disliked_foods": s.get("disliked", []), "liked_foods": [],
         "temp_c": 20, "humidity_pct": 60}
    sp = s["sport"]
    if sp == "running":  m |= {"run_distance": s["distance_mi"], "run_pace": s["pace"], "run_distance_unit": "mi", "run_pace_unit": "min_per_mile"}
    elif sp == "cycling": m |= {"distance_miles": s["distance_mi"], "speed_mph": s["speed_mph"]}
    elif sp == "swimming": m |= {"distance_meters": s["distance_m"], "pace_per_100m_seconds": s["pace_100m"]}
    elif sp == "brick":   m |= {"brick_segments": s["segments"]}
    if "duration_min" in s: m["duration_minutes"] = s["duration_min"]
    row = {"id": s["id"], "label": s["label"], "sport": sp}
    try:
        mac = post("generate-macros-v4", m)
        macros = mac.get("macros") or {}
        def phase(prefix, keys):
            out = {}
            for wire, mac_key in keys.items():
                v = macros.get(mac_key)
                if v is not None: out[wire] = v
            return out or None
        mt = {}
        pre = phase("pre_run", {"carbs_g":"pre_run_carbs_g","carbs_low_g":"pre_run_carbs_low_g","carbs_high_g":"pre_run_carbs_high_g",
                    "protein_g":"pre_run_protein_g","protein_low_g":"pre_run_protein_low_g","protein_high_g":"pre_run_protein_high_g",
                    "fat_g":"pre_run_fat_g","sodium_mg":"pre_run_sodium_mg","water_ml":"pre_run_water_ml",
                    "water_low_ml":"pre_run_water_low_ml","water_high_ml":"pre_run_water_high_ml"})
        if pre is not None:
            pre.setdefault("water_ml", 0); mt["pre_run"] = pre
        dur = phase("during_run", {"carbs_g":"during_total_g",
                    "sodium_mg":"during_sodium_total_mg","sodium_low_mg":"during_sodium_low_mg","sodium_high_mg":"during_sodium_high_mg",
                    "water_ml":"during_water_total_ml","water_low_ml":"during_water_low_ml","water_high_ml":"during_water_high_ml"})
        if dur: mt["during_run"] = dur
        post_ = phase("post_run", {"carbs_g":"post_run_carbs_g","carbs_low_g":"post_run_carbs_low_g","carbs_high_g":"post_run_carbs_high_g",
                    "protein_g":"post_run_protein_g","protein_low_g":"post_run_protein_low_g","protein_high_g":"post_run_protein_high_g",
                    "sodium_mg":"post_run_sodium_mg","water_ml":"post_run_water_ml",
                    "water_low_ml":"post_run_water_low_ml","water_high_ml":"post_run_water_high_ml"})
        if not post_:
            post_ = phase("post_run", {"carbs_g":"post_carbs_g","protein_g":"post_protein_g","sodium_mg":"post_sodium_mg","water_ml":"post_water_ml"})
        if post_: mt["post_run"] = post_
        p = {"device_id": dev_id, "hours_before": s["hours_before"],
             "weight_kg": s["weight_kg"], "activity_type": sp,
             "duration_minutes": s.get("duration_min") or sum(x["duration_minutes"] for x in s.get("segments", [])),
             "gut_training_level": s.get("gut", "moderate"),
             "dietary_preference": s.get("diet"), "allergies": s.get("allergies", []),
             "disliked_foods": s.get("disliked", []), "liked_foods": [],
             "macro_targets": mt,
             "emit_ephemeral_default_formula": True,
             "pre_run_selections": macros.get("pre_run_selections")}
        if sp == "brick":
            ph = macros.get("phases") or {}
            p["brick_phases"] = ph
            p["brick_segments"] = [{"sport": seg.get("sport"), "duration_minutes": seg.get("duration_minutes"),
                "macro_targets": {k: seg[k] for k in ("carbs_g","carbs_low_g","carbs_high_g","sodium_mg",
                                  "sodium_low_mg","sodium_high_mg","water_ml","water_low_ml","water_high_ml")
                                  if k in seg}} for seg in (ph.get("during_segments") or [])]
            bt = {}
            if ph.get("before"): bt["pre_run"] = ph["before"]
            if ph.get("after"):  bt["post_run"] = ph["after"]
            segs = ph.get("during_segments") or []
            if segs:
                bt["during_run"] = {"carbs_g": sum(x.get("carbs_g",0) for x in segs),
                                    "sodium_mg": sum(x.get("sodium_mg",0) for x in segs),
                                    "water_ml": sum(x.get("water_ml",0) for x in segs)}
            if bt: p["macro_targets"] = bt
        plan = post("generate-nutrition-plan-v3", p)
        pl = plan.get("plan", {})
        during = pl.get("during", {}) or {}
        dpath = during.get("generation_path") or (during.get("template_metadata") and "template")
        dpin = (during.get("pin_decision") or {})
        st = step_of(dpath, dpin)
        row |= {"ok": True, "during_path": dpath, "during_step": st,
                "during_foods": [f.get("display_name") or f.get("food_id") for f in (during.get("foods") or [])],
                "before_slots": list((pl.get("before") or {}).keys()),
                "warnings": plan.get("warnings", [])[:3]}
        funnel[st] += 1
    except Exception as e:
        row |= {"ok": False, "error": str(e)[:200]}; funnel["error"] += 1
    results.append(row); print(f"  {s['id']} {s['label'][:40]:42s} {row.get('during_step', row.get('error',''))}")
    time.sleep(0.4)

# --- authoritative pass: generation_path lives ONLY in plan_generation_log, never on the wire ---
try:
    sec = f"{MV_ROOT}/secrets/supabase_service_role_keys.md"
    import re as _re
    txt = open(sec).read()
    sects = _re.findall(r'##\s*(\w+)\s*[\u2014-]+\s*([a-z0-9]{15,25})\s*\n+\s*(\S{30,})', txt)
    ref, skey = next((r, k) for l, r, k in sects if l == ENV_SEL)
    q = ("select=device_id,during_path,pin_decision,created_at&device_id=like.BENCH-*"
         "&order=created_at.desc&limit=200")
    rq = urllib.request.Request(f"https://{ref}.supabase.co/rest/v1/plan_generation_log?{q}",
                                headers={"apikey": skey, "Authorization": "Bearer " + skey})
    rows = json.loads(urllib.request.urlopen(rq, timeout=30).read())
    latest = {}
    for r in rows:
        latest.setdefault(r["device_id"], r)
    funnel = Counter()
    for row in results:
        led = latest.get(f"BENCH-{row['id']}")
        if led:
            st = step_of(led.get("during_path"), (led.get("pin_decision") or {}).get("during"))
            row["ledger_path"] = led.get("during_path"); row["during_step"] = st
        funnel[row.get("during_step", "unknown")] += 1
    print("\n(steps re-derived from plan_generation_log — the wire omits generation_path)")
except Exception as e:
    print("\n(ledger join unavailable: %s — wire-only steps shown)" % str(e)[:120])

stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M")
out = f"{QA_ROOT}/bench/results-{ENV_SEL}-{LABEL}-{stamp}.json"
json.dump({"env": ENV_SEL, "label": LABEL, "when": stamp, "funnel": dict(funnel), "results": results}, open(out, "w"), indent=2)
n = sum(v for k, v in funnel.items() if k != "error")
print(f"\nDURING-PHASE FUNNEL ({n} resolvable of {len(scen)}):")
for k, v in funnel.most_common():
    print(f"  {k:26s} {v:3d}  {100*v/max(1,n):5.1f}%")
print("→", out)
