# 149: Retest: Build a Meal, favourites, Edit Meal, Manual and barcode entry

**Status:** ready-for-agent
**Blocked by:** 136.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** fix ticket 136 and the 2026-09-26 triage, about ten checks a run.

**What to build:** A retest run on the testing build (`app-build.json`). It re-runs each Finding's steps against ticket 136's fixes and runs the folded Build a Meal and scanner follow-ups. Nothing is fixed during the run. Follow `RUNBOOK.md`.

**Accounts and start state:** test@test.com, app data cleared. Every log and favourite is named `W<WAVE>-149 …`. Logs are Removed and favourites trashed at the end. Camera permission for check 11: `xcrun simctl privacy UDID reset camera com.milkman.mealvanaendurance.dev` before the first scanner tap.

**Shared account:** test@test.com is also used by 147 and 148 (their own `W<WAVE>-147/148` rows). Check only your own rows.

**COST:** none.

## Checks

1. **Trashing a Saved meal offers Undo (112-005).** Make `W<WAVE>-149 throwaway` (Build a meal > Manual item > Also save as a favorite > Log meal). Log a Meal > Recent > trash its Saved row. *Pass:* a snackbar with Undo. Undo brings the row back, and `saved_meals` is_deleted is false again after a sync. Trash it again and let the snackbar go: it stays deleted. *Verify:* screen, SELECT (id, is_deleted, updated_at).
2. **A Build a Meal favourite carries totals and the log id (112-007, 113-009).** Build a meal with two items with numbers (100 kcal, 10 g carbs and a second one), tick Also save as a favorite, Log meal. *Pass:* `saved_meals` has the summed calories and macros (a macro no item has stays null). Its quick log sheet does not say 0 kcal. The `meal_saved_as_favorite` analytics line carries the new log's id. The log row's `saved_meal_id` points at the favourite (if 136 could write it; its notes say whether). *Verify:* SELECT both tables, console `[ANALYTICS]`.
3. **Save as favorite from the Timeline (112-008).** A logged `W<WAVE>-149` meal > ⋯. *Pass:* Save as favorite is offered. The tap shows a confirmation snackbar and writes a `saved_meals` row with that meal's totals. Record whether it is still offered once the meal is a favourite (136 open question). *Verify:* screen, SELECT.
4. **The same combo twice (113-001).** Build a meal > + Add food > Common > Quick add "Banana + peanut butter", twice. *Pass:* four editable rows. No red "Duplicate keys found". Log meal writes all four items. *Verify:* screen, SELECT items.
5. **Back from Build a Meal (113-007, 112-023).** (a) A draft with two items > Back: Discard / Keep building. Keep building keeps the draft. Discard leaves. (b) The iOS swipe asks the same. (c) An empty builder leaves without asking. (d) "Start from a saved meal / recent" with a multi-item saved meal fills every item. (e) The meal name prefilled from the only item: add a second item and check the name. *Pass:* (a)-(d). (e) is recorded, and a stale name is an idea Finding. *Verify:* screen.
6. **Edit Meal saves decimal and empty calories (113-002).** Log `W<WAVE>-149 Decimal` at 251 kcal. Edit food > 250.5 > Save changes. Then empty the field and Save. *Pass:* 250.5 stores 251. Empty stores null (unknown), and the Timeline shows "—". "Meal updated" shows only when something was written. *Verify:* SELECT calories after each save.
7. **Untouched macros are not rewritten (113-003).** Log a meal with protein 12.25. Edit food, change only carbs, Save. *Pass:* protein_g stays 12.25. *Verify:* SELECT protein_g, carbs_g.
8. **Unknown macros show as unknown (113-004, 113-010 step 1).** Manual `W<WAVE>-149 No macros` with every number empty > Save. Then Build a meal > Scan barcode > Enter 4006381333931 (an Open Food Facts product with no nutrition) > add > Log meal. *Pass:* the Timeline row shows "—", not "0 kcal · 0C · 0P · 0F". Build a Meal's total shows unknown for the no-data item. Rows store null, not 0, and the day's sums skip them. *Verify:* screen, SELECT.
9. **The empty-name error is visible (113-005).** Manual, nothing typed, scroll to Save, tap it. *Pass:* the form scrolls to the name field and focuses it, and "Name is required" is on screen. *Verify:* screenshot.
10. **Barcode entry needs 8 to 14 digits (113-006).** Scan barcode > Enter > 12345. *Pass:* Look it up stays disabled, or an inline message about typing (not "try scanning again") shows. An 8-digit and a 13-digit number are accepted. Record what 9-11 digits do (136 open question). *Verify:* screen.
11. **The scanner with the camera refused, and its other doors (100-009, 118-015, 113-010 step 3).** Build a Meal > + Add food > Scan barcode: at the iOS camera prompt choose Don't Allow. *Pass:* the app says the camera is off and still offers Enter a barcode and Search for the food instead, and both work. Then open the scanner from each other entry point the app shows (plan Add Food, Swap food, carb-loading, Food preferences, where mounted), and note which exist. *Verify:* screen.

**Not counted (device: not run on simulator):** 113-010 step 2 (a real camera scan from Log a Meal and from Build a Meal). Give it a verdict row "device: not run on simulator".

**Findings:** 112-005, 112-007, 113-009, 112-008, 113-001, 113-007, 113-002, 113-003, 113-004, 113-005, 113-006; follow-ups 112-023, 113-010, 100-009, 118-015.

**Decisions:** Lee's rulings in `triage-20260926.md` (112-008, 113-007).

**Touches:** test@test.com: `W<WAVE>-149` logs and favourites (removed or trashed at the end). No account created.

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id, with evidence under `runs/149/`.
- [ ] Each Finding listed is closed with evidence or a new bug Finding.
- [ ] Every `W<WAVE>-149` log and favourite is removed at the end, checked by SELECT.

Next: /implement-lee testing-wave
