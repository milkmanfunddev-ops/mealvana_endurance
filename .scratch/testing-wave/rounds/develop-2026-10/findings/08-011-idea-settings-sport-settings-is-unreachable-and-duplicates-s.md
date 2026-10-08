# 08-011 · Idea: /settings/sport-settings is unreachable and duplicates Settings → Sport Preferences

- kind: idea
- status: closed
- ticket: 08
- run: w1-20261007T1105Z
- screen: Sport Settings (/settings/sport-settings)
- decision: 

**Steps.**
1. Delete SportSettingsScreen and its route, or point Settings → Sport Preferences at it; its only link is in the unmounted SettingsMenuScreen (from code). Settings already shows 'Sport Preferences | Running, cycling, and swimming'.

**Expected.**


**Actual.**


**Evidence.**
- runs/08/c02-sport-settings.png
- runs/08/a04-settings.png Settings' Sport Preferences row

**Decision quote.**
> 

**Triage.**
fix ticket (orphans): comment out the routes and move the screens to _archived, never delete (Lee): /pro, /settings/sport-settings, /settings/food-preferences-consolidated, /settings/food-preferences/add-food, the five standalone /meal-log/* screens, plus the never-built classes. Carefully: mealplanning and a paywall are coming, so /pro will likely be needed again

**Closed (wave 3, 2026-10-08).** retest passed in ticket 32 (runs/32/notes.md)
