# 29-001 · saveNutritionTargetOverrides on develop wiped body fat, lifestyle, training phase, sweat test and Garmin timestamps on every override save

- kind: bug
- status: closed
- ticket: 29
- run: w2-20261007T1340Z
- screen: Settings > Nutrition targets (override save)
- decision: fixed by ticket 29 (e663c3bb); retest ticket 50 (Settings > Nutrition targets override keeps the profile fields), wave 5

**Steps.**
1. On develop before ticket 29: set body fat, lifestyle, training phase, a sweat test and connect Garmin.
2. Save a nutrition target override.
3. Reload the profile.

**Expected.**
Only the override fields change; body fat, lifestyle, training phase, sweat test and the Garmin timestamps survive.

**Actual.**
Develop's `saveNutritionTargetOverrides` rebuilt the profile without those fields, so every override save silently wiped body fat, lifestyle, training phase, sweat test and the Garmin timestamps. Fixed on mealplanning by `e663c3bb` (overrides-clear part), brought to develop-next by ticket 29 (`runs/29/notes.md`, items 30 and "also taken"), with `nutrition_overrides_clear_test`. Filed so BUGS.md records that develop carried it.

**Evidence.**
- `.scratch/testing-wave/rounds/develop-2026-10/runs/29/notes.md` lines 44 and 63
- `test/features/settings/nutrition_overrides_clear_test.dart` (brought with the fix)

**Decision quote.**
> 

**Triage.**
fixed by ticket 29 (wave 2, 2026-10-07); awaiting retest in wave 3 (ticket 30 or 33, whichever covers profile saves). Status moves to closed once the retest passes.

