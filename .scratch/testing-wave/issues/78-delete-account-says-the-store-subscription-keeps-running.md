# 78: Delete account says the store subscription keeps running

**Status:** done (wave 24, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** When the account has an active store subscription, both Delete Account confirm dialogs (Settings and the paywall's menu) say that deleting the account does not cancel it and name where to cancel (App Store or Google Play), with Manage subscription reachable from the dialog. Copy through the content system.

**Findings:** 02-004 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none (the dialog copy; deleting the store subscription itself is not possible from the app).

**Touches:** lib/features/settings/presentation/screens/settings_screen.dart, lib/features/subscription/presentation/screens/paywall_screen.dart, assets/config/content_defaults.json

- [x] A widget test: with an active store subscription, the Settings confirm shows the subscription line; without one it does not.
- [x] The paywall menu's confirm shows the same line.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green. (codegen run, `flutter analyze` clean on the touched files; suite: lead)

Next: /implement-lee testing-wave
