# Ticket 27 run notes

- RUN: w15-20260924T2039Z. Slot claimed 20:39:49Z (owner testing-wave-27).
- App build commit: 52c68764b2cde49951a27220a8dbdb3a463116f7 (prompt and app-build.json). Worktree HEAD d087d4c6.
- Simulator: wave-pool-1, 555CA27A-72FE-41F5-840B-4DC909C707E6. App data cleared by the lead.
- Shared account with ticket 28 (other simulator): 28 may log one barcode product, preferably 09-23. Not mine.
- Local time zone of the simulator: America/Chicago (UTC-5), seen in run 25 (3:17 PM = 20:17Z).
- Planned values written before saving: expected.md. Before SQL: db-totals-before.txt (20:40:29Z).
- 20:41:28Z logged in (email + CRED type); What's New (Got it), TrainingPeaks sheet (Keep Sharing): known 12-008 / 30-010. 20:42Z Timeline before Food opened: Net energy balance '0 eaten - 1,538 burned = -1,538', 'Eaten 0 / 8,839', no meal rows while the server holds 8 rows / 2743 kcal for the day (known 10-001 / 26-001, not re-filed; 05-net-balance-expanded-unsynced.png).
- 20:42:20Z opened Food (syncs meal_logs), back to Timeline: all 8 rows shown. All: 'Eaten 2,743 / 8,839', net +930 (2,743 eaten - 1,813 burned). Meals: 'INTAKE TODAY 2,743 / 8,839 kcal, 382/1007g C, 169/134g P, 84/475g F' = SQL 2743 / 381.9 / 169.25 / 84.2 (08, 09 screenshots).
- 20:43:41Z saved 'W15-27 edit' (Manual, Lunch, 520/60/30/15) -> 1ce8b3b7 created 20:43:41.45Z. 20:44:16Z saved 'W15-27 delete' (Manual, Snack, 210/25/10/8) -> 7c20d895 created 20:44:17.20Z. Both equal what was typed. Manual form cleared after each save and stayed on Log a Meal (no toast seen in the element list).
- Timeline Meals after both logs (20:44:29Z): INTAKE TODAY 3,473 / 467 / 209 / 107 = SQL 3473 / 466.9 / 209.25 / 107.2. Both my meals, eaten 3:43 PM, sit under 2:08 PM time cards (snack with the snacks, lunch under W13-23 Lunch): see Finding.
- Edit: row ⋯ expands inline 'Edit food' / 'Remove'. Edit food -> Edit Meal (Scan a photo link, name, meal type, time, kcal/C/P/F prefilled '520','60.0','30.0','15.0', Add more detail, Save changes). Changed name -> 'W15-27 edited', 610 kcal, 70 C, 35 P, fat kept. Save 20:45:37Z -> toast 'Meal updated', row 1ce8b3b7 updated_at 20:45:38.19Z with the new values, same id, is_deleted false. Screen 3,563 / 477 / 214 / 107 = SQL 3563 / 476.9 / 214.25 / 107.2. Did not touch Scan a photo (AI).
- Delete: ⋯ → Remove at 20:46:16Z, no confirm, snackbar "Meal deleted · Undo" (Undo not tapped). Row 7c20d895 is_deleted true, updated_at 20:46:17.31Z (soft delete reached dev within ~1 s); row gone from the timeline. INTAKE TODAY 3,353 / 452 / 204 / 99 = SQL 3353 / 451.9 / 204.25 / 99.2. Today's Fuel: 3,353, 452/204/99, "9 logged". All: Eaten 3,353 / 8,839, net +1,471.
- Edit and delete both rewrote created_at to whole seconds on the server (27-002). No meal_log_deleted analytics line; diary_closed items_logged 0 (27-003).
- 20:47:27Z cold relaunch: notification permission prompt (Don't Allow; known 31-010). Timeline kept the edit (W15-27 edited 610 kcal), the deleted row stayed gone, INTAKE TODAY 3,353 / 452 / 204 / 99. Net balance collapsed header +1,469 (burn estimate moves with the clock).
- Timeline groups by meal type under the first meal's time (27-001); Today's Fuel lists rows at their own times but labels them by meal type (27-006).
- Totals shown only on Timeline header (All: net balance/Eaten; Meals: INTAKE TODAY with C/P/F) and Today's Fuel (Daily). Today's Fuel Weekly shows targets only (28-todays-fuel-weekly.png). ConsumedProgressWidget / MacroSummaryStrip / DailySummaryCard / TodayLogSection have no call site in lib, so no other screen shows day totals.
- Ticket 28 (same account): no row of theirs on 09-23 or 09-24 was created or updated between 20:39Z and 20:49Z (final SELECT); every total above counts only waves 13-15 rows. The search-catalog / search-nutrition-products requests at 15:44:42 and 15:45:20 local and the sync-all-data at 15:42:14 local in edge-requests.txt are 28's (I was on Manual / Timeline and had logged in at 15:41:28). ensure-credits 15:42:53 = my Log a Meal open (wallet pill, no model call); vana-action 15:42:28 = my Food open (get_home, no model call, per run 26). No describe/photo/vana chat call from this run; COST not spent (status 15: plan 0/3, logging 0/5, chat 0/5).
- Console: known noise only. TrainingPeaks token refresh 400, V.O2 "Please reconnect", FinalSurge "Date-range endpoint unavailable (404)" (dev admin's integration tokens expired, runs 15/16); "No distance data" / "No intensity distribution hints" / unknown sport "other" (fuelling-engine defaults for Patrol activities); CoreHaptics init error (simulator has no haptics); GoRouter "extra ... without a codec" on /meal-log/edit (23-004 family, listed in 27-005). No Flutter exception.
- Screens visited: Welcome, Log In (method picker, email), What's New sheet, TrainingPeaks sharing sheet, Timeline (All, Meals, header expanded), Today's Energy (Full Breakdown from All), Food (Plan), Log a Meal (Describe landing, Manual), Timeline row menu, Edit Meal, Today's Fuel (Daily, Where it came from, Weekly), notification prompt. Look-around Findings: 27-004 (row menu, snackbar), 27-005 (Edit Meal), 27-006 (Today's Fuel). Welcome, Log In, sheets, Food, Describe landing, Manual, Today's Energy covered by earlier tickets' Findings (02, 12, 23, 25, 26, 30, 31) and 25-006 (budget numbers), not repeated.
- Rows left on test@test.com: 1ce8b3b7 "W15-27 edited" (manual lunch 610/70/35/15, live) and 7c20d895 "W15-27 delete" (manual snack 210/25/10/8, is_deleted true). Both are evidence for 27-001..003.
- Console: 6 lines with session tokens cut (IMPROVEMENTS #40); evidence is console-redacted.log. Slot released 20:50:33Z.

## Totals: screen vs SQL (non-deleted rows, log_date 2026-09-24)

| Moment | Screen kcal | SQL kcal | Screen C/P/F (g) | SQL C/P/F (g) | Rows |
|---|---|---|---|---|---|
| before, phone not yet synced | 0 (Eaten 0 / 8,839) | 2743 | not shown on All | 381.9 / 169.25 / 84.2 | 0 on phone, 8 on server (10-001) |
| before, after Food opened | 2,743 | 2743 | 382 / 169 / 84 | 381.9 / 169.25 / 84.2 | 8 |
| after both logs | 3,473 | 3473 | 467 / 209 / 107 | 466.9 / 209.25 / 107.2 | 10 |
| after edit | 3,563 | 3563 | 477 / 214 / 107 | 476.9 / 214.25 / 107.2 | 10 |
| after delete | 3,353 | 3353 | 452 / 204 / 99 | 451.9 / 204.25 / 99.2 | 9 ("9 logged") |
| after cold relaunch | 3,353 | 3353 | 452 / 204 / 99 | same | 9 |

Deltas: logs +730 kcal (+520 +210), +85 C, +40 P, +23 F; edit +90 kcal, +10 C, +5 P, fat 0; delete -210 kcal, -25 C, -10 P, -8 F. Screen rounds grams to whole numbers.
