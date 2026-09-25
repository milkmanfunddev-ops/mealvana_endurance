# 30-002 · last_synced_at is written as the local wall clock into a UTC timestamptz, five hours off

- kind: bug
- status: triaged
- ticket: 30
- run: w10-20260924T1615Z
- screen: none
- decision: 

**Steps.**
1. Sign in as test@test.com at 16:17:42Z (11:17:42 CDT); the FinalSurge sync updates the 09-24 07:28 "Run" row.
2. `SELECT updated_at, last_synced_at, now() FROM activities WHERE id = '7d3c02b1-23f9-427e-90d3-5b19bbde1884'`.

**Expected.**
`last_synced_at` (timestamptz) reads 2026-09-24 16:17:42+00.

**Actual.**
`last_synced_at` = `2026-09-24 11:17:42.802874+00`, the CDT wall clock labelled UTC, five hours in the past. `updated_at` (timestamp without time zone) holds the same 11:17:42 local value. The row is serialized with `activity.lastSyncedAt?.toIso8601String()` on a local `DateTime.now()` (`activity_mapper.dart:534`, `activity_sync_handler.dart:389`, set in `final_surge_sync_service.dart` on update), which carries no offset, so Postgres reads it as UTC. The `provider_deleted_at` values in 30-001 are likely shifted the same way. Anything that compares these to `now()` is off by the device's UTC offset.

**Evidence.**
- runs/30/db-activities-touched-last-2h.txt (row 1: updated_at 11:17:42 local, last_synced_at 11:17:42+00; db now() was 16:18:33+00 when read)
- runs/30/notes.md

**Decision quote.**
> 

**Triage.**
Fix ticket 42 (Lee, 2026-09-25). Closed by the retest after it merges.
