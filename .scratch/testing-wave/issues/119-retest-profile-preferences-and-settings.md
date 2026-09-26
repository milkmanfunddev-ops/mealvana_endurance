# 119: Retest: Profile & Preferences and the Settings rows

**Status:** done (wave 36, 2026-09-26)
**Blocked by:** none.
**Pair with:** 118 (may mark test@test.com's TrainingPeaks connection as needing reconnection), and 120 (its 86-010 taps the same TrainingPeaks name chip and saves on test@test.com). This run saves test@test.com's water bottle (31-002, 31-008) and a chip (31-006). Each checks only its own saves, with times in `notes.md`.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** 93 (Lee, 2026-09-25: about ten checks per run).

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 31-002. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 31-004 (Profile & Preferences: clear a first or last name and save, check the name is cleared), 31-005 (Profile & Preferences: leave with unsaved changes by the back arrow and by swipe-back), 31-006 (Profile & Preferences: the tap-to-use chips from TrainingPeaks and Final Surge), 31-007 (Profile & Preferences: edit the Email field and save), 31-008 (Profile & Preferences: save while offline), 31-009 (Appearance: pick Light or System and check it survives a relaunch and a sign-out), 31-011 (Settings: Sign Out, then Cancel, and Delete Account, then Cancel), 31-013 (Settings rows not opened this run: Subscription, Diet, Sport, Body Composition, Nutrition Targets, Coach, Connected Apps, Privacy, Help). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup:** test@test.com for 31-002, 31-005, 31-006, 31-008 and 31-013; a throwaway account (with a first and last name set) for 31-004, 31-007, and any 31-011 step past Cancel, so test@test.com's name and email stay. 31-009 signs in as that other account; put Dark back. Offline via `netcut.sh` (31-008).

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes, and test@test.com's water bottle and name fields.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/119/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
