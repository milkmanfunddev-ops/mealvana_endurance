# 120: Retest: two accounts on one phone (leftover rows, sign-out, switching)

**Status:** ready-for-agent
**Blocked by:** none.
**Pair with:** 119 (its 31-006 taps the same TrainingPeaks name chip on test@test.com that 86-010 saves). Ticket 100 may run in the same wave on test@test.com: treat its rows as expected.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** 107 (Lee, 2026-09-25: about ten checks per run).

**What to build:** A retest run on a build that carries tickets 102-106 (the testing app was rebuilt after them; the commit is in `.scratch/testing-wave/app-build.json`). Re-run each Finding's steps, and check each fix ticket's behaviour as its file describes it. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 86-001, 86-007, 86-012, 86-005. For 86-012 (found by code reading) check it by its fix ticket's tests and one sync of a repository holding a row the server refuses, if the run can make one safely; otherwise mark it not run. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 86-002 (local plan status against dev after login), 86-003 (Plan tab within 5-10 s of login), 86-008 (wrong password, double-tap Log In), 86-010 (connected app's name suggestion leaves the email alone), 12-007 (Admin signs out and a Lapsed athlete signs in on the same device: the Gate must close, not inherit the admin's answer), 06-004 (Sign in as a paid account on a device whose RevenueCat SDK last held a different, unpaid account). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup:** 86-001 and 86-007 need two accounts on one phone: test@test.com plus a new account, with rows of the first left unsynced (`netcut.sh on`, a Manual meal log) before signing out and in as the other; read the local Drift database read-only before and after each step, as run 86 did. 86-001, 86-002 and 86-003 start from leftover rows: the wave lead does not clear the app for this ticket (RUNBOOK, wave lead step 3); run them first. 86-005 opens Ask Vana: `COST spend WAVE chat 120` first. 12-007 uses the dev admin, then a Lapsed account. 06-004 needs an unpaid (or Lapsed) account and a paid one (Test Store monthly bought within 20 minutes).

**Decisions:** the ones each Finding and fix ticket cite.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding and follow-up test above: pass | fail | not run, evidence (paths under `runs/120/`), and for a fail the new Finding's id. The run does not edit old Finding files; the lead closes the passes.
- [ ] Every account the run made is deleted at the end.

Next: /implement-lee testing-wave
