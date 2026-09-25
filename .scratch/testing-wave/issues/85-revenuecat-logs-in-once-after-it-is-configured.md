# 85: RevenueCat logs in once, after it is configured

**Status:** in-progress (wave 24, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** On a cold launch the app calls RevenueCat's logIn once, after `Purchases.configure` (09-013 saw two attempts before the SDK was ready).

**Findings:** 09-013 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/subscription/data/subscription_service.dart (and whatever calls its logIn at startup)

- [x] A test: a cold start with a signed-in account makes exactly one logIn, after configure. (`revenuecat_login_order_test.dart`, 7 cases through a fake SDK recording call order; `app_startup_service_test.dart` `initializeAppGate` group, 3 cases through the real startup service)
- [x] codegen not needed (no annotation change); `flutter analyze` clean on the touched files. [ ] the suite: wave lead.

Next: /implement-lee testing-wave
