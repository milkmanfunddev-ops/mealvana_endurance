# 18-012 · garmin-push on dev failed every record of two Garmin fan-out pushes (epochs 0 processed, 45 errors)

- kind: bug
- status: triaged
- ticket: 18
- run: w16-20260924T2100Z
- screen: none (server side: the dev `garmin-push` edge function)
- decision: none

**Steps.**
1. Nothing in the app: Garmin's fan-out (header `x-garmin-fanout: 1`, relayed from the prod project) posts to dev `garmin-push` on its own schedule.
2. Read the dev edge-function logs for 16:00-16:15 local on 2026-09-24 (ticket 18's extract).

**Expected.**
Each pushed record is processed, as at 16:01:18-20: `dailies 1/0`, `stressDetails 1/0`, `epochs 7/0` (processed/errors).


**Actual.**
At 16:13:41 `stressDetails` processed 0, errors 1; at 16:13:44 `epochs` processed 0, errors 45. The log names no cause and no user. Twelve minutes earlier the same kinds went through with no error. Not caused by either run: no app on the wave simulators calls `garmin-push`. Filed by the wave lead from ticket 18's notes ("garmin-push errors 16:13: server-side pushes, not this app"), which had no Finding for it. Whether it is one Garmin user's bad data or a function bug needs the per-record error, which the function does not log.


**Evidence.**
- runs/18/edge-function_logs.txt lines 176-181 (16:13:41-44, errors) against lines 3-15 (16:01:18-20, clean)
- runs/18/edge-function_edge_logs.txt lines 34-35 (both 16:13 POSTs answered 200 despite the errors)

**Decision quote.**
> none

**Triage.**

Fix ticket 65 (Lee, 2026-09-25). Closed by the retest after it merges.
