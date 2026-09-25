# 90: Retest: shopping and Kroger

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 16-007 18-002 18-006 19-001 19-005 19-006 20-001 20-002 20-008 21-002 21-003 21-010 22-003. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** none.

**Setup:** test@test.com. `netcut.sh` for 20-001 and 20-002. The Kroger screen half of 22-003 needs a Kroger certification shopper login (IMPROVEMENTS #52). Without one, check the Shopping tab half and mark the Kroger half not run. 19-001 deletes a list: make a new one to delete, never the confirmed plan's list (ticket 89 uses that).

**Note:** the plan-list delete warning and Rebuild shopping list are ticket 96's (19-002), retested in ticket 100.

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/NN/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
