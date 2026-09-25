# 45: The paywall closes the moment a purchase opens the Gate

**Status:** in-progress (wave 19, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** After a successful purchase the paywall keeps Continue disabled until the router has moved on, so there is no 2.4 s window where Continue is live again and a second purchase can start.

**Findings:** 05-004 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/subscription/application/pro_paywall_controller.dart, lib/features/subscription/presentation/screens/paywall_screen.dart

- [ ] A seam test through the real paywall notifier: after purchase success, Continue stays disabled.
- [ ] On the simulator the timeline follows the Test Store sheet with no enabled paywall in between.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
