# 112-010 · garmin-push on dev counts every push for two unmapped Garmin users as an error (reason=no_user_mapping)

- kind: bug
- status: triaged
- ticket: 112
- run: w34-20260925T2320Z
- screen: none
- decision: 

**Steps.**
1. Read dev edge-function logs 23:16-23:46Z (`scripts/edge_logs.sh -m 30`).

**Expected.**
A push for a Garmin user with no Mealvana mapping is skipped quietly (or the mapping is cleaned up at Garmin's end), not logged as a failed record every few minutes.

**Actual.**
garmin-push logged `record failed … reason=no_user_mapping` for garminUserId dad6fb42… (18:26:00-18:26:20 local) and 1df3fb7b… (18:37:06-18:37:09), each ending "Processing complete: {processed 0, errors N}". Not caused by this run; no app calls garmin-push. Fix ticket 65's new logging (from 18-012) now names the cause: users deregistered or never mapped on dev still get pushes.

**Evidence.**
- runs/112/edge-function-logs.txt
- runs/112/edge-requests.txt

**Decision quote.**
> 

**Triage.**

Fix ticket 138, Settings, connections, allergies, Garmin (Lee, 2026-09-26). Ruling: disconnect (`garmin_oauth_service.dart:203` deletes only our mapping) and account delete (`delete-user` never touches Garmin) call Garmin's delete-user-registration API. Leftover pushes are logged once as skipped, not as errors. garmin-auth stops logging headers and IPs. Deregister the two dev orphans (138). Closed by the retest after it merges. Record: `triage-20260926.md`.
