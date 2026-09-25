# 85: RevenueCat logs in once, after it is configured

**Status:** in-progress (wave 24, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** On a cold launch the app calls RevenueCat's logIn once, after `Purchases.configure` (09-013 saw two attempts before the SDK was ready).

**Findings:** 09-013 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/subscription/data/subscription_service.dart (and whatever calls its logIn at startup)

- [ ] A test: a cold start with a signed-in account makes exactly one logIn, after configure.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
