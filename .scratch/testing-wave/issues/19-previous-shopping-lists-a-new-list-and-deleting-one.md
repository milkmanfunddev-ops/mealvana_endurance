# 19: Previous shopping lists, a new list, and deleting one

**Status:** done (wave 11, 2026-09-24)
**Blocked by:** 20 (deletes lists 20 is checking).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** From the shopping tab's ⋯ menu the athlete opens previous lists, starts a new list and deletes one, and each change shows in the dev database.

**Decisions:** mp-244.

**Touches:** the dev test account's shopping lists

- [x] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [x] Uses the entitled dev test account from the credentials file; no new account.
- [x] Rows for each list are checked by SQL after each action.
- [x] Deleting the list tied to the confirmed plan is tried and its result recorded.

Next: /implement-lee testing-wave
