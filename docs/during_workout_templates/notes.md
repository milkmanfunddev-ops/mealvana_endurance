# During-Workout Templates: Research Notes & Implementation Plan

## Table of Contents
1. [Current Architecture Overview](#1-current-architecture-overview)
2. [Data Flow Analysis](#2-data-flow-analysis)
3. [Identified Issues & Duplication](#3-identified-issues--duplication)
4. [During-Phase Solver Deep Dive](#4-during-phase-solver-deep-dive)
5. [Database Schema Analysis](#5-database-schema-analysis)
6. [Template Foods Gap Analysis](#6-template-foods-gap-analysis)
7. [During-Workout Template Design](#7-during-workout-template-design)
8. [Algorithm Design](#8-algorithm-design)
9. [Edge Function Refactoring Plan](#9-edge-function-refactoring-plan)
10. [Test Case Design](#10-test-case-design)
11. [Open Questions](#11-open-questions)

---

## 1. Current Architecture Overview

### Two-Step Pipeline

The nutrition plan generation is a strict two-step sequential pipeline:

**Step 1: `generate-macros-v4`** (macro calculator)
- Calculates numerical targets for pre/during/post workout
- Returns carb rate, sodium rate, hydration rate with ranges (low/high)
- Also returns pre-workout food selections (`pre_run_selections`) via Algorithm C
- Called by `MacroGenerationService._callGenerateMacrosEdgeFunction()` in `lib/features/nutrition_plan/application/macro_generation_service.dart`

**Step 2: `generate-nutrition-plan-v3`** (food selector)
- Receives macro targets from Step 1 as input
- Selects actual food items to meet those targets
- Three phase algorithms run in parallel:
  - Before: Algorithm C (template-based, from `pre_workout_templates` + `template_foods`)
  - During: Rule-based solver with LP fallback
  - After: LP solver with greedy fallback
- Called by `NutritionPlanService.generatePlanFromMacrosV2()` in `lib/features/nutrition_plan/application/nutrition_plan_service.dart`

### Key Files

| File | Role |
|------|------|
| `supabase/functions/generate-macros-v4/index.ts` | Macro calculation entry point |
| `supabase/functions/generate-macros-v4/single-sport.ts` | During-workout carb/sodium/hydration calculation |
| `supabase/functions/generate-nutrition-plan-v3/index.ts` | Plan generation entry point |
| `supabase/functions/generate-nutrition-plan-v3/during-phase.ts` | During phase orchestrator |
| `supabase/functions/_shared/nutrition/during-rule-solver.ts` | During phase rule-based solver (684 lines) |
| `supabase/functions/_shared/nutrition/template-food-queries.ts` | DB queries for template_foods |
| `supabase/functions/_shared/nutrition/types.ts` | Core types (Food, FoodResult, MacroTargets) |
| `supabase/functions/_shared/nutrition/constants.ts` | MACRO_CONSTRAINT_RANGES, PREFERENCE_SCORE_MAP |
| `lib/features/nutrition_plan/application/macro_generation_service.dart` | Flutter service calling macros edge fn |
| `lib/features/nutrition_plan/application/nutrition_plan_service.dart` | Flutter service calling plan edge fn |
| `lib/features/nutrition_plan/presentation/providers/macro_targets_controller.dart` | Central state hub |
| `lib/features/nutrition_plan/presentation/providers/activity_detail_controller.dart` | Plan view/edit state |

---

## 2. Data Flow Analysis

### Happy Path Flow

```
User taps "Generate Plan" on new activity form
  -> NewActivityCoordinator.generateMacros()
    -> SportInputController (Running/Cycling/Swimming/Brick)
      -> MacroTargetsController.generateMacros()
        -> MacroGenerationService._callGenerateMacrosEdgeFunction()
          -> HTTP POST to generate-macros-v4
          <- Returns MacroTargets (carb rates, sodium, hydration, pre_run_selections)
        -> Cached to SharedPreferences (activity-scoped + global)
        -> Draft activity created in Drift

User reviews "Adjust Macros" screen, taps "Create Plan"
  -> MacroTargetsController.createNutritionPlan()
    -> Reads MacroTargets from SharedPreferences cache
    -> NutritionPlanService.generatePlanFromMacrosV2()
      -> HTTP POST to generate-nutrition-plan-v3
        -> Request body includes macro_targets from Step 1
        -> before: Algorithm C (uses pre_run_selections or re-runs)
        -> during: Rule-based solver (from during-rule-solver.ts)
        -> after: LP solver
      <- Returns plan with foods for each phase
    -> Activity updated to "planned" with nutritionPlanData JSON
    -> Written to Drift with needs_upload = true

User views Activity Detail screen
  -> ActivityDetailController loads NutritionPlan from activity.nutritionPlanData
  -> MacroTargets resolved from: activity cache > detailedMacroTargets > reconstructed
  -> During phase displayed in DuringPhaseSectionWidget
  -> User can edit foods (swap, add, delete, change quantity)
  -> Edits saved to Drift -> synced to Supabase
```

### Flow Verdict: Generally Sound, With Caveats

The macros -> nutrition plan -> display flow is correct. `generate-macros-v4` is the **sole** source of macro targets in the active code path. `generate-nutrition-plan-v3` purely does food selection against those targets — it does NOT recalculate macros.

---

## 3. Identified Issues & Duplication

### Issue A: Legacy LLM Path Still Has Macro Calculations

`LLMNutritionPlanService.generateLLMNutritionPlan()` in `llm_nutrition_plan_service.dart` reimplements during-carb formulas, gut-training multipliers, and pre-run carb-per-kg formulas **client-side**. This path is reached from:
- `NutritionPlanService.generateNutritionPlan()` (the OLD entry point, line ~1024)
- `ActivityDetailController.regenerateNutritionPlan()` (line ~2047)

**Risk**: If `regenerateNutritionPlan()` is triggered, it uses a different macro calculation than `generate-macros-v4`, potentially producing inconsistent results.

**Recommendation**: Audit whether `regenerateNutritionPlan()` is still called anywhere in the UI. If so, it should be refactored to use `generatePlanFromMacrosV2()` with cached MacroTargets instead.

### Issue B: Client-Side Macro Reconstruction

`ActivityDetailController._deriveMacroTargetsFromActivityPlan()` reconstructs MacroTargets from stored plan data when no cache exists. It uses hardcoded `_durationBandForMinutes()` logic that may drift from the server's `getDurationCarbBand()`. This is display-only (not used for plan generation), but could show wrong band ranges.

### Issue C: `_estimateMacroTargets()` Offline Fallback

`NutritionPlanService._estimateMacroTargets()` is a simple heuristic fallback. Only used when MacroTargets aren't available. Low risk but worth knowing about.

### Issue D: Before Phase Runs in Both V4 and V3

`generate-macros-v4` selects pre-workout foods and returns `pre_run_selections`. Then `generate-nutrition-plan-v3` can either:
- Use the `pre_run_selections` passed in the request (bypass), OR
- Re-run Algorithm C via `selectPreWorkoutFoods()` (if not passed)

The V3 `before-phase.ts` imports directly from V4's `pre-workout.ts`. This works but means the Algorithm C code runs in V4 (macro step) and potentially again in V3 (plan step). The Flutter client passes `pre_run_selections` to V3, so in the happy path it's NOT duplicated. But if the client doesn't send them, V3 reruns the same work.

---

## 4. During-Phase Solver Deep Dive

### Current Algorithm (during-rule-solver.ts)

The solver runs in 5 ordered steps:

1. **Primary carb source**: Pick ONE gel/chew/drink_mix (weighted by preference). Calculate servings for 70% of carb target (100% if no sports drink available). Skip if carb target < 15g.
2. **Sports drink**: Fill remaining 30% carb share + fluid contribution.
3. **Carb deficit recovery**: If > 20% deficit remains, try a second primary carb source. If > 30% deficit still, add sports drink as last resort.
4. **Bike solids** (cycling only): If > 10g carbs remain, add a bar or waffle.
5. **Hydration**: Water to fill fluid target.
6. **Electrolytes**: Two-pass scorer — picks best electrolyte by sodium/fluid/carb penalty, then tries a second source if sodium still below lower bound.

### Limitations of Current Solver

1. **No template concept**: Picks individual foods ad-hoc, no notion of a "formula" like "Gel + Water + Sports Drink"
2. **Running gets only gel/chew/drink_mix + sports_drink + water + electrolyte**: No solids allowed for running (correct for most cases, but marathon/ultra may benefit from limited solids)
3. **Cycling "bike_solid" is opportunistic**: Only added if carb gap > 10g, not as a planned formula component
4. **No per-hour max constraints**: Uses `max_servings_during` (total activity cap) but not per-hour limits
5. **No gut-training-level-aware food limits**: Same max_servings for all gut training levels
6. **No food form preference**: Can't express "I prefer Liquid + Solid over Liquid + Gel/Chew"
7. **Fixed 70/30 carb split**: Primary carb always gets 70%, sports drink 30% — no formula-specific ratios
8. **No 1:1 unit ratio for triple-source**: No concept of matching solid units to gel units

### What the Template System Would Add

1. **Template selection**: Choose the right combination based on activity type, duration, gut training, food form preference
2. **Formula-driven food selection**: Instead of picking ad-hoc, use a defined formula (e.g., "Bar + Gel + Sports Drink")
3. **Per-hour max constraints**: Tiered by gut training level
4. **1:1 ratio enforcement**: For triple-source templates (8, 10, 12, 14)
5. **Product-specific rounding**: Gels = whole units, bars = 0.5 increments, etc.
6. **Compensation logic**: If max constraints reduce carbs below target, compensate via sports drink, then flag

---

## 5. Database Schema Analysis

### Existing Tables Relevant to Templates

| Table | Active? | Purpose |
|-------|---------|---------|
| `template_foods` | YES | Curated food catalog (78 rows). Used by rule solver for during phase and Algorithm C for before phase. |
| `pre_workout_templates` | YES | Before-phase templates. Queried by `generate-nutrition-plan-v3/before-phase-db.ts`. |
| `templates` | PARTIALLY | Denormalized template table with `phase` column. Used only by client-side offline fallback (`TemplatesRepository` -> `ClientPlanService._tryTemplateBasedBefore()`). Not queried by edge functions. |
| `personal_templates` | YES | User-saved plans. Not algorithmic templates. |
| `foods` | YES | Main food catalog for LP/greedy solver. Separate from `template_foods`. |
| `user_foods` | YES | User-created custom foods. |

### The `templates` Table

Has a `phase` column with values: `before`, `during`, `after`, `transition`. BUT:
- Only actively used for `before` phase in offline client fallback
- Schema is denormalized (full JSONB `foods` array with nutrition data per food)
- Not queried by any edge function
- Could potentially be extended for during-workout templates OR a new table could be created

### Recommendation: New `during_workout_templates` Table

Given that:
- `pre_workout_templates` has its own structure tailored to Algorithm C
- `templates` is a legacy catch-all not used by edge functions
- During-workout templates have unique properties (activity, duration, food_form, gut_training tiers, formula)

A new `during_workout_templates` table is cleaner than trying to retrofit `templates`.

---

## 6. Template Foods Gap Analysis

### Foods Referenced in During-Workout Templates

| Product (from templates) | template_foods name | Exists? | default_during? | Needs Change? |
|--------------------------|---------------------|---------|----------------|---------------|
| Gel | `energy_gel` | YES | true | No |
| Chew | `energy_chews` | YES | true | No |
| Chew (mini pack) | `energy_chews_mini_pack` | YES | true | No |
| Bar | `energy_bar` | YES | true | No |
| Stroopwafel | `stroopwafel` | YES | true | No |
| Sports Drink | `sports_drink` | YES | true | No |
| High Carb Drink Mix | `high_carb_drink_mix` | YES | true | No |
| Water | `water` | YES | true | No |
| Electrolyte Drink Mix | `electrolyte_drink_mix` | YES | true | No |
| Electrolyte Packet | `electrolyte_packet` | YES | true | No |
| Electrolyte Tablet | `electrolyte_tablet` | YES | true | No |
| Electrolyte Capsule | `electrolyte_capsule` | YES | true | No |
| High Sodium Electrolyte | `high_sodium_electrolyte_mix` | YES | true | No |
| **Banana** | `banana` | YES | **false** | **YES - set default_during = true** |
| **Rice Cake** | `rice_cake` | YES | **false** | **YES - set default_during = true** |

### Required `template_foods` Changes

1. **`banana`**: Set `default_during = true`. Update `categories` to include during_run/during_bike. Update `activity_types` if needed. Set appropriate `max_servings_during` (currently needs checking).
2. **`rice_cake`**: Same changes as banana.
3. **New per-hour max columns** (optional): Add `max_units_per_hr_low`, `max_units_per_hr_moderate`, `max_units_per_hr_high` to `template_foods` for the tiered hourly constraints. Alternatively, encode these in the edge function as constants (simpler, since the constraint table is small and stable).

### Current `max_servings_during` Values (from template_foods)

These are total-activity caps, NOT per-hour caps. The new template system needs both:
- **Total cap** (existing `max_servings_during`): e.g., energy_gel max_servings_during = 8
- **Per-hour cap** (new): e.g., energy_gel max 2/hr (low gut) or 3/hr (moderate/high gut)

---

## 7. During-Workout Template Design

### Proposed `during_workout_templates` Table Schema

```sql
CREATE TABLE during_workout_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_number INTEGER NOT NULL UNIQUE,
  name TEXT NOT NULL,
  formula TEXT NOT NULL,           -- e.g., "Gel + Water + Sports Drink"
  food_form TEXT NOT NULL,         -- 'liquid_only', 'liquid_gel_chew', 'liquid_solid', 'mixed'
  activity_types TEXT[] NOT NULL,  -- ['running', 'cycling', 'triathlon_bike', 'triathlon_run', 'transition']
  duration_ranges TEXT[] NOT NULL, -- ['< 90 min', '90-150 min', '150-240 min', '> 240 min']
  gut_training_levels TEXT[] NOT NULL, -- ['low', 'moderate', 'high']
  
  -- Component foods (references template_foods.name)
  primary_food_name TEXT,          -- NULL for liquid-only templates
  secondary_food_name TEXT,        -- For triple-source templates (gel component)
  liquid_food_name TEXT,           -- sports_drink or high_carb_drink_mix
  
  -- Ratios
  primary_to_secondary_ratio TEXT, -- '1:1' for triple-source, NULL otherwise
  primary_carb_share DECIMAL,     -- fraction of food carbs from primary (e.g., 0.7)
  liquid_carb_share DECIMAL,      -- fraction of food carbs from liquid (e.g., 0.3)
  
  -- Metadata
  portions_description TEXT,
  notes TEXT,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

### Proposed Per-Hour Max Constraints

Option A: Constants in edge function (recommended for v1):
```typescript
const MAX_UNITS_PER_HR: Record<string, Record<string, number>> = {
  energy_gel:           { low: 2,   moderate: 3,   high: 3 },
  energy_chews:         { low: 1,   moderate: 2,   high: 2 },
  energy_bar:           { low: 0.5, moderate: 1,   high: 1 },
  stroopwafel:          { low: 1,   moderate: 1,   high: 2 },
  banana:               { low: 0.5, moderate: 1,   high: 1 },
  rice_cake:            { low: 1,   moderate: 1,   high: 2 },
  sports_drink:         { low: 16,  moderate: 20,  high: 24 }, // oz/hr
  high_carb_drink_mix:  { low: 0,   moderate: 0,   high: 1 },  // bottles/hr (high only)
};
```

Option B: Columns on `template_foods` (more flexible but requires migration):
```sql
ALTER TABLE template_foods ADD COLUMN max_per_hr_low DECIMAL;
ALTER TABLE template_foods ADD COLUMN max_per_hr_moderate DECIMAL;
ALTER TABLE template_foods ADD COLUMN max_per_hr_high DECIMAL;
ALTER TABLE template_foods ADD COLUMN min_increment DECIMAL DEFAULT 0.5;
```

### Rounding Rules (Constants)

```typescript
const MIN_INCREMENT: Record<string, number> = {
  energy_gel: 1,           // All-or-nothing
  energy_chews: 0.5,       // Half serving = 2-3 pieces
  energy_bar: 0.5,         // Half bars common
  stroopwafel: 1,          // Hard to split
  banana: 0.5,             // Half banana practical
  rice_cake: 0.5,          // Half rice cake practical
  sports_drink: 0.5,       // Continuous sipping (0.5 serving increments)
  high_carb_drink_mix: 0.5,
};
```

---

## 8. Algorithm Design

### Template-Based During-Phase Algorithm

This replaces the current rule-based solver with a template-aware system.

#### Phase 1: Template Selection

```
Input: activity_type, duration_minutes, gut_training_level, food_form_preference (optional), dietary_preference, allergies, liked/disliked foods

1. Query during_workout_templates WHERE:
   - activity_type IN activity_types
   - duration bracket IN duration_ranges
   - gut_training_level IN gut_training_levels
   - is_active = true

2. Filter by dietary constraints:
   - For each template, check if all component foods are compatible with diet/allergies
   - Remove templates where any component food is excluded

3. Filter by food form preference (if provided):
   - Exact match first; if none, relax to all eligible

4. Score remaining templates by:
   - User food preferences (liked foods in template components get bonus)
   - Variety from recent plans (if available)
   - Template sort_order as tiebreaker

5. Select top template (or random among top-scoring ties)
```

#### Phase 2: Quantity Calculation

```
Input: selected template, macro targets (carbs_g, sodium_mg, water_ml), gut_training_level, duration_hours

1. Calculate per-hour targets:
   carbs_per_hr = carbs_g / duration_hours
   sodium_per_hr = sodium_mg / duration_hours
   water_per_hr = water_ml / duration_hours

2. Calculate food carb budget:
   food_carb_target = carbs_g * template.primary_carb_share (or 1.0 - liquid share)
   liquid_carb_target = carbs_g * template.liquid_carb_share

3. For triple-source templates (primary + secondary + liquid):
   a. Calculate ideal primary units = food_carb_target * 0.5 / primary_food.carbs_per_serving
   b. Calculate ideal secondary units = food_carb_target * 0.5 / secondary_food.carbs_per_serving
   c. Enforce 1:1 ratio: units = min(primary_units, secondary_units)
   d. Apply binding max: units = min(units, max_per_hr[primary][gut] * duration_hours, max_per_hr[secondary][gut] * duration_hours)
   e. Apply rounding: round to min_increment for each product

4. For dual-source templates (primary + liquid):
   a. Calculate primary units = food_carb_target / primary_food.carbs_per_serving
   b. Apply max constraint: min(units, max_per_hr[primary][gut] * duration_hours)
   c. Apply rounding

5. For liquid-only templates:
   a. Calculate liquid servings = carbs_g / liquid_food.carbs_per_serving
   b. Apply max constraint

6. Calculate liquid servings to fill remaining carb target:
   remaining_carbs = carbs_g - food_carbs_delivered
   liquid_servings = remaining_carbs / liquid_food.carbs_per_serving
   Apply sports drink volume ceiling
```

#### Phase 3: Constraint Enforcement & Compensation

```
1. Clamp all food units to per-hour max * duration_hours
2. Calculate shortfall = target_carbs - delivered_carbs
3. If shortfall > 10g/hr * duration_hours:
   a. Try increasing sports drink (within ceiling)
   b. If still short, flag warning: "Carb target may be too aggressive for this template"
4. Apply rounding rules per product
5. Add water to fill fluid gap
6. Add electrolytes to fill sodium gap (reuse existing two-pass scorer)
```

#### Phase 4: Validation

```
1. Check totals against MACRO_CONSTRAINT_RANGES
2. Check per-hour rates don't exceed max constraints
3. Log warnings for any out-of-range values
4. Return foods + by_hour_data (if duration >= 60 min)
```

---

## 9. Edge Function Refactoring Plan

### Current `generate-nutrition-plan-v3` Structure

```
generate-nutrition-plan-v3/
  index.ts              (entry point, ~200 lines)
  types.ts              (PlanInputV2, etc.)
  validation.ts         (macro bounds checking)
  before-phase.ts       (Algorithm C orchestrator)
  before-phase-db.ts    (DB queries for pre_workout_templates)
  before-phase-substitution.ts
  before-phase-explosion.ts
  during-phase.ts       (during orchestrator, ~100 lines)
  lp-phase.ts           (LP solver orchestration)
  brick-handler.ts      (multi-sport handler)
  by-hour-apportionment.ts (deprecated)
```

### Proposed Refactoring

**Option A: Split into multiple files within same function (recommended for v1)**

```
generate-nutrition-plan-v3/
  index.ts                    (unchanged orchestrator)
  types.ts                    (add DuringTemplate type)
  validation.ts               (unchanged)
  before-phase.ts             (unchanged)
  before-phase-db.ts          (unchanged)
  before-phase-substitution.ts (unchanged)
  before-phase-explosion.ts   (unchanged)
  during-phase.ts             (updated orchestrator - template selection + fallback to rule solver)
  during-phase-templates.ts   (NEW - template selection logic)
  during-phase-quantities.ts  (NEW - quantity calculation with max constraints)
  lp-phase.ts                 (unchanged, still LP fallback)
  brick-handler.ts            (updated to use template system for each segment)
  by-hour-apportionment.ts    (deprecated, unchanged)

_shared/nutrition/
  during-rule-solver.ts       (PRESERVED - becomes fallback if no template matches)
  during-template-solver.ts   (NEW - template-based solver)
  during-template-queries.ts  (NEW - DB queries for during_workout_templates)
  during-constraints.ts       (NEW - max units per hour, rounding rules)
```

**Option B: New edge function `generate-during-plan-v1`**

Separate edge function for during phase only. Called after macros, parallel to or replacing the during phase in V3. More modular but adds another HTTP hop and deployment target.

**Recommendation**: Option A for v1. The during phase is already isolated in `during-phase.ts` and `during-rule-solver.ts`. We add the template layer on top and keep the rule solver as fallback.

---

## 10. Test Case Design

### Test Categories

#### A. Template Selection Tests

Test that the correct template is selected for various combinations of inputs.

| # | Activity | Duration | Gut Training | Expected Template(s) | Notes |
|---|----------|----------|-------------|----------------------|-------|
| A1 | Running | 60 min | Low | Template 5 (Sports Drink Only) | Sub-90 min running |
| A2 | Running | 120 min | Low | Template 1 (Gel + Water) | 90-150 min, low gut |
| A3 | Running | 120 min | Moderate | Template 1 or 2 | Moderate unlocks sports drink combo |
| A4 | Running | 180 min | High | Template 2 ((Gel + Water) + Sports Drink) | Long running, high gut |
| A5 | Cycling | 60 min | Low | Template 5 (Sports Drink Only) | Sub-90 min cycling |
| A6 | Cycling | 120 min | Low | Template 7 or 9 or 11 or 13 (solid + sports drink) | Cycling allows solids |
| A7 | Cycling | 180 min | High | Template 8, 10, 12, 14, 17-20 | Long cycling, many options |
| A8 | Cycling | 300 min | High | Templates 8, 10, 12, 14, 17-20 | Ultra cycling |
| A9 | Triathlon Bike | 180 min | Moderate | Cycling templates subset | Tri bike = cycling |
| A10 | Triathlon Run | 90 min | Moderate | Running templates subset | Tri run = running |
| A11 | T1/T2 Transition | any | any | Template 0 (Quick Gel Module) | Transition only |

#### B. Dietary Filter Tests

| # | Diet/Allergy | Expected Behavior |
|---|-------------|-------------------|
| B1 | Gluten-free | Exclude templates using stroopwafel, most bars |
| B2 | Vegan | Exclude templates using dairy-based products |
| B3 | Nut allergy | Exclude bars with nut ingredients |
| B4 | No restrictions | All templates available |
| B5 | Gluten-free + Vegan | Intersection: only compatible templates |

#### C. Quantity Calculation Tests

| # | Scenario | Carb Target | Gut Training | Expected Behavior |
|---|----------|------------|-------------|-------------------|
| C1 | Low carb, short run | 30g total | Low | ~1 gel + water |
| C2 | Moderate carb, 2h run | 120g total | Moderate | 2 gels + sports drink |
| C3 | High carb, 3h bike | 270g total | High | Triple source: bar + gel + sports drink |
| C4 | Ultra carb, 5h bike | 500g total | High | High carb drink mix + solid + water |
| C5 | Very high carb, low gut | 200g total | Low | Should warn: target too aggressive |

#### D. Max Unit Constraint Tests

| # | Product | Gut Level | Duration | Max Expected | Test |
|---|---------|----------|----------|-------------|------|
| D1 | Gel | Low | 2h | 4 gels (2/hr * 2h) | Clamp if solver wants 5+ |
| D2 | Gel | High | 3h | 9 gels (3/hr * 3h) | Higher ceiling |
| D3 | Bar | Low | 2h | 1 bar (0.5/hr * 2h) | Half bar per hour |
| D4 | Bar | Moderate | 3h | 3 bars (1/hr * 3h) | Full bar per hour |
| D5 | Stroopwafel | Low | 2h | 2 wafels (1/hr * 2h) | |
| D6 | Stroopwafel | High | 2h | 4 wafels (2/hr * 2h) | Only high gut gets 2/hr |
| D7 | High Carb Mix | Low | 2h | 0 (N/A for low) | Not available at low gut |
| D8 | High Carb Mix | High | 2h | 2 bottles (1/hr * 2h) | |

#### E. Triple-Source 1:1 Ratio Tests

| # | Template | Gut Level | Carb Target | Expected |
|---|----------|----------|------------|----------|
| E1 | T8 (Bar + Gel) | Moderate | 180g (3h) | Bar max=1/hr, Gel max=3/hr, Binding=1/hr each |
| E2 | T10 (Stroopwafel + Gel) | Moderate | 180g (3h) | Stroopwafel max=1/hr, Gel max=3/hr, Binding=1/hr each |
| E3 | T12 (Banana + Gel) | High | 120g (2h) | Banana max=1/hr, Gel max=3/hr, Binding=1/hr each |
| E4 | T14 (Rice Cake + Gel) | High | 120g (2h) | Rice Cake max=2/hr, Gel max=3/hr, Binding=2/hr each |

#### F. Rounding Tests

| # | Product | Raw Servings | Expected |
|---|---------|-------------|----------|
| F1 | Gel | 1.7 | 2 (round to whole) |
| F2 | Gel | 0.3 | 0 or 1 (no 0.5 gels) |
| F3 | Bar | 0.8 | 1.0 (round to 0.5 increment) |
| F4 | Bar | 0.2 | 0.5 (minimum practical) |
| F5 | Stroopwafel | 1.4 | 1 (round to whole) |
| F6 | Banana | 0.7 | 0.5 (round to 0.5) |

#### G. Compensation & Edge Case Tests

| # | Scenario | Expected |
|---|----------|----------|
| G1 | Carb target unreachable due to max constraints | Warning + compensate via sports drink |
| G2 | All solid foods excluded (allergies) | Fall back to liquid-only template |
| G3 | No matching template for criteria | Fall back to rule-based solver |
| G4 | Swimming activity | Empty during phase (no food) |
| G5 | Duration < 60 min | Template 5 or sports drink only |
| G6 | Brick workout segment | Template applied per segment |

#### H. Athlete Profile Tests (E2E)

| # | Profile | Weight | Activity | Duration | Gut | Diet | Expected |
|---|---------|--------|----------|----------|-----|------|----------|
| H1 | Beginner runner | 70kg | Running | 90 min | Low | None | Simple gel + water |
| H2 | Advanced cyclist | 75kg | Cycling | 4h | High | None | Complex multi-source |
| H3 | Light female runner | 52kg | Running | 2h | Moderate | Vegan | Compatible gels/chews |
| H4 | Heavy male cyclist | 95kg | Cycling | 3h | High | Gluten-free | No stroopwafel/bars with gluten |
| H5 | Ultra runner | 80kg | Running | 5h | High | None | High carb rate, gels + chews + drink |
| H6 | Sprint triathlete | 70kg | Brick | 75 min | Low | None | Minimal fueling, quick transitions |
| H7 | Ironman triathlete | 72kg | Brick | 12h | High | None | Complex multi-segment with solids on bike |
| H8 | Swimmer | 68kg | Swimming | 60 min | Moderate | None | Empty during phase |

### Existing Test Infrastructure to Leverage

| File | What to Reuse |
|------|--------------|
| `_shared/nutrition/test-utils.ts` | `makeFood()`, `makeDuringFoods()`, `makeTargets()`, profile constants, `strictAssertMacrosInRange()` |
| `_shared/nutrition/during-rule-solver.test.ts` | Test structure, LogCapture pattern, sport-specific grouping |
| `_shared/nutrition/algorithm-audit.test.ts` | Strict range validation pattern |
| `generate-nutrition-plan-v3/before-phase-filtering.test.ts` | Template filtering test pattern (`makeTemplate()` factory) |
| `generate-nutrition-plan-v3/index.test.ts` | E2E pattern with allergen/diet validation |
| `test/helpers/fixtures/user_fixtures.dart` | Flutter-side athlete profiles |
| `run-algorithm-tests.sh` | Test runner registration |

### New Test Files to Create

1. `_shared/nutrition/during-template-solver.test.ts` — Unit tests for the new template solver
2. `_shared/nutrition/during-constraints.test.ts` — Unit tests for max constraints, rounding, 1:1 ratio
3. `generate-nutrition-plan-v3/during-template-selection.test.ts` — Template selection/filtering tests
4. `generate-nutrition-plan-v3/during-template-e2e.test.ts` — E2E tests with real Supabase data

---

## 11. Decisions Made (Q&A Results)

### Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| DB table for templates | **New `during_workout_templates` table** | Clean separation from legacy `templates` and `pre_workout_templates`. Tailored schema for formula/constraint model. |
| Per-hour max constraints storage | **New columns on `template_foods`** | `max_per_hr_low`, `max_per_hr_moderate`, `max_per_hr_high`, `min_increment` columns. DB-driven, requires migration + updating ~15 rows. Units: servings/hr. |
| No-match fallback | **Fall back to rule solver** | Keep `during-rule-solver.ts` as fallback. If template selection returns nothing, existing solver runs. No regression risk. |
| Coexistence strategy | **Coexist: template primary, rule solver fallback** | Both paths maintained. Lower risk, gradual rollout. Deprecate rule solver later once templates cover all cases. |
| Macros + templates coupling | **Keep macros separate** | `generate-macros-v4` stays pure macro calculation. Template selection happens in `generate-nutrition-plan-v3`. Clear separation of concerns. |
| Brick workout handling | **Per-segment templates** | Each brick segment gets its own template based on that segment's sport, duration, and gut training. |
| Food pool scope | **Template-driven pool** | Only foods in the template's formula are used. Electrolytes and water always added. Most predictable output. |
| Food form preference | **Infer from liked/disliked foods** | No new preference field. Use existing liked/disliked foods to score templates — if user likes gels, prefer gel-based templates. |
| `default_during` column | **Legacy/fallback concept** | Not applicable to new template algorithm. Template selection is driven by template metadata (activity, duration, gut training). `default_during` only matters for rule solver fallback. |
| Component storage in template table | **Array of food names** | `component_food_names TEXT[]` like `pre_workout_templates`. Consistent with existing pattern. |
| Constraint units | **Servings per hour** | Sports drink: 2/2.5/3 servings/hr (since 1 serving = 8oz/240ml). Consistent across all foods. |
| Shared utilities | **Extract to `during-utils.ts`** | Move `buildFoodResult`, `clampServings`, `capServingsByUpperBounds`, electrolyte scoring into shared module. Both solvers import from there. |
| Variety scoring | **Not needed** | Accuracy > variety. Always pick best-matching template. |
| Template metadata in response | **Yes, include** | Return `template_id`, `template_number`, `template_name`, `formula` in during-phase response. |
| Triathlon activity mapping | **Map to existing types** | `triathlon_bike` -> `cycling`, `triathlon_run` -> `running`, `T1/T2` -> transition (brick). |
| Rollout strategy | **Ship everything now** | Data migration + algorithm + tests shipped together. |
| Template count | **All 21 templates** | Ship the complete set from Notion. |

### Dead Code Finding

**`ActivityDetailController.regenerateNutritionPlan()`** (line 2047 of `activity_detail_controller.dart`) is **dead code**:
- The method exists but is NEVER called from anywhere in the codebase
- The UI's "Regenerate Plan" button (`_handleRegeneratePlan`) navigates to `NewActivityScreen` which uses the proper V4 macros + V3 plan pipeline
- This method calls the legacy `NutritionPlanService.generateNutritionPlan()` which uses the old LLM service with client-side macro calculation
- **Action**: Safe to remove as part of dead code cleanup

**Other dead/legacy code candidates** (to audit during refactor):
- `LLMNutritionPlanService` — the entire class may be dead if no code path reaches it
- `NutritionPlanService.generateNutritionPlan()` (the non-V2 method) — only called from the dead `regenerateNutritionPlan()`
- `NutritionPlanService._estimateMacroTargets()` — offline fallback, check if still needed
- `ActivityDetailController._deriveMacroTargetsFromActivityPlan()._durationBandForMinutes()` — hardcoded bands that may drift from server

---

## 12. Implementation Phases

### Phase 1: Database Migration & Seed Data

**1a. New `during_workout_templates` table**
```sql
CREATE TABLE during_workout_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_number INTEGER NOT NULL UNIQUE,
  name TEXT NOT NULL,
  formula TEXT NOT NULL,
  food_form TEXT NOT NULL,  -- 'liquid_only', 'liquid_gel_chew', 'liquid_solid', 'mixed'
  activity_types TEXT[] NOT NULL,
  duration_ranges TEXT[] NOT NULL,
  gut_training_levels TEXT[] NOT NULL,
  component_food_names TEXT[] NOT NULL,  -- references template_foods.name
  portions_description TEXT,
  notes TEXT,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

**1b. New columns on `template_foods`**
```sql
ALTER TABLE template_foods ADD COLUMN max_per_hr_low DECIMAL;
ALTER TABLE template_foods ADD COLUMN max_per_hr_moderate DECIMAL;
ALTER TABLE template_foods ADD COLUMN max_per_hr_high DECIMAL;
ALTER TABLE template_foods ADD COLUMN min_increment DECIMAL DEFAULT 0.5;
```

**1c. Seed all 21 templates** from the Notion data (templates 0-20).

**1d. Update `template_foods` per-hour constraints** for the 15 during-workout foods.

**1e. RLS policies** for the new table (read-only for authenticated users).

### Phase 2: Edge Function - Template Solver

**2a. Extract shared utilities** from `during-rule-solver.ts` into `during-utils.ts`

**2b. New `during-template-queries.ts`** — DB queries for `during_workout_templates`

**2c. New `during-template-solver.ts`** — Template selection + quantity calculation + constraint enforcement

**2d. Update `during-phase.ts`** — Try template solver first, fall back to rule solver

**2e. Update `brick-handler.ts`** — Per-segment template selection

**2f. Tests** — All test categories from Section 10

### Phase 3: Dead Code Cleanup

**3a. Remove `regenerateNutritionPlan()`** from ActivityDetailController
**3b. Audit and remove** `LLMNutritionPlanService` if fully dead
**3c. Audit and remove** `NutritionPlanService.generateNutritionPlan()` (non-V2)
**3d. Clean up** any other legacy paths identified

### Phase 4: Frontend Updates (if needed)

**4a. Display template metadata** (template name/formula) in during-phase UI
**4b. Update client-side offline plan service** to be template-aware (or mark as known limitation)
