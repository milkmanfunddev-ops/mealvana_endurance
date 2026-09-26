# 123: Retest: paid and lapsed subscriptions

**Status:** in-progress (wave 38, 2026-09-26)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** 107 (Lee, 2026-09-25: about ten checks per run).

**What to build:** A retest run on a build that carries tickets 102-106 (the testing app was rebuilt after them; the commit is in `.scratch/testing-wave/app-build.json`). Re-run each Finding's steps, and check each fix ticket's behaviour as its file describes it. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 87-006, 87-009, 87-007, 87-008. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 05-008 (Lapsed paywall menu: Manage subscription and Restore purchases for an expired Test Store subscription), 09-011 (Lapsed paywall: Sign out from the menu, log back in, and relaunch while offline), 10-003 (Lapsed paywall: resubscribe with Annual, with Test failed purchase then retry, and with Cancel on the Test Store sheet), 10-005 (Resubscribe on the same device the account used before the lapse (local data present) and let the new subscription lapse again), 07-008 (Subscription screen for a paid account: which plan, its price and the renewal time), 08-005 (Subscription screen on return from Manage subscription, and Manage tapped twice or offline), 07-011 (Home and resume on the Subscription screen does not refetch the customer after a renewal). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup:** 87-006 and 87-009 need a Test Store monthly (5-minute periods; it renews only while signed in and lapses about 5 minutes after sign-out, IMPROVEMENTS #80): sign out to start the lapse, and let the same accounts serve the Lapsed checks (87-007, 87-008, 05-008, 09-011, 10-003, 10-005) once they lapse. 07-008, 08-005 and 07-011 need a paid account inside its period: buy Annual (1-hour periods) for those. New accounts only; no check here uses test@test.com.

**Decisions:** the ones each Finding and fix ticket cite.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding and follow-up test above: pass | fail | not run, evidence (paths under `runs/123/`), and for a fail the new Finding's id. The run does not edit old Finding files; the lead closes the passes.
- [ ] Every account the run made is deleted at the end.

Next: /implement-lee testing-wave
