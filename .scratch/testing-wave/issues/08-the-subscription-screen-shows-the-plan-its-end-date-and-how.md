# 08: The Subscription screen shows the plan, its end date and how to manage it

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/subscription_screen_flow_test.dart), 05.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The paid athlete opens the Subscription screen and sees the plan they bought, the date it renews or ends as RevenueCat has it, and Manage subscription.

**Decisions:** mp-494, mp-615; approved as mp-628.

**Touches:** integration_test/flows/subscription_screen_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the paid account from ticket 05.
- [ ] The dates on screen equal RevenueCat's; Manage subscription shows; Redeem code opens its sheet.

Next: /implement-lee testing-wave
