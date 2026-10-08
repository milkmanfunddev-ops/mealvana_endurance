# Ticket 50 — expected records (written before the run, 2026-10-08 17:22Z)

Account: test@test.com (user id 607f9dd5-6fa7-48ee-a628-720d4a0506a1), shared with ticket 49 (meal_logs,
saved_meals, food_preferences are theirs). RevenueCat: nothing read or written (no check names it).

## users (check 6, 29-001)
- Before (db-users-before.txt): body_fat_pct null, lifestyle mixed, training_phase base, sweat_test_date null,
  sweat_test_source null, sweat_sodium average, known_sweat_rate_ml_per_hour null,
  known_sodium_concentration_mg_per_liter null, weight_pounds_updated_at 2026-09-24 00:44:09+00,
  body_fat_pct_updated_at 2026-04-22 12:16:04+00, typical_weekly_hours null, carb_cycle_opt_in false,
  nutrition_target_overrides {duringRun 50.4, duringCycling 50.4}.
- After one override save: only nutrition_target_overrides and updated_at change; every other column above unchanged.
- After revert: nutrition_target_overrides back to the before value (the run restores the pre-existing
  50.4 g/h run+cycling overrides it found; it does not clear what was there before it), other columns unchanged.

## events (check 8, 32-010)
- Row "Test" 65379d67-…: event_date 2026-07-17, start_time 2026-06-20T08:58:00.000 (read only; this run does not
  edit or delete it). Expected per 32-010: one date per event, same on every surface and in both columns.

## integrations (checks 10-12)
- Start (db-integrations-start.txt): vdot is_active false, last_sync_status requires_reauth,
  last_sync_error "Please reconnect your V.O2 account" (an English sentence left from before ticket 37);
  training_peaks active, success, error null, last_sync_at 2026-10-08 13:29:18+00.
- After V.O2 disconnect (or as shown, it is already inactive): card shows not connected, no "needs reconnect";
  no V.O2 refresh line in the console.
- After TP disconnect: is_active false, tokens cleared, last_sync_status/last_sync_error null;
  TP activities hidden_by_disconnect = true.
- After TP reconnect + Sync Now: is_active true, last_sync_status success, last_sync_error null or a code
  (network, rate_limited, http_<n>, reauth_required, unknown), never an English sentence; last_sync_at ≈ sync time;
  no TokenExpiredException; card date updates in place; hidden TP rows unhidden by the sync.
- End: TrainingPeaks connected. V.O2 disconnected (no test login).

## activities (check 12)
- Start (db-activities-hidden-start.txt): training_peaks 3 hidden, 40 not hidden.
