# 27-002 · Editing or deleting a meal log rewrites the server's created_at from the phone's copy, cut to whole seconds

- kind: bug
- status: triaged
- ticket: 27
- run: w15-20260924T2039Z
- screen: Timeline row → Edit Meal / Remove (sync to dev meal_logs)
- decision: 

**Steps.**
1. Log "W15-27 edit" (Manual). Server row 1ce8b3b7 created_at 2026-09-24 20:43:41.451694+00.
2. Log "W15-27 delete". Server row 7c20d895 created_at 20:44:17.196817+00.
3. Edit 1ce8b3b7 (Save changes 20:45:37Z); Remove 7c20d895 (20:46:16Z).
4. SELECT created_at, updated_at from meal_logs after each step.

**Expected.**
An edit or delete changes the edited fields, updated_at and is_deleted; created_at stays what the server first wrote.

**Actual.**
After the edit, 1ce8b3b7's created_at reads 20:43:41+00 (fraction gone); after the delete, 7c20d895's reads 20:44:17+00. The upsert sends the phone's created_at (MealLog.toSupabaseJson writes 'created_at'), and the local copy holds whole seconds, so each edit or delete rewrites the server's created time. Harmless at one second, but created_at is used for ordering rows with the same eaten time (meal_log.dart comment) and wave runs use it to tell whose row is whose; a phone with a wrong clock would move it further.

**Evidence.**
- runs/27/db-totals-after-logs.txt (created_at with microseconds)
- runs/27/db-totals-after-edit.txt (1ce8b3b7 created_at cut to 20:43:41+00)
- runs/27/db-totals-after-delete.txt (7c20d895 created_at cut to 20:44:17+00)

**Decision quote.**
> 

**Triage.**
Fix ticket 54 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 113 when 91 was split (Lee, 2026-09-25).
