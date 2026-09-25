# 112: Retest: Log a Meal quick logs (Recent, Common, Recipes)

**Status:** done (wave 34, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** 91 (Lee, 2026-09-25: about ten checks per run).

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 26-002 26-003 26-004 26-005. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 26-006 (Log a Meal Recent: a Saved meals row, its trash icon, servings above 1 and a double tap on Log it), 26-007 (Log a Meal Common: a single ingredient at 1.5 servings keeps its portion and sodium), 26-008 (Log a Meal Recipes: a multi-serving recipe, half servings, category filters and search), 26-009 (Quick log confirm sheet: time eaten is the time the sheet opened, a changed time and yesterday, offline), 09-005 (Log a Meal quick add: the same item twice, a changed time eaten, and logging offline). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup:** test@test.com. Offline via `netcut.sh` (26-009, 09-005). No AI call in this ticket. 26-006's trash icon only on a throwaway saved meal made for the test, never an existing one. Read new rows from dev `meal_logs` (SELECT only).

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes, and the meals it logs on test@test.com.

- [x] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [x] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/112/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [x] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [x] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
