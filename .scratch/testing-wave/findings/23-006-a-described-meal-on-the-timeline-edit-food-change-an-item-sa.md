# 23-006 · A described meal on the timeline: Edit food (change an item, Save changes) and Remove, with the day's totals and the row checked

- kind: followup-test
- status: triaged
- ticket: 23
- run: w13-20260924T1903Z
- screen: Timeline
- decision: 

**Steps.**
1. Tap a described meal on the Timeline: it shows Edit food and Remove.
2. Edit food, change one item's portion, Save changes: the card, Eaten on the Net Energy Balance card and the meal_logs row (items, totals, updated_at) all move together.
3. "Scan a photo" on Edit Meal for a described meal: whether it replaces the items and costs an AI call.
4. Remove: the card goes, Eaten drops by the meal's kcal, the row gets is_deleted = true.

**Expected.**
The screen and the row agree after each change.

**Actual.**
Not run; this run opened Edit food and went Back without saving. Use a meal this ticket made (W13-23 in the name), never one from a shared-account ticket.

**Evidence.**
- runs/23/13-meal-opened.png: Edit food and Remove under the card.
- runs/23/14-edit-food.png: Edit Meal.

**Triage.**

Picked for retest ticket 91 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 114 when 91 was split (Lee, 2026-09-25).
