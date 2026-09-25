# 112-019 · Log a Meal Recipes: the Recipes tab offline on a fresh install, and recipe calories when servings > 1

- kind: followup-test
- status: open
- ticket: 112
- run: w34-20260925T2320Z
- screen: Log a Meal (Recipes)
- decision: 

**Steps.**
1. 26-008 step 4, not run here (the app already had recipes): clear the app, sign in, cut the network before opening Recipes.
2. Confirm with the recipe owner that `recipes.calories` is per serving: "Banana & Rice Peanut Butter Chews" (servings 8) shows 195 kcal per tile and logs 195 × servings; Build a meal lists it as "5 ingredients" at the same 195.

**Expected.**
A clear empty/offline state; the tile's figure is per serving.

**Actual.**


**Evidence.**
- runs/112/31-recipes-tab.png
- runs/112/65-build-add-food.png

**Decision quote.**
> 

**Triage.**
