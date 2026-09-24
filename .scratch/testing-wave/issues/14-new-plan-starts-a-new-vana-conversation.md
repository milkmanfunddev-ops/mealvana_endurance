# 14: New plan starts a new Vana conversation

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete taps New meal plan and a fresh, empty conversation opens with a fresh Draft; the plan it was on is archived.

**Decisions:** mp-241.

**Touches:** the dev test account's plans and Vana conversations

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] Counts one new plan against the wave's cap of 3 before starting; refuses and writes a followup-test if the cap is reached.
- [ ] Expected rows (a new conversation, a new draft plan, the old plan archived) are checked by SQL.

Next: /implement-lee testing-wave
