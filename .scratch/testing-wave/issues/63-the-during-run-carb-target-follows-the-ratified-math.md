# 63: The during-run carb target follows the ratified math

**Status:** in-progress (wave 22, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The stored during-run carb target sits inside its own band and follows "The math (RATIFIED)" in `docs/ssot/spec/fueling/during-workout-carbs.md`, which says body weight must not change the rate. Start from `docs/ssot/vectors/`: if the vectors agree with the spec and the engine disagrees, fix the engine until the vectors go green. If the vectors themselves produce 91 g for Finding 30-003's run, stop: the question goes to Xuan (the QA repo owns the spec), and this ticket reports it instead of changing code.

**Findings:** 30-003 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** the ratified spec `docs/ssot/spec/fueling/during-workout-carbs.md` ("The math (RATIFIED)").

**Touches:** lib/features/nutrition_plan/application/macro_generation_service.dart, lib/features/nutrition_plan/data/offline_macro_calculator.dart, lib/features/nutrition_plan/domain/macro_targets.dart, test/qa_conformance/

- [ ] The vectors for during-run carbs are green against the engine (or the ticket reports why the spec and vectors disagree, for Xuan).
- [x] Finding 30-003's run (12 mi, 91 g vs 97-126 g band) reproduced in a test and landing inside the band.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
