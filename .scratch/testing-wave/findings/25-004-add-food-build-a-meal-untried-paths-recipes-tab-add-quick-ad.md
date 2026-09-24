# 25-004 · Add food (build a meal): untried paths (Recipes tab add, Quick add combo, search results, barcode button, adding the same food twice)

- kind: followup-test
- status: open
- ticket: 25
- run: w14-20260924T2015Z
- screen: Build a Meal → + Add food (Recipes, Common, Manual tabs)
- decision: 

**Steps.**
1. Build a Meal → + Add food. Ticket 25 used Common → Chicken breast and Manual → one food. Nothing else was tried.

**Expected.**
- Recipes tab: add a multi-ingredient recipe (e.g. Chicken & Brown Rice Recovery Bowl, 6 ingredients); does it add one line or its ingredients, and do the totals equal the recipe row?
- Common → Quick add combo (e.g. Eggs + toast): both items added.
- Search field: results from the catalog, USDA and OpenFoodFacts; confirm no AI call is made (edge logs) and that a picked result's macros reach the draft unchanged.
- The barcode icon in the search bar on a simulator (no camera): what shows.
- Tapping the same ingredient twice: two lines or a quantity of 2.
- The screen gives only a snackbar per add and no count of what is already in the meal; check whether an athlete can tell what they have added before going back.
- The Manual form's portion field starts as "1 serving": clear it and add; the code falls back to "1 serving".

**Actual.**
Not run in ticket 25.

**Evidence.**
- runs/25/12-add-food-recipes.png
- runs/25/13-add-food-common.png
- runs/25/16-add-food-manual.png

**Decision quote.**
> 

**Triage.**
