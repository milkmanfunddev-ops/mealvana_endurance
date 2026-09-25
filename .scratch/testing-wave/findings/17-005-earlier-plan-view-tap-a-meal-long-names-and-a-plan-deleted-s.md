# 17-005 · Earlier plan view: tap a meal, long names, and a plan deleted since the list was read

- kind: followup-test
- status: triaged
- ticket: 17
- run: w12-20260924T1712Z
- screen: Earlier plan view ("An earlier plan. View only.")
- decision: 

**Steps.**
1. Open an earlier plan and tap a meal row. Does it open the meal's detail, and does that detail offer Log, Swap, Delete or servings changes that would write to an archived plan?
2. Check what ×N shows: `servings` or `servings_left` (every opened plan had them equal, so this run could not tell).
3. Open the sheet, delete that plan elsewhere (another device, or SQL on a throwaway account), then tap its row: `planById` answers null; what does the view show?
4. Open a plan whose `meal_plans.days` is set (d5b89888 or 83eb5608, once 17-001 lets them show) and check the days and day notes shown against the stored rows.
5. Scroll a plan with more meals than fit the screen; check long names wrap without clipping.

**Expected.**
The view stays read-only everywhere reachable from it; a deleted plan shows a clear message; days shown equal `meal_plans.days`.

**Actual.**
Not run (followup). Three opened plans (f2c0bc78, fc9687ff, 0694c723) matched their `plan_meals` rows in name, slot, servings, macros and order; no row offered an action.

**Evidence.**
- runs/17/10-opened-plan-sep13-6meals.png — the view.
- runs/17/15-opened-plan-aug30-4meals.png — a second plan.

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 89 (Lee, 2026-09-25).
