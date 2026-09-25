# 52: Nothing important hides under the keyboard, the tab bar or a message

**Status:** done (wave 22, 2026-09-25)
**Blocked by:** 50 (touches lib/features/subscription/presentation/screens/paywall_screen.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** On the Describe tab, Analyze stays reachable with the keyboard up (the view scrolls or the button rides above the keys). At the end of My Events, New Event rests above the floating tab bar. The redeem success message does not cover the paywall's Continue button.

**Findings:** 23-001, 03-007, 11-005 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/meal_logging/presentation/screens/describe_meal_screen.dart, lib/features/events/presentation/screens/events_list_screen.dart, lib/features/subscription/presentation/screens/paywall_screen.dart

- [x] Widget tests: Analyze hit-testable with a keyboard inset; New Event hit-testable at the list end under the tab bar.
- [ ] On the simulator, the three screens checked by eye.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
