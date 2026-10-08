# 61: garmin-push logs an unmapped Garmin user without a 23502

**Status:** done 2026-10-09: lead's function_logs read at the wave-7 close: unmapped push 22:23Z logged act/actdet/actdetfull skips with reason=no_user_mapping and the -detail id; no 23502
**Labels:** fix, round:develop-2026-10, area:integrations, area:functions
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** nothing.
**Next:** `/testing-wave develop-2026-10` (fix wave 6)
**Model:** opus

**What to build:** At 17:28:59Z a Garmin push arrived for Garmin user `05fec9ca-1bde-4c7b-b2fe-8b8b852298a3`, who maps to no Mealvana user on dev. The function skipped the activity correctly, but its forensic payload log first tried three `garmin_health_data` writes with `user_id` null, and Postgres refused each with 23502. Lee (2026-10-08): "garmin-push: an unmapped Garmin user is logged with a warning or keyed by garmin_user_id, never a 23502". Line numbers are from code at `b2313ed7` (no function change since `f8dd9171`).

1. **The forensic log skips the write when no user maps.** `logInboundGarminPayload` (`supabase/functions/garmin-push/index.ts:299-361`) upserts into `garmin_health_data` with `user_id: userId` (`:330-343`, the field at `:333`), and every caller passes `mapping?.user_id ?? null`: activities `:419-426`, activity detail summary `:969-976`, activity detail full `:997-1004`. The column is `uuid NOT NULL` with a foreign key to `users(id) ON DELETE CASCADE` (`docs/dev_schema.txt:2258`, `:5670-5671`; the live dev column also reads `is_nullable NO`). When `userId` is null, return before the upsert and write one line: `console.warn('[garmin-push] inbound payload log skipped key=<key> garminUserId=<id> reason=no_user_mapping')`, built after the key (`:322-329`) so the line names which payload was not kept. That is the D9 record: a PROD-readable function log, one line per payload, never the payload itself. The mapped path is unchanged, and the contract stays "MUST NOT THROW" (`:295-297`).
2. **Move the function where a test can reach it.** `index.ts` calls `serve(...)` at module load (`:72`), so a test cannot import it without starting a server. Move `logInboundGarminPayload` unchanged except for item 1 into `supabase/functions/_shared/garmin/push_log.ts`, beside `GarminMappingMisses` (`push_log.ts:125-176`), export it, and import it in `index.ts` (the import block at `:53-56`). Its client parameter stays `any`, so a stub client works.
3. **The activity-detail skip line names the activity.** The unmapped tally for activity details passes `detail.summary?.summaryId` (`index.ts:1018-1024`, the argument at `:1021`). Garmin puts the id at the top level of a detail (the comment at `:952-957`), so the 17:28:59Z line read `summaryId=none`. Pass `detailLogId` (`:958-960`) instead, as the log calls above it already do.

What happened to the payload, from the function logs (17:28:59.2Z to .8Z): the activity and activity-detail loops each tallied `skipped: 1` with `reason=no_user_mapping` (`push_log.ts:162-173`), `Processing complete` (`index.ts:1370`) counted 0 errors, and no `activities` row exists for summary `24654452703`. The skip was right; only the three log writes failed.

**Findings:** 49-011.

**Decisions:**
- Skip with a warning, not a nullable `user_id` plus `garmin_user_id` key. The log exists to answer "a mapped athlete's activity went missing: did it arrive?" (`index.ts:273-287`). An unmapped user's payload belongs to nobody on this project, so keeping it would store a stranger's health data (heart rate, steps, device) with no owner to read it under RLS (`docs/dev_schema.txt:6019`, `auth.uid() = user_id`) and no account whose deletion removes it. The table already has `garmin_user_id` (`text NOT NULL`, `:2259`), so the nullable path would only drop `user_id`'s NOT NULL and its meaning for every reader that keys on it (the indexes at `:4837` and `:4844` lead with `user_id`). Skipping needs no migration and no schema change, and the warning line plus the existing skip tally answer the forensic question: the payload arrived and no user maps.
- Whose Garmin user it is: nobody's on dev. `garmin_user_mappings` (columns read: `id`, `user_id`, `garmin_user_id`, `created_at`, `updated_at`) has no row for `05fec9ca-…`; dev holds 7 mappings, the newest from 2026-09-13. `integrations` (columns read: `user_id`, `provider`, `is_active`, `updated_at`, filtered on `provider = 'garmin'` and `provider_athlete_id`) has no row either. A Garmin account that authorised the dev Garmin app and was later unmapped, or a mapping deleted with its user, would look like this; Garmin keeps pushing until the user revokes it. The fix does not depend on which.
- Not changed: the wellness loops (dailies, sleeps, body composition, stress) already skip before any write when unmapped (`index.ts:493-510`, `:556-573`, `:619-636`, `:711-728`); only the three forensic calls write before the mapping check, by design, so a dropped mapped activity still leaves a trace.
- No retry or timeout is added (#82 does not apply).

**Touches:** supabase/functions/garmin-push/index.ts, supabase/functions/_shared/garmin/push_log.ts, supabase/functions/_shared/garmin/push_log.test.ts. 3 files. No migration, no Dart, no generated files.

**Overlaps:** 62 also touches an edge function (`generate-nutrition-plan-v3`), with no shared file. 63 and 64 are app-side Garmin-adjacent work in `lib/features/integrations/`; no shared file.

No schema change. One function to deploy: `garmin-push`.

- [x] Deno test (`push_log.test.ts`, new `describe('logInboundGarminPayload')`) with a stub client whose `from('garmin_health_data').upsert(...).select(...)` records calls, after `buildSupabaseInsertStub` in `garmin-push/index.test.ts:748-780`: (a) `userId` null, `garminUserId '05fec9ca-…'`, summary id `24654452703`, for each of `activity`, `activity_detail`, `activity_detail_full`: no upsert call, exactly one `console.warn` line containing `act:24654452703` (or the `actdet:`/`actdetfull:` key), `garminUserId=05fec9ca-…` and `reason=no_user_mapping`, and no payload field in the line; (b) a mapped user: one upsert whose row has that `user_id`, `garmin_user_id`, the prefixed `summary_id` and `onConflict: 'summary_id'`, as today; (c) the stub's upsert throws: the function resolves, no throw. Red-check (a) against the pre-fix function.
- [x] `deno test --allow-all supabase/functions/_shared/garmin/push_log.test.ts supabase/functions/garmin-push/index.test.ts` green, plus `deno check supabase/functions/garmin-push/index.ts`.
- [x] Before committing, grep `supabase/functions/` and `test/` for `logInboundGarminPayload`, `GarminMappingMisses` and `push_log` and run every test file they name (#116).
- [x] Source guard (#117): the new warning is a Deno `console.warn`, not a Dart Report helper, so `source_guard.dart` does not apply; say so in the fix notes. No silent catch is added (the existing one at `index.ts:357-360` keeps its warning).
- [x] Runs twice or after a refresh: Garmin retries a push it thinks failed, and the fan-out can deliver the same summary twice. For an unmapped user each delivery writes one warning line and nothing else, so a repeat is harmless. For a mapped user the upsert keeps `ignoreDuplicates` on `summary_id` and the "wrote NOTHING" warning (`index.ts:352-355`), unchanged.
- [x] `flutter analyze`: not needed (no Dart touched).
- [ ] Dev deploy: the lead deploys once from the merged tree, SQL first; agents deploy nothing. No SQL for this ticket; the function is `garmin-push` (`./scripts/deploy_dev.sh garmin-push`).
- [ ] Retest: server-side: verified by SQL/edge logs at the close, no simulator retest. The lead reads `function_logs` for `garmin-push` after the deploy: an unmapped push shows `inbound payload log skipped … reason=no_user_mapping` and no 23502; the activity-detail skip line carries the `…-detail` id, not `none`.

Next: /testing-wave develop-2026-10 (fix wave 6)

## Fix notes

**What changed.**
1. `logInboundGarminPayload` moved out of `garmin-push/index.ts` into `supabase/functions/_shared/garmin/push_log.ts` (exported, client parameter still `any`) and `index.ts` imports it. The only behaviour change: when `userId` is null it builds the key, writes one line `[garmin-push] inbound payload log skipped key=<key> garminUserId=<id> reason=no_user_mapping` with `console.warn`, and returns before the upsert. No payload field reaches the line. The mapped path and the "MUST NOT THROW" catch are unchanged.
2. The activity-detail unmapped tally in `index.ts` passes `detailLogId` instead of `detail.summary?.summaryId`, so the skip line names the `…-detail` id instead of `none`.
3. Folded in from ticket 64's Decisions: `stampIntegrationSyncHealth` adds `.eq("is_active", true)` to its `integrations` update (one line), so a disconnected Garmin row takes no status write.

**Files.** `supabase/functions/garmin-push/index.ts`, `supabase/functions/_shared/garmin/push_log.ts`, `supabase/functions/_shared/garmin/push_log.test.ts`, `supabase/functions/garmin-push/index.test.ts` (one new case for the folded-in guard; the ticket's Touches listed three files, this is the fourth).

**Tests.**
- `push_log.test.ts`, new `describe("logInboundGarminPayload")`: (a) unmapped user, one case per kind (`act:`/`actdet:`/`actdetfull:24654452703`): no upsert, one warn line with the key, `garminUserId=05fec9ca-…` and `reason=no_user_mapping`, no payload field in it; (b) mapped user: one upsert with `user_id`, `garmin_user_id`, `summary_id act:24654452703`, `onConflict summary_id`, `ignoreDuplicates true`; (c) upsert throws: resolves, one "non-fatal" warn. Red-checked: the three (a) cases failed against the moved but unfixed function, (b) and (c) passed.
- `index.test.ts`, new `describe('stampIntegrationSyncHealth')`: a source guard (the function cannot be imported, same pattern as the file's failure-logging guard) that the `integrations` update chain carries `.eq("is_active", true)`. Red-checked by removing the line: 1 failed.
- `deno test --allow-all supabase/functions/_shared/garmin/push_log.test.ts supabase/functions/garmin-push/index.test.ts`: ok, 9 passed (71 steps), 0 failed.
- `deno check` on `garmin-push/index.ts` and `_shared/garmin/push_log.ts`: clean. `deno lint` on the four files: clean.
- #116: `grep -rl "logInboundGarminPayload\|GarminMappingMisses\|push_log\|stampIntegrationSyncHealth" supabase/functions test` names only the four files above; both test files ran.

**#117.** The new line is a Deno `console.warn` in an edge function, not a Dart Report helper or a Dart by-contract catch. `source_guard.dart` covers Dart only, so it does not apply and is unchanged. No silent catch is added; the existing catch keeps its warning.

**Twice or after a refresh.** Garmin retries a push it thinks failed, and the fan-out can deliver one summary twice. Unmapped user: each delivery writes one warn line and nothing else, so a repeat only adds a line. Mapped user: unchanged; the upsert keeps `ignoreDuplicates` on `summary_id` and the second delivery logs "wrote NOTHING … (duplicate summary_id)". The stamp guard: two pushes at once each update only the active row, setting the same status; an inactive row is untouched by both.

**The lead deploys.** No SQL. One function: `./scripts/deploy_dev.sh garmin-push`. `_shared/garmin/push_log.ts` changed, so check its import closure: `grep -rln "push_log" supabase/functions` names only garmin-push (and its tests), so garmin-push is the whole deploy list.

