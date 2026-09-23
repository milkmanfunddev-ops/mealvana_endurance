# 21: The Subscription screen shows a Grant's source and days left

**Status:** in-progress (wave 7, 2026-09-23)
**Blocked by:** 03 (touches lib/features/content/domain/content_keys.dart), 04 (touches lib/features/content/domain/content_keys.dart), 15 (touches lib/features/content/domain/content_keys.dart), 16 (touches lib/features/subscription/presentation/screens/subscription_screen.dart), 18 (touches lib/features/subscription/presentation/screens/subscription_screen.dart).
**Next:** `/implement-lee paywall`
**Model:** opus

**What to build:** The Subscription screen shows a Grant as its source (Legacy grace month, a Code, a coach's gift) and the days left until it ends, read from RevenueCat, with no Manage subscription for a Grant alone.

**Decisions:** mp-558, mp-495; approved as mp-613.

**Touches:** lib/features/subscription/presentation/screens/subscription_screen.dart, lib/features/subscription/application/subscription_screen_controller.dart, lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json, test/features/subscription/presentation/subscription_screen_test.dart, test/features/subscription/application/subscription_screen_controller_test.dart

- [ ] A Grant shows its source and days left (controller test fed RevenueCat-shaped customer info for a promotional entitlement; screen widget test).
- [ ] A store subscription still shows as today, with Manage subscription (screen test).
- [ ] Copy from the content system.
- [ ] Seen on the dev simulator with a granted account.

Next: /implement-lee paywall
