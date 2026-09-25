# 41: Unknown numbers stay unknown in meal logs

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A decimal calorie value (250.5) saves as that number, not null, on both the Manual tab and Build a Meal's manual form; the fields and the parser agree. Totals over items whose sodium is missing stay null (unknown), never 0 (`null ≠ 0`).

**Findings:** 25-001, 26-004 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/meal_logging/presentation/widgets/manual_log_form.dart, lib/features/meal_logging/presentation/widgets/manual_component_form.dart, lib/features/meal_logging/domain/consumed_totals.dart, lib/features/meal_logging/presentation/screens/log_meal_screen.dart

- [ ] 250.5 kcal saves as 250.5 (or rounds as the column requires) and shows on the timeline (seam test through the real notifier).
- [ ] A quick add of two items with no sodium saves `sodium_mg` null.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
