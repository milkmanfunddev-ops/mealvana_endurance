# 16: The Subscription screen in Settings

**Status:** in-progress (wave 4, 2026-09-22)
**Blocked by:** 03 (touches lib/features/content/domain/content_keys.dart), 04 (touches lib/features/content/domain/content_keys.dart), 15 (touches lib/features/content/domain/content_keys.dart).
**Next:** `/implement-lee paywall`
**Model:** opus

**What to build:** A Subscription row in Settings opens a screen with the plan status (trial with its end date, active with its renewal date, founding member, or ended), a tick list of what Pro includes with the AI features under one Vana line, Upgrade (opens the paywall, when the plan has ended) and Manage subscription (the store's page, when there is a subscription). No Redeem code yet (mp-496).

**Decisions:** mp-495, mp-496, mp-497, mp-493; approved as mp-500.

**Touches:** lib/features/subscription/presentation/screens/subscription_screen.dart, lib/features/subscription/application/subscription_screen_controller.dart, lib/features/settings/presentation/screens/settings_screen.dart, lib/features/content/domain/content_keys.dart, test/features/subscription/application/subscription_screen_controller_test.dart, test/features/subscription/presentation/subscription_screen_test.dart, test/features/subscription/presentation/goldens/

- [x] Trial, active, founding and ended each show the right status and date from fake customer info (screen widget test).
- [x] Upgrade only when ended and opens the paywall; Manage only with a subscription.
- [x] Built from the `kyle_design` widgets 14 and 15 added; copy from the content system.
- [x] Goldens light and dark.
- [x] Settings opens it as a named push (route settings carry its name), so the router file is left to ticket 11.
- [x] Checked on the dev simulator from Settings.

Next: /implement-lee paywall
