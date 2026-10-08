# 49-009 · Swap picker: untried paths after wave 5 (search, Create Custom Food and Scan barcode in swap mode, editing a swapped item's quantity)

- kind: followup-test
- status: closed
- ticket: 49
- run: w5-20261008T1719Z
- screen: Add Food (swap picker)
- decision: 

**Steps.**
1. From Review & Log or Edit Meal, swipe an item right to left. In the picker: search a food and pick it; Create Custom Food and come back; Scan barcode on the simulator (no camera).
2. After a swap to quantity 2, open Edit Item and change Quantity to 3 (or 1.5): row text, kcal and the stored `quantity` follow.
3. Pick a food that has a serving unit (a cup, a slice) and check the row reads "2 × 1 <unit>", not "1 serving".

**Expected.**
Search and custom food return to the meal with the new item; barcode on the simulator explains itself; quantity edits after a swap keep the base portion and scale the numbers.

**Actual.**
Not run. This run checked: picker Back keeps the original item (Edit Meal, 55-picker-back.png); Apple (medium) at 1.5 = 143 kcal and at 2 = 190 kcal in both picker and row. Apple has no serving unit, so only "1 serving" was seen.

**Evidence.**
- runs/49/16-swap-picker.png — the picker's controls
- runs/49/55-picker-back.png — Back from the picker keeps the item

**Decision quote.**
> 

**Triage.**
- closed · retest passed or ran in wave 7 (ticket 68 check 10 ran it; the search crash is 68-006, Create Food 68-009, rest in 68-016) · lead, 2026-10-09
