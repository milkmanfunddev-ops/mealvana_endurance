# 08-025 · garmin-push on dev logs a warning for every push from an unmapped Garmin user (11 in the wave window, 9 distinct users)

- kind: bug
- status: open
- ticket: 08
- run: w1-20261007T1105Z
- screen: none (server, garmin-push)
- decision: 

**Steps.**
1. Pull the dev function_logs for the wave window (10:55Z to 11:40Z) from /analytics/endpoints/logs, source function_logs.
2. Filter level warning.

**Expected.**
No warning the wave did not cause. A Garmin push for a user the dev project does not know should be acknowledged quietly (or once per user), not logged as a warning on every push.

**Actual.**
Filed by the wave lead from the whole-wave extract. 11 `[garmin-push] No user mapping for Garmin userId: …` warnings between 11:00Z and 11:33Z, 9 distinct Garmin user ids (40737893-… three times), all 27 garmin-push requests answered 200. No run in the wave connected Garmin, so none caused them: these are pushes for users mapped on prod (or deleted on dev) that Garmin still sends to the dev endpoint. Recurrence of mealplanning 112-010, whose fix ticket (138) is a mealplanning change not on develop-next.

**Evidence.**
- runs/wave-1-edge-logs.txt — the 11 warning lines and the 27 garmin-push request lines
- docs/testing-wave/BUGS.md — row 112-010 (mealplanning-2026-09, fix ticket 138)

**Decision quote.**
> 

**Triage.**

