# 88-019 · Delete plan leaves the plan's shopping list in Previous lists although the dialog says it goes with it

- kind: bug
- status: triaged
- ticket: 88
- run: w29-20260925T1949Z
- screen: Food > Plan (Plan options > Delete plan); Shopping > Previous lists
- decision: 

**Steps.**
1. Retest of 14-007 step 3. Confirmed 8ebeb6da (list 2aeb8156, 5 rows). Plan options > Delete plan; the dialog reads "The meals and shopping list for this week go with it. You can undo for a moment afterwards." Tap Delete (20:26:34Z); wait past the undo.
2. Read meal_plans and shopping_lists; open Shopping > List options > Previous lists.

**Expected.**
The plan and its list are gone (the draft 666be167 is untouched).

**Actual.**
8ebeb6da has is_deleted = true (status stays confirmed) and the draft is untouched, but list 2aeb8156 is still there with confirmed_at, and Previous lists shows it as "Week of Sep 20 · From plan · 5 items". Confirming the draft afterwards worked and archived nothing unexpected.

**Evidence.**
- runs/88/111-14-007-delete-confirm-dialog.png: the dialog text.
- runs/88/db-25-after-delete.txt: 8ebeb6da is_deleted, 2aeb8156 kept.
- runs/88/115-14-007-previous-lists-after-delete.png

**Decision quote.**
> 

**Triage.**

Fix ticket 127 (Lee, 2026-09-25). Closed by the retest after it merges.
