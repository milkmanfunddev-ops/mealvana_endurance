# 107: Retest the fixes of 102 to 106, and wave 25's follow-up tests

**Status:** ready-for-agent
**Blocked by:** 102, 103, 104, 105, 106.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A retest run on a build that carries tickets 102-106. The wave lead rebuilds the testing app first (RUNBOOK, wave lead step 2). Re-run each Finding's steps, and check each fix ticket's behaviour as its file describes it. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 86-001, 86-007, 86-012, 86-004, 86-005, 86-006, 87-006, 87-009, 87-001, 87-007, 87-008. For 86-012 (found by code reading) check it by its fix ticket's tests and one sync of a repository holding a row the server refuses, if the run can make one safely; otherwise mark it not run.

**Follow-up tests to run:** 86-002 (local plan status against dev after login), 86-003 (Plan tab within 5-10 s of login), 86-008 (wrong password, double-tap Log In), 86-009 (Use a different email, superseded code), 86-010 (connected app's name suggestion leaves the email alone), 86-011 (paywall Delete account offline), 87-003 (delete account at 10 fps: any paywall frame?), 87-004 (redeem double tap, close mid-request, spaced code), 87-005 (second giveaway on a Grant, a Grant's last day).

**Setup:** 86-001 and 86-007 need two accounts on one phone: test@test.com plus a new account, with rows of the first left unsynced (`netcut.sh on`, a Manual meal log) before signing out and in as the other; read the local Drift database read-only before and after each step, as run 86 did. 87-006 and 87-009 need a Test Store monthly (5-minute periods, ends after five): plan around the 25-minute lapse. 87-005 uses `seed-codes.mjs seed` and `own <id> --days 1`. New accounts for signup, delete and redeem paths. Ticket 100 may run in the same wave on test@test.com: treat its rows as expected.

**Decisions:** the ones each Finding and fix ticket cite.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding and follow-up test above: pass | fail | not run, evidence, and for a fail the new Finding's id. The run does not edit old Finding files; the lead closes the passes.
- [ ] Every account the run made is deleted at the end.

Next: /implement-lee testing-wave
