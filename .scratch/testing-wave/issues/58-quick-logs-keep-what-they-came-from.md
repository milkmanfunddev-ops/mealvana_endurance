# 58: Quick logs keep what they came from

**Status:** done (wave 23, 2026-09-25)
**Blocked by:** 54 (touches lib/features/meal_logging/presentation/providers/meal_log_providers.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Re-logging a meal from Recent saves a copy of the original: the same items (not one synthetic "1 serving" line), the same totals, and the original's `source` (a history re-log is not `saved`, and no `saved_meal_id` is invented). A Common quick-add tile saves under the tile's own name ("Rice cake + almond butter"), not a name built from its items, so Recent's de-duplication treats it as the same meal next time.

**Findings:** 26-002, 26-003 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes (a re-log saves the meal as the source had it).

**Touches:** lib/features/meal_logging/presentation/screens/log_meal_screen.dart, lib/features/meal_logging/presentation/widgets/log_sheet_helpers.dart, lib/features/meal_logging/domain/meal_auto_name.dart, lib/features/meal_logging/presentation/providers/meal_log_providers.dart

- [x] A seam test through the real notifier: re-logging a two-item Recent meal saves both items and the original's source.
- [x] A Common tile saves under its tile name.
- [x] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
