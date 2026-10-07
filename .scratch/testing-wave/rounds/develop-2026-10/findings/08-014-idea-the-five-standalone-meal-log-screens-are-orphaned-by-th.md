# 08-014 · Idea: the five standalone /meal-log/* screens are orphaned by the Log a meal sheet

- kind: idea
- status: triaged
- ticket: 08
- run: w1-20261007T1105Z
- screen: Log a Meal, Photo, Describe to Mealvana, Recent & Saved, Choose a Recipe
- decision: 

**Steps.**
1. Delete the routes /meal-log/manual, photo, describe, recent-saved and recipe (and screens not used elsewhere), or wire them. No push to any of them in lib/ (grep, from code: only /meal-log/edit and /meal-log/review are pushed). All five render by deep link.

**Expected.**


**Actual.**


**Evidence.**
- runs/08/c06-meal-log-manual.png
- runs/08/c07-meal-log-photo.png
- runs/08/c08-meal-log-describe.png
- runs/08/c09-meal-log-recent-saved.png
- runs/08/c10-meal-log-recipe.png

**Decision quote.**
> 

**Triage.**
fix ticket (orphans): comment out the routes and move the screens to _archived, never delete (Lee): /pro, /settings/sport-settings, /settings/food-preferences-consolidated, /settings/food-preferences/add-food, the five standalone /meal-log/* screens, plus the never-built classes. Carefully: mealplanning and a paywall are coming, so /pro will likely be needed again
