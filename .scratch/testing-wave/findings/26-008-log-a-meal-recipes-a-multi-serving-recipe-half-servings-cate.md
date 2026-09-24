# 26-008 · Log a Meal Recipes: a multi-serving recipe, half servings, category filters and search

- kind: followup-test
- status: open
- ticket: 26
- run: w13-20260924T1904Z
- screen: Log a Meal (Recipes)
- decision: 

**Steps.**
1. Log a recipe whose `servings` is more than 1, e.g. "Banana & Rice Peanut Butter Chews" (servings 8, 195 kcal) or "Red Lentil & Vegetable Soup" (servings 4).
2. Log a recipe at 0.5 and at 2 servings.
3. Tap each category chip (Breakfast, Mains, Snacks, Workout Fuel, Recovery; Recovery is cut off at the right edge, 16-recipes-snacks.png) and check the list; search a recipe by name.
4. Open the Recipes tab offline on a fresh install (recipes not yet synced).

**Expected.**
The logged calories match the per-serving figure the tile shows times the servings, and the tile's figure is per serving (check what `recipes.calories` means when servings > 1). Filters show only that type. Offline with no local recipes: a clear empty or offline state, not a spinner forever.

**Actual.**


**Evidence.**
- runs/26/15-recipes-tab.png
- runs/26/16-recipes-snacks.png

**Decision quote.**
> 

**Triage.**
