# 31-011 · Log a Meal Describe and the swap picker: untried paths (Camera on the simulator, Gallery cancel, very long text, picker Back, search and Create Custom Food in swap mode)

- kind: followup-test
- status: triaged
- ticket: 31
- run: w3-20261008T1256Z
- screen: Log a Meal (Describe tab)
- decision: retest ticket 49 (meal logging), wave 5

**Steps.**
1. Describe: tap Camera on the simulator (no camera); open Gallery and cancel; paste a 1,000-character description; Analyze twice quickly (one token or two?).
2. Review swap picker (swipe right to left): Back without choosing, search a food, Create Custom Food, Scan barcode; then edit the swapped item's Quantity in Edit Item.

**Expected.**
No-camera path explained; cancel leaves the text; a double tap charges once; picker Back keeps the original item; editing a swapped item keeps its numbers consistent.

**Actual.**


**Evidence.**
- runs/31/05-log-meal-sheet.png — Describe tab controls
- runs/31/23-swap-picker.png — swap picker

**Decision quote.**
> 

**Triage.**

