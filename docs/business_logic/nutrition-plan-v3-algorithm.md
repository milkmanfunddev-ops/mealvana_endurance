# Nutrition Plan V3 Algorithm Documentation

## Overview

`generate-nutrition-plan-v3` is the **main production** edge function for generating personalized nutrition plans. It is invoked by `nutrition_plan_service.dart` (line 798).

The function takes macro targets (from `generate-macros-v4`) and user preferences, then selects specific foods for three phases: before, during, and after a workout.

## Input Contract

Flutter sends a `PlanInputV2` object containing:

| Field | Type | Description |
|-------|------|-------------|
| `device_id` | string | User device identifier |
| `activity_type` | string | "running", "cycling", "swimming", or "brick" |
| `hours_before` | number | Hours before workout (determines meal type) |
| `weight_kg` | number | User body weight |
| `macro_targets.pre_run` | MacroTargets | Before-phase targets (carbs, protein, fat, sodium, water + low/high ranges) |
| `macro_targets.during_run` | MacroTargets | During-phase targets |
| `macro_targets.post_run` | MacroTargets | After-phase targets |
| `dietary_preference` | string? | "vegan", "vegetarian", "gluten_free", etc. |
| `allergies` | string[]? | Allergen list |
| `liked_foods` | string[]? | Preferred foods |
| `disliked_foods` | string[]? | Avoided foods |
| `willing_to_try_foods` | string[]? | Neutral foods |
| `duration_minutes` | number? | Activity duration |
| `gut_training_level` | string? | "low", "moderate", "high" |
| `brick_segments` | array? | Multi-sport segments for brick workouts |

## Before Phase: Algorithm C

**File:** `before-phase.ts` (orchestrator) + `before-phase-db.ts`, `before-phase-substitution.ts`, `before-phase-explosion.ts`

### Step 1: Determine Meal Type
Based on `hours_before`:
- >= 2.5 hours: `full_meal`
- >= 1.0 hours: `snack`
- < 1.0 hours: `top_up`
- 0 carbs + 0 water: `fasted` (skip before phase entirely)

### Step 2: Build Targets
Uses V4 macro ranges directly. Falls back to percentage-based ranges when low/high are missing:
- Carbs: +/- 12.5%
- Protein: +/- 15% (0 if top_up)
- Sodium: +/- 15%
- Water: +/- 15%

### Step 3: Fetch Templates
Three parallel queries to `pre_workout_templates` table:
- Food templates (meals, snacks)
- Drink templates (sports drinks, water, etc.)
- Electrolyte templates (tablets, drink mixes)

### Step 4: Algorithm C Food Selection
Calls `selectPreWorkoutFoods()` from `generate-macros-v4/pre-workout.ts`:

1. **Target splitting**: Divides overall targets into sub-phase budgets (meal/snack/top_up)
2. **Template scoring**: Each template scored by how well it fills the carb target
3. **Diversity band**: Picks from templates within 15% of best score (adds variety)
4. **Stacking**: If primary food fills < 80% of carbs, a second food is stacked
5. **Add-ons**: If > 10g carb gap remains, adds banana or sports drink
6. **Drink selection**: Independent drink picked based on water target
7. **Electrolyte selection**: Independent electrolyte picked based on sodium target

### Step 5: Component Explosion
Templates are multi-component (e.g., "Toast + PB + Jam"). The explosion step:
1. Fetches `template_foods` rows for all component names
2. Splits template into individual FoodResult items per component
3. Scales nutrition proportionally by component quantity
4. Normalizes totals to match the template selection contract exactly
5. Fixes residual rounding drift on the first component

### Step 6: User Food Substitution
If user has custom foods (from barcode scanning or manual entry):
1. Fetches `user_foods` where `product_type != 'import'` and suitable for before phase
2. Matches by product_type compatibility (e.g., user's "gel" can replace template's "energy_gel")
3. Requires carbs within 50% tolerance
4. Picks closest carb profile match
5. Never substitutes water or essential liquids

### Step 7: Sub-Phase Assembly
Converts V4 `PreWorkoutPhaseResult[]` into V2's `BeforePhaseResult` shape:
- `{ meal?: SubPhaseResult, snack?: SubPhaseResult, top_up?: SubPhaseResult }`

## During Phase: Rule-Based Solver

**File:** `during-phase.ts`

### Primary Path: Rule Solver
1. Fetches foods from `template_foods` for "during" phase
2. Calls `generateDuringPhaseRuleBased()` from `during-rule-solver.ts`
3. Rule solver picks foods sequentially: primary carb source -> sports drink -> water -> electrolytes
4. Validates result against macro ranges

### Fallback Path: LP Solver
If rule solver result is out of range:
1. Falls back to `generateLPPhase()` with "during" phase
2. LP solver uses javascript-lp-solver library to optimize food selection
3. Two-pass approach: LP focuses on carbs (sodium weight reduced to 0.05), then post-processing adds electrolytes for sodium deficit

### Swimming Exception
Swimming activities return empty during phase (no nutrition during swim).

### Imported User Food Sanitization
If LP result is out of range and imported user foods are in the pool, retries without them to prevent extreme nutritional values from imported labels.

## After Phase: LP Solver

**File:** `lp-phase.ts`

1. Fetches "after" phase foods from `template_foods`
2. **Recovery food filtering**: Removes high-carb/zero-protein foods (drink mixes, gels) that are inappropriate for recovery
3. Builds LP model with phase-specific optimization weights
4. Solves LP model (maximize score = weighted sum of carb/protein/sodium/water fit + preference)
5. Falls back to greedy algorithm if LP is infeasible
6. **Imported user food retry**: Same sanitization logic as during phase

### LP Solver Details (lp-solver.ts)
- Uses `javascript-lp-solver` library
- Constraints: carb/protein/sodium/water ranges, max foods, max servings per food
- Objective: maximize weighted score (carbs, preference, sodium, water, protein)
- Post-solve: rounds to 0.5 serving increments, corrects macro drift

## Brick Workouts

**File:** `brick-handler.ts`

Multi-sport workouts (swim/bike/run) with special handling:

1. **Before phase**: Shared across all segments (same Algorithm C)
2. **During phases**: Generated per-segment with sport-specific food pools
3. **Transitions (T1, T2)**: Duration-based nutrition targets:
   - Sprint (<90 min): no transition nutrition
   - Olympic (90-180 min): water only (50ml)
   - Half Ironman (180-420 min): T1=25g carbs, T2=10g carbs
   - Ironman (420+ min): T1=30g carbs, T2=25g carbs
4. **After phase**: Uses "running" activity type (brick recovery is run-like)

## Validation

**File:** `validation.ts`

Every phase result is validated against macro ranges:
- Uses V4-provided ranges when available (carbs_low_g/carbs_high_g)
- Falls back to `MACRO_CONSTRAINT_RANGES` percentage-based ranges
- Validation is **non-fatal**: out-of-range results produce warnings, not errors
- Warnings are included in the response for client-side logging

## Known Limitations

1. **Before phase optimizes primarily for carbs**: Protein and sodium are secondary in Algorithm C scoring, so they may slightly exceed ranges
2. **LP rounding drift**: Continuous LP solutions rounded to 0.5 increments can overshoot small targets by up to 25%
3. **During rule solver can't backtrack**: Sequential picks are final; if Step 1 overshoots, later steps can't compensate
4. **Limited after-phase food pool**: Aggressive filtering can leave too few options for LP
5. **By-hour apportionment is deprecated**: Server generates it but client creates empty buckets for user-driven placement
