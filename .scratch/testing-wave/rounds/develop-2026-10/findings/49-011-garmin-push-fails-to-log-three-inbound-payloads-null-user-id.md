# 49-011 · garmin-push fails to log three inbound payloads: null user_id into garmin_health_data (23502) for Garmin user 05fec9ca…

- kind: bug
- status: open
- ticket: 49
- run: w5-20261008T1719Z
- screen: none
- decision: 

**Steps.**
1. No action of this run: a Garmin server push arrived at 17:28:59Z while this run was on Review & Log.
2. Read `function_logs` warnings for 17:19-17:49Z.

**Expected.**
Each inbound payload is logged against its user, or a push for a Garmin user with no Mealvana match is recorded as unmatched without a constraint error.

**Actual.**
Three `[garmin-push] inbound payload log error` warnings at 17:28:59.3-.8Z (`actdet:24654452703-detail`, `actdetfull:24654452703-detail`, `act:24654452703`): Postgres 23502, `null value in column "user_id" of relation "garmin_health_data" violates not-null constraint`; the failing rows carry Garmin userId 05fec9ca-1bde-4c7b-b2fe-8b8b852298a3 and user_id null. Not caused by this run; filed per RUNBOOK step 7 (a server error a run did not cause is still filed). Whether the activity itself was processed was not checked.

**Evidence.**
- runs/49/edge-errors-1719-1749.txt — the three warnings

**Decision quote.**
> 

**Triage.**
