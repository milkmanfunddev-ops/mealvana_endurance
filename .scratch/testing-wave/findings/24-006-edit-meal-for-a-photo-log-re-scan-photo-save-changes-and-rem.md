# 24-006 · Edit Meal for a photo log: Re-scan photo, Save changes, and Remove from the timeline card

- kind: followup-test
- status: open
- ticket: 24
- run: w14-20260924T2015Z
- screen: Edit Meal, Timeline meal card
- decision: 

**Steps.**
1. Open a photo log from the timeline, Edit food: tap the photo ("Tap to re-scan") or Re-scan photo.
   Spend a logging call first; check it charges once and replaces the items.
2. Change the name, slot or time and Save changes; check the row and the timeline.
3. Timeline card, Remove: check `is_deleted` and whether the photo object in `meal-photos` is deleted.

**Expected.**
1: one new ai_usage row and ledger debit, items replaced, same log id. 2: row updated. 3: row
soft-deleted; photo handling as the product intends.

**Actual.**


**Evidence.**
- runs/24/14-edit-food.png: Edit Meal showing the photo, Tap to re-scan and Re-scan photo.
- runs/24/13-meal-opened.png: the expanded card with Edit food and Remove.

**Decision quote.**
> 

**Triage.**
