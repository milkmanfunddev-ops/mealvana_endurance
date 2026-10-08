# Ticket 69 — expected records (written before the run, 2026-10-08 23:14Z)

Account for checks 2-14: test@test.com (user id 607f9dd5-6fa7-48ee-a628-720d4a0506a1), shared with ticket 68
(food_preferences, meal_logs, user_foods, token_ledger debits are theirs). RevenueCat: nothing read or written.
Check 1: one new account lee+e2e-69-<UTC>@rightpathprogramming.com, deleted in the app (auth user gone after).

## events (checks 5, 6) — start: db-events-start.txt
- "Test" 65379d67-…: event_date 2026-06-20, start_time 2026-06-20T08:58 (the lead's SQL has run). List + detail read
  June 20. Left as it is.
- New event `tw69 <time>`: one row, event_date = date part of start_time; after a date edit both move together.
  Deleted at the end: row gone from `events` (hard delete, from code) and its linked activity gone.
- "IM NC 70.3" 3e874ee3-…: origin training_peaks, location null, event_date = start_time date 2026-10-17. After the
  Location edit + TP Sync Now: no duplicate row; record whether the location survives and the origin. End: location
  null again (origin may stay `manual`, code map D-2c).

## integrations (checks 8-13) — start: db-integrations-start.txt
- vdot: is_active false, last_sync_status null, last_sync_error null (ticket 64 close SQL). Unchanged after the
  V.O2 Connect → Cancel.
- training_peaks: active, success, error null at start. After Disconnect: is_active false, status/error null.
  After reconnect: active, last_sync_status pending or success, last_sync_error null. End: connected, sharing on.
- runna: no row at start (not run if no calendar URL).
- garmin: active, success; Sync Now writes nothing to this row from the app (server-side only).

## activities (check 10) — start: db-activities-hidden-start.txt
- training_peaks, deleted_at null: 43 rows hidden_by_disconnect false, 0 true.
- After Disconnect (no Sync Now, no sign-out): the TP rows this device holds read hidden true on the server at once.
- After reconnect as the same athlete (2687398), before any Sync Now: 0 hidden on the server and in a Drift copy.

## device prefs (checks 3, 13)
- After a resume that collected a tap and a terminate: flutter.ios_un_response_payload absent.
- flutter.tp_writeback_enabled false after Turn Off Sharing, true after the toggle is back on; card agrees.

## console (checks 4, 8, 12)
- Offline cold start: zero error_reported; content/education expected failures counted (Debug console Info, Sentry).
- V.O2 cancel: expected_failure {area: vdot, reason: oauth_cancelled}; no error_reported, no integration_connect_failed.
- TP Sync Now: integration_sync_started (+ success/failed), no integration_connect_started; device_id != user id.
