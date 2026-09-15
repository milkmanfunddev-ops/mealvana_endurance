# 19: Seven free days, then the paywall, and nothing else

**Status:** in-progress (wave 2, 2026-09-15)
**Blocked by:** 18.
**Next:** `/implement-lee mealplanning`

**What to build:** A new athlete finishes onboarding, subscribes with the free week, and uses the whole app; on day eight without payment they land on the paywall, which offers Restore, Manage subscription, Sign out and Delete account and nothing else. The gate provider reads the SDK's cached entitlement, treats no cache plus a short timeout as locked, and reacts when RevenueCat refreshes; the router redirect covers every route; existing accounts meet the same paywall; coaches get no branch; the Pro screen and the gate flag are gone from the client.

**Decisions:** mp-279, mp-280, mp-283, mp-284, mp-286, mp-266, mp-270; approved as mp-297.

**Touches:** lib/features/subscription/application/pro_gate.dart, lib/features/subscription/application/subscription_status_provider.dart, lib/features/subscription/presentation/pro_gate_redirect.dart, lib/features/subscription/presentation/screens/pro_version_screen.dart, lib/features/subscription/data/user_entitlements_repository.dart, lib/features/onboarding, lib/shared/services/app_config.dart, lib/shared/core/app_router.dart, test/features/subscription

- [x] Onboarding ends on the paywall with the introductory offer shown from store prices.
- [x] Cached entitlement opens the app online or offline; no cache and no answer within two seconds locks it; a later refresh reopens (controller tests through the real notifier).
- [x] The paywall carries Restore, Manage subscription, Sign out and Delete account, and no app route renders behind it (golden plus redirect test).
- [x] The Pro screen, the proGateEnabled config and the Pro-gated path list are removed; the one redirect covers every route.
- [ ] Simulator: a sandbox account without an entitlement sees the paywall on launch; Restore after a sandbox purchase reopens the app.

Next: /implement-lee mealplanning
