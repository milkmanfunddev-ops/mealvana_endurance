# 32-014 · Idea: Recipes tab offers salmon, chicken and turkey recipes to a vegetarian account with no marker; no SSOT rule covers the log sheet's recipe list

- kind: idea
- status: open
- ticket: 32
- run: w3-20261008T1256Z
- screen: Log a Meal, Recipes
- decision: 

**Steps.**
1. Decide whether the Log a Meal sheet's Recipes tab filters or marks recipes against the athlete's Dietary
   Preference, as plan generation (`docs/ssot/spec/recommendation/generate-plan.md` H2) and formula pins
   (`formula-pin-surface.md` FP-4a) already do. Today `recipe_repository.dart:83-86` selects every active recipe.
   On test@test.com (Vegetarian) the tab lists Baked Salmon & Sweet Potato Recovery Bowl, Chicken & Brown Rice
   Recovery Bowl, Salmon Sushi, Smashed Avocado Toast with Smoked Salmon, Teriyaki Chicken Rice, and two turkey
   recipes, unmarked. Retest of 08-016: unfiltered, and no ratified rule is broken.

**Expected.**
A product ruling (filter, mark, or leave as is).

**Actual.**
Product question for the review queue.

**Evidence.**
- runs/32/h03-recipes-list.txt the 30 recipes offered
- runs/32/g02-food-preferences.png Vegetarian
- runs/32/h02-recipes-tab.png the tab

**Decision quote.**
> 

**Triage.**
