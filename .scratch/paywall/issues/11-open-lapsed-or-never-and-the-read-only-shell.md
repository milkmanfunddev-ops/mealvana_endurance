# 11: Open, lapsed or never, and the read-only shell

**Status:** in-progress (wave 3, 2026-09-22)
**Blocked by:** 04 (touches lib/features/subscription/application/subscription_status_provider.dart).
**Next:** `/implement-lee paywall`
**Model:** opus

**What to build:** A dev account whose `pro` has expired opens the app with a bar on every screen saying the plan has ended and a Subscribe button; the Vana launcher and every AI entry open the paywall. An account that never had `pro` meets the paywall and nothing else. The write-access provider exists and says no for a lapsed account.

**Decisions:** mp-457, mp-280, mp-284, mp-335, mp-416; approved as mp-490.

**Touches:** lib/features/subscription/domain/entitlement.dart, lib/features/subscription/application/pro_gate.dart, lib/features/subscription/application/subscription_status_provider.dart, lib/features/subscription/presentation/pro_gate_redirect.dart, lib/shared/core/app_router.dart, lib/shared/widgets/tabs_screen.dart, test/features/subscription/application/pro_gate_test.dart, test/features/subscription/application/subscription_status_provider_test.dart, test/features/subscription/presentation/pro_gate_redirect_test.dart

- [ ] The gate answers open, lapsed or never from fake customer info (through the real notifier).
- [ ] Lapsed reaches app routes with the bar; never is redirected to the paywall (redirect test).
- [ ] AI entry points open the paywall for a lapsed account.
- [ ] Checked on the dev simulator with an expired sandbox account.

Next: /implement-lee paywall
