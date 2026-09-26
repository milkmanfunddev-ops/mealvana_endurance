# 117-001 · integrations.last_sync_at is still written as the local wall clock labelled UTC, five hours off (30-002's fault in another table)

- kind: bug
- status: triaged
- ticket: 117
- run: w40-20260926T1052Z
- screen: none
- decision: 

**Steps.**
1. Retest of 30-002: sign in as test@test.com on a cleared app at 10:54:00Z (05:54 CDT); the FinalSurge sync runs and completes at 10:54:05Z.
2. `SELECT provider, last_sync_at, last_sync_status, updated_at FROM integrations WHERE user_id = <test@test.com>` (no token columns).

**Expected.**
`integrations.last_sync_at` (timestamptz) reads about 2026-09-26 10:54:0x+00, like `updated_at` next to it.

**Actual.**
`last_sync_at` reads `2026-09-26 05:54:05+00` for final_surge and `05:54:03+00` for training_peaks and vdot: the CDT wall clock labelled UTC, five hours early, while `updated_at` on the same rows is `10:54:05+00`. Ticket 42 fixed `activities.last_synced_at` (30-002 passes: 10:54:05+00), but its scope said "any timestamptz the sync writes". The writer is `integrations_repository.dart` (`lastSyncAt: Value(DateTime.now())` at line 374, sent as `lastSyncAt?.toIso8601String()` at lines 652 and 680, a local time with no offset). Anything reading last_sync_at against now() (a "data is fresh" check across devices, a coach view) is off by the device's UTC offset.

**Evidence.**
- runs/117/db-integrations-state.txt
- runs/117/notes.md (10:55:42 line)

**Decision quote.**
> 

**Triage.**

Fix ticket 138, Settings, connections, allergies, Garmin (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
