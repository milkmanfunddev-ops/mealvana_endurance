# 89: Retest: previous plans, lists and Browse search

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 17-001 17-002 17-003 18-004 19-003 73-001. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 17-005 (earlier plan view: tap a meal, a plan deleted since the list was read, long names), 17-006 (Previous plans sheet: empty, offline and error states, swipe-dismiss), 19-009 (after the confirmed plan's list is deleted, a plan edit rebuilds it).

**Setup:** test@test.com. Dev lists 4 of its 27 plans now: plans archived before 09-16 are dropped, which is known and not a Finding. 17-005 step 3 (a plan deleted elsewhere) and 17-006 step 1 (empty sheet) use a new throwaway account, not test@test.com. 19-009 deletes the confirmed plan's list, and ticket 88 runs on the same account in the same wave: do 19-009 last, and write its times in `notes.md`.

**Note:** 17-004 (plans look alike) and 17-007 (Back to the sheet) are ticket 97's and are retested in ticket 100.

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/NN/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
