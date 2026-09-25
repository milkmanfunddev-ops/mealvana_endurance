# 86-001 · Rows another account left on the phone before the sign-out fix are never cleared: signed in as test@test.com, Lee's plans, logs and activities are still in the local database

- kind: bug
- status: triaged
- ticket: 86
- run: w25-20260925T1324Z
- screen: Welcome → Log in (email) → Timeline
- decision: 

**Steps.**
Retest of 14-004 (fix ticket 33), on the dev simulator's leftover data as the wave lead set it up.
1. Simulator wave-pool-1, app build 5e05f8a6, app data not cleared: it opens signed out on Welcome and its
   local database holds rows of two accounts, 37129f7e (Lee's dev account) and 607f9dd5 (test@test.com),
   left by a sign-out made before ticket 33 (runs/86/local-drift-00-before-launch.txt).
2. Log in with email as test@test.com (13:26:18Z).
3. Read the local Drift database read-only and count rows per user_id (13:26:42Z).

**Expected.**
Finding 14-004's Expected: signing out clears the previous account's local data, "or at least signing in as
another account leaves none of it on the phone". Ticket 33: "Signing out, or signing in as a different
account, leaves nothing of the previous account on the phone."

**Actual.**
Signed in as 607f9dd5, the database still holds every row of 37129f7e: activities 58, meal_logs 24,
meal_plans 4, plan_meals 10, events 3, carb_loading_plans 3, food_preferences_table 46, integrations 1
(Runna), plus its `users` row. Ticket 33 clears an account's rows only when that account signs out
(`AppDatabase.clearUserData(userId)` from the sign-out path), so rows already on a phone from before the fix
(any install updated from 1.27.x or earlier) are never removed: they survived three sign-ins and four
sign-outs or deletions of other accounts in this run. Nothing of 37129f7e was seen on screen. The sign-out part of the fix
does work: test@test.com's rows were gone after each of its sign-outs, and the new account's after its own.

**Evidence.**
- runs/86/local-drift-00-before-launch.txt (leftover, before launch)
- runs/86/local-drift-01-after-login-test.txt (signed in as test@test.com: 37129f7e rows all present)
- runs/86/local-drift-02-after-settings-signout.txt (after test@test.com signs out: only 37129f7e rows left)
- runs/86/local-drift-06-after-delete-A.txt (end of run: 37129f7e rows still there)

**Decision quote.**
> 

**Triage.**
Fix ticket 102 (Lee, 2026-09-25): signing in sweeps other accounts' rows the server already holds and keeps their unsynced rows. Closed by retest ticket 107 after it merges.
Moved to retest ticket 120 when 107 was split (Lee, 2026-09-25).
