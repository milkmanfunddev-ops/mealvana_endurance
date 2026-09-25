# 34: Confirm and Browse act on the conversation's own plan

**Status:** in-progress (wave 19, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** The Review sheet's Confirm sends the conversation's plan (conversation id or plan id), so the server confirms the Draft on screen and never falls back to "the week's active plan". Browse knows which meals are already in the conversation's plan: they show as added when Browse opens again, and a meal already in the plan is never added a second time by a tap on its card or on the detail's Add to plan (servings do not double without the athlete choosing that).

**Findings:** 16-001, 18-001, 18-003 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/meal_planning/presentation/screens/vana_chat_screen.dart, lib/features/meal_planning/presentation/widgets/review_sheet.dart, lib/features/meal_planning/application/meal_plan_controller.dart, lib/features/meal_planning/presentation/screens/vana_browse_screen.dart, lib/features/meal_planning/presentation/widgets/meal_catalog_browser.dart, lib/features/meal_planning/presentation/widgets/meal_add_button.dart, supabase/functions/_shared/vana/plan.ts, supabase/functions/_shared/vana/actions.ts

- [ ] Confirm in a Draft's conversation, while the week already has a confirmed plan, confirms that Draft and archives the old plan (deno test on `resolvePlan`/confirm, plus a seam test through the real notifier that the call carries the scope).
- [ ] Reopened Browse shows meals already in the plan as added.
- [ ] Add to plan on a meal already in the plan does not raise its servings.
- [ ] Deployed to dev; retest 16-011.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
