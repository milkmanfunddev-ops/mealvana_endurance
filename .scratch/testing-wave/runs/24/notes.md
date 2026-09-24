# Ticket 24 run notes

- RUN: w14-20260924T2015Z
- App build commit: 52c68764b2cde49951a27220a8dbdb3a463116f7 (per prompt and app-build.json, same).
- Device: wave-pool-1 A44F9C3E-4EDA-4DCD-828B-64F0EE21E085. App data cleared by the lead (opens signed out).
- Slot claimed 2026-09-24T20:15:08Z.
- Worktree HEAD b3ddc260 (base check passed; main clone mealplanning at the same commit).

## Food photo
- Source: https://commons.wikimedia.org/wiki/File:Spaghetti_bolognese_(hozinja).jpg (CC BY 2.0, by hozinja on Flickr).
- Method: `curl -L "https://commons.wikimedia.org/wiki/Special:FilePath/Spaghetti_bolognese_(hozinja).jpg?width=1024"`
  into SCRATCH/food.jpg (768x1024 JPEG, 327 KB), then `xcrun simctl addmedia <UDID> SCRATCH/food.jpg`.
  A copy is kept as runs/24/food-photo-used.jpg.

## Run
- 20:16Z launched (console to console.log, later redacted). Opened signed out on Welcome as expected.
- 20:17:04Z logged in as test@test.com (password via CRED type). What's New (shake) sheet then the
  TrainingPeaks "Your fuel plan goes to your coach" sheet stacked: known (12-008). Got it, Keep Sharing (no setting change).
- 20:17:36Z timeline before: Eaten 0 / 8,839, net -1,492, and no meal cards, although the account already had
  four meals on 09-24 (38c4f0ed, 00a120e5, f952f981, 46b1d076). Known: 10-001 / 26-001 (logs empty after
  sign-in until Food opens). Not re-filed. After my save the timeline showed only my meal (Eaten 780);
  ticket 25's rows from wave-pool-2 did not appear either (same known cause, not re-filed).
- + Add Food opened Log a Meal on the Describe tab. Budget pill read 255%: known and expected for this account (23-005 notes it).
- 20:18:10 local-15:18 picked the spaghetti photo in the system picker (Private Access to Photos banner, "Location Is Included" footer).
- 20:18:30Z COST spend 14 logging 24 -> 1/5. 20:18:33Z tapped Analyze; "Looking at your photo..." skeleton;
  20:18:44Z analyze-meal-photo 200, latency 11.1 s; Review & Log at 20:18:48Z.
- Review & Log: Medium confidence, name "Spaghetti Bolognese", Dinner pre-selected (by the model's slot; local time 3:18 PM),
  one item "Spaghetti Bolognese with Parmesan" 780 kcal C 95 P 38 F 22. Appended " W14-24" to the name (idb text; read back OK).
  No keyboard showed (hardware keyboard), so 23-001 did not come up here.
- Save window: tapped Log this meal at 20:19:18Z; went to /main; timeline card "3:19 PM Spaghetti Bolognese W14-24 780 kcal · 95C · 38P · 22F".
- Opened the card (Edit food / Remove), then Edit food: Edit Meal shows the photo with "Tap to re-scan" and Re-scan photo.
  Went Back without saving (row's updated_at unchanged, db-meal-logs-day-final.txt).
- Console: TrainingPeaks 400 and V.O2 reconnect at login, known noise (integrations expired on the test account; runs 03, 12, 23).
  RevenueCat "credits" offering packages with unknown duration WARN: known (07-004 area, runs/07 notes).
  GoRouter "extra ... without a codec" on /meal-log/review and /meal-log/edit: known (23-004 covers the Review extra).
  iOS haptics / AVSystemController / photospicker view-service lines: simulator noise.
  `diary_closed items_logged 0` before the save: filed 24-002.
  `DailyBaselineCalculator unknown sport "other"`: ruled behaviour (F4a), noise.
- Edge logs (edge-function-logs.txt, edge-requests.txt): one analyze-meal-photo request 15:18:44 local for this user, success line
  names "Spaghetti Bolognese". sync-all-data, calculate-daily-macros-v6, ensure-credits at login are mine. garmin lines belong to other users.
- 20:22Z stopped the log stream (PID only), terminated the app, released the slot. No account created; nothing to delete.

## Result against expected.md
- meal_logs: one new row f510d5d3-a680-4dee-897a-66db4f540fca, created 20:19:18.29Z (save tap 20:19:18Z), source photo,
  slot dinner, log_date 2026-09-24, is_deleted false, name "Spaghetti Bolognese W14-24", one item; calories 780, carbs 95.0,
  protein 38.0, fat 22.0, sodium 780 = the item = Review & Log total = timeline card. photo_path
  607f9dd5-.../66f0e1b9-d68e-4567-9b78-aa7a1aed6d83.jpg, and that object exists in meal-photos (154,538 bytes, image/jpeg, 20:18:34Z). Match.
- ai_usage: one analyze-meal-photo row 20:18:44Z, claude-sonnet-4.6, 2368 in / 162 out, $0.013695. Match.
- token_ledger: reserve -13000 (20:18:35Z) then settle -695; wallet 11,636,181 -> 11,622,486 (-13,695 = cost). Match.
- jade_calls/vana_calls: two rows for the one call (expected one): filed 24-001.
- Entitlement unchanged (active_until 2027-09-15). Ticket 25's rows (35409440, a61f94fd, ae7dba02) and earlier waves' four rows untouched.
