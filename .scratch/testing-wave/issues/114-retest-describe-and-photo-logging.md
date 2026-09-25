# 114: Retest: Describe and photo logging (AI calls)

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** 91 (Lee, 2026-09-25: about ten checks per run).

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 23-002 24-001 24-002. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 23-003 (Describe tab input edges: empty, under 5 characters, non-food text, a very long description, Analyze tapped twice, Back while analyzing), 23-005 (Describe with describe-meal failing, offline, or with the monthly AI budget under a tenth), 24-003 (Log a Meal, Describe with a photo: not-food photo, photo plus text, remove photo, cancelled picker, Camera, offline, double Analyze), 23-004 (Review & Log: Back without logging, edit an item, rename and change meal type before logging, and the app backgrounded or killed on the screen), 24-005 (Review & Log after a photo: Back without logging, edit the item, empty name, and the slot the model picks against the clock), 24-004 (Photos picker says Location Is Included: log a geotagged photo and check the stored object has no GPS), 24-006 (Edit Meal for a photo log: Re-scan photo, Save changes, and Remove from the timeline card), 23-006 (A described meal on the timeline: Edit food (change an item, Save changes) and Remove, with the day's totals and the row checked). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup:** test@test.com; 23-005's low-budget leg on the account its Steps name. `COST spend WAVE logging 114` before every AI logging call (Analyze, Re-scan). This ticket may use the wave's whole logging cap (five calls): the wave lead never pairs it with another ticket that spends logging. A step past the cap is skipped and written as a followup-test Finding (RUNBOOK step 5). Offline via `netcut.sh`. 24-004 adds a GPS-tagged photo with `simctl addmedia`.

**Order, to cover the most per call:** (1) one text Analyze serves 23-002, 23-004 (edit and rename before logging) and then 23-006 (Edit food and Remove on the timeline). (2) One photo Analyze of the GPS-tagged photo serves 24-001, 24-002 and 24-004. (3) 24-005 Back without logging. (4) 23-003's non-food text. (5) 24-006's Re-scan or 24-003's not-food photo. The legs that make no call (23-003 empty and short text, 23-005 offline and insufficient credits, 24-003 remove photo, cancelled picker, offline) run in any case.

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes, and the meals it logs on test@test.com.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/114/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
