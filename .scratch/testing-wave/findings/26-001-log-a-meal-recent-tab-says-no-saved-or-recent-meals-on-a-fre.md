# 26-001 · Log a Meal Recent tab says no saved or recent meals on a fresh sign-in until the Food tab has been opened

- kind: bug
- status: open
- ticket: 26
- run: w13-20260924T1904Z
- screen: Log a Meal (Recent)
- decision: 

**Steps.**
1. On a simulator with the app's data cleared, log in with email as test@test.com (19:06:24Z).
2. Dismiss the What's New and TrainingPeaks sheets. On Timeline tap + Add Food, then the Recent tab (19:07:15Z).
3. Back, open the Food tab (19:07:52Z), back to Timeline, + Add Food → Recent again (19:08:10Z).

**Expected.**
Recent lists the account's saved meals and its recent logs as soon as the athlete is signed in. The server holds them: 9162543b "Rice cake and Almond butter" (09-23), 8a4e9125 "Oatmeal with Blueberries" (09-16), two Patrol Build rows and a saved meal "Egg & Veggie Scramble".

**Actual.**
Step 2 showed "No saved or recent meals yet. Meals you log (and favorite) show up here." (06-recent-tab.png). The console shows why: after login only users, integrations, activities and recipes had synced; `meal_logs_last_sync` and `saved_meals_last_sync` were first written at 14:07:52 local (19:07:52Z), the moment Food opened. At step 3 Recent listed the saved meal and eight recent meals (08-recent-after-food-tab.png). Recent reads only the local database (`getRecentLogs`), and nothing on the way to Log a Meal asks for a meal_logs sync. Same root as 10-001 (timeline shows no meals until Food opens), seen here on a second screen: an athlete on a new phone who goes straight to logging sees an empty history and cannot re-log anything.

**Evidence.**
- runs/26/06-recent-tab.png
- runs/26/08-recent-after-food-tab.png
- runs/26/console-excerpts.log (lines for users/activities/recipes sync at login; saved_meals/meal_logs first synced 14:07:52 local, after diary_closed at 14:07:50)
- runs/26/db-meal-logs.txt (the Recent source row existed on the server throughout)

**Decision quote.**
> 

**Triage.**
