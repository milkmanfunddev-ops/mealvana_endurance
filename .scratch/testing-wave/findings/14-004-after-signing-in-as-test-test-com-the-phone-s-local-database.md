# 14-004 · After signing in as test@test.com the phone's local database still holds another account's plans, logs, activities and events

- kind: bug
- status: open
- ticket: 14
- run: w8-20260924T1418Z
- screen: Welcome → Log in (email) → Timeline
- decision: 

**Steps.**
1. The simulator's app was on the welcome screen, signed out (it was copied from the dev simulator, last signed in as another account).
2. Log in with email as test@test.com (user 607f9dd5).
3. Read the app's local Drift database read-only (14:24:58Z) and count rows whose user_id is not 607f9dd5.

**Expected.**
Signing out clears the previous account's local data, or at least signing in as another account leaves none of it on the phone.

**Actual.**
The local database holds rows of user 37129f7e (Lee's own dev account): meal_plans 4, plan_meals 10, meal_logs 24, activities 58, events 3, carb_loading_plans 3, food_preferences_table 46, integrations 1. None of it was seen on screen in this run, but it sits beside the signed-in account's rows, and 14-003's stray meal may be one of them. How the simulator was signed out (in the app or by the copy) is not known to this run.

**Evidence.**
- runs/14/local-drift-users.txt — row counts per user_id in the local database.

**Decision quote.**
> 

**Triage.**

