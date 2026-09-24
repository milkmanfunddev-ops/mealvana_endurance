# 31 expected records (run w11-20260924T1648Z)

Account: dev test account test@test.com (user id 607f9dd5-6fa7-48ee-a628-720d4a0506a1). No new account.

Setting changed: "Runs with a water bottle" on Settings > Profile & Preferences, column
`public.users.runs_with_water_bottle`. Chosen because it is not read by the meal plan or the
shopping list (ticket 19 is using the same account), is not null (the save path keeps the old
value when a field is null, so a null field could not be put back through the app), and is not
units, diet, household size, email or password.

## Before
- `runs_with_water_bottle = false` (db-before.txt, read 2026-09-24 16:5x UTC).
- `unit_system = imperial`, `dietary_preference` unchanged by this run.

## After change (Save Changes, then terminate + launch)
- App: the toggle shows "on" after the relaunch.
- DB: `runs_with_water_bottle = true`, `updated_at` later than before; `unit_system` still `imperial`,
  `dietary_preference` unchanged.

## After putting it back
- DB: `runs_with_water_bottle = false`; `unit_system`, `dietary_preference` unchanged.

## Sign-out
- App returns to a signed-out screen (Welcome or Log in); after terminate + launch it stays signed out.
- No database record is expected to change on sign-out.

## RevenueCat
- Nothing written. test@test.com is entitled (admin); the paywall should not show after login.
