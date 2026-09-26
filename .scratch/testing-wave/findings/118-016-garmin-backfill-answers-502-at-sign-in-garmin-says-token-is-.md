# 118-016 · garmin-backfill answers 502 at sign-in: Garmin says Token is not active and rate-limited, yet Connected Apps shows Garmin as working

- kind: bug
- status: triaged
- ticket: 118
- run: w36-20260926T0031Z
- screen: none
- decision: 

**Steps.**
1. Fresh app data, sign in as test@test.com (00:40:44Z) and use the app; the Garmin backfill runs
   in the background.

**Expected.**
The backfill works, or a Garmin connection whose token Garmin no longer accepts is marked as
needing reconnection like TrainingPeaks and V.O2 (fix ticket 64).

**Actual.**
At 19:42:32 local (00:42:32Z) `POST /functions/v1/garmin-backfill` answered 502. The app logged
"[syncGarmin] backfill temporarily unavailable (Garmin 502/rate-limit) — will retry next session"
with Garmin's answers: body_composition "Token is not active"; user_metrics and activities "Too
many request: Limit 100 per 1 minute : Rate limit quota violation". The `integrations` row for
garmin stayed `success` (last sync 2026-09-19) and Connected Apps showed Garmin with Sync Now. Two
wave runs share this account and signed in within minutes, which may explain the rate limit; the
inactive token would not come from that. Not caused by this ticket's steps; filed because the
runbook files every server error.

**Evidence.**
- runs/118/edge-requests.txt: `[19:42:32] POST | 502 | .../garmin-backfill`.
- runs/118/console-redacted.log: 19:42:32 local, "[syncGarmin] backfill temporarily unavailable".
- runs/118/db-integrations-after-login1.txt: garmin `success`.
- runs/118/41-connected-apps.png: Garmin shown with Sync Now.

**Decision quote.**
> 

**Triage.**

Fix ticket 138, Settings, connections, allergies, Garmin (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
