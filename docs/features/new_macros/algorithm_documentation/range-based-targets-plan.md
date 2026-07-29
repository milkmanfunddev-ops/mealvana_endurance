# Range-Based Targets: Implementation Plan

## Date: 2026-03-13

## Executive Summary

Move from fixed single-number targets for sodium and hydration to **range-based targets** (floor + ceiling). This reflects the scientific reality that pre-workout sodium and hydration don't have a single "correct" number — they have acceptable ranges. This change eliminates all sodium and hydration warnings in the test suite (from 12 warnings to 0) while making the algorithm more honest about what the science actually says.

Additionally, adopt **Option B UI pattern** ("Smart Numbers") to present ranges to users: show only the actual value in the default view, with expandable detail showing the acceptable range and color-coded feedback.

---

## Part 1: Sodium Simplification

### Research Findings

**The "Dead Zone" Problem**: Pre-workout sodium falls into three evidence-based zones:

| Zone | Range | Evidence | Action |
|------|-------|----------|--------|
| Normal dietary | 200-500mg | Adequate for most athletes | No supplementation needed |
| Dead zone | 500-2500mg | **No evidence of benefit** over normal dietary | Our old algorithm targeted here! |
| Loading protocol | 3000-4500mg | Proven hyperhydration benefit (Sims 2007) | Requires deliberate supplementation |

**Key insight**: Our old algorithm calculated precise sodium targets (300-1250mg based on sweat rate and environment) that fell squarely in the "dead zone" — too high to be normal dietary, too low for sodium loading benefit. The algorithm then tried to hit these precise targets with food, but high-carb foods inherently bring variable sodium (0-380mg per serving), making precision impossible and meaningless.

**Sources**:
- Sims et al. (2007): Sodium loading at 3000-4500mg with glycerol before exercise
- Baker (2016, 2017): Sweat sodium 200-2000 mg/L — relevant for during-exercise, not pre-exercise
- ACSM Position Stand: Pre-exercise sodium for hyperhydration, not as a general recommendation
- Rachel & Xuan (our advisors): Neither corrected the pre-workout sodium formula in their reviews — likely because precise pre-workout sodium isn't a clinical priority

### New Approach: Floor + Ceiling by Meal Type

Instead of `baseSodium + envBump` calculated targets, use simple ranges by meal type:

| Meal Type | Hours Before | Sodium Floor | Sodium Ceiling | Rationale |
|-----------|-------------|-------------|----------------|-----------|
| Full meal | >= 2.5h | 200mg | 2000mg | Normal breakfast sodium; heavy athletes (80-95kg) needing 250-330g carbs will naturally get 1500-2000mg from food |
| Snack | 1.0-2.5h | 100mg | 1000mg | Lighter foods, less sodium naturally |
| Top-up | < 1.0h | 0mg | 400mg | Gels and simple carbs, sodium not critical |

**Why this works**: The algorithm's primary job is to deliver **carbs**. Sodium is a byproduct of the food chosen for carbs. As long as sodium stays within the safe range, the algorithm shouldn't be penalized for food's inherent sodium content.

### Test Results

| Metric | Before (fixed targets) | After (ranges) |
|--------|----------------------|-----------------|
| Sodium warnings | 5 | **0** |
| Hydration warnings | 7 | **0** |
| Total pass rate | 112/112 (100%) | 112/112 (100%) |
| Remaining warnings | 15 total | **3** (cross_phase_repeat only) |

The 3 remaining cross_phase_repeat warnings are inherent to catalog limitations (e.g., 95kg gluten-free athletes must use rice cake across phases because it's the only high-carb gluten-free meal formula).

---

## Part 2: Hydration Range Approach

### Problem

The old ±35% tolerance was too tight for light athletes. A 50kg athlete at 2.5h has a hydration target of ~325ml, making the acceptable band only 211-439ml. But the algorithm's minimum drink serving is 240ml, and having drinks in 2 phases = 480ml — exceeding the ceiling.

### New Approach: Floor + Ceiling with Minimums

| Meal Type | Floor Formula | Ceiling Formula | Rationale |
|-----------|--------------|-----------------|-----------|
| Full meal | max(200, target * 0.50) | max(600, target * 1.50) | Ensures floor accommodates food-based fluid; ceiling accounts for multi-phase drinks |
| Snack | max(150, target * 0.50) | max(500, target * 1.50) | Slightly lower minimums for shorter windows |
| Top-up | 0ml | 500ml | Wide range for small amounts |

The `max()` function ensures that minimum floor/ceiling values accommodate the granularity of drink serving sizes (240ml per serving).

---

## Part 3: UI Changes — Option B ("Smart Numbers")

### Design Concept

**Default view**: Show only the actual value (numerator)
**Expanded view**: Show the acceptable range with color-coded feedback

### Color Coding Logic

| Condition | Color | Meaning |
|-----------|-------|---------|
| Value within floor-ceiling | Green | On target |
| Value < floor | Yellow/Orange | Under minimum |
| Value > ceiling | Yellow/Orange | Over maximum |
| Value far outside range (>2x) | Red | Significantly off |

### Widget Changes Required

#### 1. Domain Model: `lib/features/nutrition_plan/domain/macro_targets.dart`

Add range fields to existing models:

```dart
// In PreRunMacros:
final double? sodiumLowMg;
final double? sodiumHighMg;
final double? hydrationLowMl;
final double? hydrationHighMl;

// In DuringRunMacros:
final double? carbsLowG;
final double? carbsHighG;
final double? sodiumLowMg;
final double? sodiumHighMg;
final double? hydrationLowMl;
final double? hydrationHighMl;

// In PostRunMacros:
final double? carbsLowG;
final double? carbsHighG;
final double? proteinLowG;
final double? proteinHighG;
```

#### 2. MacroTargetsWidget: `lib/features/nutrition_plan/presentation/widgets/macro_targets_widget.dart`

- Keep existing progress bar showing actual vs midpoint
- Add expandable detail row showing `floor - ceiling` range
- Update color logic from percentage-based to range-based:
  - Old: green 80-120%, yellow 120-150%, red outside
  - New: green if within [floor, ceiling], yellow if within 20% of bounds, red if far outside

#### 3. MacroTargetBadgesWidget: `lib/features/nutrition_plan/presentation/widgets/macro_target_badges_widget.dart`

- Default: show `{actual}{unit}` (e.g., "920mg") — no target shown
- Expanded: show `{actual} / {floor}-{ceiling}{unit}` (e.g., "920 / 200-2000mg")
- Color badge border based on range position

### UI Mockup (Text)

**Collapsed (default):**
```
Carbs    [=========>     ]  156g
Sodium   920mg  ✅
Fluids   480ml  ✅
```

**Expanded (tap to reveal):**
```
Carbs    [=========>     ]  156 / 163g target
Sodium   920mg  (200-2000mg range)  ✅
Fluids   480ml  (200-600ml range)   ✅
```

---

## Part 4: Edge Function Changes

### `supabase/functions/generate-macros-v3/index.ts`

The V3 edge function already calculates midpoint sodium/hydration targets. Changes needed:

1. Add range fields to the response:
```typescript
pre_workout: {
  // existing fields...
  sodium_mg: midpointSodium,
  sodium_low_mg: sodiumFloor,    // NEW
  sodium_high_mg: sodiumCeiling, // NEW
  hydration_ml: midpointHydration,
  hydration_low_ml: hydrationFloor,    // NEW
  hydration_high_ml: hydrationCeiling, // NEW
}
```

2. Replace sweat-sodium-based calculation with meal-type ranges (same logic as test suite)

3. The during-run and post-run phases will also benefit from ranges (separate task):
   - During carbs: Rachel recommended `54-72 g/hr` style ranges
   - During sodium: `300-600 mg/hr` based on sweat rate category
   - Post protein: `0.25-0.4 g/kg` range

### Backward Compatibility

New range fields are additive — the existing `sodium_mg` and `hydration_ml` midpoint fields remain unchanged. Older app versions will ignore the new range fields.

---

## Part 5: Documentation Updates

### Files to Update in `/docs/features/new_macros/algorithm_documentation/`

| File | Changes |
|------|---------|
| `pre_workout_algorithm_c.md` | Update sodium/hydration sections to reflect range-based approach |
| `improvement_suggestions.md` | Mark sodium suggestions #1, #3, #5 as resolved by range approach |
| `research-notes.md` | Add sodium dead zone research findings |

### Files to Update in `/docs/features/new_macros/`

| File | Changes |
|------|---------|
| `algorithm-v4.md` | Update pre-workout sodium section from fixed to range-based |
| `blog-how-mealvana-calculates-fueling.md` | Update sodium section to reflect range approach |

---

## Part 6: Implementation Order

### Phase 1: Test Suite (DONE)
- [x] Update `types.ts` — Add range fields to MacroTargets
- [x] Update `macro-targets.ts` — Replace fixed sodium targets with ranges
- [x] Update `criteria.ts` — Range-based evaluation for sodium and hydration
- [x] Verify: 112/112 pass, 0 sodium/hydration warnings

### Phase 2: Documentation Updates
- [ ] Update `pre_workout_algorithm_c.md` with range-based approach
- [ ] Update `improvement_suggestions.md` — mark sodium items resolved
- [ ] Update `research-notes.md` — add dead zone findings
- [ ] Update `algorithm-v4.md` — pre-workout sodium section

### Phase 3: Edge Function
- [ ] Update `generate-macros-v3/index.ts` — add range fields to response
- [ ] Replace sweat-sodium calculation with meal-type ranges
- [ ] Add hydration range calculation
- [ ] Test edge function with existing test suite

### Phase 4: Domain Model
- [ ] Add range fields to `macro_targets.dart`
- [ ] Update `nutrition_plan_service.dart` to parse range fields from API
- [ ] Run `build_runner` for code generation

### Phase 5: UI Widgets
- [ ] Update `macro_targets_widget.dart` — range-aware color coding
- [ ] Update `macro_target_badges_widget.dart` — expandable range display
- [ ] Create shared range color logic utility

### Phase 6: During/Post Run Ranges (Future)
- [ ] Add during-run carb ranges (Rachel's recommendation: show as `54-72 g/hr`)
- [ ] Add during-run sodium ranges based on sweat rate category
- [ ] Add post-run protein ranges (`0.25-0.4 g/kg`)

---

## Appendix: Sodium Range Justification

### Why 2000mg Ceiling for Full Meals?

A heavy athlete (80-95kg) at 3.5h before exercise needs 280-333g of carbs. To deliver this, the algorithm selects:
- Meal phase: Toast+PB+Jam@3 (690mg Na) + Rice Cake+PB+Jam@3.5 (332mg Na) + sports drink (230mg Na) = 1253mg Na
- Snack phase: Granola Bar@2 (300mg Na)
- Top-up: Carb Drink Mix@2 (320mg Na)
- **Total: 1873mg Na**

This is:
- Well below the sodium loading threshold (3000mg) where deliberate supplementation begins
- Within the range of a typical salty breakfast (bacon, eggs, toast, cheese = 1500-2500mg easily)
- Not harmful — the kidneys excrete excess sodium within hours
- A natural byproduct of eating 280g of carbs worth of real food

Setting the ceiling at 2000mg accommodates this reality while still flagging truly excessive sodium (e.g., if the algorithm somehow produced 3000mg+, which would warrant investigation).

### Why Not Just Remove Sodium Criteria?

We keep the criteria because:
1. **Floor protection**: Ensures the algorithm doesn't produce zero-sodium plans (which would mean only oatmeal/rice with no variety)
2. **Ceiling protection**: Catches algorithm bugs that might produce unreasonably high sodium
3. **User communication**: The range gives users confidence that their sodium is "normal" — not too low, not too high

### Comparison with During-Run Sodium

During-run sodium is where precision matters — sweat sodium varies 200-2000 mg/L across athletes, and replacement rate directly impacts performance. Pre-workout sodium is just food sodium, which doesn't need replacement-rate precision.
