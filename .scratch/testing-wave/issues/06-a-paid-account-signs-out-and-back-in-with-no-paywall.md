# 06: A paid account signs out and back in with no paywall

**Status:** in-progress (wave 6, 2026-09-24)
**Blocked by:** 03 (touches integration_test/flows/paid_relogin_flow_test.dart), 05.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A paid athlete signs out and signs back in and lands in the app without seeing the paywall, including on a cold start.

**Decisions:** mp-457, mp-335; approved as mp-626.

**Touches:** integration_test/flows/paid_relogin_flow_test.dart

- [x] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [x] Signs up its own account at a new plus address, logs it in the credentials file, and buys Pro Monthly through the Test Store at the start, the way ticket 05 did (its run notes have the steps). The Test Store monthly renews every 5 minutes and lapses about 25 minutes after purchase (05-003), so the paid checks are done within 20 minutes of buying; a lapse before they finish is written down in the run notes, not worked around. The account is deleted in the app at the end (a failed delete is a Finding).
- [x] Sign out, sign in, and a terminate-and-relaunch each land in the app; RevenueCat and the Entitlement row are unchanged.

Next: /implement-lee testing-wave
