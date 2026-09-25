# 54: Recent updates at once, and edits keep the server's created time

**Status:** done (wave 22, 2026-09-25)
**Blocked by:** 50 (touches lib/features/meal_logging/presentation/providers/meal_log_providers.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A meal re-logged from Recent (or logged from a recipe) moves to the top of Recent without reopening Log a Meal. Editing or deleting a meal log no longer rewrites the server's `created_at` from the phone's copy.

**Findings:** 26-005, 27-002 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/meal_logging/presentation/providers/meal_log_providers.dart, lib/features/meal_logging/domain/meal_log.dart

- [x] Seam test: after `logRecipe` and a Recent re-log, `recentMealsProvider` lists the meal first.
- [x] Unit test: the upsert payload for an edit carries no `created_at`.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
