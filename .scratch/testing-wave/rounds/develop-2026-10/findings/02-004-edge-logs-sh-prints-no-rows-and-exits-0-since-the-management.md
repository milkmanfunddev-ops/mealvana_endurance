# 02-004 · edge_logs.sh prints no rows and exits 0 since the Management API removed logs.all

- kind: bug
- status: triaged
- ticket: 02
- run: w1-20261007T1103Z
- screen: none
- decision: 

**Steps.**
1. Export `SUPABASE_PAT` per runbook step 6.
2. `scripts/edge_logs.sh -s function_edge_logs -m 12 -l 200` and `scripts/edge_logs.sh -m 12 -l 300` right after a describe-meal call (11:10:51Z, call at 11:08:38Z), and again at 11:12Z with `-m 20`.
3. `scripts/edge_logs.sh -s function_edge_logs -m 30 -l 5 --raw`.

**Expected.**
The request lines and function logs for the window, or a non-zero exit on any answer that is not rows (runbook step 6: "It exits 1 on any answer that is not rows, so "(no rows in window)" really means none").

**Actual.**
Both sources print "(no rows in window)" and exit 0. `--raw` shows the Management API's answer: "The logs.all endpoint has been removed. Use GET /v1/projects/{ref}/analytics/endpoints/logs instead." The script's formatter treats a JSON body with no `result` and no `error` key as zero rows, so every wave's edge-log check now passes silently. The replacement endpoint has no `function_edge_logs`/`function_logs` tables; it exposes one ClickHouse `logs` table filtered by `source` (`select … from logs where source='function_edge_logs'`), with fields under `log_attributes[...]`. This run's extracts came from that endpoint through a read-only scratch helper: 11 request lines, all 200. Every other wave-1 ticket that relied on edge_logs.sh has an empty extract that means nothing.

**Evidence.**
- runs/02/edge-requests.txt — request lines pulled from the replacement endpoint
- runs/02/edge-function-logs.txt — function logs from the replacement endpoint
- runs/02/notes.md — the edge_logs.sh output and the removed-endpoint message

**Decision quote.**
> 

**Triage.**
fix ticket: edge-function logs are read through the Supabase MCP's query_logs (ClickHouse SQL on the logs table) from now on; runbook step 6 and the other callers switch to it and scripts/edge_logs.sh is deleted so nothing passes silently again (Lee)
