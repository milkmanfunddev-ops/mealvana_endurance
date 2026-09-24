# 23: Logging a meal by describing it

**Status:** done (wave 13, 2026-09-24)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete describes a meal in words and saves it; the logged meal and its numbers show on the day and in the dev database.

**Decisions:** none.

**Touches:** the dev test account's meal logs

- [x] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [x] Uses the entitled dev test account from the credentials file; no new account.
- [x] Counts each AI call against the wave's cap of 5; refuses and writes a followup-test at the cap.
- [x] The saved meal's rows are checked by SQL.

Next: /implement-lee testing-wave
