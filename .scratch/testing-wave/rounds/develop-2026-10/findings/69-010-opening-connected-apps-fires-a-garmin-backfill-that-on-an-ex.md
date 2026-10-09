# 69-010 · Opening Connected Apps fires a Garmin backfill that, on an expired Garmin token, reports error_reported degraded to Sentry

- kind: bug
- status: triaged
- ticket: 69
- run: w7-20261008T2311Z
- screen: Connected Apps
- decision: 

**Steps.**
1. Dev test account with a Garmin integration whose token Garmin no longer accepts (row was active/success at 23:37Z).
2. First open of Settings → Connected Apps in the app session (23:38:05Z). Nothing tapped.

**Expected.**
"Garmin needs you to sign in again" is an expected, athlete-fixable state: the card shows Reconnect and the run records
it as an expected failure (count or breadcrumb), not a Sentry error each session.

**Actual.**
The screen's first build fired `triggerGarminBackfill()` on its own (`connect_training_controller.dart:452-467`).
garmin-backfill answered 409 at 23:38:08Z ("Garmin connection expired; the athlete must reconnect Garmin",
body_composition "Token is not active"); the console printed an orange `⚠️ [garmin] garmin-backfill 409: Garmin token
expired, athlete must reconnect Garmin` box and `error_reported {severity: degraded, area: garmin, exception_type:
FunctionException, sentry_event_id: ef8d56c94f4b43d2a1a077d813683c52}`. The row moved to requires_reauth /
reauth_required at the same second (23:38:08Z), and the card shows Reconnect with no Sync Now. The Timeline also shows
"Garmin needs you to sign in again to keep syncing." The dev Garmin link itself is dead, so Garmin Sync Now could not
be tried (check 13).

**Evidence.**
- runs/69/console-redacted.log the garmin-backfill 409 box and error_reported at 18:38:08 local
- runs/69/edge-23-16-to-23-44.txt POST 409 garmin-backfill at 23:38:08Z
- runs/69/db-integrations-after-tp-reconnect.txt garmin requires_reauth, updated 23:38:08Z
- runs/69/k01-connected-apps.png Garmin card with Reconnect

**Decision quote.**
> 

**Triage.**
- triaged · fix ticket 77 (Garmin reauth read from the integrations row on every device; a dead token on the automatic backfill is an expected_failure), fix wave 8 · Lee, 2026-10-09
