# 01-013 · scripts/edge_logs.sh returns '(no rows in window)' for every query on dev, even 24 h unfiltered

- kind: idea
- status: triaged
- ticket: 01
- run: w1-20261007T1103Z
- screen: none
- decision: 

**Steps.**
1. Idea: fix or replace `scripts/edge_logs.sh` (the runbook's step 6 tool) so a run can read delete-user's own log lines; add a self-check that fails loudly when a 24 h unfiltered query returns nothing.

**Expected.**
`./scripts/edge_logs.sh -m 60 "Deleting user"` shows the three delete-user calls this run made (11:12:53Z, 11:18:25Z, 11:35:01Z).

**Actual.**
Every query returned "(no rows in window)" and exit 0: `-m 35` and `-m 60` with "Deleting user" / "Successfully deleted", `-s function_edge_logs -m 35 delete-user`, and `-m 1440 -l 3` and `-s function_edge_logs -m 1440 -l 3` with no filter. The deletes did happen (SQL and `sweep-accounts.mjs footprint` show nothing left). So "(no rows in window)" from this script does not mean "none" right now, which the runbook relies on.

**Evidence.**
- runs/01/edge-delete-user.txt
- runs/01/db-A-after-delete.txt

**Decision quote.**
> 

**Triage.**
fix ticket: edge-function logs are read through the Supabase MCP's query_logs (ClickHouse SQL on the logs table) from now on; runbook step 6 and the other callers switch to it and scripts/edge_logs.sh is deleted so nothing passes silently again (Lee)
