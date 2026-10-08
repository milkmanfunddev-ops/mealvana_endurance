# 08-016 · Follow-up: Choose a Recipe on a vegetarian account lists salmon and chicken recipes

- kind: followup-test
- status: closed
- ticket: 08
- run: w1-20261007T1105Z
- screen: Choose a Recipe (/meal-log/recipe)
- decision: 

**Steps.**
1. test@test.com is Vegetarian (Food Preferences). Open the recipe picker through the Log a meal sheet and check whether meat and fish recipes should be filtered or marked.

**Expected.**
Recipes respect the dietary preference, or the spec says the picker is unfiltered.

**Actual.**


**Evidence.**
- runs/08/c10-meal-log-recipe.png 'Baked Salmon & Sweet Potato Recovery Bowl', 'Chicken & Brown Rice Recovery Bowl'
- runs/08/c03-food-prefs-consolidated.png Vegetarian selected

**Decision quote.**
> 

**Triage.**
retest ticket 32 (retest: startup, tabs, deep links), wave 3 (Lee: all 27 followups into four retest tickets)

**Closed (wave 3, 2026-10-08).** run in ticket 32; unfiltered with no rule, idea 32-014
