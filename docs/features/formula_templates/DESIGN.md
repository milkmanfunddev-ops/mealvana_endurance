# Pre-Workout Template System: Design Specification

## Overview

A multi-phase pre-workout nutrition system that recommends complete meals — food AND drink — at each timing window, the same way a sports dietitian would for a client. Food templates are curated human-authored combinations. Drinks are selected per-phase from a drink pool based on timing context and remaining sodium/fluid needs.

### Objectives

1. Tell athletes **what to eat and drink** before their workout, phased across a realistic timeline
2. Hit macro targets (carbs, protein, fat) with ~10% tolerance
3. Hit sodium and hydration targets with ~30% tolerance
4. **Never present weird food or drink combinations** — all food combos are human-curated, drinks are timing-appropriate
5. Recommend carb-containing drinks (sports drink, OJ, chocolate milk) when sodium/fluid needs warrant it
6. Maximize variety — different plans each time via random selection of both food templates and drinks
7. Avoid repetitive foods across phases (no toast in every meal)

---

## Architecture: The Dietitian Model

Every pre-workout plan consists of **up to 3 complete recommendations**, each with food + drink:

```
🍽  Full Meal (3-4h before)           🥜  Snack (1-2h before)           ⚡  Top Off (<30 min before)
   Oatmeal + Banana + Honey              Rice Cakes + PB + Banana          Energy Gel
   + Orange Juice                         + Sports Drink                    + Water
```

**Key principle**: Each phase is a complete unit — food paired with a drink — just like a dietitian would recommend. Food templates are curated in the database. Drinks are selected per-phase by the algorithm from a timing-appropriate pool.

### Phase Schedules (from existing implementation)

The number of phases depends on how early the athlete starts eating:

| Earliest eating | Phases | Carb Split |
|----------------|--------|------------|
| 3-4 hours before | full_meal + snack + top_up | 60% / 25% / 15% |
| 1-2 hours before | snack + top_up | 75% / 25% |
| 30-60 min before | top_up only | 100% |
| < 30 min before | top_up only | 100% |

---

## Macro Budget Flow

### Step 1: Total Pre-Workout Targets (from v3/v4 algorithm)

The existing macro algorithm outputs total pre-workout targets:

```
pre_run_carbs_g:    150g   (example: 73kg athlete, 3h before)
pre_run_protein_g:  19g
pre_run_fat_g:      30g
pre_run_sodium_mg:  450mg
pre_run_water_ml:   730ml  (evidence-based: ~10 ml/kg, see Hydration Evidence)
```

### Step 2: Split Budgets Across Phases

**Carb split** (from existing implementation, 60/25/15):

```
Full Meal:  150g * 0.60 = 90g
Snack:      150g * 0.25 = 38g
Top Off:    150g * 0.15 = 23g
```

**Protein split** (70/25/5):

```
Full Meal:  19g * 0.70 = 13g
Snack:      19g * 0.25 = 5g
Top Off:    19g * 0.05 = 1g
```

**Fat split** (80/15/5):

```
Full Meal:  30g * 0.80 = 24g
Snack:      30g * 0.15 = 5g
Top Off:    30g * 0.05 = 2g
```

**Hydration split** (30/40/30 — evidence-based, see below):

```
Full Meal:  730ml * 0.30 = 219ml
Snack:      730ml * 0.40 = 292ml   ← highest: maps to Sims sodium-loading window
Top Off:    730ml * 0.30 = 219ml
```

**Sodium split** (30/50/20 — snack-phase emphasis per Sims protocol):

```
Full Meal:  450mg * 0.30 = 135mg   ← mostly from food (bagels, eggs, etc.)
Snack:      450mg * 0.50 = 225mg   ← concentrated electrolyte / sports drink
Top Off:    450mg * 0.20 = 90mg    ← light sodium from drink
```

### Step 3: Select Food Template + Drink Per Phase

For each phase (in order: full_meal → snack → top_up):

1. **Select food template** from curated templates (see Template Selection)
2. **Scale food template** to hit phase carb target (see Template Scaling)
3. **Calculate food's sodium/fluid contribution** from scaled template
4. **Calculate remaining sodium/fluid gap** for this phase
5. **Select drink** from phase-appropriate drink pool to fill gap (see Drink Selection)
6. **Subtract drink carbs** from the food carb target; re-scale if adjustment is > 5g

### Step 4: Present to User

Each phase is one card showing food + drink together:

```
🍽  Full Meal (3-4 hours before)
   1 Bagel + 2 tbsp Peanut Butter + 1 Banana
   + 1 cup Coffee + 8oz Water
   ─────────────────────────
   90g carbs | 17g protein | 20g fat

🥜  Snack (1-2 hours before)
   2 Rice Cakes + 1 tbsp Honey + 0.5 cup Berries
   + 16oz Sports Drink
   ─────────────────────────
   38g carbs | 2g protein | 1g fat

⚡  Top Off (15-30 min before)
   1 Energy Gel
   + 8oz Water
   ─────────────────────────
   23g carbs
```

---

## Food Templates (Food-Only)

### Data Model

Templates are stored in the `templates` table with food items only (no beverages). Existing templates that contain beverages (water, coffee, sports_drink, OJ, etc.) should have those items **stripped** so that all drink recommendations come from the per-phase drink selection.

### Template Selection Algorithm

**Input:**
- Phase: `full_meal`, `snack`, or `top_up`
- Phase carb target (after drink carb subtraction)
- User's allergen and diet preference exclusions
- Already-selected templates from prior phases (for conflict avoidance)

**Process:**

```
1. FILTER: meal_type matches phase

2. FILTER: allergen exclusion
   Template allergens must not intersect with user's excluded allergens

3. FILTER: diet exclusion
   Template excluded_diets must not intersect with user's diet preferences

4. FILTER: base_category conflict (Layer 1)
   Template base_category must NOT match any already-selected template's base_category
   Example: if full_meal used "Oatmeal", snack can't use "Oatmeal"

5. FILTER: food-name overlap (Layer 2)
   Template must not share any food_name with already-selected templates
   EXCEPT staples allowlist: [banana, honey, maple_syrup]
   Example: if full_meal has "white_bread", snack templates with "white_bread" are excluded

6. FILTER: scalability check
   Template must reach phase carb target within its min/max serving ranges
   Check: min_possible_carbs <= target_carbs <= max_possible_carbs

7. RANK: by carb fit proximity
   Prefer templates whose default_servings carbs are closest to target
   Less scaling = more natural portions

8. SELECT: random from top 3 candidates
   Provides variety across different plan generations
```

**Selection order**: full_meal first (largest pool: 16 templates), then snack, then top_up.

### Staples Allowlist

Foods that may repeat across phases without feeling repetitive:

```
STAPLES = ['banana', 'honey', 'maple_syrup']
```

All other foods are "distinctive" and blocked from appearing in multiple phases.

### Template Scaling Algorithm

The existing **grid search over friendly fractions** from `/development/templates_testing/src/lib/scaling.js` is the production scaling algorithm:

1. For each food, generate all valid serving values as friendly fractions (1/4, 1/3, 1/2, 2/3, 3/4 for cups; 0.5 increments for whole items)
2. Enumerate all combinations (prune if search space > 500K)
3. Score each combination: **carbs accuracy (50%) + hydration accuracy (30%) + sodium accuracy (20%)**
4. Return the combination with the highest score

This multi-objective grid search naturally optimizes for carbs, hydration, and sodium simultaneously. Food templates contribute sodium/fluid from items like oatmeal (200ml fluid/cup), bagels (462mg sodium), etc.

### Scaling Limits

- **Full meal**: max_servings = default * 3.5, min = default * 0.5
- **Snack**: max = default * 2.5, min = default * 0.5
- **Top-up**: max = default * 2.0, min = default * 0.25

---

## Per-Phase Drink Selection

### Design Principle

Drinks are selected per-phase — not globally — because different timing windows have different natural drink contexts. Coffee is natural at breakfast, sports drink is natural with a light snack, water is natural with a gel.

### Drink Pool

Drinks come from the `template_foods` table, filtered to beverage items and tagged with valid phases:

| Drink | Carbs/serving | Sodium/serving | Fluid/serving | Valid Phases |
|-------|---------------|----------------|---------------|-------------|
| Coffee (black) | 0g | 5mg | 237ml | full_meal |
| Orange Juice | 26g/cup | 2mg | 219ml | full_meal, snack |
| Chocolate Milk | 26g/cup | 150mg | 220ml | full_meal, snack |
| Milk (whole) | 12g/cup | 105mg | 220ml | full_meal |
| Fruit Smoothie | 27g/cup | 20mg | 215ml | full_meal, snack |
| Sports Drink | 14g/cup | 110mg | 237ml | snack, top_up |
| Electrolyte Mix | 2g/serving | 300mg | ~500ml (in water) | snack, top_up |
| Water | 0g | 0mg | 240ml | full_meal, snack, top_up |

**Note:** The pool is restricted to **beverages** (things you drink from a glass). Supplements like salt packets, electrolyte tablets, and salt capsules are NOT in the drink pool. If sodium supplementation beyond beverages is needed, that's a separate supplementation recommendation (future feature).

### Selection Logic

For each phase, after food template is scaled:

```
1. Calculate food's sodium and fluid contribution for this phase

2. Calculate remaining gap:
   sodium_gap = phase_sodium_target - food_sodium
   fluid_gap  = phase_fluid_target - food_fluid

3. Get all drinks valid for this phase (from drink pool)

4. Filter to drinks that can reasonably fill the gap:
   - Drink must not OVERSHOOT sodium by > 50% at minimum serving
   - Drink must provide meaningful fluid (> 100ml at 1 serving)
   - If sodium_gap <= 0 and fluid_gap <= 0: all drinks valid (variety-only selection)

5. For each candidate drink, calculate optimal servings:
   servings = max(
     sodium_gap / drink.sodium_per_serving,
     fluid_gap / drink.fluid_per_serving,
     0.5  // minimum: always show at least half a serving
   )
   Cap at reasonable maximums (4 cups for drinks, 2 servings for mixes)
   Round to nearest 0.5

6. Randomly select from viable candidates
   → Provides variety: sometimes OJ, sometimes sports drink, sometimes milk
```

### Drink Carb Accounting

The selected drink's carbs are **subtracted from the food phase's carb target** before template scaling:

```
Phase snack target: 38g carbs
Selected drink: 1 cup Sports Drink = 14g carbs
Adjusted food target: 38 - 14 = 24g carbs
→ Scale food template to hit 24g carbs instead of 38g
```

If the drink provides a large portion of the carbs (e.g., OJ at 26g out of 38g target), the food template scales down significantly. This is natural — a glass of OJ with a light snack is a reasonable pre-race meal.

### Variety Mechanism

Both food templates AND drinks rotate randomly:

```
Plan A:                              Plan B:
🍽 Oatmeal + Banana + Honey          🍽 Pancakes + Syrup + Eggs
   + Orange Juice                       + Coffee + Water
🥜 Rice Cakes + PB + Banana          🥜 Waffles + Maple Syrup
   + Sports Drink                       + Chocolate Milk
⚡ Energy Gel                         ⚡ Energy Chews
   + Water                              + Sports Drink
```

Every regeneration produces a different combination because both the food template and drink are randomly selected from their respective candidate pools.

---

## Hydration Evidence (ACSM/NATA Research)

### Total Pre-Workout Fluid Target

**ACSM Position Stand (2007):** 5-7 ml/kg at 4h before + 3-5 ml/kg at 2h before = **8-12 ml/kg total**

**NATA Position Statement (2017):** 500-600ml at 2-3h + 200-300ml at 10-20min = **700-900ml total** for ~70kg athlete

**Recommended formula:** `total_pre_workout_fluid_ml = weightKg * 10` (midpoint of ACSM range)

This replaces the v3 single-phase calculation (6.5 ml/kg for full meal = 475ml for 73kg) which is ~35% too low vs. evidence.

### Hydration Distribution (30/40/30)

| Phase | % | Evidence |
|-------|---|---------|
| Full meal (3-4h) | 30% | ACSM: 5-7 ml/kg with meal, allows kidney processing time |
| Snack (1-2h) | 40% | **Sims protocol**: concentrated electrolyte drink 90-120 min before. NATA: bulk of fluid 2-3h before. This is the key absorption window. |
| Top off (<30 min) | 30% | NATA: 200-300ml final top-off 10-20 min before. Finish drinking 45 min before to allow urination. |

### Sodium Timing (30/50/20)

**Sims et al. (2007):** Pre-exercise sodium loading with concentrated electrolyte drink (1500mg/L) 90-120 min before exercise significantly improves fluid retention and endurance performance. This maps to the **snack phase**.

| Phase | % | Strategy |
|-------|---|---------|
| Full meal | 30% | Sodium from food naturally (bagels, eggs, cereal have significant sodium) |
| Snack | 50% | **Primary sodium delivery** via sports drink or electrolyte mix |
| Top off | 20% | Light sodium from drink or gel |

### Carb-Containing Drinks

Research confirms the primary benefit of sports drinks for pre-exercise hydration comes from **sodium content** (improves fluid retention via SGLT-1 glucose-sodium cotransport), not carbs alone. However, 1-3% carbohydrate concentration improves both palatability and absorption rate vs. plain water.

**Sources:**
- ACSM Position Stand: Exercise and Fluid Replacement (2007) — pubmed.ncbi.nlm.nih.gov/17277604
- NATA Position Statement: Fluid Replacement for the Physically Active (2017) — PMC5634236
- Sims et al. (2007): Preexercise sodium loading — pubmed.ncbi.nlm.nih.gov/17463297
- Sims et al. (2007): Sodium loading aids fluid balance — pubmed.ncbi.nlm.nih.gov/17218894

---

## Data Model Changes

### Templates Table: Strip Beverages

Remove beverage items (water, coffee, sports_drink, orange_juice, electrolyte_drink) from the JSONB `foods` array in existing templates. These become drink pool selections instead.

Templates that are beverage-only (Template 39 "Orange Juice", Template 40 "Sports Drink Only") are retired from the templates table — they become drink pool options.

### template_foods Table: Tag Drink Pool Items

```sql
ALTER TABLE template_foods ADD COLUMN is_drink_pool BOOLEAN DEFAULT false;
ALTER TABLE template_foods ADD COLUMN drink_pool_phases TEXT[];
-- e.g., '{full_meal,snack}' for OJ, '{snack,top_up}' for sports drink

UPDATE template_foods SET is_drink_pool = true, drink_pool_phases = '{full_meal}'
  WHERE name IN ('coffee', 'milk_whole');
UPDATE template_foods SET is_drink_pool = true, drink_pool_phases = '{full_meal,snack}'
  WHERE name IN ('orange_juice', 'chocolate_milk', 'fruit_smoothie');
UPDATE template_foods SET is_drink_pool = true, drink_pool_phases = '{snack,top_up}'
  WHERE name IN ('sports_drink', 'electrolyte_drink');
UPDATE template_foods SET is_drink_pool = true, drink_pool_phases = '{full_meal,snack,top_up}'
  WHERE name = 'water';
```

### templates Table: Add Conflict Metadata

```sql
ALTER TABLE templates ADD COLUMN food_names TEXT[];

UPDATE templates SET food_names = (
  SELECT array_agg(item->>'food_name')
  FROM jsonb_array_elements(foods) AS item
);
```

---

## Edge Cases

### 1. No Valid Food Templates After Filtering

If conflict avoidance filters eliminate all candidates for a phase:

- **Relax Layer 2** (food-name overlap): Allow overlap with secondary ingredients
- If still no candidates: **Relax Layer 1** (base_category): Allow same category if templates have different food compositions
- If still no candidates: Skip the phase and redistribute carbs to other phases

### 2. Carb Target Too Low for Any Template

For small athletes or short timing windows:

- Allow "partial" templates: scale to min_servings even if it slightly overshoots
- Or skip the food template entirely: phase becomes drink-only (valid for top offs)

### 3. Carb Target Too High for Any Template

For large athletes (> 90kg) with long timing windows:

- Scale to max_servings and accept the deficit (~10% tolerance)
- Or add a simple "bonus" item from staples: "+ 1 extra banana"

### 4. Drink Provides Most of Phase Carbs

If OJ at the full meal provides 26g of a 90g target, food template scales to 64g. This is fine and natural — OJ with breakfast is normal.

If sports drink at the snack provides 28g of a 38g target, food template scales to 10g. The snack becomes "a few rice cakes + sports drink" — also natural.

### 5. Food Already Exceeds Sodium/Fluid Targets

Some food templates are sodium-heavy (bagel = 462mg). If food alone hits the phase's sodium target:

- Drink selection skips sodium-containing options
- Water or low-sodium drink (coffee, OJ) is selected instead
- All drinks remain viable for the variety pool

### 6. No Sodium Gap at Any Phase

If the athlete has very low sodium needs AND food templates are sodium-rich:

- All phases default to water, coffee, OJ, or milk (low-sodium drinks)
- This is fine — not every athlete needs electrolyte supplementation

---

## Algorithm Summary (Pseudocode)

```
function generatePreWorkoutPlan(macroTargets, userPrefs, timingKey):

  // Step 1: Determine phases and split budgets
  phases = PHASE_SCHEDULE[timingKey]
  totalCarbs = macroTargets.carbs_g
  totalHydration = macroTargets.weight_kg * 10  // ACSM-based
  totalSodium = macroTargets.sodium_mg

  for each phase:
    phase.carbTarget = totalCarbs * phase.carbPct
    phase.hydrationTarget = totalHydration * HYDRATION_SPLITS[phase.role]
    phase.sodiumTarget = totalSodium * SODIUM_SPLITS[phase.role]

  // Step 2: For each phase, select food + drink
  selectedTemplates = []
  plan = []

  for phase in phases (ordered: full_meal, snack, top_up):

    // 2a. Select drink first (to determine carb contribution)
    drinkCandidates = DRINK_POOL
      .filter(d => d.drink_pool_phases.includes(phase.role))
      .filter(d => canFillGap(d, phase.sodiumTarget, phase.hydrationTarget))
    drink = randomSelect(drinkCandidates)
    drinkServings = calculateDrinkServings(drink, phase.sodiumTarget, phase.hydrationTarget)
    drinkCarbs = drinkServings * drink.carbs_per_serving

    // 2b. Adjust food carb target
    foodCarbTarget = phase.carbTarget - drinkCarbs

    // 2c. Select and scale food template
    candidates = filterFoodTemplates(phase, userPrefs, selectedTemplates)
    if candidates.empty AND foodCarbTarget < 10:
      // Drink-only phase (valid for top offs)
      plan.append({ phase, food: null, drink, drinkServings })
      continue

    template = randomFromTop3(rankByCarbFit(candidates, foodCarbTarget))
    scaled = scaleTemplate(template.foods, foodCarbTarget,
                           phase.hydrationTarget, phase.sodiumTarget)
    selectedTemplates.append(template)

    // 2d. Recalculate drink after knowing food's sodium/fluid contribution
    foodSodium = scaled.actualSodium
    foodFluid = scaled.actualFluid
    remainingSodium = max(0, phase.sodiumTarget - foodSodium)
    remainingFluid = max(0, phase.hydrationTarget - foodFluid)
    drinkServings = recalculateDrinkServings(drink, remainingSodium, remainingFluid)

    plan.append({ phase, food: scaled, drink, drinkServings })

  return plan


// Drink selection helpers
HYDRATION_SPLITS = { full_meal: 0.30, snack: 0.40, top_up: 0.30 }
SODIUM_SPLITS = { full_meal: 0.30, snack: 0.50, top_up: 0.20 }

CARB_SPLITS = {
  '3-4 hours': { full_meal: 0.60, snack: 0.25, top_up: 0.15 },
  '1-2 hours': { snack: 0.75, top_up: 0.25 },
  '30-60 min': { top_up: 1.0 },
  '< 30 min':  { top_up: 1.0 },
}
```

---

## Existing Implementation (templates_testing)

A working React + Vite testing app exists at `/development/templates_testing` with:

| Module | Status | Notes |
|--------|--------|-------|
| `macrosV3.js` | Complete | Client-side port of generate-macros-v3 edge function |
| `scaling.js` | Complete | Grid search over friendly fractions, multi-objective (carb/fluid/sodium) |
| `mealChain.js` | Complete (needs update) | Combo finder with scoring. Currently uses per-phase independent hydration calc — needs switch to budget-based splits. |
| `dietFilter.js` | Complete | Diet/allergen/preference filtering with diet-implied allergens |
| `MealChainValidator.jsx` | Complete | UI for testing combos across personas/timing/environment |

**Key changes needed in templates_testing:**
1. Replace per-phase independent hydration calculation with budget-based splits (30/40/30)
2. Replace per-phase independent sodium calculation with budget-based splits (30/50/20)
3. Add per-phase drink selection from drink pool
4. Update total hydration formula to `weightKg * 10` (ACSM-based)
5. Strip beverage items from template JSONB data

---

## Implementation Phases

### Phase 1: Data Cleanup + Core Algorithm
- Strip beverages from template JSONB foods arrays
- Tag drink pool items in template_foods
- Update mealChain.js with budget-based hydration/sodium splits
- Add per-phase drink selection logic
- Update total hydration formula to ACSM-based (10 ml/kg)

### Phase 2: Production Integration
- Port algorithm to edge function or Dart client
- Create Dart models for template + drink responses
- Build UI for phased pre-workout plan display
- Integrate with existing nutrition plan flow

### Phase 3: Personalization
- Diet preference filtering (vegan, paleo, keto)
- User drink preference tracking
- Configurable budget splits via Supabase content management
- A/B testing of different split ratios

### Phase 4: Extended Drink Pool
- Add Maurten 160/320, Tailwind, Skratch to template_foods
- High-carb drink selection logic for athletes who prefer liquid fuel
- Drink brand preferences

---

## Resolved Questions

1. **Budget split ratios**: 60/25/15 for carbs (from tested implementation). 70/25/5 for protein. 80/15/5 for fat. Hydration: 30/40/30 (ACSM-informed, snack-phase emphasis). Sodium: 30/50/20 (Sims protocol). Should be in Supabase app_config for remote tuning.

2. **Sodium/hydration distribution**: Evidence-based. Total fluid = 10 ml/kg (ACSM midpoint). Sodium concentrated at snack phase per Sims protocol. See "Hydration Evidence" section for citations.

3. **Where does this run?**: Client-side JavaScript (templates_testing) for development/testing. Production TBD — lightweight enough for client-side Dart, but server-side edge function enables A/B testing and remote tuning.

4. **Hydration approach**: Per-phase drink selection from timing-appropriate drink pool. NOT a separate global hydration layer. Each phase card shows food + drink together (dietitian model). Drink pool restricted to beverages only (no supplement tablets/packets).
