# 89-002 · Shared list text says 9 items to buy while 6 of the 9 are ticked

- kind: bug
- status: open
- ticket: 89
- run: w29-20260925T1950Z
- screen: Food (Shopping sub-tab) > Share
- decision: 

**Steps.**
1. test@test.com, Shopping showing hand-made list 90c2fefc "List 2026-09-19" (9 rows, 6 ticked).
2. Share in the header > Copy; read the pasteboard.

**Expected.**
The count of "items to buy" leaves out the rows already ticked, or the line says "9 items" without "to buy".

**Actual.**
The text begins "Mealvana shopping list / 9 items to buy" and then lists six rows as ☑ and three as ☐. The tab's own header also says "9 items". The count is `itemCount` = rows not marked `have`; ticked (checked) rows are still counted as to buy.

**Evidence.**
- runs/89/19-009-share-text-no-plan-list.txt: the shared text.
- runs/89/02-shopping-before-19-009.png: the list with its ticked rows.

**Decision quote.**
> 

**Triage.**
