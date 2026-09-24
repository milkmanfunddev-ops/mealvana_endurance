# 26-003 · A Common quick-add combo saves under a name built from its items, not the name on the tile

- kind: bug
- status: open
- ticket: 26
- run: w13-20260924T1904Z
- screen: Log a Meal (Common) → quick log sheet
- decision: 

**Steps.**
1. Log a Meal → Common → Quick add → tap "🥣 Oatmeal + raisins" (204 kcal · C 41g P 6g F 3g).
2. The sheet is titled "Oatmeal + raisins". Meal type Any time, Log it (19:09:30–19:09:31Z).
3. Read the new row; reopen Log a Meal → Recent.

**Expected.**
The meal is saved and later shown as "Oatmeal + raisins", the name the athlete picked and the sheet showed.

**Actual.**
Row f952f981 is named "Rolled oats and Raisins" (`deriveMealName` over the two items). Its items and totals equal the tile exactly (Rolled oats 1/2 cup dry 150/27/5/2.5, Raisins 2 tbsp 54/14/0.6/0.1; 204 kcal, 41.0 C, 5.6 P, 2.6 F; SQL `items_eq true`, `tile_name_eq false`). The timeline and Recent then show "Rolled oats and Raisins" (21-recent-reopened.png), and Recent's name-based de-duplication treats it as a different meal from the tile. The account's older "Rice cake and Almond butter" log looks like the same thing happening to the "Rice cake + almond butter" tile. The quick-add path also persists `source = manual`, so nothing in the row says it came from Common.

**Evidence.**
- runs/26/13-common-confirm-sheet.png
- runs/26/14-common-after-log.png
- runs/26/21-recent-reopened.png
- runs/26/db-meal-logs.txt (row f952f981 and the "common" comparison line)

**Decision quote.**
> 

**Triage.**
