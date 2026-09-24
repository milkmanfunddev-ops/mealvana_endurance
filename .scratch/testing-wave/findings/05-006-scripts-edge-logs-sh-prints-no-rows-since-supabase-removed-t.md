# 05-006 · scripts/edge_logs.sh prints no rows since Supabase removed the logs.all endpoint, so a webhook check reads as not fired

- kind: bug
- status: open
- ticket: 05
- run: w5-20260924T0839Z
- screen: none
- decision: 

**Steps.**
1. At 08:51Z `scripts/edge_logs.sh -m 10 rc-webhook` returned the INITIAL_PURCHASE lines.
2. At 10:47Z the same script (`-m 120` and `-m 200`) printed `(no rows in window)` for both `function_logs` and `function_edge_logs`.

**Expected.**
The runbook's step 8 reads edge-function logs with `scripts/edge_logs.sh`. An API failure should be reported as a failure, never as an empty result.

**Actual.**
The Management API now answers `GET …/analytics/endpoints/logs.all` with HTTP 410 and `{"message":"The logs.all endpoint has been removed. Use GET /v1/projects/{ref}/analytics/endpoints/logs instead…"}`. The script only treats an `error` key as a failure, so a `message` body falls through to "no rows". A later run would read that as "the webhook did not fire". The new endpoint works with the unified `logs` table (`select timestamp, source, event_message from logs where event_message like '%rc-webhook%'`); `function_edge_logs` as a table name fails there with `Table "function_edge_logs" does not exist`. This run read the full webhook timeline that way (edge-logs-webhook-through-expiry.txt). The script is repo tooling, not app code; it was not changed.

**Evidence.**
- runs/05/edge-logs-webhook.txt (08:51Z, old endpoint still worked)
- runs/05/edge-logs-webhook-through-expiry.txt (10:52Z, new endpoint)
- scripts/edge_logs.sh (the `data.get("error")` check)

**Decision quote.**
> 

**Triage.**

