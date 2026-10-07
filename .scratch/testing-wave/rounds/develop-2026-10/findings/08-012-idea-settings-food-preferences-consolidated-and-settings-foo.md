# 08-012 · Idea: /settings/food-preferences-consolidated and /settings/food-preferences/add-food are unreachable

- kind: idea
- status: open
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
