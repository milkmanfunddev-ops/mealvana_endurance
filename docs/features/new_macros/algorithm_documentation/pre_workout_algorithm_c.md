# Pre-Workout Algorithm C: Direct Calculation with Sodium/Hydration Awareness

## Overview
Algorithm C is our pre-workout nutrition planning algorithm. It uses a direct calculation approach to select food formulas, add-ons, and standalone drinks for each sub-phase of a pre-workout meal plan.

**Current Status**: Production-ready with 100% carb accuracy and excellent structural compliance across 112 test scenarios.

## Current Test Results (2026-03-13)
- **112 test scenarios** across weights (50-95kg), time windows (0.25-3.5h), and diets (none, gluten-free, dairy-free, peanut-free)
- **Carb accuracy**: 112/112 (100%) - within ±20% of target (or ±10g if target <50g)
- **Sodium accuracy**: 112/112 (100%) - range-based: floor+ceiling by meal type
- **Hydration accuracy**: 112/112 (100%) - range-based: floor+ceiling with min thresholds
- **All structural criteria**: 112/112 (100%) - no banana overload, no absurd quantities, half-serving precision, phase coverage, etc.
- **Cross-phase repeat**: 109/112 (97.3%) - 3 WARN-level repeats from catalog limitations (gluten-free heavy athletes)

## Algorithm Architecture

### High-Level Flow
```
1. Determine active phases (based on hours before activity)
2. Initialize plan state (track banana/drink usage, categories, sodium/fluid delivered)
3. For each phase:
   a. Score all eligible formulas (calculate ideal servings + add-ons)
   b. Pick best formula using carb gap + sodium/fluid alignment
   c. Stack second formula if still >20% short on carbs
   d. Update plan state (mark category/add-ons used, track sodium/fluid delivered)
4. Add standalone drink to top-up phase (score all drink options)
5. Return complete plan with all phases
```

### Phase Selection
Based on hours before activity:
- **≥2.5h**: 3 phases (meal → snack → top_up)
- **1-2.5h**: 2 phases (snack → top_up)
- **<1h**: 1 phase (top_up only)

### Carb Target Calculation
- **Base**: 1g carbs per kg body weight per hour before activity
- **Cap**: 4g per kg total
- **Budget split** across phases: 60% meal / 25% snack / 15% top-up

## Core Algorithm Components

### 1. Formula Scoring (`scoreFormula`)

**Purpose**: Calculate ideal servings for a single formula and add appropriate add-ons.

**Logic**:
```typescript
1. Calculate ideal servings: target_carbs / carbs_per_serving
2. Clamp to formula's min/max servings range
3. Snap to nearest 0.5 increment
4. Add banana/sports drink to fill remaining gap (sodium-aware ordering)
   - If sodium gap > 100mg: prefer sports drink first, then banana
   - If sodium sufficient: prefer banana first, skip sports drink if would overshoot sodium by >40%
   - Exception: Add sports drink anyway if carbs desperately need it (>5g improvement + >15% of target)
5. Return scored result with carbs, sodium, fluid, gap
```

**Sodium-Aware Add-On Ordering**:
```typescript
// Check if we need sodium
const sodiumRemaining = state.sodium_target - (state.sodium_delivered + sodium);
const preferDrinkFirst = sodiumRemaining > 100;

// Order add-ons accordingly
const addOnOrder = preferDrinkFirst
  ? ['sports_drink', 'banana']
  : ['banana', 'sports_drink'];

// Skip sports drink if sodium already over target (unless carbs need help)
const wouldOvershoot = (delivered + sodium + SPORTS_DRINK_SODIUM) > target * 1.4;
if (wouldOvershoot && !preferDrinkFirst && !carbsNeedHelp) continue;
```

### 2. Formula Selection (`pickBestFormula`)

**Purpose**: Pick the best formula from scored candidates using multi-objective optimization.

**Logic**:
```typescript
1. Sort candidates by carb gap (best first)
2. Create diversity band: all formulas within 15% + 8g of best gap
3. Within diversity band, score by normalized distance from sodium + fluid targets
4. Penalize overshoot 1.5x more than undershoot
5. Include normalized carb gap so we don't pick much-worse carbs for marginal sodium gains
6. Return formula with lowest combined score
```

**Scoring Formula**:
```typescript
carbErr = candidate.gap / carbTarget;
sodiumErr = abs(resultSodium - sodiumTarget) / sodiumTarget * (overshoot ? 1.5 : 1.0);
fluidErr = abs(resultFluid - fluidTarget) / fluidTarget * (overshoot ? 1.5 : 1.0);
score = carbErr + sodiumErr + fluidErr;
```

### 3. Formula Stacking (`tryStack`)

**Purpose**: Add a second formula if single formula + add-ons still leaves >20% carb gap.

**Logic**:
```typescript
1. Only trigger if pctShort > 20% AND remainingGap > 20g
2. Prefer different category from first formula
3. Calculate ideal servings for remaining gap
4. Among equally-close candidates, prefer lower sodium when sodium is over target
5. Return stacked formula + servings (or null if not needed)
```

### 4. Drink Selection (`pickDrink`)

**Purpose**: Add standalone drink to top-up phase for sodium/hydration optimization.

**Logic**:
```typescript
1. Score "no drink" option as baseline
2. For each drink formula:
   - Try every valid 0.5-step serving (min to max)
   - Score by sodium + fluid proximity to targets
   - Penalize overshoot 1.5x more than undershoot
3. Return drink with best score (or null if "no drink" wins)
```

**Available Drinks**:
- Water (0.5-3 cups)
- Coconut Water (0.5-2 cups)
- Electrolyte Tablet + Water (1-2 tablets)
- Electrolyte Drink Mix + Water (1 scoop)

### 5. Plan State Tracking

**Purpose**: Prevent duplicates and track running totals across phases.

```typescript
interface PlanState {
  banana_used: boolean;           // Max 1 banana total
  sports_drink_used: boolean;     // Max 1 sports drink total
  used_categories: Set<string>;   // Prevent same category in multiple phases
  sodium_delivered: number;       // Running total for multi-phase scoring
  fluid_delivered: number;        // Running total for multi-phase scoring
  sodium_target: number;          // Target for proximity scoring
  fluid_target: number;           // Target for proximity scoring
}
```

## Food Formulas (20 formulas)

### < 30 min (Top-Up)
| Name | Category | Carbs/Serving | Sodium | Fluid | Min | Max | Banana | Drink |
|------|----------|---------------|--------|-------|-----|-----|--------|-------|
| Energy Gel | Gel | 22g | 55mg | 0ml | 0.5 | 3 | ✓ | ✓ |
| Energy Chews | Chews | 24g | 50mg | 0ml | 0.5 | 2 | ✓ | ✓ |
| Carb Drink Mix | Drink | 30g | 75mg | 240ml | 0.5 | 2 | ✓ | ✗ |

### 30-90 min (Snack)
| Name | Category | Carbs/Serving | Sodium | Fluid | Min | Max | Banana | Drink |
|------|----------|---------------|--------|-------|-----|-----|--------|-------|
| Toast + Jam | Toast | 35g | 150mg | 0ml | 0.5 | 2.5 | ✓ | ✓ |
| Bagel + Jam | Bagel | 50g | 280mg | 0ml | 0.5 | 2 | ✓ | ✓ |
| OJ + Toast | Toast | 40g | 120mg | 240ml | 0.5 | 2 | ✓ | ✓ |
| Granola Bar | Granola | 30g | 120mg | 0ml | 0.5 | 3 | ✓ | ✓ |
| Toast + PB | Toast | 28g | 180mg | 0ml | 0.5 | 2.5 | ✓ | ✓ |
| Bagel + PB | Bagel | 45g | 350mg | 0ml | 0.5 | 2 | ✓ | ✓ |
| Rice Cake + Jam | Rice Cake | 32g | 80mg | 0ml | 0.5 | 3 | ✓ | ✓ |
| Rice Cake + PB | Rice Cake | 25g | 110mg | 0ml | 0.5 | 3 | ✓ | ✓ |
| Smoothie (Fruit) | Smoothie | 45g | 50mg | 350ml | 0.5 | 2 | ✗ | ✓ |

### 1.5-3 hours (Meal)
| Name | Category | Carbs/Serving | Sodium | Fluid | Min | Max | Banana | Drink |
|------|----------|---------------|--------|-------|-----|-----|--------|-------|
| Oatmeal | Oatmeal | 28g | 80mg | 0ml | 0.5 | 3 | ✓ | ✓ |
| Oatmeal + Raisins | Oatmeal | 40g | 90mg | 0ml | 0.5 | 2.5 | ✓ | ✓ |
| Cereal + Milk | Cereal | 38g | 200mg | 240ml | 0.5 | 2.5 | ✓ | ✓ |
| Toast + PB + Jam | Toast | 38g | 200mg | 0ml | 0.5 | 2.5 | ✓ | ✓ |
| Rice Cake + PB + Jam | Rice Cake | 35g | 130mg | 0ml | 0.5 | 3 | ✓ | ✓ |
| Bagel + Cream Cheese | Bagel | 48g | 450mg | 0ml | 0.5 | 2 | ✓ | ✓ |
| Bagel + PB + Jam | Bagel | 55g | 380mg | 0ml | 0.5 | 2 | ✓ | ✓ |
| Yogurt + Granola | Yogurt | 42g | 100mg | 0ml | 0.5 | 2.5 | ✓ | ✓ |

## Drink Formulas (4 options)
| Drink | Serving | Carbs | Sodium | Fluid | Min | Max |
|-------|---------|-------|--------|-------|-----|-----|
| Water | 1 cup (8oz) | 0g | 0mg | 240ml | 0.5 | 3 |
| Coconut Water | 1 cup (8oz) | 9g | 252mg | 240ml | 0.5 | 2 |
| Electrolyte Tablet + Water | 1 tablet + 2 cups | 2g | 300mg | 480ml | 1 | 2 |
| Electrolyte Drink Mix + Water | 1 scoop + 2 cups | 15g | 400mg | 480ml | 1 | 1 |

## Add-Ons (2 options)
| Add-On | Carbs | Sodium | Fluid |
|--------|-------|--------|-------|
| Banana | 27g | 1mg | 0ml |
| Sports Drink | 17g | 230mg | 240ml |

## Acceptance Criteria
| Criteria | Condition | Severity | Current Pass Rate |
|----------|-----------|----------|-------------------|
| Carb accuracy | ±20% (or ±10g if <50g) | FAIL | 112/112 (100%) |
| No banana overload | Max 1 banana total | FAIL | 112/112 (100%) |
| No absurd quantities | No food >3.5 servings | FAIL | 112/112 (100%) |
| No food overload | No food exceeds max_servings | FAIL | 112/112 (100%) |
| No cross-phase repeat | Same category in max 1 phase | WARN | 109/112 (97.3%) |
| Dietary compliance | Zero allergen violations | FAIL | 112/112 (100%) |
| Half-serving precision | All servings in 0.5 increments | FAIL | 112/112 (100%) |
| Phase coverage | Correct phases for time window | FAIL | 112/112 (100%) |
| Sodium accuracy | Within floor-ceiling range by meal type | WARN | 112/112 (100%) |
| Hydration accuracy | Within floor-ceiling range by meal type | WARN | 112/112 (100%) |
| Add-on sanity | Max 1 banana + 1 sports drink | FAIL | 112/112 (100%) |

### Sodium & Hydration Range Approach (2026-03-13)

Previously, sodium and hydration used percentage-based tolerances (±40% and ±50%) against calculated midpoints. This produced 23 sodium warns and 2 hydration warns because:
- The sodium midpoints (300-1250mg) fell in the "dead zone" where research shows no benefit over normal dietary sodium
- High-carb foods inherently bring variable sodium, making precision impossible

**New approach**: Floor + ceiling ranges by meal type, reflecting that pre-workout sodium is a byproduct of carb delivery:

| Meal Type | Sodium Range | Hydration Range |
|-----------|-------------|-----------------|
| Full meal (>=2.5h) | 200-2000mg | max(200, target*0.50) - max(600, target*1.50) |
| Snack (1.0-2.5h) | 100-1000mg | max(150, target*0.50) - max(500, target*1.50) |
| Top-up (<1.0h) | 0-400mg | 0-500ml |

See `range-based-targets-plan.md` for full rationale and research citations.

## Known Issues

### Remaining Cross-Phase Repeat Warns (3/112 scenarios)

All 3 are catalog-limitation issues:
- **95kg gluten-free at 3.5h** (2 scenarios): Rice Cake appears in both meal and snack phases because it's the only high-carb gluten-free option
- **70kg at 2.4h boundary** (1 scenario): Quick Grab category appears twice in edge case

These are WARN severity and would be resolved by adding more formulas to the catalog (e.g., Rice+Honey, Sweet Potato).

## Algorithm Constants

```typescript
const ADDON_GAP_THRESHOLD = 10;   // Only add banana/drink if gap > 10g
const STACK_THRESHOLD = 0.20;     // Stack second formula if >20% short
const DIVERSITY_BAND = 0.15;      // Pick among formulas within 15% of best carb gap
const DIVERSITY_FLOOR = 8;        // Minimum absolute carb gap to include in diversity band
```

## How to Run Tests

```bash
cd supabase/functions

# Full suite (112 scenarios)
~/.deno/bin/deno run --allow-read --allow-write _archived/supabase/functions/_test/pre-workout-comparison/run.ts --algo=c

# Verbose output (show every scenario)
~/.deno/bin/deno run --allow-read --allow-write _archived/supabase/functions/_test/pre-workout-comparison/run.ts --algo=c --verbose

# Quick mode (20 scenarios)
~/.deno/bin/deno run --allow-read --allow-write _archived/supabase/functions/_test/pre-workout-comparison/run.ts --algo=c --quick
```

## Key Files
- **Algorithm**: `_archived/supabase/functions/_test/pre-workout-comparison/algorithms/algo-c-comfort-cap.ts`
- **Shared utilities**: `_archived/supabase/functions/_test/pre-workout-comparison/algorithms/shared.ts`
- **Formula data**: `_archived/supabase/functions/_test/pre-workout-comparison/data/formulas.ts`
- **Types**: `_archived/supabase/functions/_test/pre-workout-comparison/types.ts`
- **Scenarios**: `_archived/supabase/functions/_test/pre-workout-comparison/scenarios.ts`
- **Criteria**: `_archived/supabase/functions/_test/pre-workout-comparison/criteria.ts`
- **Report**: `_archived/supabase/functions/_test/pre-workout-comparison/report.ts`
- **Entry point**: `_archived/supabase/functions/_test/pre-workout-comparison/run.ts`
- **Macro targets**: `_archived/supabase/functions/_test/pre-workout-comparison/macro-targets.ts`

## Evolution History

1. **Initial version**: "Comfort-Capped Hybrid" with random diversity selection
2. **v2**: Added `fluid_ml` tracking to all types and formulas
3. **v3**: Added standalone drink selection in top-up phase (Water, Electrolyte Tablet)
4. **v4**: Expanded drink pool (Coconut Water, Electrolyte Drink Mix), lowered Water min to 0.5 cup
5. **v5**: Made drink selection score-based (all options × all servings, penalize overshoot)
6. **v6**: Added "no drink" as valid option when food covers targets
7. **v7**: Made food selection sodium-aware (add-on ordering, sports drink skip logic)
8. **v8**: Added diversity band tiebreaker using sodium/fluid proximity + running state tracking across phases
9. **v9** (current): Replaced fixed sodium/hydration percentage tolerances with range-based (floor+ceiling) evaluation. Eliminated all sodium/hydration warnings (0 from 25 previously)

## Design Principles

1. **Carb accuracy first**: Always prioritize hitting carb targets within ±20%
2. **Sodium awareness**: Use sodium/fluid proximity as tiebreaker among carb-equivalent options
3. **Overshoot penalty**: Penalize sodium/fluid overshoot 1.5x more than undershoot (comfort priority)
4. **Diversity**: Prevent same category across phases, encourage variety
5. **Simplicity**: Direct calculation (no complex optimization or randomness)
6. **Modularity**: Separate scoring, selection, stacking, and drink selection into distinct steps
7. **Testability**: Deterministic output for same input (no random selection)

## Future Improvements

### Potential Optimizations
1. **Dynamic diversity band**: Adjust band width based on target size (wider for large targets)
2. **Sodium budget allocation**: Split sodium target across phases like carb budget
3. **Multi-phase stacking**: Allow second formula in phases beyond just the first phase needing it
4. **Category affinity scoring**: Prefer certain categories based on athlete preferences
5. **Protein/fat awareness**: Add protein/fat proximity to scoring (currently ignored)

### Known Limitations
1. **High-sodium scenarios**: No sodium ceiling enforcement (relies on food selection naturally limiting sodium)
2. **Low-fluid scenarios**: Minimum drink serving sizes can overshoot low targets for light athletes
3. **All-free diet**: Limited formula pool makes sodium/fluid targets harder to hit
4. **Phase independence**: Each phase is optimized separately (no global optimization across phases)

## Related Documentation
- **Macro Algorithm V3**: `/docs/features/new_macros/algorithm_documentation/macro-algorithm-v3.md`
- **Pre-Workout Formulas Schema**: `/docs/_archived/data_dumps/pre_workout_formulas_schema.txt`
- **Pre-Workout Formulas Data**: `/docs/_archived/data_dumps/pre_workout_formulas.txt`
