# 117: Retest: timeline week walk, cold starts, sign-in sheets, Learn and Events

**Status:** in-progress (wave 40, 2026-09-26)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** 92 (Lee, 2026-09-25: about ten checks per run).

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 30-001 30-002. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 30-006 (Timeline week walk: past-day cards, filters, hide times, brick card title, pull to refresh, offline), 30-007 (Month picker: days with only skipped sessions carry no marker; tap a day, month arrows, Today), 30-010 (Sign-in sheets: What's New and TrainingPeaks sharing sheet on a fresh sign-in, Turn Off Sharing and Keep Sharing), 29-004 (Cold start untried path: switch tabs within a second of sign-in, before the first sync ends; console and each tab's first screen), 29-003 (Cold start untried paths: signed in with no network, and with an expired session; every tab and the console), 10-004 (Timeline after resubscribing on a fresh install: cold relaunch and a day change without opening Food, and whether workouts and the net balance come back), 05-007 (Cold relaunch of a paid account opens the app without a paywall frame), 29-005 (Learn tab untried paths: play lesson 1.1 and 1.2, Notify Me, Courses; console for video player errors), 29-006 (Events tab untried paths: open the upcoming and a past event, New Event then back, on a cold start; console). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup:** test@test.com. 30-001 and 30-002 read `activities` by SQL (SELECT only) right after the cleared app's first sign-in, which runs the FinalSurge sync; 30-010 and 29-004 use that same first sign-in, so plan it for all four. 29-003 cuts the network with `netcut.sh launch`, then `on`. 10-004 needs a Lapsed account with meals and a planned workout that resubscribes (Test Store); 05-007 a new account that buys Pro, recorded at 10 fps or more.

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/117/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
