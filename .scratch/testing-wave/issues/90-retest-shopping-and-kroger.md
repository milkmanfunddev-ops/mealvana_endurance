# 90: Retest: shopping and Kroger

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 16-007 18-002 18-006 19-001 19-005 19-006 20-001 20-002 20-008 21-002 21-003 21-010 22-003. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** none.

**More follow-up tests (Lee, 2026-09-25, cap of ten lifted for this pass):** 16-009 (Shopping list after confirm: the Farro count, row menu, share, check-off and Kroger button), 19-010 (New list: Add an item, Share and rename on a hand-made list, and New list twice in a day), 20-005 (Shopping tab: tick a row while the local copy is being swapped for the server's list, and double-tap a row fast), 20-004 (Shopping tab offline: the list menu, Share, Shop with Kroger, Previous lists, Add item, and a row's count), 21-005 (Kroger sheet: tap Cancel on the kroger.com system alert and close the sign-in sheet with X), 21-006 (Kroger sheet: wrong password, then the right one), 21-007 (Kroger screen: connect with the network cut, and double-tap Connect Kroger), 21-008 (Kroger screen: the connection shows connected on an access token expired a week, prove the refresh path), 21-009 (Kroger screen: allow location on Shop with Kroger and see whether the delivery area fills), 22-004 (Kroger screen: Set delivery ZIP and Match all while not connected, on certification). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup:** test@test.com. `netcut.sh` for 20-001 and 20-002. The Kroger screen half of 22-003 needs a Kroger certification shopper login (IMPROVEMENTS #52). Without one, check the Shopping tab half and mark the Kroger half not run. 19-001 deletes a list: make a new one to delete, never the confirmed plan's list (ticket 89 uses that).

**Note:** the plan-list delete warning and Rebuild shopping list are ticket 96's (19-002), retested in ticket 100.

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/NN/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
