# 08-012 · Idea: /settings/food-preferences-consolidated and /settings/food-preferences/add-food are unreachable

- kind: idea
- status: closed
- ticket: 08
- run: w1-20261007T1105Z
- screen: Food Preferences; Add Food
- decision: 

**Steps.**
1. Wire or delete both routes. No push to either path in lib/ (grep, from code); Settings has its own 'Diet, Allergies & Formulas' row, and the meal builder uses a private _AddFoodScreen.

**Expected.**


**Actual.**


**Evidence.**
- runs/08/c03-food-prefs-consolidated.png
- runs/08/c04-add-food.png

**Decision quote.**
> 

**Triage.**
fix ticket (orphans): comment out the routes and move the screens to _archived, never delete (Lee): /pro, /settings/sport-settings, /settings/food-preferences-consolidated, /settings/food-preferences/add-food, the five standalone /meal-log/* screens, plus the never-built classes. Carefully: mealplanning and a paywall are coming, so /pro will likely be needed again

**Closed (wave 3, 2026-10-08).** retest passed in ticket 32 (runs/32/notes.md)
