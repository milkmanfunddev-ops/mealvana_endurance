# 62: Pre-workout cards add up and say when

**Status:** in-progress (wave 22, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Each BEFORE phase card shows the fluid its own foods hold (the Top-Off card with 2 cups of water shows them), so the cards add up to the BEFORE header. A card's timing label is relative to the session: a session in the past or hours away never reads "NOW".

**Findings:** 30-004, 30-005 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/nutrition_plan/application/pre_workout_before_card_assembler.dart, lib/features/nutrition_plan/domain/pre_workout_before_card_model.dart, lib/features/nutrition_plan/domain/pre_workout_feeding_labels.dart

- [x] Assembler tests: card fluids sum to the header; the Top-Off card with water shows its fluid.
- [ ] Label tests: a session 3 days past and one 9 hours ahead read their real timing, not NOW.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
