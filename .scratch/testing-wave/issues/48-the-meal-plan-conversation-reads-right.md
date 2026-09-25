# 48: The meal-plan conversation reads right

**Status:** ready-for-agent
**Blocked by:** 34 (touches lib/features/meal_planning/presentation/screens/vana_chat_screen.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Meal cards in a resumed conversation tick the meals that are in that conversation's plan. A resumed conversation is headed by its plan (not "New meal plan"). The Review sheet counts in the singular for one ("1 meal · 1 serving"). A trailing question in Vana's bubble that equals the choice prompt below it shows once.

**Findings:** 15-003, 16-005, 16-004, 15-002 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/meal_planning/presentation/screens/vana_chat_screen.dart, lib/features/meal_planning/presentation/widgets/review_sheet.dart

- [ ] Widget tests for each of the four.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
