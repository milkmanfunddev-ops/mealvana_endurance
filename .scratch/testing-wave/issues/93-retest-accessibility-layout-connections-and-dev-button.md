# 93: Retest: accessibility, layout, connections and the dev button

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 03-007 08-002 11-005 12-002 18-005 21-004 23-001 28-006 31-002 64-001. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** none.

**More follow-up tests (Lee, 2026-09-25, cap of ten lifted for this pass):** 31-004 (Profile & Preferences: clear a first or last name and save, check the name is cleared), 31-005 (Profile & Preferences: leave with unsaved changes by the back arrow and by swipe-back), 31-006 (Profile & Preferences: the tap-to-use chips from TrainingPeaks and Final Surge), 31-007 (Profile & Preferences: edit the Email field and save), 31-008 (Profile & Preferences: save while offline), 31-009 (Appearance: pick Light or System and check it survives a relaunch and a sign-out), 31-011 (Settings: Sign Out, then Cancel, and Delete Account, then Cancel), 31-013 (Settings rows not opened this run: Subscription, Diet, Sport, Body Composition, Nutrition Targets, Coach, Connected Apps, Privacy, Help), 04-006 (Onboarding back button mid-flow keeps the answers already given). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup:** test@test.com, plus a new account for 08-002 and 11-005 (the paywall). Read VoiceOver labels with `idb ui describe-all --udid UDID`. 21-004 and 64-001 need a TrainingPeaks token that the API refuses: check that the app marks the connection as needing reconnection. If you cannot cause the refusal without a write the runbook forbids, mark it not run and say why.



**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/NN/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
