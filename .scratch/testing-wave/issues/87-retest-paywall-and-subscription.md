# 87: Retest: paywall and subscription

**Status:** done (wave 25, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 05-004 05-005 06-002 07-002 08-001 09-001 09-009 10-002 11-003 11-004 11-012 02-004. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 06-001 (offline cold launch of a paid account inside the paid period), 08-004 (the Subscription screen for cancelled, ended and Grant plans), 11-006 (Redeem code offline, the code not spent, then a retry that works).

**Setup:** A new account that buys the Test Store monthly. It lapses 25 minutes after purchase, so order the steps around it: paid-state checks (06-001, 08-004 running and cancelled) first, then the lapse checks (05-005, 08-004 ended). For 07-002: a cold launch offline more than 15 minutes after a period end. For 05-005: leave the app open across the expiry. Run `node scripts/testing-wave/seed-codes.mjs seed` before the redeem steps. Offline means `netcut.sh` (runbook step 5).

**Moved out:** 32-007 (auto-submit of emailed codes) is retested in ticket 100 after ticket 94.

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/NN/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
