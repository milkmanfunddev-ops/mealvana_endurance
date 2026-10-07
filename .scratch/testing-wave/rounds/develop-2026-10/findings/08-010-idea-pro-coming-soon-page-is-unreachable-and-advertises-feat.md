# 08-010 · Idea: /pro 'Coming Soon' page is unreachable and advertises features that already ship

- kind: idea
- status: triaged
- ticket: 08
- run: w1-20261007T1105Z
- screen: Mealvana Pro (/pro)
- decision: 

**Steps.**
1. Wire /pro from somewhere, or delete ProVersionScreen and its route. Nothing in lib/ pushes '/pro' (grep, from code).

**Expected.**


**Actual.**


**Evidence.**
- runs/08/c01-pro.png lists 'App Integrations' (TrainingPeaks, Final Surge, V.O2) and 'Barcode Scanning' as coming soon, while Settings → Connected Apps and Add Food's barcode scan exist

**Decision quote.**
> 

**Triage.**
fix ticket (orphans): comment out the routes and move the screens to _archived, never delete (Lee): /pro, /settings/sport-settings, /settings/food-preferences-consolidated, /settings/food-preferences/add-food, the five standalone /meal-log/* screens, plus the never-built classes. Carefully: mealplanning and a paywall are coming, so /pro will likely be needed again
