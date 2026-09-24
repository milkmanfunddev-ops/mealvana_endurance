# Ticket 23 run notes

- RUN: w13-20260924T1903Z
- App build commit: 52c68764b2cde49951a27220a8dbdb3a463116f7 (per prompt and app-build.json, same).
- Device: wave-pool-1 5B683809-01F3-47DF-93B7-7C9103A02B57. App data cleared by the lead (opens signed out).
- Slot claimed 2026-09-24T19:03:55Z.
- 19:08Z timeline before: Eaten 0 / 8,839 kcal, burned 1,358, net -1,358 (screenshot 05).
- 19:07:43Z tapped Analyze (COST logging 1/5 spent before).
- save window: before 19:08:16Z, after 19:08:19Z (tapped Log this meal).
- 19:10Z a tap meant for the Food tab landed on the Patrol H5 activity card (tab bar was collapsed after scrolling); opened its detail read-only and went back. No write.
- Correction: the "timeline before" reading above was taken at about 19:07:20Z, before Analyze (19:07:43Z), not 19:08Z.
- Burned rose 1,358 (19:07:20Z) -> 1,402 (19:08:20Z) -> 1,440 (19:10:56Z). Known noise: burned-so-far is resting + movement pro-rated to the clock plus digestion = 10% of eaten kcal (lib/features/daily_macros/domain/intraday_display.dart L21, L39-41). +44 matches 404 kcal eaten x 0.10 plus the clock; +38 matches ticket 26's 372 kcal meal. Not a Finding.
- 19:10:56Z Eaten 776 on the timeline: my 404 plus a 372 kcal meal from ticket 26 (shared account, expected).
- Describe tab is the Describe segment of Log a Meal (not the separate /meal-log/describe route); while analyzing it shows "Reading your description..." and a skeleton, no echo of the text (screenshot 08).
- Console: TrainingPeaks token refresh 400 and V.O2 "Please reconnect" at login 14:06:32 local. Known noise: the test account's integrations are expired (runs 03, 12, 14, 16, 17, 19 notes; 03-008).
- Console 14:07:54 local: GoRouter "An extra with complex data type _Map<String, Object?> is provided without a codec" on pushing /meal-log/review. Covered by followup 23-004 (the Review screen's result lives only in the route extra).
- Edge logs (edge-requests.txt, edge-function-logs.txt): describe-meal 14:07:44-14:07:54 local is mine (log line names "W13-23 Lunch", 97 chars). vana-action get_home 14:07:55 and 14:09:58 local are for this user id; 14:09:58 matches my opening the Food tab, 14:07:55 came while I was on Review & Log and may be mine or ticket 26's. Neither wrote an ai_usage row. garmin-push errors belong to other Garmin users (no mapping); not this run.
- The What's New sheet (shake) and then the TrainingPeaks "Your fuel plan goes to your coach" sheet stacked after login: known (12-008). Tapped Got it, then Keep Sharing (no setting change).
- First mobile-MCP tap at 19:05Z sent the app to the background (SpringBoard showed); relaunched by tapping the icon with idb. Taps done with idb afterwards, typing with the MCP. Known noise: harness (runbook step 3 SpringBoard note).
- 19:12Z stopped log stream (PID only), terminated the app, released slot. No account created, so nothing to delete (test@test.com kept).

## Result against expected.md
- meal_logs: one new row 38c4f0ed-e7d2-453c-9b8e-a19614dbe522, created 19:08:16.7Z (save window 19:08:16Z-19:08:19Z), source describe, slot lunch, log_date 2026-09-24, is_deleted false, 3 items. calories 404, carbs 41.0, protein 16.8, fat 20.3, sodium 503; the item sums equal the totals. App: Review & Log total "404 kcal C 41g P 17g F 20g", Timeline card "404 kcal · 41C · 17P · 20F", Eaten 0 -> 404. Match (protein and fat rounded on screen).
- ai_usage: one describe-meal row 19:07:54Z, claude-sonnet-4.6, 1351 in / 232 out, $0.011493.
- token_ledger: reserve -8000 then settle -3493 (= 11493 micro-dollars = cost_usd); wallet 11,647,674 -> 11,636,181. Match.
- Entitlement unchanged. Ticket 26's three rows (saved, manual, recipe; 19:08:36Z-19:10:05Z) untouched by this run.
- Screenshot names: 02 shows SpringBoard after the first MCP tap; 15 is the Patrol activity detail opened by the mis-tap.
