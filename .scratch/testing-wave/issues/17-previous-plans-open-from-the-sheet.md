# 17: Previous plans open from the sheet

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/previous_plans_flow_test.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete opens the previous plans sheet and opens an older plan, which shows its meals as they were.

**Decisions:** mp-241; approved as mp-637.

**Touches:** integration_test/flows/previous_plans_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] The plans listed equal the archived and confirmed plans by SQL.
- [ ] An opened plan's meals equal its stored rows.

Next: /implement-lee testing-wave
