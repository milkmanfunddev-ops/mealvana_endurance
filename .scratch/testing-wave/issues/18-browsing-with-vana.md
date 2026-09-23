# 18: Browsing with Vana

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/vana_browse_flow_test.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete opens Vana's browse screen and moves through what it offers without starting a new plan.

**Decisions:** approved as mp-638.

**Touches:** integration_test/flows/vana_browse_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] No new plan is generated.
- [ ] Every control on the screen is tried once and its result recorded.

Next: /implement-lee testing-wave
