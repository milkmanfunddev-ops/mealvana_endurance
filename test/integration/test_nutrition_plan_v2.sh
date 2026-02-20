#!/bin/bash
# Integration test script for generate-nutrition-plan-v2
# Tests the full flow: generate-macros-v3 -> generate-nutrition-plan-v2
# with various diets, allergies, and food preferences

SUPABASE_URL="https://vlmtsdzpnjnavdgytcmi.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZsbXRzZHpwbmpuYXZkZ3l0Y21pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk4NTI3OTAsImV4cCI6MjA3NTQyODc5MH0._7t1pjG_1zk4xkfseu2ACqYXdwEJKcRUWyvY4ZXs35o"
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZsbXRzZHpwbmpuYXZkZ3l0Y21pIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1OTg1Mjc5MCwiZXhwIjoyMDc1NDI4NzkwfQ.ugFmXxvIEYZPNMzIhPRB6x-MGbODfE1BXVdKyLpngO0"

PASS_COUNT=0
FAIL_COUNT=0
RESULTS_FILE="/tmp/nutrition_v2_test_results.json"

echo "[]" > "$RESULTS_FILE"

run_test() {
  local test_name="$1"
  local macros_payload="$2"
  local v2_extra_params="$3"

  echo ""
  echo "============================================================"
  echo "TEST: $test_name"
  echo "============================================================"

  # Step 1: Call generate-macros-v3
  echo "  [1/2] Calling generate-macros-v3..."
  local macros_response
  macros_response=$(curl -s -w "\n%{http_code}" \
    -X POST "${SUPABASE_URL}/functions/v1/generate-macros-v3" \
    -H "Authorization: Bearer ${SERVICE_KEY}" \
    -H "Content-Type: application/json" \
    -d "$macros_payload")

  local macros_http_code=$(echo "$macros_response" | tail -n1)
  local macros_body=$(echo "$macros_response" | sed '$d')

  if [ "$macros_http_code" != "200" ]; then
    echo "  FAIL: generate-macros-v3 returned HTTP $macros_http_code"
    echo "  Response: $macros_body"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # Extract macro targets from v3 flat response format (macros.pre_run_carbs_g, etc.)
  local pre_carbs=$(echo "$macros_body" | python3 -c "import sys,json; m=json.load(sys.stdin).get('macros',{}); print(int(m.get('pre_run_carbs_g',0)))" 2>/dev/null)
  local pre_protein=$(echo "$macros_body" | python3 -c "import sys,json; m=json.load(sys.stdin).get('macros',{}); print(int(m.get('pre_run_protein_g',0)))" 2>/dev/null)
  local pre_fat=$(echo "$macros_body" | python3 -c "import sys,json; m=json.load(sys.stdin).get('macros',{}); print(int(m.get('pre_run_fat_g',0)))" 2>/dev/null)
  local pre_sodium=$(echo "$macros_body" | python3 -c "import sys,json; m=json.load(sys.stdin).get('macros',{}); print(int(m.get('pre_run_sodium_mg',0)))" 2>/dev/null)
  local pre_fluids=$(echo "$macros_body" | python3 -c "import sys,json; m=json.load(sys.stdin).get('macros',{}); print(int(m.get('pre_run_water_ml',0)))" 2>/dev/null)
  local during_carbs=$(echo "$macros_body" | python3 -c "import sys,json; m=json.load(sys.stdin).get('macros',{}); print(int(m.get('during_total_g',0)))" 2>/dev/null)
  local during_sodium=$(echo "$macros_body" | python3 -c "import sys,json; m=json.load(sys.stdin).get('macros',{}); print(int(m.get('during_sodium_total_mg',0)))" 2>/dev/null)
  local during_fluids=$(echo "$macros_body" | python3 -c "import sys,json; m=json.load(sys.stdin).get('macros',{}); print(int(m.get('during_water_total_ml',0)))" 2>/dev/null)
  local post_carbs=$(echo "$macros_body" | python3 -c "import sys,json; m=json.load(sys.stdin).get('macros',{}); print(int(m.get('post_run_carbs_g',0)))" 2>/dev/null)
  local post_protein=$(echo "$macros_body" | python3 -c "import sys,json; m=json.load(sys.stdin).get('macros',{}); print(int(m.get('post_run_protein_g',0)))" 2>/dev/null)
  local post_sodium=$(echo "$macros_body" | python3 -c "import sys,json; m=json.load(sys.stdin).get('macros',{}); print(int(m.get('post_run_sodium_mg',0)))" 2>/dev/null)
  local post_fluids=$(echo "$macros_body" | python3 -c "import sys,json; m=json.load(sys.stdin).get('macros',{}); print(int(m.get('post_run_water_ml',0)))" 2>/dev/null)
  local hours_before=$(echo "$macros_payload" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('hours_before',2))" 2>/dev/null)
  local weight_kg=$(echo "$macros_payload" | python3 -c "import sys,json; d=json.load(sys.stdin); w=d.get('weight',70); u=d.get('weight_unit','kg'); print(w if u=='kg' else round(w*0.453592,1))" 2>/dev/null)

  echo "  Macros targets: pre_carbs=${pre_carbs}g pre_protein=${pre_protein}g pre_fat=${pre_fat}g pre_sodium=${pre_sodium}mg pre_fluids=${pre_fluids}ml"
  echo "                  during_carbs=${during_carbs}g post_carbs=${post_carbs}g post_protein=${post_protein}g"

  # Step 2: Call generate-nutrition-plan-v2
  echo "  [2/2] Calling generate-nutrition-plan-v2..."

  local v2_payload
  v2_payload=$(python3 -c "
import json, sys

base = {
    'device_id': 'integration-test-$(date +%s)',
    'activity_type': 'running',
    'hours_before': ${hours_before},
    'weight_kg': ${weight_kg},
    'macro_targets': {
        'pre_run': {
            'carbs_g': ${pre_carbs},
            'protein_g': ${pre_protein},
            'fat_g': ${pre_fat},
            'sodium_mg': ${pre_sodium},
            'water_ml': ${pre_fluids}
        },
        'during_run': {
            'carbs_g': ${during_carbs},
            'sodium_mg': ${during_sodium},
            'water_ml': ${during_fluids}
        },
        'post_run': {
            'carbs_g': ${post_carbs},
            'protein_g': ${post_protein},
            'sodium_mg': ${post_sodium},
            'water_ml': ${post_fluids}
        }
    }
}

# Merge extra params
extra = json.loads('${v2_extra_params}') if '${v2_extra_params}' else {}
base.update(extra)
print(json.dumps(base))
")

  local v2_response
  v2_response=$(curl -s -w "\n%{http_code}" \
    -X POST "${SUPABASE_URL}/functions/v1/generate-nutrition-plan-v2" \
    -H "Authorization: Bearer ${SERVICE_KEY}" \
    -H "Content-Type: application/json" \
    -d "$v2_payload")

  local v2_http_code=$(echo "$v2_response" | tail -n1)
  local v2_body=$(echo "$v2_response" | sed '$d')

  if [ "$v2_http_code" != "200" ]; then
    echo "  FAIL: generate-nutrition-plan-v2 returned HTTP $v2_http_code"
    echo "  Response: $(echo "$v2_body" | python3 -m json.tool 2>/dev/null || echo "$v2_body")"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # Check success field
  local success=$(echo "$v2_body" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('success', False))" 2>/dev/null)

  if [ "$success" != "True" ]; then
    echo "  FAIL: success=false"
    local error_msg=$(echo "$v2_body" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error', 'unknown'))" 2>/dev/null)
    echo "  Error: $error_msg"
    echo "  Full response: $(echo "$v2_body" | python3 -m json.tool 2>/dev/null || echo "$v2_body")"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # Analyze the before phase
  echo "  SUCCESS: Plan generated"

  python3 -c "
import json, sys

data = json.loads('''${v2_body}''')
plan = data.get('plan', {})
before = plan.get('before', {})

# Sub-phases are at top level of before (meal, snack, top_up)
sub_phase_names = [k for k in before if isinstance(before[k], dict) and 'foods' in before[k]]

if not sub_phase_names:
    print('  BEFORE PHASE: Empty (fasted or no pre-run)')
else:
    total_carbs = 0
    total_fluids = 0
    total_sodium = 0
    total_protein = 0
    for sp_name in sub_phase_names:
        sp_data = before[sp_name]
        foods = sp_data.get('foods', [])
        sp_carbs = sum(f.get('carbs_grams', 0) or 0 for f in foods)
        sp_fluids = sum(f.get('fluids_ml', 0) or 0 for f in foods)
        sp_sodium = sum(f.get('sodium_mg', 0) or 0 for f in foods)
        sp_protein = sum(f.get('protein_grams', 0) or 0 for f in foods)
        total_carbs += sp_carbs
        total_fluids += sp_fluids
        total_sodium += sp_sodium
        total_protein += sp_protein

        food_names = [f.get('display_name', f.get('food_name', '?')) for f in foods]
        drink_flags = [f.get('is_drink', False) for f in foods]
        drinks = [n for n, d in zip(food_names, drink_flags) if d]
        non_drinks = [n for n, d in zip(food_names, drink_flags) if not d]

        targets = sp_data.get('targets', {})
        t_carbs = targets.get('carbs_g', 0)

        pct = round(sp_carbs / t_carbs * 100) if t_carbs > 0 else 0
        template = sp_data.get('template_name', '?')
        print(f'  Sub-phase: {sp_name} (template: {template})')
        print(f'    Foods: {non_drinks}')
        print(f'    Drinks: {drinks}')
        print(f'    Carbs: {sp_carbs:.0f}g / {t_carbs:.0f}g target ({pct}%)')
        print(f'    Fluids: {sp_fluids:.0f}ml  Sodium: {sp_sodium:.0f}mg  Protein: {sp_protein:.0f}g')

    # Overall targets
    pre_target_carbs = ${pre_carbs}
    pre_target_fluids = ${pre_fluids}
    pre_target_sodium = ${pre_sodium}
    pre_target_protein = ${pre_protein}

    carb_pct = round(total_carbs / pre_target_carbs * 100) if pre_target_carbs > 0 else 0
    fluid_pct = round(total_fluids / pre_target_fluids * 100) if pre_target_fluids > 0 else 0
    sodium_pct = round(total_sodium / pre_target_sodium * 100) if pre_target_sodium > 0 else 0

    print(f'')
    print(f'  OVERALL BEFORE PHASE:')
    print(f'    Carbs:   {total_carbs:.0f}g / {pre_target_carbs}g ({carb_pct}%)')
    print(f'    Fluids:  {total_fluids:.0f}ml / {pre_target_fluids}ml ({fluid_pct}%)')
    print(f'    Sodium:  {total_sodium:.0f}mg / {pre_target_sodium}mg ({sodium_pct}%)')
    print(f'    Protein: {total_protein:.0f}g / {pre_target_protein}g')

    if 70 <= carb_pct <= 130:
        print(f'    Carbs accuracy: GOOD')
    else:
        print(f'    Carbs accuracy: POOR (off by {abs(100-carb_pct)}%)')

    if pre_target_fluids > 0 and 50 <= fluid_pct <= 150:
        print(f'    Fluids accuracy: GOOD')
    elif pre_target_fluids > 0:
        print(f'    Fluids accuracy: POOR (off by {abs(100-fluid_pct)}%)')

# Analyze during phase
during = plan.get('during', [])
if during:
    d_carbs = sum(f.get('carbs_grams', 0) or 0 for f in during)
    d_names = [f.get('display_name', '?') for f in during]
    print(f'')
    print(f'  DURING PHASE: {len(during)} foods - {d_names}')
    print(f'    Carbs: {d_carbs:.0f}g / {${during_carbs}}g')
else:
    print(f'  DURING PHASE: Empty or not generated')

# Analyze after phase
after = plan.get('after', [])
if after:
    a_carbs = sum(f.get('carbs_grams', 0) or 0 for f in after)
    a_protein = sum(f.get('protein_grams', 0) or 0 for f in after)
    a_names = [f.get('display_name', '?') for f in after]
    print(f'  AFTER PHASE: {len(after)} foods - {a_names}')
    print(f'    Carbs: {a_carbs:.0f}g / {${post_carbs}}g  Protein: {a_protein:.0f}g / {${post_protein}}g')
else:
    print(f'  AFTER PHASE: Empty or not generated')
" 2>&1

  PASS_COUNT=$((PASS_COUNT + 1))
}

echo "======================================================================="
echo "INTEGRATION TESTS: generate-macros-v3 -> generate-nutrition-plan-v2"
echo "Dev Supabase: ${SUPABASE_URL}"
echo "Date: $(date)"
echo "======================================================================="

# ==========================================
# TEST 1: Standard runner, 3h before, omnivore, no allergies
# ==========================================
run_test "Standard 10mi runner, 3h before, omnivore, no restrictions" \
  '{
    "weight": 70, "weight_unit": "kg", "age": 30, "gender": "male",
    "hours_before": 3.0, "is_fasted": false,
    "activity_type": "running",
    "run_distance": 10, "run_distance_unit": "mi",
    "run_pace": "8:30", "run_pace_unit": "min_per_mile",
    "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"
  }' \
  '{}'

# ==========================================
# TEST 2: Short run, 1h before (snack + top_up only)
# ==========================================
run_test "Short 5K, 1h before (should only have snack + top_up)" \
  '{
    "weight": 60, "weight_unit": "kg", "age": 25, "gender": "female",
    "hours_before": 1.0, "is_fasted": false,
    "activity_type": "running",
    "run_distance": 3.1, "run_distance_unit": "mi",
    "run_pace": "9:00", "run_pace_unit": "min_per_mile",
    "gut_training": "beginner", "sweat_rate_category": "light", "sweat_sodium": "light"
  }' \
  '{}'

# ==========================================
# TEST 3: Quick top-up only (<1h before)
# ==========================================
run_test "Quick run, 30min before (should only have top_up)" \
  '{
    "weight": 80, "weight_unit": "kg", "age": 35, "gender": "male",
    "hours_before": 0.5, "is_fasted": false,
    "activity_type": "running",
    "run_distance": 5, "run_distance_unit": "mi",
    "run_pace": "7:30", "run_pace_unit": "min_per_mile",
    "gut_training": "advanced", "sweat_rate_category": "heavy", "sweat_sodium": "heavy"
  }' \
  '{}'

# ==========================================
# TEST 4: Vegan diet
# ==========================================
run_test "Vegan diet, 2h before, 8mi run" \
  '{
    "weight": 65, "weight_unit": "kg", "age": 28, "gender": "female",
    "hours_before": 2.0, "is_fasted": false,
    "activity_type": "running",
    "run_distance": 8, "run_distance_unit": "mi",
    "run_pace": "9:30", "run_pace_unit": "min_per_mile",
    "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"
  }' \
  '{"dietary_preference": "vegan"}'

# ==========================================
# TEST 5: Gluten-free diet
# ==========================================
run_test "Gluten-free, 3h before, half marathon" \
  '{
    "weight": 75, "weight_unit": "kg", "age": 32, "gender": "male",
    "hours_before": 3.0, "is_fasted": false,
    "activity_type": "running",
    "run_distance": 13.1, "run_distance_unit": "mi",
    "run_pace": "8:00", "run_pace_unit": "min_per_mile",
    "gut_training": "advanced", "sweat_rate_category": "heavy", "sweat_sodium": "moderate"
  }' \
  '{"allergies": ["gluten"]}'

# ==========================================
# TEST 6: Dairy-free + nut-free
# ==========================================
run_test "Dairy + tree nut allergies, 2.5h before" \
  '{
    "weight": 68, "weight_unit": "kg", "age": 40, "gender": "female",
    "hours_before": 2.5, "is_fasted": false,
    "activity_type": "running",
    "run_distance": 10, "run_distance_unit": "mi",
    "run_pace": "10:00", "run_pace_unit": "min_per_mile",
    "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "light"
  }' \
  '{"allergies": ["dairy", "tree_nuts"]}'

# ==========================================
# TEST 7: Keto/Low-carb diet (challenging for carb targets!)
# ==========================================
run_test "Low-carb diet, 3h before (challenging scenario)" \
  '{
    "weight": 85, "weight_unit": "kg", "age": 45, "gender": "male",
    "hours_before": 3.0, "is_fasted": false,
    "activity_type": "running",
    "run_distance": 6, "run_distance_unit": "mi",
    "run_pace": "9:00", "run_pace_unit": "min_per_mile",
    "gut_training": "beginner", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"
  }' \
  '{"dietary_preference": "low_carb"}'

# ==========================================
# TEST 8: Paleo diet
# ==========================================
run_test "Paleo diet, 2h before, 7mi run" \
  '{
    "weight": 72, "weight_unit": "kg", "age": 33, "gender": "male",
    "hours_before": 2.0, "is_fasted": false,
    "activity_type": "running",
    "run_distance": 7, "run_distance_unit": "mi",
    "run_pace": "8:15", "run_pace_unit": "min_per_mile",
    "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"
  }' \
  '{"dietary_preference": "paleo"}'

# ==========================================
# TEST 9: Vegetarian + soy allergy
# ==========================================
run_test "Vegetarian + soy allergy, 3h before, marathon training" \
  '{
    "weight": 62, "weight_unit": "kg", "age": 29, "gender": "female",
    "hours_before": 3.0, "is_fasted": false,
    "activity_type": "running",
    "run_distance": 20, "run_distance_unit": "mi",
    "run_pace": "9:45", "run_pace_unit": "min_per_mile",
    "gut_training": "advanced", "sweat_rate_category": "heavy", "sweat_sodium": "heavy"
  }' \
  '{"dietary_preference": "vegetarian", "allergies": ["soy"]}'

# ==========================================
# TEST 10: Multiple allergies (gluten + dairy + eggs)
# ==========================================
run_test "Multiple allergies (gluten+dairy+eggs), 2h before" \
  '{
    "weight": 70, "weight_unit": "kg", "age": 35, "gender": "male",
    "hours_before": 2.0, "is_fasted": false,
    "activity_type": "running",
    "run_distance": 8, "run_distance_unit": "mi",
    "run_pace": "8:30", "run_pace_unit": "min_per_mile",
    "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"
  }' \
  '{"allergies": ["gluten", "dairy", "eggs"]}'

# ==========================================
# TEST 11: With liked and disliked foods
# ==========================================
run_test "Food preferences: likes bananas+honey, dislikes oatmeal" \
  '{
    "weight": 70, "weight_unit": "kg", "age": 30, "gender": "male",
    "hours_before": 3.0, "is_fasted": false,
    "activity_type": "running",
    "run_distance": 10, "run_distance_unit": "mi",
    "run_pace": "8:30", "run_pace_unit": "min_per_mile",
    "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"
  }' \
  '{"liked_foods": ["banana", "honey", "rice"], "disliked_foods": ["oatmeal", "yogurt"]}'

# ==========================================
# TEST 12: Fasted run, 2h before
# ==========================================
run_test "Fasted state, 2h before, 6mi run" \
  '{
    "weight": 68, "weight_unit": "kg", "age": 28, "gender": "male",
    "hours_before": 2.0, "is_fasted": true,
    "activity_type": "running",
    "run_distance": 6, "run_distance_unit": "mi",
    "run_pace": "7:45", "run_pace_unit": "min_per_mile",
    "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"
  }' \
  '{}'

# ==========================================
# TEST 13: Heavy runner (100kg), long run, 4h before
# ==========================================
run_test "Heavy runner (100kg), marathon, 4h before (high targets)" \
  '{
    "weight": 100, "weight_unit": "kg", "age": 38, "gender": "male",
    "hours_before": 4.0, "is_fasted": false,
    "activity_type": "running",
    "run_distance": 26.2, "run_distance_unit": "mi",
    "run_pace": "10:00", "run_pace_unit": "min_per_mile",
    "gut_training": "advanced", "sweat_rate_category": "heavy", "sweat_sodium": "heavy"
  }' \
  '{}'

# ==========================================
# TEST 14: Vegan + gluten allergy (very restrictive)
# ==========================================
run_test "Vegan + gluten-free (very restrictive combo)" \
  '{
    "weight": 65, "weight_unit": "kg", "age": 30, "gender": "female",
    "hours_before": 3.0, "is_fasted": false,
    "activity_type": "running",
    "run_distance": 10, "run_distance_unit": "mi",
    "run_pace": "9:00", "run_pace_unit": "min_per_mile",
    "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"
  }' \
  '{"dietary_preference": "vegan", "allergies": ["gluten"]}'

# ==========================================
# TEST 15: Imperial units (lbs)
# ==========================================
run_test "Imperial units (154 lbs), 3h before, 10mi run" \
  '{
    "weight": 154, "weight_unit": "lb", "age": 30, "gender": "male",
    "hours_before": 3.0, "is_fasted": false,
    "activity_type": "running",
    "run_distance": 10, "run_distance_unit": "mi",
    "run_pace": "8:30", "run_pace_unit": "min_per_mile",
    "gut_training": "moderate", "sweat_rate_category": "moderate", "sweat_sodium": "moderate"
  }' \
  '{}'


echo ""
echo "======================================================================="
echo "SUMMARY"
echo "======================================================================="
echo "  Tests passed: $PASS_COUNT"
echo "  Tests failed: $FAIL_COUNT"
echo "  Total: $((PASS_COUNT + FAIL_COUNT))"
echo "======================================================================="
