# 61-001 · The Swap screen and set_day_slot still offer or place a meal with no nutrition numbers, and Browse's Add on one shows a raw error

- kind: bug
- status: triaged
- ticket: 61
- run: w22-20260925T1215Z
- screen: Swap meal; Browse meals; none (set_day_slot action)
- decision: 

**Steps.**
1. Read `swap_meal_screen.dart`: its candidate list comes from `search_meals` called straight from Dart.
2. Read `set_day_slot` in `supabase/functions/_shared/vana/actions.ts`.
3. In Browse, tap Add on a library meal whose kcal is null.

**Expected.**
mp-678: a meal with missing numbers "stays browsable but is never put in a plan". No screen offers it as a pick into a plan, and Browse's Add says plainly that the meal can't go in a plan yet.

**Actual.**
Ticket 61 guarded every server add path through `addMeal`/`swapMeal`, so the write is refused. But the Swap screen still lists blank-number meals (tapping one fails with the server error), `set_day_slot` still lets a blank library or saved meal into a day slot by hand, and Browse's Add stays live and shows the raw English error `no nutrition numbers: … can't go in a plan`. Found in wave 22's review; code read, not seen on a device (dev has no blank meals since the 31 were filled).

**Evidence.**
- supabase/functions/_shared/vana/actions.ts (set_day_slot has no hasNutritionNumbers check)
- lib/features/meal_planning/presentation/screens/swap_meal_screen.dart (candidates from search_meals, unfiltered)
- supabase/functions/_shared/vana/plan-math.ts (hasNutritionNumbers)

**Decision quote.**
> 

**Triage.**
Fix ticket 74 (filed by the wave lead from wave 22's review, 2026-09-25). Closed by the retest after it merges.
