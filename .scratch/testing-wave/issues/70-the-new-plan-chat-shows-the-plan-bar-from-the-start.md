# 70: The new-plan chat shows the plan bar from the start

**Status:** in-progress (wave 22, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Tapping New meal plan keeps this week's plan as it is (the ruling on mp-668: the current plan stays until the new plan is confirmed). The new conversation shows the plan bar from the start at "Your plan · 0 meals", before any pick.

**Findings:** 14-001, 14-002 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** mp-234, and the ruling on mp-668 (Lee, 2026-09-25).

**Touches:** lib/features/meal_planning/presentation/screens/vana_chat_screen.dart, lib/features/meal_planning/presentation/widgets/plan_bar.dart

- [x] A widget test: a new meal-plan conversation shows "Your plan · 0 meals" before any pick.
- [x] A test: New meal plan leaves this week's confirmed plan confirmed.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
