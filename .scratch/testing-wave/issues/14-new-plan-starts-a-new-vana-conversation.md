# 14: New plan starts a new Vana conversation

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/vana_new_plan_flow_test.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete taps New meal plan and a fresh, empty conversation opens with a fresh Draft; the plan it was on is archived.

**Decisions:** mp-241; approved as mp-634.

**Touches:** integration_test/flows/vana_new_plan_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] Counts one new plan against the wave's cap of 3 before starting; refuses and writes a followup-test if the cap is reached.
- [ ] Expected rows (a new conversation, a new draft plan, the old plan archived) are checked by SQL.
- [ ] The Patrol flow covers opening Vana and starting a new plan up to the first model turn, and no further.

Next: /implement-lee testing-wave
