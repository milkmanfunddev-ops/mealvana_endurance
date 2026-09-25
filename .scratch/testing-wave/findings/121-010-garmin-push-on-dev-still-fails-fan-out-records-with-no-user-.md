# 121-010 · garmin-push on dev still fails fan-out records with no_user_mapping (18-012 closed)

- kind: bug
- status: open
- ticket: 121
- run: w34-20260925T2320Z
- screen: none (server side: dev garmin-push)
- decision: 

**Steps.**
1. Nothing in the app: Garmin's fan-out relayed from the prod project posts to dev garmin-push.
2. Read the dev function logs for 18:20-18:38 local on 2026-09-25.

**Expected.**
Records for a Garmin user with no dev mapping are skipped quietly (not counted as errors), per whatever fix ticket 65 settled for 18-012.

**Actual.**
18:26:00, 18:26:02, 18:26:20 local: `[garmin-push] record failed kind=stressDetails|epochs|dailies garminUserId=dad6fb42-9b9c-4d5e-9d3a-01fa7acbad05 … reason=no_user_mapping`, `Processing complete: {"epochs":{"processed":0,"errors":5}}`. The `[garmin-auth]` line also logs every request header including caller IPs. Not caused by this run; filed per the runbook.

**Evidence.**
- runs/121/edge-function-logs-2320-2338.txt

**Decision quote.**
> 

**Triage.**

