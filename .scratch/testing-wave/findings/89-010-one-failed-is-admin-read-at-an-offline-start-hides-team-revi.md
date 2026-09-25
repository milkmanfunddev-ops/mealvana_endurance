# 89-010 · One failed is_admin read at an offline start hides Team review for the whole session

- kind: bug
- status: triaged
- ticket: 89
- run: w29-20260925T1950Z
- screen: Meal detail (Team review)
- decision: 

**Steps.**
1. test@test.com (users.is_admin = true). Cold launch with the app's network cut (19:55:00Z), restore it a minute later (19:56:02Z).
2. Twenty minutes later open a meal's detail from Browse.

**Expected.**
The Team review box shows for an admin once the app is online.

**Actual.**
No Team review box. The console at the offline launch has "[IS_ADMIN] is_admin read failed; treating as not admin" (Network is unreachable). `isAdminProvider` is keepAlive and re-reads only on a change of user, so one failed read at start hides admin surfaces until the app is killed. After a relaunch online the box showed and a review saved (meal_reviews 8861acf0).

**Evidence.**
- runs/89/62-18-010-detail-from-browse.png: no Team review after the offline start.
- runs/89/71-18-010-detail-admin.png: Team review after a relaunch online.
- runs/89/console-redacted.log: 14:55:04 local, [IS_ADMIN] is_admin read failed.

**Decision quote.**
> 

**Triage.**

Fix ticket 130 (Lee, 2026-09-25). Closed by the retest after it merges.
