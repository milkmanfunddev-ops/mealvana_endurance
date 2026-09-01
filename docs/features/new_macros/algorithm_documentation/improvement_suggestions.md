# Pre-Workout Algorithm C: Improvement Suggestions

## Current Performance (2026-03-13)
| Metric | Score | Notes |
|--------|-------|-------|
| Carb accuracy | 112/112 (100%) | All within ±20% |
| Sodium accuracy | 112/112 (100%) | Range-based: floor+ceiling by meal type |
| Hydration accuracy | 112/112 (100%) | Range-based: floor+ceiling with min thresholds |
| Cross-phase repeat | 109/112 (97.3%) | 3 warns (catalog limitation for gluten-free heavy athletes) |

### Previous Performance (2026-03-12, fixed targets)
| Metric | Score | Notes |
|--------|-------|-------|
| Sodium accuracy | 89/112 (79.5%) | 23 warns at ±40% tolerance |
| Hydration accuracy | 110/112 (98.2%) | 2 warns at ±50% tolerance |

## Root Cause Analysis

### Sodium Overshooting (21 of 23 warns)

The core problem: **high-carb foods inherently bring high sodium**, and when the algorithm stacks multiple high-sodium formulas to reach large carb targets, sodium compounds dramatically.

**Formula sodium-to-carb ratios (the problem):**
```
HIGH SODIUM (>8 Na per gram carb):
  Bagel + PB             375mg Na / 28g carbs = 13.4 Na/carb
  Bagel + Cream Cheese   350mg Na / 27g carbs = 13.0
  Bagel + PB + Jam       380mg Na / 33g carbs = 11.5
  Toast + PB             225mg Na / 20g carbs = 11.3
  Bagel + Jam            305mg Na / 28g carbs = 10.9
  Toast + PB + Jam       230mg Na / 25g carbs = 9.2

LOW SODIUM (<3 Na per gram carb):
  Oatmeal                  0mg Na / 27g carbs = 0.0
  Oatmeal + Raisins        5mg Na / 35g carbs = 0.1
  Rice Cake + Jam         20mg Na / 10g carbs = 2.0
  Smoothie (Fruit)        51mg Na / 25g carbs = 2.0
  Energy Gel              50mg Na / 25g carbs = 2.0
```

**Worst case example — 80kg, 3.5h, no restrictions (target: 280g carbs, 775mg Na):**
```
meal:  Toast+PB+Jam@3 (690mg Na) + Rice Cake+PB+Jam@3.5 (332mg Na) + sports drink (230mg) = 1253mg Na
snack: Granola Bar@2 (300mg Na)
topup: Carb Drink Mix@2 (320mg Na)
TOTAL: 280g carbs ✅, 1873mg Na ❌ (141% over target)
```

The algorithm correctly delivers carbs but can't avoid sodium when it needs Toast+PB+Jam@3 (max servings, max sodium per serving) + a stacked formula.

### Sodium Undershooting (2 of 23 warns)

All-free diet restrictions (gluten+dairy+peanut) eliminate most high-sodium formulas, leaving only low-sodium options like Oatmeal (0mg Na) and Rice Cakes (20mg Na). The drink can only add so much.

### Hydration Overshooting (2 of 2 warns)

50kg dairy-free at 3.5h: the algorithm picks an electrolyte drink for sodium gap, but its minimum serving size (480ml) overshoots the low fluid target (325ml). Rare edge case.

---

## Improvement Suggestions

### 1. Add Low-Sodium Formula Alternatives (HIGH IMPACT)

The formula catalog is missing high-carb, low-sodium options that are common pre-race foods:

| Suggested Formula | Time Window | Carbs/srv | Na/srv | Na/carb ratio | Notes |
|-------------------|-------------|-----------|--------|---------------|-------|
| **Pancakes + Maple Syrup** | 1.5-3h | 30g | 150mg | 5.0 | Lower Na than toast+PB combos |
| **Rice + Honey** | 1.5-3h | 35g | 5mg | 0.1 | Very low Na, very high carb |
| **Fruit Bowl** | 30-90 min | 25g | 5mg | 0.2 | Apple/berries/grapes, nearly zero Na |
| **Sweet Potato** | 1.5-3h | 27g | 35mg | 1.3 | Common pre-race, low Na |
| **Pasta (plain)** | 1.5-3h | 35g | 5mg | 0.1 | Classic carb loading food |

These would give the algorithm low-sodium paths to high carb delivery. Currently the meal-window (1.5-3h) formulas are dominated by 200-380mg Na options. Adding rice/pasta/sweet potato at <35mg Na would be transformative for heavy athletes.

### 2. Dynamic Carb Budget Split for Heavy Athletes (MEDIUM IMPACT)

Current fixed split: **60% meal / 25% snack / 15% top-up**

For a 95kg athlete at 3.5h (333g target), the meal phase carries 200g of carbs. This forces stacking 2 formulas at max servings, compounding sodium.

**Suggestion:** Flatten the split when total carbs > 200g:
```
if totalCarbs > 200:
  meal: 50% (instead of 60%)
  snack: 30% (instead of 25%)
  top_up: 20% (instead of 15%)
```

This distributes carbs more evenly, reducing the need for extreme stacking in the meal phase. Each formula stays closer to comfortable serving sizes, and sodium from any single phase stays lower.

### 3. Sodium Budget Gate for Sports Drink Add-On (MEDIUM IMPACT)

The sports drink add-on adds **230mg Na** alongside just 17g carbs. It's the worst Na/carb ratio item in the plan (13.5:1). Currently the algorithm skips it when sodium would exceed 1.4x target, but for multi-phase plans this threshold may be too generous.

**Suggestion:** Track sodium budget across phases and only allow the sports drink when:
```
cumulative_sodium + 230 < sodium_target * 1.2
```

This is more conservative than the current 1.4x threshold but preserves carbs since sports drink only adds 17g (usually a small carb improvement).

### 4. Sodium-Aware Stacking (MEDIUM IMPACT)

When the algorithm stacks a second formula (because the primary is >20% short on carbs), it currently picks the one with the best carb gap. Among equally-close options, it prefers lower sodium, but only when the gap difference is <3g.

**Suggestion:** Widen the sodium preference window for stacking:
- Currently: prefer lower Na only when carb gaps differ by <3g
- Proposed: prefer lower Na when carb gaps differ by <8g (same as diversity floor)

Example: If Rice Cake+PB+Jam@3.5 (gap 5g, 332mg Na) and Oatmeal@2 (gap 8g, 0mg Na) are both stack candidates, the algorithm should prefer Oatmeal despite 3g worse carb gap.

### 5. Cap Meal Phase Sodium Independently (LOW IMPACT, EASY)

Add a per-phase sodium cap: if a single phase's sodium exceeds 600mg, prefer alternative formulas for that phase even at slight carb cost.

This prevents the worst offenders like meal phases with 1200+ mg sodium.

### 6. Improve Sodium Targets for Short Windows (LOW IMPACT)

For <1h windows, sodium target is fixed at 100mg (`topUpSodium = envBump + 100`). This is very low — even Energy Gel@1 delivers 50mg, and Carb Drink Mix@1 delivers 160mg. Consider whether 100mg is too aggressive for the formula granularity available.

**Suggestion:** Raise short-window sodium target from 100mg to 200mg, which would bring Carb Drink Mix@1 (160mg) within tolerance.

### 7. Add Formula Sodium to Catalog Database Schema (FUTURE)

The current pre_workout_formulas are hardcoded in the test suite. When moving to production, ensure `sodium_mg` and `fluid_ml` are stored per formula in the database (not just in template_foods) so the algorithm can access them for scoring.

---

## Priority Ranking

| # | Suggestion | Impact | Effort | Status |
|---|-----------|--------|--------|--------|
| 1 | Add low-sodium formulas | High | Low (add data) | **SUPERSEDED** — range approach eliminates need |
| 2 | Dynamic carb budget split | Medium (reduce stacking) | Low (logic change) | Open |
| 6 | Raise short-window Na target | Low | Trivial | **RESOLVED** — range approach covers this |
| 3 | Sports drink Na budget gate | Medium | Low | **SUPERSEDED** — range approach accepts sports drink sodium |
| 4 | Wider sodium preference for stacking | Medium | Low | Open (still beneficial for variety) |
| 5 | Per-phase sodium cap | Low | Medium | **SUPERSEDED** — range approach eliminates need |
| 7 | Database schema update | Future | Medium | Open |

### Resolution Note (2026-03-13)

Suggestions #1, #3, #5, and #6 were superseded by the **range-based sodium approach**. Instead of trying to hit a precise sodium target (which is scientifically meaningless in the 500-2500mg "dead zone"), we now use floor+ceiling ranges by meal type. This eliminates all sodium warnings without needing low-sodium formulas, sports drink gates, or per-phase caps.

See `range-based-targets-plan.md` for full rationale.

## Remaining Improvements

1. **Dynamic carb budget split** (#2) — Still valuable for reducing stacking in heavy athletes
2. **Wider sodium preference for stacking** (#4) — Still helps with food variety
3. **Database schema update** (#7) — Needed for production deployment
