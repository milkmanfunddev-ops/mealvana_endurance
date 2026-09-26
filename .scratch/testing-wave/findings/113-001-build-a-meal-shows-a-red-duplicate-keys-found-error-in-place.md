# 113-001 · Build a Meal shows a red 'Duplicate keys found' error in place of the items when the same Quick add combo is added twice

- kind: bug
- status: triaged
- ticket: 113
- run: w40-20260926T1051Z
- screen: Build a Meal
- decision: 

**Steps.**
1. Follow-up 25-004 ("adding the same food twice"). Signed in as test@test.com, today.
2. Timeline → + Add Food → Build a meal → + Add food → Common → Quick add "Banana + peanut butter" (11:07:0xZ), wait for "Added Banana + peanut butter", tap it again.
3. Back to Build a Meal.
4. Seen first at 11:02Z with a mixed draft (Manual food, a recipe, Eggs + toast, Banana + peanut butter twice, Almonds), then reproduced alone as above.

**Expected.**
Two Banana and two Peanut butter lines (or one line with a quantity of 2), each editable and swipeable.

**Actual.**
The Items card is replaced by Flutter's red debug error box: "Duplicate keys found. If multiple keyed widgets exist as children of another widget, they must have unique keys. Column(...) has multiple children with key [MealComponent#3c207]." No line can be seen, edited or swiped away; the totals row (398 kcal) and Log meal still work. Logging it ("W40-113 Twice", 11:07:36Z) saved four items and 398 kcal correctly (row 4561f7ca). In a release build the box is a grey area instead, so the athlete sees an empty items list.
Likely cause (code read): `MealComponentEditor` keys each row `Dismissible(key: ObjectKey(item))`, and a Quick add combo adds the same `MealComponent` instances each time, so two adds give two rows with the same ObjectKey. Loading the same four items from the database into Edit Meal renders fine (distinct objects, 71-edit-meal-twice-items.png). No Flutter error line reached the console.

**Evidence.**
- runs/113/47-items-a.png (mixed draft, red box)
- runs/113/56-builder-same-combo-twice.png (combo added twice, red box)
- runs/113/db-after-twice.txt (the logged row holds all four items)
- runs/113/71-edit-meal-twice-items.png (Edit Meal shows the same items without error)

**Decision quote.**
> 

**Triage.**

Fix ticket 136, Build a Meal, saved meals, Manual and Edit (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
