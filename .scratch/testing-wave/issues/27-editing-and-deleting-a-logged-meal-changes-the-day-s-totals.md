# 27: Editing and deleting a logged meal changes the day's totals

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/meal_log_edit_flow_test.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete edits a logged meal and deletes another, and the day's totals change to match.

**Decisions:** approved as mp-647.

**Touches:** integration_test/flows/meal_log_edit_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] Totals on screen before and after equal the sums by SQL.

Next: /implement-lee testing-wave
