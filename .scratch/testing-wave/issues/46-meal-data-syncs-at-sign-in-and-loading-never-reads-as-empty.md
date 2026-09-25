# 46: Meal data syncs at sign-in, and loading never reads as empty

**Status:** in-progress (wave 20, 2026-09-25)
**Blocked by:** 36 (touches lib/features/meal_planning/presentation/screens/shopping_tab.dart).
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** Meal logs, saved meals and meal plans are synced where they are read (repository-level `ensureSynced`, never a startup sync-all), so the timeline, Log a Meal's Recent tab, the Plan sub-tab and the Shopping sub-tab show the athlete's data after sign-in without first opening Food. While a read is in flight the screens show a loading state, never "No plan yet" or "No shopping list", and the Shopping list does not jump when the server copy replaces the local one.

**Findings:** 10-001, 26-001, 19-004, 16-003, 20-003 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/shared/services/sync/sync_coordinator.dart, lib/features/meal_logging/presentation/providers/meal_log_providers.dart, lib/features/meal_planning/presentation/screens/plan_tab.dart, lib/features/meal_planning/presentation/screens/shopping_tab.dart

- [ ] After a fresh sign-in the timeline shows a meal logged earlier, before Food is opened (seam test with producer-shaped rows).
- [ ] Recent lists earlier meals on a fresh sign-in.
- [ ] Plan and Shopping show a loading state, not their empty states, until the first read answers.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
