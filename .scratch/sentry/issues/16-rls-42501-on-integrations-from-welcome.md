# 16: RLS 42501 on integrations from welcome

**What to build:** MEALVANA-ENDURANCE-3W: inserting into `integrations` violates row-level security from the welcome screen's get-started path (59 events, 3 users). Find why the insert runs before the session exists or with the wrong user id, fix it, and resolve the issue.

**Blocked by:** 10 Contract

**Status:** done

- [x] Root cause written in the ticket
- [x] The insert no longer runs unauthenticated, or the policy is corrected with a migration applied to dev (the client no longer sends it; the policy is correct, so no migration)
- [x] A seam test covers the path through the real repository (`test/features/integrations/integrations_rls_seam_test.dart`)
- [ ] Issue resolved in Sentry with the fixing commit (lead, after merge; see the table below)

## Root cause

**MEALVANA-ENDURANCE-3W** (prod; 448 events, 3 users, 2025-11-18 to 2026-10-01). The legacy reporter grouped this issue by culprit (`welcome.get_started_button`), so it holds more than one failure. Of the 50 events the API still returns:

| Failure | Events | Note |
|---|---|---|
| `integrations` upsert, 42501 RLS (403) | 1 | the latest event, 1.29.0+148 |
| `integrations` upsert, 23503 `integrations_user_id_fkey` (409) | 15 | 1.26.0 to 1.28.0+145 |
| `users` update_profile, PGRST003 pool timeout (504) | 28 | one user, 2026-09-20, server-side |
| other 504 Gateway Timeouts (activities, food_preferences, users) | 6 | server-side |

Every integrations event follows the same breadcrumbs: Settings, sign out, the welcome screen, **Get Started**, a fresh anonymous sign-in, `onboarding`, then `POST /rest/v1/integrations?on_conflict=id` fails within about a second. The Sentry user tag is `anonymous` or the previous user.

The policy is correct. On prod and dev, the insert policy is `auth.uid() = user_id OR user_id IN (users where device_id = x-device-id header)`. The app no longer sends `x-device-id`, so in practice a row is accepted only when `user_id = auth.uid()`. `integrations.user_id` references `public.users(id)`.

Both failures come from the immediate push in `IntegrationsRepository._pushToSupabase`. Every connect, sync-status, token and zones write calls it. Unlike `uploadDirtyRecords`, which has had a parent-row guard since July, it upserted without checking either condition:

- **42501:** the row's `user_id` was not the session's `auth.uid()`. In the latest event the anonymous user `e377…` had just been created and had no `users` row (the `GET users?id=eq.e377…` returned `[]`). A row owned by `e377…` would have passed RLS and failed on the FK instead. So the 403 means the row belonged to someone else, almost certainly the user who had signed out two seconds earlier. Some writer captured that id before sign-out (a provider sync or connect still in flight) and pushed under the new anonymous session.
- **23503:** the row's `user_id` was the anonymous `auth.uid()`, but the user connected a provider (TrainingPeaks or Runna) during onboarding, before the profile row existed remotely.

Since ticket 10 both already reach Sentry as `degraded` (warning), not fault. The request still failed every time, though, and the row only uploaded later through the dirty-record pass.

## Fix

- `lib/features/integrations/data/integrations_repository.dart`: new `_remoteWriteAllowed(userId, path:, rows:)`, called by **both** remote write paths (`_pushToSupabase` and `uploadDirtyRecords`) before any upsert:
  1. Session guard: if `auth.currentUser?.id != userId` (another user, or signed out), skip the write and leave the row dirty. It records a promoted `report.note` in area `sync` (D9) with `rowUserId`, `sessionUserId`, `hasSession`, `path` and `deferred`. The row uploads when its owner signs back in.
  2. Parent-row guard (the existing `_remoteUserExists` probe, now shared): defer with an `info` log until the `users` row is remote.
- No migration. The policy matches the intent.
- Test: `test/features/integrations/integrations_rls_seam_test.dart`. It runs the real repository, in-memory Drift and the real PostgREST client. The fake HTTP server applies the prod policy (`auth.uid() = user_id`, `users_select_own`, the FK) and answers with PostgREST's wire shape for each failure (403/42501, 409/23503). Three cases: a previous user's write after Get Started (no POST, row dirty, one promoted Note, then it uploads when the owner signs back in); fully signed out; and an anonymous onboarding connect before the profile row exists (deferred, then uploads once the row lands). Without the fix, all three are red; with it, all three are green.
- Verified: `dart analyze` is clean on both files. Green: the new test, `connect_identity_seam_test`, `final_surge_sync_service_test`, `runna_sync_service_test`, `integration_sync_coordinator_test` and `test/shared/source_guard` (61 tests).

## Owed

- I did not find which writer carried the previous user's id in the 1.29.0 event; breadcrumbs don't record the payload. The guard covers every writer, but a stale writer will now show up as the promoted Note `Integration upload skipped: rows belong to a user other than the session`. If that Note fires often, find the writer next (likely a provider sync spanning sign-out).
- If any athlete still has rows keyed by a local profile id that differs from their auth uid (the case `connect_identity_seam_test` describes), the server already rejects those rows. They will now raise the same Note instead of a degraded 42501. That is the signal to re-key them.
- The 34 timeout events in this group (PGRST003 pool exhaustion and 504s on `users`/`activities`/`food_preferences`) are server capacity, not this bug. Code doesn't change them; any new ones arrive as their own issues under the current reporter.
- No device check was run; none is in the acceptance list.

## Sentry resolution

| Issue | Action | Comment for Sentry |
|---|---|---|
| MEALVANA-ENDURANCE-3W | resolve | Ticket 16 <sha>: integrations writes now check the session uid matches the row's user_id (RLS 42501) and that the users row exists (FK 23503) before any push; rows stay dirty until both hold. The grouped 504/PGRST003 timeouts are server-side and regroup under the current reporter. |
