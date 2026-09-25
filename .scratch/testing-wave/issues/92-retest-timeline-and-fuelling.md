# 92: Retest: timeline and fuelling

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 09-002 27-001 27-006 30-001 30-002 30-003 30-004. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** none.

**More follow-up tests (Lee, 2026-09-25, cap of ten lifted for this pass):** 30-008 (Activity fuelling screen: By Hour tab, low-carb info icon, snack expander, After targets, a session with no stored plan), 30-006 (Timeline week walk: past-day cards, filters, hide times, brick card title, pull to refresh, offline), 30-010 (Sign-in sheets: What's New and TrainingPeaks sharing sheet on a fresh sign-in, Turn Off Sharing and Keep Sharing), 29-004 (Cold start untried path: switch tabs within a second of sign-in, before the first sync ends; console and each tab's first screen), 29-003 (Cold start untried paths: signed in with no network, and with an expired session; every tab and the console), 10-004 (Timeline after resubscribing on a fresh install: cold relaunch and a day change without opening Food, and whether workouts and the net balance come back), 05-007 (Cold relaunch of a paid account opens the app without a paywall frame), 29-005 (Learn tab untried paths: play lesson 1.1 and 1.2, Notify Me, Courses; console for video player errors), 29-006 (Events tab untried paths: open the upcoming and a past event, New Event then back, on a cold start; console), 03-005 (formula_pin_conflict has never run on the dev admin: no Before library formula conflicts with its allergies), 14-010 (Plan tab Vana note says the day needs 1007 g of carbs), 25-006 (Timeline daily budget on test@test.com reads 8,839 kcal with 475 g fat; check the numbers behind it), 30-009 (Net balance: every past day reads -2,447 and every future day +0), 05-009 (Timeline for a brand-new account shows a net balance of -229 kcal slight deficit before anything is logged), 26-010 (Timeline groups two snacks eaten a minute apart under the first one's time, and net balance moved 597 kcal for 672 kcal logged), 30-007 (Month picker: days with only skipped sessions carry no marker; tap a day, month arrows, Today). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup for the added number checks:** 14-010, 25-006, 30-009, 05-009 and 26-010 are about numbers. Read each figure off the screen, then read what produced it (the day's `calculate-daily-macros` answer or the stored rows, SELECT only) and say which one is wrong, if either. A figure the SSOT rules is checked against `docs/ssot/`.

**Setup:** test@test.com. Before 30-003, clear test@test.com's `nutrition_target_overrides.during` (50.4 g/h) through the app's own edit path, or record that the override is set and judge 30-003 by override behaviour (mp-680). Write down which in `notes.md`. **30-005 is not retestable** (it waits on Xuan) and is not in this ticket.



**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/NN/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
