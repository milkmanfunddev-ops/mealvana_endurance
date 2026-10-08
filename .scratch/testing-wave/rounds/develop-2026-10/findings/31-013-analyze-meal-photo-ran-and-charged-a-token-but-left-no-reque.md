# 31-013 · analyze-meal-photo ran and charged a token but left no request line in function_edge_logs

- kind: bug
- status: closed
- ticket: 31
- run: w3-20261008T1256Z
- screen: none
- decision: investigation item in fix ticket 41 (why analyze-meal-photo leaves no edge-log row)

**Steps.**
1. Describe tab with a Gallery photo plus text, Analyze at 13:10:47.4Z (spend 2).
2. Supabase MCP query_logs on dev, `source = 'function_edge_logs'`, 12:56-13:20Z, queried at 13:14Z and again ~13:20Z.

**Expected.**
One `POST | 200 | /functions/v1/analyze-meal-photo` request line, as describe-meal gets for each call (13:02:50Z, 13:12:03Z).

**Actual.**
No analyze-meal-photo line in function_edge_logs, on either query. The call did happen: edge_logs has the app's photo upload (13:10:48Z) and the function's storage GET (13:10:49.6Z); function_logs has "[analyze-meal-photo] Analyzing photo …" (13:10:49.85Z) and "Success … Bread slices and orange (from food spread)" (13:10:57.40Z); token_ledger has `debit_usage −1 analyze-meal-photo` at 13:10:56.48Z. A wave check that reads request lines (the runbook's edge-log step) would report this call as never made. Cause unknown (ingestion, or how the photo function is invoked); not this app's screen.

**Evidence.**
- runs/31/edge-requests.txt — request lines; the photo call's function and storage lines are listed under NOTE
- runs/31/db-spend2.txt — the analyze-meal-photo debit

**Decision quote.**
> 

**Triage.**

