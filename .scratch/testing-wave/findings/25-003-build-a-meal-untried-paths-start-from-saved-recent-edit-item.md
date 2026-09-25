# 25-003 · Build a Meal: untried paths (Start from saved/recent, Edit item quantity scaling, remove an item, Also save as a favorite, back with a draft, Time eaten stamped at open)

- kind: followup-test
- status: triaged
- ticket: 25
- run: w14-20260924T2015Z
- screen: Build a Meal
- decision: 

**Steps.**
1. Log a Meal → Build a meal. Ticket 25 added Chicken breast (Common) and a Manual food, renamed the meal, picked Dinner and logged it; the saved row matched exactly. Nothing else was tried.

**Expected.**
Each path below saves what the builder shows:
- "Start from a saved meal / recent": pick a saved meal and a multi-item recent log; are the items copied one by one (compare 26-002, where a Recent re-log collapses them)?
- Edit item (pencil): the sheet has Quantity "Scales the nutrients below"; set 1.5 and check the saved item and totals, then edit a macro by hand and check which wins. The sheet was opened by accident in this run and cancelled (22-edit-item-sheet.png).
- Remove an item (swipe or edit), then log: totals drop by exactly that item.
- "Also save as a favorite": a saved_meals row with the same items appears, and the log's saved_meal_id.
- Back arrow with two items in the draft: is the draft kept when Build a meal is reopened (draftMealControllerProvider is per log date)?
- Add a note ("Add a note"), check the row's notes.
- Time eaten: shows the time the builder opened (3:19 PM), and the row got eaten_at 20:19Z though it was logged at 20:21:48Z; decide whether that is intended (same kind as 26-009).
- Meal name: auto-name "Chicken breast and W14-25 jasmine rice" tracks the items until edited; check that adding a third item after renaming keeps the user's name.

**Actual.**
Not run in ticket 25.

**Evidence.**
- runs/25/19-builder-two-items.png
- runs/25/21-builder-ready.png
- runs/25/22-edit-item-sheet.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 91 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 113 when 91 was split (Lee, 2026-09-25).
