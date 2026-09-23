# 19: Previous shopping lists, a new list, and deleting one

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/shopping_lists_flow_test.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** From the shopping tab's ⋯ menu the athlete opens previous lists, starts a new list and deletes one, and each change shows in the dev database.

**Decisions:** mp-244; approved as mp-639.

**Touches:** integration_test/flows/shopping_lists_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] Rows for each list are checked by SQL after each action.
- [ ] Deleting the list tied to the confirmed plan is tried and its result recorded.

Next: /implement-lee testing-wave
