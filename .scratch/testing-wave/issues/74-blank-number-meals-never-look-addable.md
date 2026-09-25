# 74: Blank-number meals never look addable

**Status:** done (wave 24, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Finish mp-678 on the client and the last server path. The Swap screen does not offer a meal whose kcal, carbs, protein or fat is missing. `set_day_slot` refuses such a meal like `addMeal` does (ticket 61's `hasNutritionNumbers`). In Browse the meal stays listed, but its Add control says it can't go in a plan yet (a content-system message, not the server's English error) instead of failing after the tap.

**Findings:** 61-001 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** mp-678: a meal with missing numbers "stays browsable but is never put in a plan".

**Touches:** lib/features/meal_planning/presentation/screens/swap_meal_screen.dart, lib/features/meal_planning/presentation/widgets/meal_add_button.dart, lib/features/meal_planning/presentation/widgets/meal_catalog_browser.dart, supabase/functions/_shared/vana/actions.ts

- [x] A deno test: `set_day_slot` with a null-kcal library or saved meal is refused and writes nothing.
- [x] A widget test: the Swap list leaves out a blank-number meal.
- [x] A widget test: Browse shows a blank-number meal with Add unavailable and the message.
- [x] Deployed to dev. (wave lead, 2026-09-25 12:37 UTC; vana-action and vana-day-notes again 12:5x with the review fix)
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
