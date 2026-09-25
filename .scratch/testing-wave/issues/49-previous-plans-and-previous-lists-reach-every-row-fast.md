# 49: Previous plans and Previous lists reach every row, fast

**Status:** in-progress (wave 21, 2026-09-25)
**Blocked by:** 34 (touches supabase/functions/_shared/vana/plan.ts), 46 (touches lib/features/meal_planning/presentation/screens/shopping_tab.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The Previous plans sheet reaches every plan the athlete has (paging or a higher bound applied after dropping empty and current plans), and `list_plans` counts meals in one query, not one per plan. The Previous lists sheet scrolls, with no overflow stripe.

**Findings:** 17-001, 17-003, 19-003 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** supabase/functions/_shared/vana/plan.ts, lib/features/meal_planning/presentation/widgets/previous_plans_sheet.dart, lib/features/meal_planning/presentation/screens/shopping_tab.dart

- [ ] deno test: an account with 25 plans lists them all; one query counts the meals.
- [ ] Widget test: 14 lists scroll to the last with no overflow.
- [ ] Deployed to dev.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
