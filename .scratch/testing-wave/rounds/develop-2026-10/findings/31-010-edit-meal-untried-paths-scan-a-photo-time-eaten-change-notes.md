# 31-010 · Edit Meal: untried paths (Scan a photo, Time eaten Change, Notes edit, Hide details, Back with unsaved changes)

- kind: followup-test
- status: open
- ticket: 31
- run: w3-20261008T1256Z
- screen: Edit Meal
- decision: 

**Steps.**
1. From a meal card's ⋯ -> Edit food: try Scan a photo (a re-scan is an AI call: spend first), Time eaten -> Change across midnight, edit the Notes text, Hide details, and Back after changing an item without Save changes.

**Expected.**
Each change shows the same on the card, Net Balance and the row; Back with unsaved changes asks or keeps nothing; a re-scan costs one token.

**Actual.**


**Evidence.**
- runs/31/33-edit-meal.png — Edit Meal controls
- runs/31/38-edit-meal-lunch.png — slot chips, Time eaten, items

**Decision quote.**
> 

**Triage.**

