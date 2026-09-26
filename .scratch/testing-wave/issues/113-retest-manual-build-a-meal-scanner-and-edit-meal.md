# 113: Retest: Manual, Build a Meal, the barcode scanner and Edit Meal

**Status:** in-progress (wave 40, 2026-09-26)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** 91 (Lee, 2026-09-25: about ten checks per run).

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 25-001 27-002 27-003 28-001 28-002. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 27-004 (timeline Remove: Undo, offline remove, remove then kill before upload, rows with items), 25-004 (Add food (build a meal): untried paths (Recipes tab add, Quick add combo, search results, barcode button, adding the same food twice)), 25-003 (Build a Meal: untried paths (Start from saved/recent, Edit item quantity scaling, remove an item, Also save as a favorite, back with a draft, Time eaten stamped at open)), 27-005 (Edit Meal screen: untried leave-with-unsaved-changes, decimal and empty values, meal type and time eaten changes, kill on the screen), 25-002 (Log a Meal Manual tab: untried paths (empty name, no macros, Time eaten change, two-decimal and huge values, a second log in a row, back mid-entry)), 28-005 (Scan to Add Food untried paths: denied permission, background and return, not-found and invalid dialogs, offline, other entry points), 25-005 (Timeline Meals after manual and built logs: untried edit and delete through the row menu, and whether the 250.5 kcal row can be corrected). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup:** test@test.com. The camera legs of 28-001 and 28-002 need a real device: mark them not run. 28-005 resets camera permission with `xcrun simctl privacy <udid> revoke camera com.milkman.mealvanaendurance.dev`. Offline via `netcut.sh`. No AI call in this ticket (the photo log's Edit Meal is ticket 114's 24-006).

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes, and the meals it logs, edits and removes on test@test.com.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/113/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
