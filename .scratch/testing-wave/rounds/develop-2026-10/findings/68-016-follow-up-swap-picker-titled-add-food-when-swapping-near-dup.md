# 68-016 · Follow-up swap picker: titled 'Add Food' when swapping, near-duplicate Bagel rows, quantity steps of 0.5

- kind: followup-test
- status: open
- ticket: 68
- run: w7-20261008T2309Z
- screen: Edit Meal > swipe right-to-left > swap picker
- decision: 

**Steps.**
1. Swiped the item right to left: picker heading 'Add Food', button 'ADD FOOD', swap_food_screen_viewed {is_swapping: false}. Recommended list holds 'Bagel (Large)' 56 g and 'Bagel (large)' 53 g. Quantity stepper moves 1.0 -> 1.5 -> 2.0.

**Expected.**
Next wave tries (after 68-006 is fixed): search and pick, check the title says Swap; whether the duplicate bagels are two catalog rows; a food whose serving is ½ cup at quantity 2 (code says the row would still read '1 cup'); Back from the picker with a food selected but not added.


**Actual.**
Not run (look-around).


**Evidence.**
- runs/68/10b-swap-picker.png: the 'Add Food' title and list.

**Decision quote.**
> 

**Triage.**

