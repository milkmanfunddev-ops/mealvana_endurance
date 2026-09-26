# 113-007 · Back from Build a Meal throws away the whole draft (15 items) with no prompt, while Edit Meal asks Discard changes?

- kind: idea
- status: open
- ticket: 113
- run: w40-20260926T1051Z
- screen: Build a Meal
- decision: 

**Steps.**
Product question (how should the app behave?), from follow-up 25-003 "Back arrow with two items in the draft".

1. Build a meal with 15 items (a Manual food, a six-ingredient recipe, Quick add combos, two searched foods), then tap Back (11:02Z). Reopen Build a meal.
2. The builder is empty ("Start building your meal"); the draft is gone with no prompt. The code does this on purpose: `DraftMealController` auto-disposes when the screen closes "so re-opening it always starts a fresh draft".
3. Edit Meal, by contrast, stops Back with "Discard changes? … Keep editing / Discard / Save".

Question for Lee: should Back from a non-empty Build a Meal ask before throwing the items away (as Edit Meal does), or keep the draft for the day? A mis-tap on Back loses minutes of building. Related open follow-up: 112-023.

**Expected.**
A decision on Back from a non-empty draft.

**Actual.**
Draft discarded silently.

**Evidence.**
- runs/113/46-builder-many-items.png (15-item draft)
- runs/113/49-builder-reopened.png (empty after Back and reopen)
- runs/113/61-edit-meal-leave-dialog.png (Edit Meal's leave dialog, for comparison)

**Decision quote.**
> 

**Triage.**
