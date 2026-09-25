# 121: Retest: a new account's sign-up and onboarding paywall

**Status:** in-progress (wave 34, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** 107 (Lee, 2026-09-25: about ten checks per run).

**What to build:** A retest run on a build that carries tickets 102-106 (the testing app was rebuilt after them; the commit is in `.scratch/testing-wave/app-build.json`). Re-run each Finding's steps, and check each fix ticket's behaviour as its file describes it. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 86-004, 86-006. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 86-009 (Use a different email, superseded code), 86-011 (paywall Delete account offline), 04-002 (A signed-in new account relaunched cold lands on the paywall again), 04-003 (Restore purchases on a new account with nothing to restore), 04-004 (Paywall offline or with no offerings shows the pricing-unavailable state and still no way off), 04-005 (Continue then cancel the Test Store sheet leaves the new account on the paywall), 05-010 (Paywall Continue tapped twice, or during the 2.4 s after a purchase, buys once). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup:** new accounts for the signup and paywall paths (`CRED new`), reused across checks before their delete. Offline via `netcut.sh` (86-011, 04-004). 86-009 sends auth emails (Resend): count them in `notes.md`. 05-010 buys through the Test Store.

**Decisions:** the ones each Finding and fix ticket cite.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding and follow-up test above: pass | fail | not run, evidence (paths under `runs/121/`), and for a fail the new Finding's id. The run does not edit old Finding files; the lead closes the passes.
- [ ] Every account the run made is deleted at the end.

Next: /implement-lee testing-wave
