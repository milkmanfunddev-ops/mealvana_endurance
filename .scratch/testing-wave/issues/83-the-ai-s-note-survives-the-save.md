# 83: The AI's note survives the save

**Status:** done (wave 24, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The note the AI writes for a described or photographed meal, shown on Review & Log, is saved to `meal_logs.notes` and shows again in Edit Meal (23-002). Offline-first: the local row carries it and the upload sends it.

**Findings:** 23-002 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/meal_logging/presentation/providers/draft_meal_controller.dart, lib/features/meal_logging/application/meal_logging_service.dart

- [x] A seam test through the real notifier: a draft with an AI note logs a row whose notes equal it, locally and in the upload payload.
- [x] Edit Meal shows the note (widget test).
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
