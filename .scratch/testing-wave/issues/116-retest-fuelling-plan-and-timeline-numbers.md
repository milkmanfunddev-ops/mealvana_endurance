# 116: Retest: the fuelling plan, the Plan-tab note and the timeline's numbers

**Status:** in-progress (wave 32, 2026-09-25)
**Blocked by:** none.
**Pair with:** 115 (confirms a Draft on test@test.com last, 16-003), and any of 112, 113, 114 (they log, edit and remove meals on test@test.com today). This run logs and removes two Manual meals (27-001) and logs snacks (26-010) on test@test.com today. Read every figure with its time in `notes.md`, and the rows behind it at the same minute.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** 92 (Lee, 2026-09-25: about ten checks per run).

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 09-002 27-001 27-006 30-003 30-004. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 30-008 (Activity fuelling screen: By Hour tab, low-carb info icon, snack expander, After targets, a session with no stored plan), 03-005 (formula_pin_conflict has never run on the dev admin: no Before library formula conflicts with its allergies), 14-010 (Plan tab Vana note says the day needs 1007 g of carbs), 25-006 (Timeline daily budget on test@test.com reads 8,839 kcal with 475 g fat; check the numbers behind it), 30-009 (Net balance: every past day reads -2,447 and every future day +0), 05-009 (Timeline for a brand-new account shows a net balance of -229 kcal slight deficit before anything is logged), 26-010 (Timeline groups two snacks eaten a minute apart under the first one's time, and net balance moved 597 kcal for 672 kcal logged). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup for the number checks:** 14-010, 25-006, 30-009, 05-009 and 26-010 are about numbers. Read each figure off the screen, then read what produced it (the day's `calculate-daily-macros` answer or the stored rows, SELECT only) and say which one is wrong, if either. A figure the SSOT rules is checked against `docs/ssot/`.

**Setup:** test@test.com. Before 30-003, clear test@test.com's `nutrition_target_overrides.during` (50.4 g/h) through the app's own edit path, or record that the override is set and judge 30-003 by override behaviour (mp-680). Write down which in `notes.md`. **30-005 is not retestable** (it waits on Xuan) and is not in this ticket. 09-002 reads the Vana note on test@test.com's confirmed plan: no new plan. 05-009 needs a new account that buys Pro (Test Store). 03-005 runs on the Patrol account (`CRED list`) as its Steps say.

**Order:** the Plan-tab note (09-002, 14-010) and the figures (25-006, 30-009) before this run logs anything; 26-010 and 27-001 after.

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes, and the meals it logs and removes on test@test.com.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [x] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/116/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [x] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [x] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
