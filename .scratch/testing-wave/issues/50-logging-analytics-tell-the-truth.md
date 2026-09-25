# 50: Logging analytics tell the truth

**Status:** done (wave 21, 2026-09-25)
**Blocked by:** 41 (touches lib/features/meal_logging/presentation/screens/log_meal_screen.dart), 46 (touches lib/features/meal_logging/presentation/providers/meal_log_providers.dart), 33 (touches lib/features/settings/presentation/providers/settings_controller.dart), 45 (touches lib/features/subscription/presentation/screens/paywall_screen.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** `diary_closed` fires with the real `items_logged` after a photo, describe or manual log (not 0 as Review & Log opens). Removing a meal from the timeline tracks `meal_log_deleted`. Deleting an account from the paywall menu is tracked as a paywall event, not `settings_delete_account_tapped`.

**Findings:** 24-002, 27-003, 04-001 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/meal_logging/presentation/screens/log_meal_screen.dart, lib/features/meal_logging/presentation/providers/meal_log_providers.dart, lib/features/settings/presentation/providers/settings_controller.dart, lib/features/subscription/presentation/screens/paywall_screen.dart

- [x] Tests on each event's payload with a fake analytics sink.
- [x] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
