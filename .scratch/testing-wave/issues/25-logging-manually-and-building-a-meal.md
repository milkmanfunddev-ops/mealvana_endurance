# 25: Logging manually and building a meal

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/meal_log_build_flow_test.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete logs a meal by hand and builds one from foods, and both save with the numbers entered.

**Decisions:** approved as mp-645.

**Touches:** integration_test/flows/meal_log_build_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] No AI call.
- [ ] Saved numbers equal what was entered, by SQL.

Next: /implement-lee testing-wave
