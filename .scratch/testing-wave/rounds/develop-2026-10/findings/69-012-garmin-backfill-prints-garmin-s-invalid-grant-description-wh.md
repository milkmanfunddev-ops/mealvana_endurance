# 69-012 · garmin-backfill prints Garmin's invalid_grant description, which carries the refresh token value, into the dev function logs

- kind: bug
- status: triaged
- ticket: 69
- run: w7-20261008T2311Z
- screen: none (garmin-backfill edge function)
- decision: 

**Steps.**
1. Dev test account with an expired Garmin link; open Connected Apps (the app fires garmin-backfill on its own).
2. Read the dev `function_logs` for garmin-backfill at that minute (Supabase MCP query_logs).

**Expected.**
A failed token refresh logs the status and an error code; no token value (access or refresh, raw or encoded) reaches
the logs, which are readable by anyone with log access and are kept.

**Actual.**
23:38:07.982Z: `[garmin-backfill] Token refresh failed (400): {"error":"invalid_grant","error_description":"Invalid
refresh token: eyJ…=="}`. The base64 after "Invalid refresh token:" decodes to a JSON object holding
`refreshTokenValue` and `garminGuid`, so the function writes Garmin's whole response body, refresh token included, into
the log. This token is already dead (Garmin rejected it), but the same line would print a live one on any other
refresh failure. The value is cut from this run's extract. The same call then hit Garmin's rate limit (429, "Limit
100 per 1 minute") on user_metrics and activities.

**Evidence.**
- runs/69/edge-23-16-to-23-44.txt function_logs lines for garmin-backfill at 23:38:07-08Z (token value cut)

**Decision quote.**
> 

**Triage.**
- triaged · fix ticket 76 (garmin-backfill and siblings redact provider error bodies before logging), fix wave 8 · Lee, 2026-10-09
