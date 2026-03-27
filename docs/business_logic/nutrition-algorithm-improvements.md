# Nutrition Algorithm Improvement Recommendations

> **This document is recommendations only — no code changes.** Each section explains the problem in plain English, the recommended fix, and which files would need to change.

---

## A. LP Rounding Problem

**File:** `_shared/nutrition/lp-solver.ts` (lines ~265-415)

### What's happening
The LP solver finds optimal food quantities as continuous values — e.g., "2.3 servings of energy gel." But you can't eat 0.3 of a gel. So it rounds to the nearest 0.5 increment (2.5 servings). That extra 0.2 servings means +5g carbs, +1g sodium, etc.

The solver tries to fix this by tweaking other foods, but it only tries **3 correction iterations** and only adjusts by **0.5 servings per step**. For small targets (like 20g carbs), one rounding step can overshoot by 25%.

### Example
- Target: 20g carbs [18-22g range]
- LP solution: 0.8 servings gel (20g carbs) + 1.3 servings water (0g carbs) = 20g total
- After rounding: 1.0 servings gel (25g carbs) + 1.5 servings water (0g carbs) = 25g total
- Result: 25% overshoot, out of range

### Recommended fix
After rounding the primary foods, re-run the LP solver with rounded foods **locked in** as fixed constraints. Let the remaining (divisible) foods compensate precisely. This is a "round-then-resolve" approach that guarantees the final solution respects the original constraints as closely as possible.

Alternatively, increase the correction iteration limit from 3 to 10 and reduce the adjustment increment from 0.5 to 0.25 for targets under 30g.

### Files affected
- `_shared/nutrition/lp-solver.ts`

---

## B. During-Phase Sequential Picks Can't Backtrack

**File:** `_shared/nutrition/during-rule-solver.ts`

### What's happening
The during-phase solver picks foods in a fixed order: carb source -> sports drink -> water -> electrolytes. If Step 1 picks a gel that gives 25g carbs but the target was 20g, it can't undo that choice. It just logs a warning and moves on.

This matters because:
- The food pool for during phase is small (typically 4-8 candidate foods)
- The number of "slots" is small (1-4 foods)
- A single bad pick in Step 1 cascades to all subsequent steps

### Example
- Target: 20g carbs, 300mg sodium
- Step 1 picks energy gel (25g carbs, 50mg sodium) — overshoots carbs
- Steps 2-4 can't reduce carbs, only add more
- Final: 28g carbs (40% over target), 320mg sodium (fine)

### Recommended fix
With only 4-8 candidate foods and 1-4 slots, **try ALL valid combinations** (~280 combos maximum) and pick the best one. This is called "exhaustive enumeration" and is trivially fast for this problem size — it would run in under 1ms.

Implementation: generate all permutations of (food, quantity) tuples that respect constraints, score each by total macro deviation, return the best.

### Files affected
- `_shared/nutrition/during-rule-solver.ts`

---

## C. LP Score Doesn't Penalize Being Near the Ceiling

**File:** `_shared/nutrition/lp-solver.ts` (in `buildLPModel()`)

### What's happening
The LP solver maximizes a "score" that rewards foods based on how well they fill macro targets. But it **doesn't penalize** getting close to the upper limit of a constraint. So it picks solutions right at the boundary — and then rounding pushes them over.

### Example
- Carb range: [18g, 22g]
- LP finds a solution at exactly 22.0g (maximum allowed) — this scores the same as 20.0g
- Rounding pushes it to 23.5g — now out of range
- If the LP had targeted 20.0g (center), rounding to 21.0g would still be in range

### Recommended fix
Add a small penalty in the score formula that discourages solutions near the constraint boundaries:

```
penalty = 0.5 * max(0, (actual - midpoint) / (max - midpoint))
```

This nudges the LP toward the **center** of the acceptable range, leaving headroom for rounding. The penalty weight (0.5) is small enough not to override food preference scores but large enough to avoid boundary solutions.

### Files affected
- `_shared/nutrition/lp-solver.ts` (`buildLPModel()`)

---

## D. Before-Phase Only Optimizes for Carbs

**File:** `generate-macros-v4/pre-workout.ts` (in `selectPreWorkoutFoods()`)

### What's happening
Algorithm C scores pre-workout templates by how well they fill the **carb target**. Protein and sodium are afterthoughts — they're filled by whatever the carb-optimal template happens to contain. So you might nail 100% of the carb target but only 60% of the protein target.

### Example
- Targets: 60g carbs, 20g protein, 400mg sodium
- Algorithm C picks "Oatmeal + Banana" (58g carbs, 8g protein, 50mg sodium)
- Carbs: 97% hit. Protein: 40% hit. Sodium: 13% hit.

### Recommended fix
Run Algorithm C **3 times** with different random diversity picks (it already uses a "diversity band" of 15% of best scores). For each run, score the result on **ALL macros combined**, not just carbs:

```
combined_score = 0.5 * carb_accuracy + 0.3 * protein_accuracy + 0.2 * sodium_accuracy
```

Pick the run that maximizes the combined score. This takes ~3x longer (still < 5ms total) but produces much more balanced results.

### Files affected
- `generate-macros-v4/pre-workout.ts` (`selectPreWorkoutFoods()`)

---

## E. Food Pool Gaps — Missing Food Types

**Tables affected:** `template_foods`, `pre_workout_templates`

### What's happening
Some macro target combinations can't be achieved because the `template_foods` table doesn't have foods with the right nutritional profiles. The solver can only pick from what's available — if no food can satisfy both carbs AND protein constraints simultaneously, the best solution will still violate one constraint.

### Example
- After-phase target: 40g protein + 30g carbs
- Available high-protein foods all have 50g+ carbs (chocolate milk, recovery shakes)
- Available moderate-carb foods have < 10g protein (banana, toast)
- LP can't find a combination that hits both targets

### Recommended fix
1. **Audit query**: Run `generate-macros-v4` across 100 representative personas (varying weight, duration, sport). Collect the output macro targets for each phase.
2. **Gap analysis**: For each target combination, check whether `template_foods` has foods that can plausibly satisfy the constraints. Identify "dead zones" where no combination works.
3. **Add missing foods**: Likely gaps include:
   - Moderate-carb/high-protein recovery options (Greek yogurt with berries, protein bar with moderate carbs)
   - High-sodium/low-carb options for during phase (broth, salted nuts)
   - Low-carb electrolyte options for short activities

### Tables affected
- `template_foods` — add new rows for underserved macro combinations
- `pre_workout_templates` — potentially add templates with better protein/sodium profiles
