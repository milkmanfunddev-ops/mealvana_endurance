# Corpus-Driven Parity Test Harness

## Purpose

This harness catches the recurring production problem where the generated
nutrition plan does NOT meet the macro targets produced by the macro-generation
step. It runs a corpus of athlete scenario fixtures through the pure plan solver
and asserts the resulting foods hit the targets within documented tolerance.

## How to Run

```bash
# Run only the parity harness
deno test --no-check --allow-read --allow-write \
  supabase/functions/tests/parity/parity.test.ts

# Run the full algorithm test suite (includes parity as section 1h)
bash supabase/functions/run-algorithm-tests.sh
```

## Tolerance Constants

| Constant | Value | Rationale |
|---|---|---|
| `RELATIVE_TOLERANCE` | 15% | Solver inner bounds (±10%) + discrete-serving rounding (~5%) |
| `ABSOLUTE_CARBS_G` | 8g | Floor for small targets (10g carbs with 7g actual is clinically irrelevant) |
| `ABSOLUTE_SODIUM_MG` | 100mg | Floor matching tablet/capsule serving discreteness |
| `ABSOLUTE_FLUID_ML` | 100ml | One cup of water (~240ml serving quantization) |
| `RELATIVE_PROTEIN_TOLERANCE` | 20% | After-phase template portions vary more than during |

Pass condition for each macro:
```
|actual - target| <= max(RELATIVE_TOLERANCE × target, ABSOLUTE_FLOOR)
```

**Personal formula pins bypass macro targets by design** (locked pin policy
2026-05-21). When a personal formula fires, the harness checks structural
invariants (no NaN/negative/empty fields, all components present) but skips
macro parity — the user authored the formula; the algorithm honors it
unconditionally. This is correct behavior, not a bug.

## Fixture List

| File | Description |
|---|---|
| `01-light-easy-run.json` | 50kg female, 30-min easy run — degenerate short-workout case (**known failure: fluid floor**) |
| `02-heavy-long-ride.json` | 95kg male, 3-hour high-intensity cycling — upper-bound solver pressure |
| `03-ultra-high-sweat.json` | 75kg, 5-hour run, high sweat — fluid/electrolyte stress |
| `04-very-short-workout.json` | 25-min cycling, near-zero during targets |
| `05-vegetarian-constrained.json` | 70kg vegetarian — food-pool constraint (**known failure: sodium gap in small catalog**) |
| `06-vegan-dairy-allergy.json` | 62kg vegan + dairy/egg allergy — double-constraint elimination |
| `07-pinned-during-system-template.json` | Athlete with pinned system during template |
| `08-personal-formula-during.json` | **NEW**: pinned personal formula, during phase, running/90-150min |
| `09-personal-formula-after.json` | **NEW**: pinned personal formula, after phase, running |
| `10-personal-formula-before-slot.json` | **NEW**: pinned personal formula, before phase, full_meal slot |
| `11-during-template-high-gut.json` | 78kg, 2-hour cycling, high gut training |
| `12-tight-constraints-greedy-path.json` | Gluten-free vegan + nut allergy — greedy fallback pressure |
| `13-personal-formula-out-of-scope.json` | **NEW**: cycling-scoped formula during a run — must NOT fire |
| `14-personal-formula-wrong-duration-bracket.json` | **NEW**: >240min formula during 120-min workout — must NOT fire |
| `15-personal-formula-all-three-phases.json` | **NEW**: formulas pinned for all 3 phases simultaneously |
| `16-medium-triathlon.json` | **NEW**: triathlon activity with triathlon_bike-scoped formula |

## How to Add a Production Regression Fixture

When production generates a bad plan:

1. Capture the plan inputs: athlete profile, workout params, targets, and
   active pins from the `formula_pins` table.

2. Create `fixtures/NN-description.json` following the existing schema:
   ```json
   {
     "description": "One-line description of what this stresses",
     "athlete": { "weight_kg": 72, "sex": "male" },
     "workout": {
       "activity_type": "running",
       "duration_minutes": 120,
       "gut_training_level": "moderate"
     },
     "targets": {
       "during_run": { "carbs_g": 60, "sodium_mg": 900, "water_ml": 900 },
       "post_run": { "carbs_g": 60, "protein_g": 25, "sodium_mg": 700, "water_ml": 600 }
     },
     "preferences": {
       "liked_foods": [], "willing_to_try_foods": [],
       "disliked_foods": [], "allergies": [],
       "dietary_preference": "none"
     },
     "pins": null
   }
   ```

3. If the algorithm currently fails the new fixture (i.e. it's the production
   bug you're trying to reproduce), set `"knownFailure": true` and add a
   `"knownFailureReason"` field describing the violation precisely. The test
   will WARN instead of FAIL, keeping CI green while the fix is tracked.

4. Once the bug is fixed, remove the `knownFailure` flag and verify the test
   now passes cleanly.

## Known Failures (Algorithm Gaps)

Two fixtures are currently marked `knownFailure: true`:

### Fixture 01: Fluid floor on short workouts
The rule solver cannot deliver fluid below its minimum serving floor
(1 water serving = 240ml + 1 sports drink = 240ml = 480ml minimum).
Short-workout fluid targets (e.g. 300ml) can never be satisfied.
**TODO**: Add fractional serving support for fluid items OR gate fluid
selection on target size.

### Fixture 05: Sodium gap with electrolyte scoring logic
The rule solver's electrolyte fill pass skips addition when "it won't
improve the score", leaving a large sodium gap when the carb backbone
already exhausted all candidate foods. The in-memory test catalog has
limited high-sodium options (compared to production DB), amplifying this.
**TODO**: Electrolyte scoring logic should prioritize filling a sodium
gap regardless of score improvement when the deficit exceeds 30%.

## Pipeline Seams (Pure Entry Points)

The harness calls these functions without HTTP or a database:

| Function | File | Used for |
|---|---|---|
| `generateDuringPhaseRuleBased(foods, targets, activityType)` | `_shared/nutrition/during-rule-solver.ts` | During-phase rule solver (in-memory) |
| `matchPersonalFormulaPin(pins, phase, activityType, duration?)` | `_shared/nutrition/personal-formula-pins.ts` | Personal formula scope check |
| `personalFormulaToFoodResults(pin, timing)` | `_shared/nutrition/personal-formula-pins.ts` | Render formula components to FoodResult[] |
