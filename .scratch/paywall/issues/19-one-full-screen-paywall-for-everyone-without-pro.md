# 19: One full-screen paywall for everyone without Pro

**Status:** in-progress (wave 7, 2026-09-23)
**Blocked by:** 03 (touches lib/features/subscription/presentation/screens/paywall_screen.dart), 11 (touches lib/features/subscription/application/pro_gate.dart), 14 (touches lib/features/subscription/presentation/screens/paywall_screen.dart), 15 (touches lib/features/subscription/presentation/screens/paywall_screen.dart), 17 (touches lib/features/subscription/presentation/pro_gate_redirect.dart), 18 (touches lib/features/subscription/presentation/screens/paywall_screen.dart).
**Next:** `/implement-lee paywall`
**Model:** opus

**What to build:** The Gate answers open or closed, and closed always lands on the full-screen paywall with no close button, for an account that never had Pro and one whose Pro ended alike. The paywall-over-the-app sheet and its close button go; the glass sheet widget stays, since Redeem code uses it.

**Decisions:** mp-280, mp-457, mp-493, mp-494; approved as mp-611.

**Touches:** lib/features/subscription/application/pro_gate.dart, lib/features/subscription/domain/entitlement.dart, lib/features/subscription/presentation/pro_gate_redirect.dart, lib/features/subscription/application/paywall_location.dart, lib/features/subscription/presentation/ai_action_guard.dart, lib/shared/core/app_router.dart, lib/features/subscription/presentation/screens/paywall_screen.dart, test/features/subscription/application/pro_gate_test.dart, test/features/subscription/presentation/pro_gate_redirect_test.dart, test/features/subscription/presentation/paywall_screen_test.dart

- [ ] The Gate answers open or closed; a lapsed account and a never-subscribed one both get closed (Gate test through the real provider).
- [ ] Closed lands on the full-screen paywall with no close button, from a cold start and from any route (redirect tests).
- [ ] No paywall sheet over the app: the sheet presentation and its close button are gone; Redeem code still opens its glass sheet (paywall screen tests).
- [ ] A lapsed account on the dev simulator opens on the full-screen paywall, and subscribing or restoring lands it back in the app.

Next: /implement-lee paywall
