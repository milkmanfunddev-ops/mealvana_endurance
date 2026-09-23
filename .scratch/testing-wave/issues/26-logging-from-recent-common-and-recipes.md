# 26: Logging from Recent, Common and Recipes

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/meal_log_sources_flow_test.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete logs one meal from each of Recent, Common and Recipes, and each saves as the source had it.

**Decisions:** approved as mp-646.

**Touches:** integration_test/flows/meal_log_sources_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] No AI call.
- [ ] Each saved meal equals its source by SQL.

Next: /implement-lee testing-wave
