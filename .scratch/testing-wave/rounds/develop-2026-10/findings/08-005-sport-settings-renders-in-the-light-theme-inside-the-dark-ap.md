# 08-005 · Sport Settings renders in the light theme inside the dark app, and its FTP value is nearly invisible

- kind: bug
- status: closed
- ticket: 08
- run: w1-20261007T1105Z
- screen: Sport Settings (/settings/sport-settings)
- decision: 

**Steps.**
1. Dark app theme (as the rest of the run). Open xcrun simctl openurl <udid> "com.milkman.mealvanaendurance:///settings/sport-settings" (three slashes), signed in as test@test.com.

**Expected.**
The screen follows the app's dark Kyle theme and the stored FTP reads clearly.

**Actual.**
Cream background with black headings while every other screen is dark; the FTP field's value '180' is pale on white and hard to see; a teal 'TrainingPeaks' chip (idb also lists 'stale'). Water Bottles shows none of 1/2/3+ selected.

**Evidence.**
- runs/08/c02-sport-settings.png

**Decision quote.**
> 

**Triage.**
fix ticket (orphans): comment out the routes and move the screens to _archived, never delete (Lee): /pro, /settings/sport-settings, /settings/food-preferences-consolidated, /settings/food-preferences/add-food, the five standalone /meal-log/* screens, plus the never-built classes. Carefully: mealplanning and a paywall are coming, so /pro will likely be needed again

**Closed (wave 3, 2026-10-08).** retest passed in ticket 32 (runs/32/notes.md)
