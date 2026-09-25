# 80: Small words in the wrong place

**Status:** done (wave 24, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** Four copy fixes. A returning account that resubscribes is welcomed back, not greeted as new (10-002; the paywall's purchase success reads its `hadPro`). Today's Fuel "Where it came from" names each meal by its name, falling back to the meal type only when it has none (27-006). Profile & Preferences opens with its own screen title, not onboarding's "Tell us about yourself" (31-014). The daily plan preview does not offer Connect with Garmin after the athlete said they use no training app (04-008).

**Findings:** 10-002, 27-006, 31-014, 04-008 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/subscription/presentation/screens/paywall_screen.dart, lib/features/macro_dashboard/domain/dashboard_models.dart, lib/features/settings/presentation/screens/preferences_screen.dart, lib/features/onboarding/presentation/screens/daily_plan_preview_screen.dart, assets/config/content_defaults.json

- [x] A test for each of the four.
- [ ] codegen if annotations changed (none needed), `flutter analyze` (green on every touched file) and the suite green (lead).

Next: /implement-lee testing-wave
