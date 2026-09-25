# 73: Previous plans: open, edit, rename, delete and use again

**Status:** done (wave 22, 2026-09-25)
**Blocked by:** 49 (touches lib/features/meal_planning/presentation/widgets/previous_plans_sheet.dart and supabase/functions/_shared/vana/plan.ts).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Plans are a list (Lee, 2026-09-25). From Previous plans the athlete opens any earlier plan and can edit it (meals and servings), rename it or delete it, not only view it. "Use this plan again" copies an earlier plan into this week as a new draft; confirming it replaces this week's plan like any new plan. A past week's leftover draft is not listed (the ruling on mp-671).

**Findings:** 17-002 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** the ruling on mp-668 and the new card for the plan list (Lee, 2026-09-25), and the ruling on mp-671.

**Touches:** lib/features/meal_planning/presentation/widgets/previous_plans_sheet.dart, lib/features/meal_planning/presentation/screens/previous_plan_screen.dart, lib/features/meal_planning/application/meal_plan_controller.dart, supabase/functions/_shared/vana/plan.ts, supabase/functions/_shared/vana/actions.ts

- [x] A deno test: use-again copies a plan's meals into this week's new draft; delete removes a plan; drafts are not listed.
- [x] Seam tests through the real notifier for edit, rename, delete and use again.
- [x] Deployed to dev. (wave lead, 2026-09-25 12:00 UTC)
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
