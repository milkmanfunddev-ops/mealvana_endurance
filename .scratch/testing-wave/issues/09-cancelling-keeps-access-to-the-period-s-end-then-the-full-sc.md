# 09: Cancelling keeps access to the period's end, then the full-screen paywall

**Status:** in-progress (wave 7, 2026-09-24)
**Blocked by:** 03 (touches integration_test/flows/cancellation_flow_test.dart), 05.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The paid athlete cancels. Until the period ends the app stays open, and RevenueCat and the Entitlement row agree on the end date. After it passes, the account stays signed in and every launch lands on the full-screen paywall with no close button, with Restore, Redeem code, Manage, Sign out and Delete account in the ⋯ menu. Any read-only mode, plan-ended bar or paywall sheet still in the build is an SSOT-conflict Finding against mp-457.

**Decisions:** mp-457, mp-280; approved as mp-629.

**Touches:** integration_test/flows/cancellation_flow_test.dart

- [x] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [x] Signs up its own account at a new plus address, logs it in the credentials file, and buys Pro Monthly through the Test Store at the start, the way ticket 05 did. Before the purchase lapses it makes one meal plan and logs one meal (ticket 10 checks they survive). The account is kept, lapsed, for ticket 10 and marked so in the credentials file.
- [x] Should run after paywall ticket 20 (read-only plumbing comes out) has merged, and says in its run notes which paywall tickets were in the build.
- [x] Cancels inside the Test Store if it can. If it cannot, the Test Store monthly lapses on its own about 25 minutes after purchase (05-003), and that lapse stands in for the cancellation; the run notes say which happened. A Grant ending within ten minutes, set by API, is the last resort and is said so.
- [x] Before the end (the first few minutes after buying): app open; RevenueCat expiry equals `user_entitlements.active_until`.
- [x] After the end: signed in, full-screen paywall on launch and on relaunch, no close button; an AI call made by API with the account's token is refused by the server.
- [x] The account's data is still in the dev database, checked by SQL.

Next: /implement-lee testing-wave
