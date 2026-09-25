# 110: Retest: the Shopping tab's lists, ticks and offline copy

**Status:** ready-for-agent
**Blocked by:** none.
**Pair with:** 111 (Shop with Kroger, same account). This run ticks rows, makes hand-made lists (19-006, 19-010), deletes one of its own lists (19-001) and adds to a draft's list from Browse (18-002); 111 writes test@test.com's Kroger connection (connect, disconnect, the production row in 22-005) and reads the current list on the Kroger screen (22-003). Each checks only its own rows and treats the other's as expected.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** 90 (Lee, 2026-09-25: about ten checks per run).

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 16-007 18-002 18-006 19-001 19-005 19-006 20-001 20-002. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 16-009 (Shopping list after confirm: the Farro count, row menu, share, check-off and Kroger button), 19-010 (New list: Add an item, Share and rename on a hand-made list, and New list twice in a day), 20-005 (Shopping tab: tick a row while the local copy is being swapped for the server's list, and double-tap a row fast), 20-004 (Shopping tab offline: the list menu, Share, Shop with Kroger, Previous lists, Add item, and a row's count). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup:** test@test.com. `netcut.sh` for 20-001, 20-002 and 20-004. 19-001 deletes a list: make a new one to delete, never the confirmed plan's list (tickets 111 and 115 read it). Browse's + writes to the conversation's draft plan and builds a shopping list (IMPROVEMENTS #47): for 18-002 name in `notes.md` which conversation and plan each write went to.

**Order:** the read-only checks first (16-007, 18-006, 19-005, 16-009), then ticks and the offline copy (20-001, 20-002, 20-004, 20-005), then the list-making checks (19-006, 19-010, 19-001 on its own list), and 18-002 last.

**Note:** the plan-list delete warning and Rebuild shopping list are ticket 96's (19-002), retested in ticket 100.

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes, and the lists and ticks it makes on test@test.com.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/110/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
