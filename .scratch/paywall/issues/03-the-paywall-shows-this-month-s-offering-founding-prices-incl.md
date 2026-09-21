# 03: The paywall shows this month's offering, founding prices included

**Status:** in-progress (wave 1, 2026-09-21)
**Blocked by:** None (can start immediately).
**Next:** `/implement-lee paywall`
**Model:** opus

**What to build:** A new dev athlete meets the paywall with $24.99 and $199.99 and the free week. With the `founding` offering made current in RevenueCat, the same screen shows $12.49 and $99.99 beside the normal prices struck through, with a "Founding member" line, and no release. The paywall carries the trial terms, the price after the trial and links to terms and privacy, all copy from the content system.

**Decisions:** mp-453, mp-452, mp-279, mp-417; approved as mp-482.

**Touches:** lib/features/subscription/application/pro_paywall_controller.dart, lib/features/subscription/data/subscription_service.dart, lib/features/subscription/presentation/screens/paywall_screen.dart, lib/features/content/domain/content_keys.dart, test/features/subscription/application/pro_paywall_controller_test.dart, test/features/subscription/presentation/paywall_screen_test.dart

- [ ] The paywall reads the Current Offering (controller test with fake offerings).
- [ ] With `founding` current, each plan shows the founding price and the `default` price struck through (controller test and a golden).
- [ ] Trial terms, price after, terms and privacy links are on screen from the content system.
- [ ] On the dev simulator the paywall shows the new store prices.

Next: /implement-lee paywall
