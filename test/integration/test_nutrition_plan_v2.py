#!/usr/bin/env python3
"""
Integration tests for generate-nutrition-plan-v2 edge function.
Tests the full flow: generate-macros-v3 -> generate-nutrition-plan-v2
with various diets, allergies, and food preferences.

Uses only Python standard library (no pip install needed).
"""

import json
import sys
import urllib.request
import urllib.error
from dataclasses import dataclass, field
from typing import Optional

SUPABASE_URL = "https://vlmtsdzpnjnavdgytcmi.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZsbXRzZHpwbmpuYXZkZ3l0Y21pIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1OTg1Mjc5MCwiZXhwIjoyMDc1NDI4NzkwfQ.ugFmXxvIEYZPNMzIhPRB6x-MGbODfE1BXVdKyLpngO0"
HEADERS = {
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}


def http_post(url: str, payload: dict, timeout: int = 30) -> dict:
    """Make an HTTP POST request using urllib (stdlib)."""
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8")
            return json.loads(body)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        return {"error": f"HTTP {e.code}: {body[:500]}"}
    except urllib.error.URLError as e:
        return {"error": f"URL error: {e.reason}"}
    except Exception as e:
        return {"error": str(e)}


@dataclass
class TestResult:
    name: str
    passed: bool
    macros_ok: bool
    v2_ok: bool
    error: str = ""
    before_carbs_pct: float = 0
    before_fluids_pct: float = 0
    before_sodium_pct: float = 0
    sub_phases_found: list = field(default_factory=list)
    foods_by_phase: dict = field(default_factory=dict)
    template_coverage: str = ""
    warnings: list = field(default_factory=list)
    during_foods: list = field(default_factory=list)
    after_foods: list = field(default_factory=list)
    # Raw targets for reporting
    pre_carbs_target: float = 0
    pre_fluids_target: float = 0
    pre_sodium_target: float = 0


def call_macros_v3(payload: dict) -> Optional[dict]:
    """Call generate-macros-v3 and return the macros dict."""
    url = f"{SUPABASE_URL}/functions/v1/generate-macros-v3"
    data = http_post(url, payload)
    if data.get("error"):
        return None
    if not data.get("success"):
        return None
    return data.get("macros", {})


def call_v2(payload: dict) -> dict:
    """Call generate-nutrition-plan-v2 and return the full response."""
    url = f"{SUPABASE_URL}/functions/v1/generate-nutrition-plan-v2"
    return http_post(url, payload)


def run_test(
    name: str,
    macros_payload: dict,
    v2_extra: dict = None,
) -> TestResult:
    """Run a full integration test: macros-v3 -> v2."""
    result = TestResult(name=name, passed=False, macros_ok=False, v2_ok=False)

    # Step 1: Generate macros
    macros = call_macros_v3(macros_payload)
    if macros is None:
        result.error = "generate-macros-v3 failed"
        return result
    result.macros_ok = True

    # Extract flat macro values from macros-v3 response
    pre_carbs = macros.get("pre_run_carbs_g", 0)
    pre_protein = macros.get("pre_run_protein_g", 0)
    pre_fat = macros.get("pre_run_fat_g", 0)
    pre_sodium = macros.get("pre_run_sodium_mg", 0)
    pre_fluids = macros.get("pre_run_water_ml", 0)
    during_carbs = macros.get("during_total_g", 0)
    during_sodium = macros.get("during_sodium_total_mg", 0)
    during_fluids = macros.get("during_water_total_ml", 0)
    post_carbs = macros.get("post_run_carbs_g", 0)
    post_protein = macros.get("post_run_protein_g", 0)
    post_sodium = macros.get("post_run_sodium_mg", 0) if "post_run_sodium_mg" in macros else 0
    post_fluids = macros.get("post_run_water_ml", 0)

    result.pre_carbs_target = pre_carbs
    result.pre_fluids_target = pre_fluids
    result.pre_sodium_target = pre_sodium

    hours_before = macros_payload.get("hours_before", 2.0)
    weight_kg = macros_payload.get("weight", 70)
    if macros_payload.get("weight_unit") == "lb":
        weight_kg = round(weight_kg * 0.453592, 1)

    # Step 2: Build v2 payload
    v2_payload = {
        "device_id": f"integration-test-{name[:20]}",
        "activity_type": "running",
        "hours_before": hours_before,
        "weight_kg": weight_kg,
        "macro_targets": {
            "pre_run": {
                "carbs_g": pre_carbs,
                "protein_g": pre_protein,
                "fat_g": pre_fat,
                "sodium_mg": pre_sodium,
                "water_ml": pre_fluids,
            },
            "during_run": {
                "carbs_g": during_carbs,
                "sodium_mg": during_sodium,
                "water_ml": during_fluids,
            },
            "post_run": {
                "carbs_g": post_carbs,
                "protein_g": post_protein,
                "sodium_mg": post_sodium,
                "water_ml": post_fluids,
            },
        },
    }
    if v2_extra:
        v2_payload.update(v2_extra)

    # Step 3: Call v2
    v2_resp = call_v2(v2_payload)
    if v2_resp.get("error"):
        result.error = f"v2 failed: {v2_resp['error']}"
        return result
    if not v2_resp.get("success"):
        result.error = f"v2 success=false: {v2_resp.get('error', json.dumps(v2_resp)[:200])}"
        return result
    result.v2_ok = True

    plan = v2_resp.get("plan", {})
    before = plan.get("before", {})

    # Analyze before sub-phases (they are direct keys: meal, snack, top_up)
    sub_phase_keys = ["meal", "snack", "top_up"]
    total_carbs = 0
    total_fluids = 0
    total_sodium = 0
    total_protein = 0

    for sp_key in sub_phase_keys:
        sp_data = before.get(sp_key)
        if sp_data is None:
            continue
        result.sub_phases_found.append(sp_key)

        foods = sp_data.get("foods", [])
        targets = sp_data.get("targets", {})
        template_name = sp_data.get("template_name", "none")
        drink = sp_data.get("drink")

        # Sum food macros
        sp_carbs = sum(f.get("carbs_grams", 0) or 0 for f in foods)
        sp_fluids = sum(f.get("fluids_ml", 0) or 0 for f in foods)
        sp_sodium = sum(f.get("sodium_mg", 0) or 0 for f in foods)
        sp_protein = sum(f.get("protein_grams", 0) or 0 for f in foods)

        # Add drink contributions
        if drink:
            sp_carbs += drink.get("carbs_grams", 0) or 0
            sp_fluids += drink.get("fluids_ml", 0) or 0
            sp_sodium += drink.get("sodium_mg", 0) or 0
            sp_protein += drink.get("protein_grams", 0) or 0

        total_carbs += sp_carbs
        total_fluids += sp_fluids
        total_sodium += sp_sodium
        total_protein += sp_protein

        food_names = [f.get("display_name") or f.get("name", "?") for f in foods]
        drink_name = (drink.get("display_name") or drink.get("name", "none")) if drink else "none"
        scale = sp_data.get("scale_multiplier", "?")

        t_carbs = targets.get("carbs_g", 0)
        t_fluids = targets.get("water_ml", 0)
        t_sodium = targets.get("sodium_mg", 0)
        pct = round(sp_carbs / t_carbs * 100) if t_carbs > 0 else 0
        fluids_pct = round(sp_fluids / t_fluids * 100) if t_fluids > 0 else 0

        result.foods_by_phase[sp_key] = {
            "template": template_name,
            "foods": food_names,
            "drink": drink_name,
            "carbs": sp_carbs,
            "carbs_target": t_carbs,
            "carbs_pct": pct,
            "fluids": sp_fluids,
            "fluids_target": t_fluids,
            "fluids_pct": fluids_pct,
            "sodium": sp_sodium,
            "sodium_target": t_sodium,
            "protein": sp_protein,
            "scale": scale,
        }

    # Calculate overall before accuracy
    if pre_carbs > 0:
        result.before_carbs_pct = round(total_carbs / pre_carbs * 100)
    if pre_fluids > 0:
        result.before_fluids_pct = round(total_fluids / pre_fluids * 100)
    if pre_sodium > 0:
        result.before_sodium_pct = round(total_sodium / pre_sodium * 100)

    # Check expected sub-phases based on hours_before
    expected = []
    if hours_before >= 2.5:
        expected = ["meal", "snack", "top_up"]
    elif hours_before >= 1.0:
        expected = ["snack", "top_up"]
    else:
        expected = ["top_up"]

    if set(result.sub_phases_found) != set(expected):
        result.warnings.append(
            f"Expected sub-phases {expected} but got {result.sub_phases_found}"
        )

    # Check carb accuracy (want 70-130% range)
    if result.before_carbs_pct < 50:
        result.warnings.append(f"Carbs VERY LOW: {result.before_carbs_pct}% of target ({total_carbs:.0f}g / {pre_carbs:.0f}g)")
    elif result.before_carbs_pct < 70:
        result.warnings.append(f"Carbs LOW: {result.before_carbs_pct}% of target ({total_carbs:.0f}g / {pre_carbs:.0f}g)")
    elif result.before_carbs_pct > 150:
        result.warnings.append(f"Carbs VERY HIGH: {result.before_carbs_pct}% of target ({total_carbs:.0f}g / {pre_carbs:.0f}g)")
    elif result.before_carbs_pct > 130:
        result.warnings.append(f"Carbs HIGH: {result.before_carbs_pct}% of target ({total_carbs:.0f}g / {pre_carbs:.0f}g)")

    # Check fluids accuracy
    if result.before_fluids_pct < 50:
        result.warnings.append(f"Fluids VERY LOW: {result.before_fluids_pct}% of target ({total_fluids:.0f}ml / {pre_fluids:.0f}ml)")
    elif result.before_fluids_pct > 150:
        result.warnings.append(f"Fluids VERY HIGH: {result.before_fluids_pct}% of target ({total_fluids:.0f}ml / {pre_fluids:.0f}ml)")

    # Check during/after phases
    during = plan.get("during", [])
    after_plan = plan.get("after", [])
    result.during_foods = [f.get("display_name") or f.get("name", "?") for f in during] if isinstance(during, list) else []
    result.after_foods = [f.get("display_name") or f.get("name", "?") for f in after_plan] if isinstance(after_plan, list) else []

    if not during and during_carbs > 10:
        result.warnings.append(f"During phase empty but target carbs = {during_carbs}g")
    if not after_plan and post_carbs > 10:
        result.warnings.append(f"After phase empty but target carbs = {post_carbs}g")

    result.passed = True
    return result


def print_result(r: TestResult, verbose: bool = True):
    status = "\033[92mPASS\033[0m" if r.passed else "\033[91mFAIL\033[0m"
    plain_status = "PASS" if r.passed else "FAIL"
    print(f"\n{'='*75}")
    print(f"[{status}] {r.name}")
    print(f"{'='*75}")

    if not r.macros_ok:
        print(f"  ERROR: {r.error}")
        return

    print(f"  Macro targets -> Carbs: {r.pre_carbs_target:.0f}g | Fluids: {r.pre_fluids_target:.0f}ml | Sodium: {r.pre_sodium_target:.0f}mg")

    if not r.v2_ok:
        print(f"  Macros OK, but V2 failed: {r.error}")
        return

    print(f"  Sub-phases found: {r.sub_phases_found}")

    if verbose:
        for sp, data in r.foods_by_phase.items():
            print(f"\n  [{sp.upper()}] Template: {data['template']} (scale: {data['scale']})")
            print(f"    Foods: {', '.join(data['foods'])}")
            print(f"    Drink: {data['drink']}")
            print(f"    Carbs:  {data['carbs']:6.1f}g / {data['carbs_target']:6.1f}g target ({data['carbs_pct']}%)")
            print(f"    Fluids: {data['fluids']:6.0f}ml / {data['fluids_target']:6.0f}ml target ({data['fluids_pct']}%)")
            print(f"    Sodium: {data['sodium']:6.0f}mg | Protein: {data['protein']:.0f}g")

    print(f"\n  OVERALL BEFORE ACCURACY:")
    carbs_ok = "OK" if 70 <= r.before_carbs_pct <= 130 else "!!!"
    fluids_ok = "OK" if 50 <= r.before_fluids_pct <= 150 else "!!!"
    sodium_ok = "OK" if 30 <= r.before_sodium_pct <= 200 else "!!!"
    print(f"    Carbs:  {r.before_carbs_pct:3d}% [{carbs_ok}]")
    print(f"    Fluids: {r.before_fluids_pct:3d}% [{fluids_ok}]")
    print(f"    Sodium: {r.before_sodium_pct:3d}% [{sodium_ok}]")

    if r.during_foods:
        print(f"\n  During phase: {', '.join(r.during_foods[:5])}")
    if r.after_foods:
        print(f"  After phase:  {', '.join(r.after_foods[:5])}")

    if r.warnings:
        print(f"\n  \033[93mWARNINGS:\033[0m")
        for w in r.warnings:
            print(f"    - {w}")


# ===================================================================
# TEST DEFINITIONS
# ===================================================================

TESTS = [
    # (name, macros_payload, v2_extra)
    (
        "1. Standard 10mi runner, 3h before, omnivore",
        {"weight": 70, "weight_unit": "kg", "age": 30, "gender": "male",
         "hours_before": 3.0, "is_fasted": False,
         "activity_type": "running", "run_distance": 10, "run_distance_unit": "mi",
         "run_pace": "8:30", "run_pace_unit": "min_per_mile",
         "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"},
        {},
    ),
    (
        "2. Short 5K, 1h before (snack+top_up only)",
        {"weight": 60, "weight_unit": "kg", "age": 25, "gender": "female",
         "hours_before": 1.0, "is_fasted": False,
         "activity_type": "running", "run_distance": 3.1, "run_distance_unit": "mi",
         "run_pace": "9:00", "run_pace_unit": "min_per_mile",
         "gut_training": "beginner", "sweat_rate_category": "light", "sweat_sodium": "light"},
        {},
    ),
    (
        "3. Quick run, 30min before (top_up only)",
        {"weight": 80, "weight_unit": "kg", "age": 35, "gender": "male",
         "hours_before": 0.5, "is_fasted": False,
         "activity_type": "running", "run_distance": 5, "run_distance_unit": "mi",
         "run_pace": "7:30", "run_pace_unit": "min_per_mile",
         "gut_training": "advanced", "sweat_rate_category": "heavy", "sweat_sodium": "heavy"},
        {},
    ),
    (
        "4. Vegan diet, 2h before, 8mi",
        {"weight": 65, "weight_unit": "kg", "age": 28, "gender": "female",
         "hours_before": 2.0, "is_fasted": False,
         "activity_type": "running", "run_distance": 8, "run_distance_unit": "mi",
         "run_pace": "9:30", "run_pace_unit": "min_per_mile",
         "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"},
        {"dietary_preference": "vegan"},
    ),
    (
        "5. Gluten-free, 3h before, half marathon",
        {"weight": 75, "weight_unit": "kg", "age": 32, "gender": "male",
         "hours_before": 3.0, "is_fasted": False,
         "activity_type": "running", "run_distance": 13.1, "run_distance_unit": "mi",
         "run_pace": "8:00", "run_pace_unit": "min_per_mile",
         "gut_training": "advanced", "sweat_rate_category": "heavy", "sweat_sodium": "moderate"},
        {"allergies": ["gluten"]},
    ),
    (
        "6. Dairy + tree nut allergies, 2.5h before",
        {"weight": 68, "weight_unit": "kg", "age": 40, "gender": "female",
         "hours_before": 2.5, "is_fasted": False,
         "activity_type": "running", "run_distance": 10, "run_distance_unit": "mi",
         "run_pace": "10:00", "run_pace_unit": "min_per_mile",
         "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "light"},
        {"allergies": ["dairy", "tree_nuts"]},
    ),
    (
        "7. Low-carb diet, 3h before (challenging!)",
        {"weight": 85, "weight_unit": "kg", "age": 45, "gender": "male",
         "hours_before": 3.0, "is_fasted": False,
         "activity_type": "running", "run_distance": 6, "run_distance_unit": "mi",
         "run_pace": "9:00", "run_pace_unit": "min_per_mile",
         "gut_training": "beginner", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"},
        {"dietary_preference": "low_carb"},
    ),
    (
        "8. Paleo diet, 2h before, 7mi",
        {"weight": 72, "weight_unit": "kg", "age": 33, "gender": "male",
         "hours_before": 2.0, "is_fasted": False,
         "activity_type": "running", "run_distance": 7, "run_distance_unit": "mi",
         "run_pace": "8:15", "run_pace_unit": "min_per_mile",
         "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"},
        {"dietary_preference": "paleo"},
    ),
    (
        "9. Vegetarian + soy allergy, 3h before, 20mi",
        {"weight": 62, "weight_unit": "kg", "age": 29, "gender": "female",
         "hours_before": 3.0, "is_fasted": False,
         "activity_type": "running", "run_distance": 20, "run_distance_unit": "mi",
         "run_pace": "9:45", "run_pace_unit": "min_per_mile",
         "gut_training": "advanced", "sweat_rate_category": "heavy", "sweat_sodium": "heavy"},
        {"dietary_preference": "vegetarian", "allergies": ["soy"]},
    ),
    (
        "10. Multiple allergies (gluten+dairy+eggs), 2h before",
        {"weight": 70, "weight_unit": "kg", "age": 35, "gender": "male",
         "hours_before": 2.0, "is_fasted": False,
         "activity_type": "running", "run_distance": 8, "run_distance_unit": "mi",
         "run_pace": "8:30", "run_pace_unit": "min_per_mile",
         "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"},
        {"allergies": ["gluten", "dairy", "eggs"]},
    ),
    (
        "11. Food prefs: likes bananas+honey, dislikes oatmeal",
        {"weight": 70, "weight_unit": "kg", "age": 30, "gender": "male",
         "hours_before": 3.0, "is_fasted": False,
         "activity_type": "running", "run_distance": 10, "run_distance_unit": "mi",
         "run_pace": "8:30", "run_pace_unit": "min_per_mile",
         "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"},
        {"liked_foods": ["banana", "honey", "rice"], "disliked_foods": ["oatmeal", "yogurt"]},
    ),
    (
        "12. Fasted state, 2h before, 6mi",
        {"weight": 68, "weight_unit": "kg", "age": 28, "gender": "male",
         "hours_before": 2.0, "is_fasted": True,
         "activity_type": "running", "run_distance": 6, "run_distance_unit": "mi",
         "run_pace": "7:45", "run_pace_unit": "min_per_mile",
         "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"},
        {},
    ),
    (
        "13. Heavy 100kg runner, marathon, 4h before",
        {"weight": 100, "weight_unit": "kg", "age": 38, "gender": "male",
         "hours_before": 4.0, "is_fasted": False,
         "activity_type": "running", "run_distance": 26.2, "run_distance_unit": "mi",
         "run_pace": "10:00", "run_pace_unit": "min_per_mile",
         "gut_training": "advanced", "sweat_rate_category": "heavy", "sweat_sodium": "heavy"},
        {},
    ),
    (
        "14. Vegan + gluten-free (very restrictive)",
        {"weight": 65, "weight_unit": "kg", "age": 30, "gender": "female",
         "hours_before": 3.0, "is_fasted": False,
         "activity_type": "running", "run_distance": 10, "run_distance_unit": "mi",
         "run_pace": "9:00", "run_pace_unit": "min_per_mile",
         "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"},
        {"dietary_preference": "vegan", "allergies": ["gluten"]},
    ),
    (
        "15. Imperial units (154 lbs), 3h before",
        {"weight": 154, "weight_unit": "lb", "age": 30, "gender": "male",
         "hours_before": 3.0, "is_fasted": False,
         "activity_type": "running", "run_distance": 10, "run_distance_unit": "mi",
         "run_pace": "8:30", "run_pace_unit": "min_per_mile",
         "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"},
        {},
    ),
    (
        "16. Keto diet, 3h before, 5mi",
        {"weight": 90, "weight_unit": "kg", "age": 42, "gender": "male",
         "hours_before": 3.0, "is_fasted": False,
         "activity_type": "running", "run_distance": 5, "run_distance_unit": "mi",
         "run_pace": "9:30", "run_pace_unit": "min_per_mile",
         "gut_training": "beginner", "sweat_rate_category": "light", "sweat_sodium": "light"},
        {"dietary_preference": "keto"},
    ),
    (
        "17. All major allergens (gluten+dairy+eggs+soy+nuts+peanuts)",
        {"weight": 70, "weight_unit": "kg", "age": 30, "gender": "male",
         "hours_before": 3.0, "is_fasted": False,
         "activity_type": "running", "run_distance": 10, "run_distance_unit": "mi",
         "run_pace": "8:30", "run_pace_unit": "min_per_mile",
         "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"},
        {"allergies": ["gluten", "dairy", "eggs", "soy", "tree_nuts", "peanuts"]},
    ),
    (
        "18. Vegan + all nut allergies",
        {"weight": 60, "weight_unit": "kg", "age": 25, "gender": "female",
         "hours_before": 2.0, "is_fasted": False,
         "activity_type": "running", "run_distance": 8, "run_distance_unit": "mi",
         "run_pace": "9:00", "run_pace_unit": "min_per_mile",
         "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"},
        {"dietary_preference": "vegan", "allergies": ["tree_nuts", "peanuts"]},
    ),
    (
        "19. Very short time: 15 min before, 3mi",
        {"weight": 70, "weight_unit": "kg", "age": 30, "gender": "male",
         "hours_before": 0.25, "is_fasted": False,
         "activity_type": "running", "run_distance": 3, "run_distance_unit": "mi",
         "run_pace": "8:00", "run_pace_unit": "min_per_mile",
         "gut_training": "advanced", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"},
        {},
    ),
    (
        "20. Ultra runner: 50mi, 4h before, advanced gut",
        {"weight": 75, "weight_unit": "kg", "age": 35, "gender": "male",
         "hours_before": 4.0, "is_fasted": False,
         "activity_type": "running", "run_distance": 50, "run_distance_unit": "mi",
         "run_pace": "12:00", "run_pace_unit": "min_per_mile",
         "gut_training": "advanced", "sweat_rate_category": "heavy", "sweat_sodium": "heavy"},
        {},
    ),
]


def main():
    print("=" * 75)
    print("INTEGRATION TESTS: generate-macros-v3 -> generate-nutrition-plan-v2")
    print(f"Dev Supabase: {SUPABASE_URL}")
    print(f"Total tests: {len(TESTS)}")
    print("=" * 75)

    results = []
    for name, macros_payload, v2_extra in TESTS:
        r = run_test(name, macros_payload, v2_extra)
        print_result(r)
        results.append(r)

    # =========================================================
    # SUMMARY
    # =========================================================
    passed = sum(1 for r in results if r.passed)
    failed = sum(1 for r in results if not r.passed)
    total = len(results)

    print("\n" + "=" * 75)
    print("SUMMARY")
    print("=" * 75)
    print(f"  Passed: {passed}/{total}")
    print(f"  Failed: {failed}/{total}")

    # Failed tests detail
    if failed > 0:
        print(f"\n  FAILED TESTS:")
        for r in results:
            if not r.passed:
                print(f"    - {r.name}: {r.error}")

    # Accuracy analysis
    carbs_pcts = [r.before_carbs_pct for r in results if r.passed and r.before_carbs_pct > 0]
    if carbs_pcts:
        avg_carbs = sum(carbs_pcts) / len(carbs_pcts)
        min_carbs = min(carbs_pcts)
        max_carbs = max(carbs_pcts)
        within_range = sum(1 for p in carbs_pcts if 70 <= p <= 130)
        print(f"\n  BEFORE PHASE CARBS ACCURACY ({len(carbs_pcts)} tests):")
        print(f"    Average: {avg_carbs:.0f}%  Min: {min_carbs}%  Max: {max_carbs}%")
        print(f"    Within 70-130% range: {within_range}/{len(carbs_pcts)}")

    fluids_pcts = [r.before_fluids_pct for r in results if r.passed and r.before_fluids_pct > 0]
    if fluids_pcts:
        avg_fluids = sum(fluids_pcts) / len(fluids_pcts)
        min_fluids = min(fluids_pcts)
        max_fluids = max(fluids_pcts)
        within_range = sum(1 for p in fluids_pcts if 50 <= p <= 150)
        print(f"\n  BEFORE PHASE FLUIDS ACCURACY ({len(fluids_pcts)} tests):")
        print(f"    Average: {avg_fluids:.0f}%  Min: {min_fluids}%  Max: {max_fluids}%")
        print(f"    Within 50-150% range: {within_range}/{len(fluids_pcts)}")

    sodium_pcts = [r.before_sodium_pct for r in results if r.passed and r.before_sodium_pct > 0]
    if sodium_pcts:
        avg_sodium = sum(sodium_pcts) / len(sodium_pcts)
        min_sodium = min(sodium_pcts)
        max_sodium = max(sodium_pcts)
        print(f"\n  BEFORE PHASE SODIUM ACCURACY ({len(sodium_pcts)} tests):")
        print(f"    Average: {avg_sodium:.0f}%  Min: {min_sodium}%  Max: {max_sodium}%")

    # Collect all warnings
    all_warnings = []
    for r in results:
        for w in r.warnings:
            all_warnings.append(f"[{r.name[:35]}] {w}")

    if all_warnings:
        print(f"\n  ALL WARNINGS ({len(all_warnings)}):")
        for w in all_warnings:
            print(f"    - {w}")

    # Template coverage analysis
    print(f"\n  TEMPLATE COVERAGE BY DIET/ALLERGY:")
    templates_seen = set()
    for r in results:
        if r.passed:
            phases = ", ".join(r.sub_phases_found)
            print(f"    {r.name[:50]:50s} -> {phases}")
            for sp, data in r.foods_by_phase.items():
                tname = data['template']
                templates_seen.add(tname)
                nfoods = len(data['foods'])
                print(f"      {sp:7s}: {tname} ({nfoods} foods, drink: {data['drink']})")

    print(f"\n  UNIQUE TEMPLATES USED: {len(templates_seen)}")
    for t in sorted(templates_seen):
        print(f"    - {t}")

    print("\n" + "=" * 75)
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
