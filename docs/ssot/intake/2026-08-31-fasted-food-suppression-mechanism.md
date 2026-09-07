> **RESOLVED 2026-09-03 → option 2: FASTED RETIRED (class-c contract change, staged for this bundle; D-001/P17 close by removal; CONFIRMED explicitly by Xuan in-session 2026-09-03)**

type: ruling-request
bundle: pre-workout-macros@v2 (deferred ledger P11/P17; D-001)

## Why this matters
Reproduced again today on develop: a fasted plan that says "No carbs this session" ships an Applesauce Pouch — the D-001 ruling is already queued, but its implementation guidance needs the mechanism recorded here.

## The question (an addendum to D-001, not a new policy ask)
When D-001 is ruled (fasted = fluid-only, or fasted retired), which of the three stacked causes should the fix target? All three independently suffice to ship food on a fasted plan:
1. v3's fasted skip guard requires ALL FOUR pre targets ≤0, but fasted keeps water/sodium >0 → never skips (`generate-nutrition-plan-v3/before-phase.ts:187-197`);
2. v3 rebuilds `meal_type` as `isFasted = carbs≤0 && water≤0` → water>0 ⇒ not fasted, so v4's `meal_type==='fasted'` guard (`pre-workout.ts:1277`) never fires when v3 recomputes;
3. `scoreFormula` clamps ideal servings (0 at zero carb target) UP to `min_servings` → a template still renders food (`pre-workout-scoring.ts:96-99`).

## Evidence
F-8 (code), F-34 (sim reproduction 2026-08-31: `33.png`, `34.png` — fasted 1h run, "No carbs this session", Pre-Workout Snack: Applesauce Pouch). Cross-ref: deferred ledger P17; DEVIATIONS D-001.

## Recommendation
Whatever D-001 rules, fix (2) — carry `meal_type` (or `is_fasted`) across the v3 wire instead of re-deriving it — and (3) — zero carb target ⇒ no food template, fluid rows only. (1) then becomes belt-and-braces.

## Gates
P17 close-out; the fasted feeding contract in pre-workout-food-composition.

## Suggested spec home
Fold into the D-001 ruling's implementation note (DEVIATIONS.md → pre-workout-carbs.md post-ratification addition).

## RULING (Xuan, 2026-09-03, RULING-DESK block — option 2)
**The fasted toggle is RETIRED — fasted plans stop being a product state.** Impact class (c)
CONTRACT CHANGE: staged for the food-recommendation bundle, not folded into current ratified
specs. Scope at implementation: remove the Fasted Workout toggle, deprecate `is_fasted` on the
v4/v3 wire (server tolerates-and-ignores during migration), remove fasted branches from
calculatePreWorkoutTargets/Carbs and FC-4 rendering. D-001 and deferred-ledger P17/P11 close by
state removal. The three-cause mechanism above becomes moot.
