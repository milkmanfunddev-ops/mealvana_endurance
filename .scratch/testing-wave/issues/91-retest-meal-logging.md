# 91: Retest: meal logging

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 04-001 10-001 16-003 19-004 20-003 23-002 24-001 24-002 25-001 26-001 26-002 26-003 26-004 26-005 27-002 27-003 28-001 28-002. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 27-004 (timeline Remove: Undo, offline remove, remove then kill before upload, rows with items).

**More follow-up tests (Lee, 2026-09-25, cap of ten lifted for this pass):** 25-004 (Add food (build a meal): untried paths (Recipes tab add, Quick add combo, search results, barcode button, adding the same food twice)), 25-003 (Build a Meal: untried paths (Start from saved/recent, Edit item quantity scaling, remove an item, Also save as a favorite, back with a draft, Time eaten stamped at open)), 27-005 (Edit Meal screen: untried leave-with-unsaved-changes, decimal and empty values, meal type and time eaten changes, kill on the screen), 24-006 (Edit Meal for a photo log: Re-scan photo, Save changes, and Remove from the timeline card), 25-002 (Log a Meal Manual tab: untried paths (empty name, no macros, Time eaten change, two-decimal and huge values, a second log in a row, back mid-entry)), 26-009 (Quick log confirm sheet: time eaten is the time the sheet opened, a changed time and yesterday, offline), 09-005 (Log a Meal quick add: the same item twice, a changed time eaten, and logging offline), 26-007 (Log a Meal Common: a single ingredient at 1.5 servings keeps its portion and sodium), 23-003 (Describe tab input edges: empty, under 5 characters, non-food text, a very long description, Analyze tapped twice, Back while analyzing), 23-005 (Describe with describe-meal failing, offline, or with the monthly AI budget under a tenth), 24-003 (Log a Meal, Describe with a photo: not-food photo, photo plus text, remove photo, cancelled picker, Camera, offline, double Analyze), 26-006 (Log a Meal Recent: a Saved meals row, its trash icon, servings above 1 and a double tap on Log it), 26-008 (Log a Meal Recipes: a multi-serving recipe, half servings, category filters and search), 23-004 (Review & Log: Back without logging, edit an item, rename and change meal type before logging, and the app backgrounded or killed on the screen), 24-005 (Review & Log after a photo: Back without logging, edit the item, empty name, and the slot the model picks against the clock), 28-005 (Scan to Add Food untried paths: denied permission, background and return, not-found and invalid dialogs, offline, other entry points), 24-004 (Photos picker says Location Is Included: log a geotagged photo and check the stored object has no GPS), 25-005 (Timeline Meals after manual and built logs: untried edit and delete through the row menu, and whether the 250.5 kcal row can be corrected), 23-006 (A described meal on the timeline: Edit food (change an item, Save changes) and Remove, with the day's totals and the row checked). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup:** test@test.com, except 04-001 and 10-001, which need their own accounts (read their Steps). `COST spend WAVE logging 91` before 23-002 and before 24-001. The camera legs of 28-001 and 28-002 need a real device: mark them not run. Everything else on the simulator. Offline via `netcut.sh`.



**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/NN/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
