# 49-010 · Retest of ticket 39: a Settings Food Preferences save never reaches the food_preferences table (no row written after Save, a relaunch and a resume), so the UTC offset cannot be checked

- kind: bug
- status: open
- ticket: 49
- run: w5-20261008T1719Z
- screen: Food Preferences
- decision: 

**Steps.**
1. Fresh sign-in on a cleared device (test@test.com, 17:22Z). Settings -> Diet, Allergies & Formulas -> Food Likes & Dislikes.
2. Move Energy Chews one level (middle -> 4th dot), Save Changes (17:42:38Z): "Food preferences saved!".
3. Wait; go back to the Timeline; relaunch (17:44:05Z); background and resume (17:45:30Z). Read `food_preferences` for the user after each.
4. Put Energy Chews back to the middle and Save (17:46:47Z).

**Expected.**
Ticket 39: the save lands in `food_preferences` with `updated_at` carrying `+00` and equal to the UTC wall clock of the save.

**Actual.**
No `food_preferences` row changed at any point: 9 rows, newest `updated_at` 2026-10-08 08:07:20+00 before the run and still at 17:47Z (db-before.txt, db-food-prefs-after-save.txt, db-food-prefs-after-restore.txt). `users.updated_at` moved to 17:42:39.67Z and 17:46:47.47Z (the profile upload ran), but `users.food_preferences` (jsonb) still holds Energy chews at slider 2. Console: only `food_preference_changed` and `food_preferences_saved` analytics, no upload line, no error. From code (unverified): the Settings path is `AuthService.saveFoodPreferences` -> `UserRepository.saveFoodPreferences`, which writes Drift only ("Remote sync is handled via the edge function in AuthService") and marks the profile dirty; the immediate upload lives in `FoodPreferencesRepository.saveFoodPreferences`, which this screen does not call.
Also seen: the local table after the save holds 10 rows with display names ("Energy Chews", "Sports Drink" level 2, "Energy Bar" level 0) while the server holds 9 snake_case rows (`energy_chews`, `sports_drink` level 4). After a fresh sign-in the screen did not show the account's server preferences (sports drink "like" 4 on the server; local default 2), so a save from this device would overwrite them with defaults if it ever uploaded.
Ticket 39's UTC fix could not be exercised by this path. The server rows' 08:07:20+00 (written about 13:07Z, before fix wave 4) is the old local-as-UTC shape.

**Evidence.**
- runs/49/59-chews-level3.png — Energy Chews moved to the 4th dot
- runs/49/60-prefs-saved.png — "Food preferences saved!"
- runs/49/62-food-prefs-reopen.png — reopened: level kept locally
- runs/49/local-food-prefs-after-save.txt — the app's local rows after Save (read from a copy of the Drift file)
- runs/49/db-food-prefs-after-save.txt — server rows unchanged after Save
- runs/49/db-food-prefs-after-restore.txt — server rows unchanged at the end

**Decision quote.**
> 

**Triage.**
