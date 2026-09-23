# 05: A trial bought through the Test Store opens the app

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/paywall_purchase_flow_test.dart), 04.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A new athlete buys a plan with its free week through the Test Store. The Gate opens and RevenueCat shows the subscription with its expiry. The run finds out whether a Test Store purchase reaches the dev webhook, and if it does, the Entitlement row carries the same expiry.

**Decisions:** mp-457, mp-279; approved as mp-625.

**Touches:** integration_test/flows/paywall_purchase_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Signs up its own account at a new plus address, logs it in the credentials file, and deletes it in the app at the end (a failed delete is a Finding).
- [ ] Expected: RevenueCat active `pro` with an expiry; `user_entitlements.active_until` equal to it if the webhook fires; the Gate opens without a paywall flash.
- [ ] The webhook answer (fires or not, and why) is written as a Finding of kind idea or bug, with the edge-function log.
- [ ] The paid account is kept in the credentials file (not deleted) for tickets 06 to 09 and marked so; ticket 10 deletes it.

Next: /implement-lee testing-wave
