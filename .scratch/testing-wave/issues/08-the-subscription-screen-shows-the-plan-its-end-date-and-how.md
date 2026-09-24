# 08: The Subscription screen shows the plan, its end date and how to manage it

**Status:** in-progress (wave 7, 2026-09-24)
**Blocked by:** 03 (touches integration_test/flows/subscription_screen_flow_test.dart), 05.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The paid athlete opens the Subscription screen and sees the plan they bought, the date it renews or ends as RevenueCat has it, and Manage subscription.

**Decisions:** mp-494, mp-615; approved as mp-628.

**Touches:** integration_test/flows/subscription_screen_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Signs up its own account at a new plus address, logs it in the credentials file, and buys Pro Monthly through the Test Store at the start, the way ticket 05 did (its run notes have the steps). The Test Store monthly renews every 5 minutes and lapses about 25 minutes after purchase (05-003), so the paid checks are done within 20 minutes of buying; a lapse before they finish is written down in the run notes, not worked around. The account is deleted in the app at the end (a failed delete is a Finding).
- [ ] The dates on screen equal RevenueCat's; Manage subscription shows; Redeem code opens its sheet.

Next: /implement-lee testing-wave
