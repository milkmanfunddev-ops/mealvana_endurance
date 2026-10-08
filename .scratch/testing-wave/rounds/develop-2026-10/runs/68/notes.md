# Ticket 68 run notes

- RUN: w7-20261008T2309Z
- App build sha: ff4e0ffb (from the prompt; ROUND/app-build.json agrees)
- Simulator: wave-pool-2, 93AF836F-8B3F-497B-B0D2-C66B46F37276 (app data cleared by the lead)
- Account: test@test.com, user 607f9dd5-6fa7-48ee-a628-720d4a0506a1
- Slot claimed 23:09:52Z.

## Log
- 23:11:30Z signed in as test@test.com (CRED type, password field confirmed by screenshot first; 10 dots). Notification prompt: Don't Allow.
- 23:12:05Z Food Preferences opened. Check 1 evidence: 01-food-prefs-load.png, 01-food-prefs-sports-drink.png.
- 23:13:03Z dragged Sports Drink 4 -> 3 (a plain tap on the dot did nothing; a drag moved it, console food_preference_changed slider_level 3). NOT saved.
- ~23:13:05Z ALL THREE wave simulators (wave-pool-1/2/3) went to Shutdown at once and my log stream was killed (signal 9). Host memory was low at that moment (vm_stat ~5k free pages); 28% free a minute later. Not caused by this run. Console before this is console-part1.log.
- 23:13:49Z booted wave-pool-2 again myself (my simulator), new log stream to console.log, relaunched the app 23:14:04Z.
- 23:14:30Z a TrainingPeaks "Your fuel plan goes to your coach" sheet showed after the relaunch; tapped Close (leaves sharing on). Screenshot 00b-tp-sharing-sheet-after-relaunch.png. Known: it is the TP sharing intro; not this ticket's area.
- Check 1: **PASS 49-010 (load)**. Server sports_drink 4 (db-food-preferences-before.txt); screen Sports Drink at the Like end, level 4 (01-food-prefs-sports-drink.png, and again after the relaunch 01b-…png).
- 23:16:20-22Z Save Changes (Sports Drink 4 -> 3). Screen popped back to the hub. Server sports_drink level 3, preference like, updated_at 2026-10-08 23:16:23+00 (db-food-preferences-after-save.txt); the idb tap call returned 23:16:22.26Z, so updated_at is within a second of the save's UTC wall clock and carries +00. Drift copy (drift-food-preferences-after-save.txt) holds the same 14 snake_case keys as the server; no "Energy Chews"-style display-name rows (Bagel (plain) and Bananas are server rows that were already there, not fuel foods).
- Check 2: **PASS 49-010 (save) and ticket 39's UTC retest**. Side effect filed: 68-001 (5 untouched foods inserted, fig_bar as dislike 0; ids/created_at rewritten).
- 23:17:41Z Sign Out (dialog "Sign out?" -> Sign out). Drift copy right after: food_preferences_table 0 rows (local rows cleared, as the lead's note expected; no app-data clear needed).
- 23:18:22Z signed in again (CRED type after a screenshot showed the focused password field). Touched SHARED/68-signin-done.
- Check 3: **PASS ticket 58 round trip**. Sports Drink shows level 3 (03-food-prefs-after-resignin.png), read from the server after a fresh pull. Restore to 4 is done at the end of the run.
- Check 4 (23:19:30Z): **PASS 49-002 (short line)**. "Egg" + Analyze: the whole line "Add a bit more: at least 5 characters, like what you ate and how much." shows wrapped on two lines, no ellipsis (04-egg-too-short.png). Console meal_ai_action_tapped + meal_ai_validation_failed, no call.
  - Seen: after clearing and typing "My bike ride" (12 chars) the too-short line stayed under the field until the next Analyze (05a-stale-too-short-line-before-analyze.png). Part of the Describe look-around Finding.
- Spend 1 (COST 1/5) -> check 5 (23:19:57Z): **PASS 49-005 + 49-002 (not-food)**. Screen: "That doesn't sound like food or drink. Describe what you ate or drank." in full, wrapped (05-not-food.png). Ledger: no row after 23:09Z (db-ledger-after-check5.txt). Console: expected_failure {area: meal_logging, reason: not_food}, meal_ai_failed notFood, no error_reported. Edge: describe-meal 422 "Not food … no debit" (edge-check5-not-food.txt). Dev Sentry (mealvana-endurance-dev, read-only, last 1h): no FunctionException; events in the run's window were SlowOperation startup from other devices and the one below. Spend 1 bought one model call (not-food answer, free to the athlete).
  - Known noise: dev Sentry "onesignal init skipped: no app id configured yet" at 23:14:16Z for this user = my relaunch after the simulator shutdown. Console shows "[LAUNCH] onesignal init: SKIPPED — no app id configured yet (configureRemotePush() will arm when it arrives)" then "onesignal started" 0.5 s later: the D9 record of a skip that recovered. Not re-checked further (notification area is not this ticket's).
- Check 7 (23:20:53Z, before the revoke): Camera -> iOS camera permission prompt first (cleared app; 07a), Allow -> plugin alert "Error / Camera not available. / OK" (07b), OK. Gallery (23:21:10Z) -> picker, X (first X tap landed while the sheet was still sliding; second closed it). meal_ai_photo_attached count 0 after both. Real pick in check 8 sent exactly one ({method: photo_gallery}). **PASS 49-006 (ticket 60)**.
- Spend 2 (COST 2/5) -> check 6 (23:22:18Z): 2,149 chars pasted. Snackbar "The AI service returned an error. Please try again." -> FAIL, filed 68-002 (Retest of 49-007). Ledger half passes (no debit). Spend 2 bought NO model call (describe-meal 400 before the model): the lead can count it back.
- 49-007 step 3: revoke camera (iOS ended the app; relaunched 23:22:5xZ), Camera at 23:23:22Z -> snackbar "Could not access the camera or gallery." + error_reported degraded PlatformException. Filed 68-003. Gallery still works with camera revoked (used for check 8).
- Check 8: SCRATCH copy of img-01.jpg (edamame). The committed fixture already carries a real GPS location; I overwrote it with a neutral point (40°44'30"N 73°59'15"W) before upload: filed 68-005 (idea). simctl addmedia; Gallery picker shows "Location Is Included" by default (08a); picked; one meal_ai_photo_attached.
  - Spend 3 (COST 3/5): double-tap Analyze, two idb taps launched 23:24:38.074Z and 23:24:38.280Z (0.21 s apart). Console: ONE meal_ai_action_tapped, ONE meal_ai_started, meal_ai_completed (7583 ms). So the first tap's rebuild removed the button and the second tap hit nothing (the in-flight join was not exercised). Edge: one storage upload POST, one analyze-meal-photo POST 200 (edge-check8-photo.txt). Ledger: one debit 9cb596fe… -1 analyze-meal-photo, balance_after 2487, 23:24:45Z (db-ledger-after-check8.txt). **PASS 49-007 step 2 (double tap)**.
  - Location half: object b1ccbabe-….jpg keeps the GPS IFD, Make/Model/DateTime (exif-uploaded-meal-photo.txt) -> FAIL, filed 68-004. Spend 3 bought one photo analysis ("Salted Edamame in the Pod", 188 kcal).
- Check 9 (Review & Log, one item only, so no swap here):
  - Swipe left-to-right removed the item; snackbar "Item removed" + "Undo" showed (09b); Total went to "— kcal". First Undo tap landed after the 3 s window (my screenshot + element read took ~2.5 s, the tap ~1 s): nothing restored, and "Log this meal" stayed enabled with zero items (09c). Back -> "Discard changes? / Your edits to this meal will be lost." (09d) -> Discard -> "Review again" (free, no ledger row) reopened the original analysis.
  - Retry: swipe, Undo tapped 0.5 s after: item and Total 188 kcal C 14 P 17 F 8 back (09e during, 09f after). **PASS 49-003 (undo)**.
  - Renamed to "Salted Edamame in the Pod tw68", Back -> "Discard changes?" dialog (09g) -> Keep editing (name kept). **PASS 49-003 (discard dialog)**. Ticket 66 closes on the screen evidence: checks 4, 5 and 9 pass.
  - 23:27:32Z Log this meal -> Timeline card "6:27 PM Salted Edamame in the Pod tw68 188 kcal". meal_logs f380f4c8-17f2-42d8-a3a1-5cfa46dfcecd (snack, source photo, photo_path b1ccbabe…, eaten_at 23:27:00+00) (db-meal-logged-check9.txt). LEFTOVER until deleted at the end.
  - Seen: console diary_closed {duration_sec: 259, items_logged: 0} right after meal_logged: filed in the Review look-around Finding.
  - Today's six older meals are not on the Timeline: all is_deleted true on the server (other runs deleted them). Expected.
- Check 10 (49-009, swap picker from Edit Meal, meal f380f4c8):
  - Swipe right-to-left on the item opened the picker titled "Add Food" with an "ADD FOOD" button (10b); swap_food_screen_viewed {is_swapping: false}. Recommended list shows near-duplicates "Bagel (Large)" 56 g and "Bagel (large)" 53 g.
  - Search: typing "rice" (23:28:3xZ) turned the screen into Flutter's red "Tried to modify a provider while the widget tree was building" (10c); again on a second open after typing one letter "r" (10e). Dev Sentry MEALVANA-ENDURANCE-DEV-BX (fatal, unhandled). Filed 68-006. Search half: FAIL. Edge-swipe back recovered Edit Meal both times. The console had NO Flutter line for this error.
  - Create Custom Food: filled name "tw68 rice cup", 1 cup, 200 kcal / 45 C / 4 P / 1 F / 5 mg Na. "Create Food" stayed dim and did nothing on four taps (10h, 10k): no "💾 FoodDetailScreen saving" debugPrint, no row. Toggling a "When would you eat this?" box rebuilt the screen and the button turned bright (10l); one tap then created user_foods 4fe1717b-3dfa-4f20-b839-c13a9e03cb73 at 23:33:12Z and returned to the picker with My Foods (2) (db-user-foods-after-create.txt). Code: the button's onPressed reads _isValid at build; typing the name does not rebuild. In the Finding for this screen.
  - Picked "Tw68 rice cup" from My Foods (no search possible), quantity stepper goes in 0.5 steps; 2.0 -> 400 kcal; ADD FOOD -> row "tw68 rice cup 2 × 1 cup · 400 kcal" (10p). Edit item -> Quantity 3 -> "3 × 1 cup · 600 kcal", Total 600 (10r, 10s). Save changes 23:34:33Z: meal_logs calories 600, items[0] {portion "1 cup", quantity 3, calories 600, carb_g 135} (db-meal-after-check10.txt). Timeline card "600 kcal · 135C · 12P · 3F". **PASS 49-009 row/kcal/quantity half.**
  - Scan barcode from the picker, camera revoked: "Camera access is off. Turn it on for Mealvana in Settings, type the barcode with Enter below, or search for the food by name." + "Search for the food instead", Reset / Switch / Enter (10u). Explains itself.
  - Custom food delete: not attempted yet (end of run, via My Foods Edit food).
  - Net verdict 49-009: not closed (search fails, 68-006).
- Check 11 (49-008, Edit Meal):
  - Notes edit + Back -> "Discard changes? / You have unsaved changes to this meal. Save them before leaving? / Keep editing / Discard / Save" (11a). Discard at 23:35:43Z: meal_logs.updated_at stayed 23:34:34.200296, notes unchanged (db-meal-after-discard.txt). PASS.
  - Notes edit + Back -> Keep editing: edit TW68KEEP still in the field (11b). PASS. (Then left with Discard.)
  - Only "Hide details" toggled (-> "Add more detail"), Back: no dialog, straight to the Timeline (11c, 11d). PASS.
  - Time eaten 11:59 PM (local clock ~6:38 PM, so in the future): accepted, no warning; Save 23:38:25Z; card sorts last on Oct 8 (after the 7:00 AM workout) (11g); eaten_at 2026-10-09 04:59:00+00, log_date 2026-10-08 (db-meal-after-1159pm.txt).
  - Time across midnight, 12:30 AM: Save 23:39:19Z; card sorts FIRST (above 6:38 AM) (11i); eaten_at 2026-10-08 05:30:00+00, log_date unchanged. A late-night meal cannot cross into the next day from this screen; moving 11:59 PM forward by 31 min moves it back ~23.5 h. In the Edit Meal Finding.
  - Re-scan photo: not run: cap (three spends used).
  - **PASS 49-008** for Discard / Keep editing / Hide details; time behaviour recorded.
- Check 12 (50-013 + 49-004):
  - Header Search empty: the Search button and keyboard Return both do nothing visible (12a, 12b). Filed 68-010 (Retest of 50-013).
  - Scan barcode (camera revoked): "Camera access is off. Turn it on for Mealvana in Settings, …" + Reset / Switch / Enter (12c). Enter sheet: "Enter a barcode / Type the number printed under the barcode. / 8 to 14 digits / Look it up" (12d).
  - Known barcode 3017620422003 (23:40:37Z): straight to "Log Food" with Nutella at 539 kcal "For 1 serving" (per-100 g values): filed 68-011. Not logged.
  - 12345670 first try (23:41:08Z): client SocketException timeout after ~30 s, no request on the server, dialog "Error / Unable to connect to product lookup service" + two error_reported; "Try Again" only went back to the scanner. Second try 23:42:31Z found "McEnnedy Double burger" (a real OFF code; not logged). Made-up 98765432109871 (23:43:00Z): server 404 "No product found", app shows the same "Unable to connect" dialog + error_reported fault FunctionException: filed 68-007.
  - Recent: not empty on this account (Saved meals: Tw49 eggs toast banana, W40-113 Built bowl, Egg & Veggie Scramble, Quinoa…; Recent: this run's meal and older ones) (12l). Empty-state copy read from code: log_meal_screen.dart:1202 hardcoded "No saved or recent meals yet.\nMeals you log (and favorite) show up here." No raw content key possible. Common: static "Quick add" list (12m), no empty state.
  - Describe offline: not run: cap.
  - 49-004: "needs a dead token; not forceable without a write" for this run. Observed: integrations at the start all success/inactive (db-integrations-start.txt); at 23:44:17Z garmin is_active true + requires_reauth (written 23:38:08Z, during ticket 69's Garmin work; expected). Timeline: no notice, also after a relaunch (23:44:39Z) and a pull-to-refresh; Connected Apps Garmin card: no "Sign in again" line (12n-12q). Notice words, Reconnect, X: not run, the notice never showed. Filed 68-008. Sync Now not tapped (69's area). End read 23:49:04Z unchanged (db-integrations-end.txt).
- Other runs' rows in my window (expected, not filed by me): dev Sentry 23:26:39-41Z "OS Error: Network is unreachable" x4 and "onesignal init skipped" for user 607f9dd5 from a launch this device did not make (ticket 69's device; DE3BCA55… is another device); garmin-push "record skipped … reason=no_user_mapping" for another Garmin user (by design, logged). Edge function_logs "sessionCost: unknown sport \"other\" — F4a zero-with-estimate-flag": by-design ruled F4a line, known noise.
- Not signed out by the other run during this run (no 68-done wait needed; ticket 69 had not touched its done flag at 23:49Z).

## Cleanup
- 23:47:25Z custom food "tw68 rice cup" deleted in the app (My Foods > Edit food > Delete food > Delete; snackbar "tw68 rice cup deleted"): user_foods 4fe1717b-3dfa-4f20-b839-c13a9e03cb73 is_deleted true (soft-deleted row stays; db-user-foods-end.txt). No barcode food was saved (both found codes were not logged; user_foods has no new row).
- 23:47:57Z meal f380f4c8-17f2-42d8-a3a1-5cfa46dfcecd removed from the Timeline card menu: is_deleted true (db-meal-logs-end.txt). It was this run's only meal.
- 23:48:43Z Sports Drink dragged 3 -> 4 and saved: sports_drink level 4 like, updated_at 23:48:44+00 (db-food-preferences-end.txt). LEFTOVER from Save's write-everything behaviour (68-001): the five rows Save inserted stay (carb_drink_mix, energy_chews_mini_pack, granola_bar, high_carb_drink_mix at 2, fig_bar at dislike 0), and every row has a new id/created_at. Removing them needs a DB write the ticket does not name.
- meal-photos object 607f9dd5-…/b1ccbabe-f422-494b-a20d-99de4a2772b2.jpg stays in the bucket (it carries the neutral test GPS point, not a real one).
- Simulator photo library holds the tw68-gps.jpg copy (simulator is removed by the lead).

## Spends (wave 7 logging, COST 3/5 after this run)
1. 23:19:57Z check 5 "My bike ride": one describe-meal model call, 422 not-food, no debit. Bought the not-food check.
2. 23:22:18Z check 6, 2,149 chars: describe-meal 400 before any model call, no debit. Bought NOTHING from the AI provider: the lead can count it back.
3. 23:24:38Z check 8 photo double-tap: one analyze-meal-photo call, one debit (9cb596fe…, balance_after 2487). Bought the double-tap and EXIF checks and the meal for checks 9-11.

## Check summary
1. PASS 49-010 (load)
2. PASS 49-010 (save) + ticket 39 UTC; side effect 68-001
3. PASS ticket 58 round trip
4. PASS 49-002 (short line)
5. PASS 49-005 + 49-002 (not-food)
6. FAIL 68-002 (long text message; ledger half passes); camera-revoked message 68-003
7. PASS 49-006 (ticket 60)
8. PASS 49-007 step 2 (double tap: one request, one debit); FAIL step 4 location 68-004
9. PASS 49-003 (undo + discard dialog)
10. 49-009: row/kcal/quantity PASS; search FAIL 68-006; Create Custom Food bug 68-009; scan-barcode state recorded
11. PASS 49-008 (discard/keep/hide details); time behaviour in 68-015; Re-scan photo not run: cap
12. 50-013: empty search 68-010, unknown barcode 68-007, Nutella serving 68-011, Recent not empty on this account, Common static; Describe offline not run: cap. 49-004: 68-008.
