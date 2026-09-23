# 06: A paid account signs out and back in with no paywall

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/paid_relogin_flow_test.dart), 05.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete from ticket 05 signs out and signs back in and lands in the app without seeing the paywall, including on a cold start.

**Decisions:** mp-457, mp-335; approved as mp-626.

**Touches:** integration_test/flows/paid_relogin_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the paid account from ticket 05.
- [ ] Sign out, sign in, and a terminate-and-relaunch each land in the app; RevenueCat and the Entitlement row are unchanged.

Next: /implement-lee testing-wave
