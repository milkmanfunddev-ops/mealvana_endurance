# Ticket 30, wave 10: what the run is judged against

Written before the app was touched (2026-09-24 16:16Z). Read only: nothing on test@test.com changes.

## Account
- test@test.com, user id `607f9dd5-6fa7-48ee-a628-720d4a0506a1`, dev project `vlmtsdzpnjnavdgytcmi`.
- Entitled (Pro Grant, dev admin): signs in to the timeline with no paywall. No RevenueCat or entitlement
  change is expected; none is read or written by this ticket.

## The week (by SQL, `db-week-activities.txt`)
- Week = Sun 2026-09-20 00:00 to Sat 2026-09-26 23:59 local wall clock (the app's week view starts on
  Sunday, `calendar_week_view_kyle.dart` `date.weekday % 7`). `scheduled_date_time` is local-naive and
  compared as such. `users.home_timezone` is NULL; the Mac and simulator are America/Chicago (CDT).
- Filter: `user_id = test@test.com`, `deleted_at IS NULL`. The app's local query also filters
  `deleted_at IS NULL` and does not filter `provider_deleted_at` (only coach mode does), so all rows
  below are expected on screen.
- 26 rows: Sun 3, Mon 4, Tue 4, Wed 5, Thu 6, Fri 2, Sat 2. 13 of them carry `provider_deleted_at`
  (FinalSurge removed them upstream) with `status = planned`.
- Expected: each day's sessions on screen equal that day's rows (title, time, count).

## One session's fuelling
- `12 mi Run`, Mon 2026-09-21 16:45, id `933edc6f-9a5f-4b8b-a7f9-840bca511088`, stored plan in
  `activities.nutrition_plan_data` (`db-fuel-plan-12mi-run-0921.json`, summary `db-fuel-plans-summary.txt`).
- Section targets stored: Before Run carbs 101 g, protein 13 g, fat 5 g, fluids 478 mL; During Run carbs 91 g,
  fluids 1298 mL, sodium 1071 mg; After Run carbs 84 g, protein 29 g, fluids 1296 mL, sodium 357 mg.
  macroTargets: carbs 276, protein 42, fat 5, sodium 1428, calories 1317.
- Expected: the numbers and foods on the fuelling plan screen equal these stored values.
- Fallback session if that one does not open: `Patrol H5 1790210557462`, today 20:45 (same summary file).
