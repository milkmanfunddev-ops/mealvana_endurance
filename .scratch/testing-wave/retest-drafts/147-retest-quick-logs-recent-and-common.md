# 147: Retest: quick logs from Recent, Common and Saved meals

**Status:** ready-for-agent
**Blocked by:** 135.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** fix ticket 135 and the 2026-09-26 triage, about ten checks a run.

**What to build:** A retest run on the testing build (`app-build.json`). It re-runs each Finding's steps against ticket 135's fixes and runs the folded Saved-meals follow-up. Nothing is fixed during the run. Follow `RUNBOOK.md`.

**Accounts and start state:** test@test.com, app data cleared (its Recent, Common and Saved rows come from dev). Every meal this run logs is renamed or noted as `W<WAVE>-147` in `RUNS/notes.md` with its row id, and Removed at the end. Offline via `netcut.sh`. The run SELECTs `meal_logs` with named columns (id, name, slot, servings, calories, carbs_g, protein_g, fat_g, sodium_mg, items, upload state where shown, created_at).

**Shared account:** test@test.com is also used by 148 and 149, which log, edit and remove their own `W<WAVE>-148` / `-149` rows. Each run checks only its own rows and expects the others. If two of them share a wave, Recent's order will move. Name the row you tap by its name, never by position.

**COST:** none. No AI logging call.

## Checks

1. **An offline log is retried (112-001, priority).** `netcut.sh on --relaunch`. Log a Meal > Common > "Apple + cheese" > Log it, and Recent > one meal > Log it. Then (a) `off` and wait 60 s on the Timeline without touching; SELECT. If still missing, (b) pull the Timeline down; SELECT. Then (c) open Log a Meal; SELECT. Then (d) background and resume; SELECT. *Pass:* both rows reach dev at (a), the network coming back, and by (d) at the latest. Write down which step did it. *Verify:* DB SELECT after each step, console lines for the owed retry.
2. **Common single ingredients keep their unit (112-002).** Common > Egg at 1 serving, then 1.5. Also a search result ("Eggs") at 1.5. *Pass:* items read "1 large" and "1.5 large", never "1 serving" / "1.5 servings". *Verify:* `items` SELECT.
3. **Recent re-log scales portions readably (112-003).** Recent > "Oatmeal + raisins" at 2 servings, and a meal whose items read "4 oz cooked (115 g)" at 1.5. *Pass:* "1 cup dry" (not "2/2 cup dry") and "6 oz cooked (172.5 g)" or similar with the grams scaled. An unparsable portion reads "1.5 × <portion>". *Verify:* `items` SELECT.
4. **Scaled logs are rounded (112-004).** From the rows of checks 2 and 3. *Pass:* macros have one decimal at most, sodium is a whole number, and null stays null (no 60.449999…). *Verify:* SELECT numeric columns and items.
5. **A double tap on Log it logs once (112-006).** Common > "Banana + peanut butter" > double tap Log it (`idb ui tap` twice within 100 ms). *Pass:* one row, and no second sheet opens for the tile under the button. *Verify:* screen, SELECT count in the minute.
6. **Recent keeps the per-serving base; same names both show (112-012, 112-016 step 2).** After check 3's 2-serving re-log, open Recent. *Pass:* the Oatmeal row still shows the original 1-serving numbers, and 1 serving logs the original amount (not 408 kcal). Then Manual-log two meals with one name and different items (`W<WAVE>-147 Same`). Recent shows both. Look-around (135 notes): Edit food on the 2-serving log's items, then check whether Recent's base drifts. File what you see. *Verify:* screen, SELECT `servings` column.
7. **A Recent re-log starts on the source's slot (112-013).** Recent > a meal logged as Dinner. *Pass:* the sheet preselects Dinner, and the saved row's slot is dinner. *Verify:* screen, SELECT `slot`.
8. **Combos carry sodium (112-014).** Common > "Eggs + toast" > Log it. *Pass:* each item with a matching single ingredient has `sodium_mg`, and the row's sodium is a number. An item with no match stays null. *Verify:* SELECT items and sodium_mg.
9. **Common logs are tracked as common (112-025).** Log a combo and a single ingredient from Common, and one search result. *Pass:* each `meal_logged` analytics line has `method: common`. *Verify:* console-redacted.log `[ANALYTICS]` lines.
10. **Saved meals trash edges (112-017).** (a) Make a throwaway saved meal (Build a meal > Manual item `W<WAVE>-147 throwaway` > Also save as a favorite > Log meal). `on`, trash it, `off`: the delete reaches dev (`saved_meals` is_deleted). (b) Trash the last saved meal left on screen (only a `W<WAVE>-147` one; never test@test.com's own): the "Saved meals" header goes cleanly. (c) Offline, log a saved meal whose totals are null, then online: the row uploads with nulls, not zeros. *Verify:* screen, SELECT `saved_meals` (id, name, is_deleted, calories) and `meal_logs`.

**Findings:** 112-001, 112-002, 112-003, 112-004, 112-006, 112-012, 112-013, 112-014, 112-025; follow-ups 112-017, 112-016 (step 2; steps 1 and 3 are in 148).

**Decisions:** Lee's rulings in `triage-20260926.md` (112-012, 112-013, 112-014).

**Touches:** test@test.com. `W<WAVE>-147` meal logs (Removed at the end) and one or two throwaway saved meals (trashed). No account created.

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id, with evidence under `runs/147/`.
- [ ] Each Finding listed is closed with evidence or a new bug Finding.
- [ ] Every `W<WAVE>-147` log is Removed and every throwaway saved meal trashed at the end, checked by SELECT.

Next: /implement-lee testing-wave
