# Ticket 30, wave 10 notes

- RUN: `w10-20260924T1615Z`. Slot claimed 16:15:00Z (testing-wave-20 also holding).
- App on UDID `964F7251-197B-4C4F-8C4B-D55948E4EE67` (wave-pool-2) built from commit
  `52c68764b2cde49951a27220a8dbdb3a463116f7` (dev simulator's testing build, copied). Worktree at `ba89bdf4`.
- App data cleared by the wave lead: expected to open signed out on Welcome, empty local database.
- Week bounds used: Sun 2026-09-20 00:00 to Sat 2026-09-26 23:59, local wall clock. Account timezone:
  `users.home_timezone` NULL; Mac clock CDT (America/Chicago), 11:15 local at start.

## Run log (UTC)
- 16:16 app launched; `simctl launch` left SpringBoard in front, relaunched with the mobile MCP. Welcome shown, signed out.
- 16:17 Log In with email, test@test.com, password via `CRED type`. Timeline opened at 16:18, no paywall (entitled).
- 16:18 "Shake to tell us what's wrong" What's New sheet, dismissed with Got it; then the TrainingPeaks
  "Your fuel plan goes to your coach" sheet, closed with its X ("Closing this leaves sharing on": no setting changed).
- 16:19-16:22 walked Sun 20 to Sat 26 with the day arrows and the month picker (tapped the 21st).
- 16:22 opened 12 mi Run (Mon 21) fuelling; 16:24 opened Patrol H5 1790210557462 (today) through its fuel link. Back without Save.
- 16:25 done on screen. Both stored plans unchanged afterwards (updated_at and md5 of nutrition_plan_data read at 16:23:
  12 mi Run 2026-09-21 15:33:27 / 7871db8b…, Patrol H5 2026-09-23 19:43:00 / 4bc49eae…).

## The week: screen against SQL (`screen-week-sessions.txt` vs `db-week-activities.txt`)
| day | SQL | screen | notes |
|---|---|---|---|
| Sun 20 | 3 | 3 | Bike - Long Ride, Foam Rolling Routine, Run; all "Skipped" |
| Mon 21 | 4 | 4 | Swim, Corpus Tempo Run, R-CORE Routine, 12 mi Run |
| Tue 22 | 4 | 4 | Speedwork, Foam Rolling, Warm Up, Corpus Endurance Ride |
| Wed 23 | 5 | 5 | Swim, Corpus Strength Block, R-CORE, Bike, and the brick at 9:00 PM shown as "BRICK · 3 legs" (title hidden, 30-006) |
| Thu 24 | 6 | 6 | Easy 5:32, Foam Rolling 7:00, Rad Device Test Swim 7:00, Run 7:28, two Patrol H5 8:45 PM |
| Fri 25 | 2 | 2 | R-CORE, Swim |
| Sat 26 | 2 | 2 | Foam Rolling, Run - Long Run 17 mi |
| total | 26 | 26 | titles, distances and durations match; the 13 provider-deleted rows show as Skipped (30-001) |

Brick shows 9:00 PM on screen for a 21:00 row: match.

## Fuelling: 12 mi Run (Mon 21 16:45) screen against stored plan
| figure | screen | stored |
|---|---|---|
| BEFORE carbs | 107 g, band 88-113, target marker | target 101 (carbsLowG 88, carbsHighG 113); foods 44+11+27+25 = 107 |
| BEFORE fluids | 17 oz, band 0-29 oz | target 478 mL; foods 506 mL = 17 oz; fluidsHighMl 839 = 28.4 oz, shown 29 |
| BEFORE sodium | 660 mg | foods 602+7+1+50 = 660; target null |
| Snack card | 82 g, 16 oz | foods 82 g, 6 mL; snack fluid tier 477.6 mL = 16 oz (30-004) |
| Top-Off card | 25 g, no fluid | foods 25 g, 500 mL (30-004) |
| DURING carbs | 92 g, band 97-126, pink + info icon | carbTotalG 91, carbsLowG 97.2, carbsHighG 126; foods 25+67 = 92 (30-003) |
| DURING fluids | 45 oz, band 37-50 | fluidTotalMl 1298 (43.9 oz); foods 1340 mL = 45 oz; band 1103-1493 mL |
| DURING sodium | 1075 mg, band 857-1285 | sodiumTotalMg 1071; foods 55+450+570 = 1075; band 857-1285 |
| DURING foods | 1 Energy Gel, 4.5 cups Sports Drink, 1 cup Water, 3 Electrolyte Capsules | same four |
| AFTER | 1 Banana, 1 bottle Whey Protein Shake, no targets | same two foods; targets 84 g C, 29 g P, 1296 mL, 357 mg not shown (30-008) |
Headline figures are the foods' sums with the stored target as a marker: consistent with the stored plan apart from 30-003/004/005.

## Surprises and noise
- Signing in ran the FinalSurge sync, which wrote to one activity row (09-24 07:28 "Run": updated_at, last_synced_at; plan and schedule values unchanged). Unavoidable on sign-in; the only write this run caused. Its timestamps are 30-002.
- known noise: TrainingPeaks token refresh 400 and VDOT "Please reconnect" at sign-in (console-excerpts.log lines 15, 18-36). The dev admin account's integrations are expired; the app reports them and carries on.
- known noise: "No distance data available / No intensity distribution hints" warnings during sync, for `other`-type routines with no distance.
- known noise: UIKit UIFocus and libCoreFSCache "fopen failed" Error lines at launch are iOS simulator system logs, not the app.
- known noise: the mobile MCP's first element list on Log In returned a mix of Welcome and an email form prefilled "test@test.com" that was not on screen (the screenshot showed the provider buttons). Runbook already warns the list can lag; screenshots were trusted.
- known noise: a tap on the DURING info icon landed on the "1 cup Water" row because the list was still scrolling; it expanded the row (no change, quantity still 1). Covered as retry in 30-008.
- No console error lines from the app after sign-in.
- Edge functions (`edge-function-requests.txt`, dev-wide, last 15 min at 16:30Z): this run's sign-in called
  `sync-all-data` (11:17:21, 11:17:41 CDT) and `calculate-daily-macros-v6` (x4), all 200. The `vana-action`,
  `kroger` 400 and `garmin-push` lines are from other callers on dev (ticket 20 is on the same account doing
  shopping; garmin-push is Garmin's server push); this run opened no Vana, Kroger or Garmin screen. Not filed here.
- console.log had 4 token-pattern hits at the scan, so it was deleted; console-excerpts.log keeps the lines the Findings cite (no hits).
