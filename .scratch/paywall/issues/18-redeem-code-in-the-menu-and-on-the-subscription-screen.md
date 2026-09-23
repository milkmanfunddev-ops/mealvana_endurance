# 18: Redeem code in the ⋯ menu and on the Subscription screen

**Status:** in-progress (wave 6, 2026-09-23)
**Blocked by:** 03 (touches lib/features/subscription/presentation/screens/paywall_screen.dart), 04 (touches lib/features/content/domain/content_keys.dart), 07, 14 (touches lib/features/subscription/presentation/screens/paywall_screen.dart), 15 (touches lib/features/subscription/presentation/screens/paywall_screen.dart), 16 (touches lib/features/subscription/presentation/screens/subscription_screen.dart), 17 (touches lib/features/subscription/presentation/screens/paywall_screen.dart).
**Next:** `/implement-lee paywall`
**Model:** opus

**What to build:** Redeem code appears in the paywall's ⋯ menu and on the Subscription screen. It opens our own code entry (no App Store sheet), sends the code to `redeem-code` and shows what it did or why it failed; a coach entering their own code goes straight into the app.

**Decisions:** mp-458, mp-494, mp-495, mp-496; approved as mp-502.

**Touches:** lib/features/subscription/presentation/screens/paywall_screen.dart, lib/features/subscription/presentation/screens/subscription_screen.dart, lib/features/subscription/application/code_entry_controller.dart, lib/features/content/domain/content_keys.dart, test/features/subscription/application/code_entry_controller_test.dart, test/features/subscription/presentation/paywall_screen_test.dart

- [ ] Redeem code in the ⋯ menu and on the Subscription screen (screen widget tests).
- [ ] The entry sends the code and shows each result (controller test with a fake function).
- [ ] A coach code opens the app without the paywall on the dev simulator.
- [ ] Copy from the content system.

Next: /implement-lee paywall
