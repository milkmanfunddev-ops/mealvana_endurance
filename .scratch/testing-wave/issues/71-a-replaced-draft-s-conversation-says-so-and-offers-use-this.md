# 71: A replaced draft's conversation says so and offers Use this plan instead

**Status:** in-progress (wave 23, 2026-09-25)
**Blocked by:** 70 (touches lib/features/meal_planning/presentation/screens/vana_chat_screen.dart), 73 (Use this plan again).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** When another confirm has archived a conversation's draft (mp-241), reopening that conversation says the athlete confirmed a different plan for this week and this one is kept in their plans. The plan shows read-only (no servings controls, no remove, no Confirm) with "Use this plan instead", which copies it as this week's new draft (ticket 73's action).

**Findings:** 15-001 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** mp-241, and the ruling on mp-670 (Lee, 2026-09-25).

**Touches:** lib/features/meal_planning/presentation/screens/vana_chat_screen.dart, lib/features/meal_planning/presentation/widgets/plan_bar.dart, lib/features/meal_planning/presentation/widgets/review_sheet.dart

- [x] A widget test: an archived draft's conversation shows the note, no Confirm and no servings controls.
- [x] Use this plan instead makes a new draft for this week with the same meals.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
