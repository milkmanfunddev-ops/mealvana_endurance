# 62: plan_generation_log takes numerics, and the 17:40Z 400s

**Status:** done 2026-10-09: lead's read at the wave-7 close: duration_minutes numeric, 2 fractional dev_cloud_e2e rows, 0 insert-failed lines, exactly the health check's four 400s
**Labels:** fix, round:develop-2026-10, area:nutrition, area:functions
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** nothing.
**Next:** `/testing-wave develop-2026-10` (fix wave 6)
**Model:** opus

**What to build:** At 17:40Z on 2026-10-08, generate-nutrition-plan-v3 lost two ledger rows to `22P02 invalid input syntax for type integer` ("18.64", "117.9"), and seven calls across four functions answered 400. Lee (2026-10-08): "plan_generation_log numeric columns by SQL migration; the 17:40Z 400s investigated from function_edge_logs". Line numbers are from code at `f8dd9171`.

The investigation (dev logs, 17:39:30Z to 17:41:30Z):
- All 23 non-Garmin calls in that window came from one client: anonymous user `4d670b49-7ba6-4eec-9561-c22830574dc4` (created 17:40:26Z, `is_anonymous true`), IP 164.111.163.1 (Birmingham), user agent `Dart/3.11 (dart:io)`. The wave-5 runs (`607f9dd5…`, `1c31d98e…`) came from 104.15.210.213 with `Dart/3.12`, so it was no wave run. It was a run of `test/e2e/dev_cloud_e2e_test.dart`, which signs in anonymously (`:44-60`) and calls the functions over plain HTTP (`:77-89`). The ledger rows the run did write carry `device_id test-strict-e2e` (`:956, :994, :1153`) and `source null`.
- The two 22P02s are the strict-macro tests. They send `duration_minutes: (v4Macros['duration_min'] as num).toDouble()` (`:1000, :1189, :1291, :1383, :1476`), and macros-v4's `duration_min` is fractional for a distance/pace run. Function log: `[PLAN-V3] Full input: … duration_minutes=18.64` (exec `0a3898ab…`) and `=117.9` (exec `19a4c272…`). The plans themselves answered 200. The app never sends a fraction: `nutrition_plan_service.dart:120, :183` types it `int?`. A fraction is still valid input, and the ledger should keep what arrived.
- The seven 400s are the same suite's own requests, all rejected by request validation before any work:
  - generate-macros-v4 at 17:40:28.688Z and 17:40:29.025Z (bodies of 213 and 214 bytes): the "validates different gut training levels" test (`dev_cloud_e2e_test.dart:556-582`) builds `baseRequest` without `hours_before`, and v4 rejects that (`supabase/functions/generate-macros-v4/index.ts:80-81`, "Missing required field: hours_before"). The test reads the 400 body as if it were macros and its `if` at `:600` skips the `expect`, so it passes green.
  - generate-nutrition-plan-v3 at 17:40:31.038Z (407 bytes): the "LP Solver" test (`:720-765`) sends no `hours_before`; `index.ts:122-124` answers "Invalid hours_before". The test accepts 200, 400 or 500 (`:774-781`).
  - generate-macros-v4, search-public-events, get-weather-forecast and generate-nutrition-plan-v3 at 17:40:38.664Z to 17:40:39.825Z (2-byte bodies): the health check (`:1530-1572`) posts `{}` to each function on purpose and counts 400 as "responding" (`:1559-1562`). get-weather-forecast logged `latitude: undefined, longitude: undefined`.
  - No function misbehaved. Two tests send stale request shapes and pass anyway.

1. **Migration `supabase/migrations/20261008166200_plan_generation_log_numeric_duration.sql`.** `plan_generation_log` has one integer column, `duration_minutes` (`supabase/migrations/20260721090000_plan_generation_log.sql:16`; live on dev and prod per `information_schema.columns`, checked 2026-10-08). That is the only integer column that receives a fraction; every other value the row carries is text, uuid or jsonb (`plan-generation-log.ts:20-45`), and the per-phase decimals (`phaseTotals`, `:75-84`) live inside the `delivered` jsonb. Write `alter table public.plan_generation_log alter column duration_minutes type numeric using duration_minutes::numeric;`. The alter is idempotent in effect: re-running it on a numeric column is a no-op. It is widening only (integer to numeric), so existing rows and the funnel query (`qa/scripts/query-ledger.sh`) read the same. Add a header naming the 22P02 and the e2e source, plus `comment on column … is 'minutes as sent by the caller; fractional allowed (e2e sends macros-v4 duration_min)'`. Update `docs/dev_schema.txt:2602` and the `docs/prod_schema.txt:2986` to `numeric` so the dumps stay true. Additive, so it can be applied to prod at any time (playbook §3).
2. **The insert reports a failed write as one structured warning (D9).** `insertPlanGenerationLog` (`supabase/functions/generate-nutrition-plan-v3/plan-generation-log.ts:155-167`) already warns on `error` (`:162`) and on a throw (`:165`), but prints the raw error object across several lines with no plan id. A lead reading `function_logs` cannot match it to a request or tell which field failed without the `Full input` line. Replace both with one line each: `console.warn("[PLAN-V3] plan_generation_log insert failed", JSON.stringify({ plan_id: row.plan_id, device_id: row.device_id, code: error.code, message: error.message, duration_minutes: row.duration_minutes }))`, and the throw path the same with `code: "threw"` and `String(err)`. It still never throws and never delays the response (`index.ts:479-507`, `brick-handler.ts:717-745`). Both callers go through this one function, so neither caller changes.
3. **The e2e suite sends the shapes the functions take, and marks itself as test traffic.** In `test/e2e/dev_cloud_e2e_test.dart`:
   - Add `'hours_before': 2.0` to `baseRequest` in the gut-training test (`:559-568`) and to `requestData` in the LP-solver test (`:727-748`), as the other tests already do (`:448, :511, :965`). Make the gut-training test `expect` 200 on both calls, so a stale shape goes red instead of passing.
   - Add `'x-mealvana-test': 'dev_cloud_e2e'` to `SupabaseTestClient.headers` (`:38-42`). plan-v3 records that header into `source` (`index.ts:108-110`, `plan-generation-log.ts:33-35`), and funnel queries exclude non-null `source`. Today the suite's rows (`test-strict-e2e`, three of them at 17:40Z) count as real traffic in the funnel.
   - The health check keeps posting `{}` and keeps accepting 400. That is its design, and the 400s it leaves in the edge logs are known noise from now on. The ticket's fix notes say so.

**Findings:** 49-012.

**Decisions:**
- One column, not a sweep: `duration_minutes` is the only integer column in the table, so "numeric columns" is one alter.
- The migration is the fix. Rounding in the function would hide what the caller sent, and the ledger exists to record inputs as they came.
- The 400s need no function change: request validation answered 400 correctly each time. The fix is in the test file (item 3).
- Not changed: the e2e suite's anonymous sign-in (`:44-60`). Lee ruled the anonymous path is being removed (30-006, 48-002). When it goes, this suite cannot sign in and needs a real dev test login. Note that in `.scratch/branch-split/HANDOFF.md` with the removal (the lead, not this ticket's agent). Each run also leaves one anonymous `auth.users` row on dev; `4d670b49…` is one.
- For the lead, not a product question: the run came from a machine that is not the wave Mac (Dart 3.11, 164.111.163.1). The tag `e2e` is excluded from the self-hosted CI run (`.github/workflows/tests-selfhosted.yml:127`), so someone ran the file by hand or ran an unfiltered `flutter test` at 17:40Z. Worth asking whose machine it was, since a plain `flutter test` there spends dev AI calls.

**Touches:** supabase/migrations/20261008166200_plan_generation_log_numeric_duration.sql (new), supabase/functions/generate-nutrition-plan-v3/plan-generation-log.ts, supabase/functions/generate-nutrition-plan-v3/plan-generation-log.test.ts (new), test/e2e/dev_cloud_e2e_test.dart, docs/dev_schema.txt, docs/prod_schema.txt. 6 files. No Dart lib change, no Drift change, no generated files.

**Overlaps:** none in fix wave 6. 61 changes `garmin-push` and `_shared/garmin/push_log.ts` only and needs no schema change, so it does not edit the schema dumps; 63, 64 and 65 add no schema change either. Tickets 55–60 were not written when this was drafted: the lead checks their Touches for the two dumps before the wave.

**Questions for Lee.** None.

- [x] Deno test (`plan-generation-log.test.ts`, new), run with `deno test --allow-all supabase/functions/generate-nutrition-plan-v3/plan-generation-log.test.ts`. (a) `buildPlanGenerationLogRow` with `input.duration_minutes = 18.64` keeps `18.64` (no rounding). (b) The insert payload validates against the new types: the test reads the new migration file and a column-type map of the table (seeded from the 20260721090000 and 20260903121000 migrations plus the alter), then asserts that every top-level field of a row built from producer-shaped fractional input (macros-v4's `duration_min` 117.9, `delivered` totals with one decimal) maps to a column whose type accepts it: no non-integer number lands in an `integer` column. Red against the current schema, green after the alter. (c) `insertPlanGenerationLog` against a fake client whose `insert` returns `{ error: { code: "22P02", message: "invalid input syntax for type integer: \"18.64\"" } }` writes exactly one `console.warn` whose JSON part has `plan_id`, `code 22P02` and `duration_minutes 18.64`; a client whose `insert` throws writes one line with `code "threw"`; neither rejects.
- [ ] The existing plan-v3 suites still green: `deno test --allow-all supabase/functions/generate-nutrition-plan-v3/` (the ledger module is imported by `index.ts` and `brick-handler.ts`).
- [x] #116: `grep -rl "insertPlanGenerationLog\|buildPlanGenerationLogRow\|plan_generation_log" supabase/functions test` and run every file it names. For `dev_cloud_e2e_test.dart`, run `flutter analyze test/e2e/dev_cloud_e2e_test.dart` only; the suite itself spends dev AI calls and is the lead's to run once after the deploy (the next box).
- [x] #117: no Dart reporting helper or by-contract catch is added; `source_guard.dart` covers Dart only, so it is unchanged. Say so in the fix notes.
- [x] Runs twice or after a refresh: the ledger insert is append-only with a fresh `plan_id` per request (`index.ts:128`), so two identical requests write two rows, as today. The migration re-run is a no-op. No retry or timeout is added (#82 does not apply).
- [x] `flutter analyze` clean on `test/e2e/dev_cloud_e2e_test.dart`; `deno check` and `deno lint` clean on the two function files.
- [ ] Dev deploy: the lead deploys once from the merged tree, SQL first; agents deploy nothing. SQL: the 20261008166200 migration on dev, then `generate-nutrition-plan-v3`. Prod: the same SQL at cutover (additive), recorded in the round's close-out owed list.
- [ ] Retest: server-side: verified by SQL/edge logs at the close, no simulator retest. After the deploy, the lead runs `flutter test test/e2e/dev_cloud_e2e_test.dart --tags e2e` once and checks: `information_schema.columns` shows `duration_minutes numeric`; the strict-macro rows land with fractional `duration_minutes` and `source 'dev_cloud_e2e'`; `function_logs` has no `plan_generation_log insert failed`; the only 400s in `function_edge_logs` for that run are the health check's four.

**Rulings (Lee, 2026-10-08, after drafting).**
- The e2e suite signs in anonymously and breaks when the anonymous path is removed: noted in `.scratch/branch-split/HANDOFF.md`.


Next: /testing-wave develop-2026-10 (fix wave 6)

## Fix notes

**What changed.**
1. New migration `supabase/migrations/20261008166200_plan_generation_log_numeric_duration.sql`: `alter table public.plan_generation_log alter column duration_minutes type numeric using duration_minutes::numeric;` plus the column comment, with a header naming the 22P02 and the e2e source. Widening only; a re-run on a numeric column changes nothing.
2. `insertPlanGenerationLog` (`generate-nutrition-plan-v3/plan-generation-log.ts`) writes one `console.warn` line per failed write: `[PLAN-V3] plan_generation_log insert failed` plus a JSON part with `plan_id`, `device_id`, `code`, `message`, `duration_minutes`. The throw path writes the same line with `code: "threw"` and `String(err)`. It still never throws; `index.ts` and `brick-handler.ts` are unchanged.
3. `test/e2e/dev_cloud_e2e_test.dart`: `'hours_before': 2.0` added to the gut-training `baseRequest` and the LP-solver `requestData`; the gut-training test now `expect`s 200 on both calls (reason: the response body); `SupabaseTestClient.headers` sends `'x-mealvana-test': 'dev_cloud_e2e'`, so plan-v3 records the suite's rows with `source = 'dev_cloud_e2e'` and funnel queries leave them out.
4. `docs/dev_schema.txt` and `docs/prod_schema.txt`: the `plan_generation_log.duration_minutes` line now reads `numeric`, one line each. (The dev dump's table also lacks the four 20260903121000 funnel columns; that drift was there before and is left alone.)

**Health check, known noise from now on.** The suite's health check (`dev_cloud_e2e_test.dart`, the "health check" group) still posts `{}` to generate-macros-v4, search-public-events, get-weather-forecast and generate-nutrition-plan-v3 and counts 400 as "responding". Those four 400s per run in `function_edge_logs` are by design; nothing else in a run should answer 400.

**Files.** `supabase/migrations/20261008166200_plan_generation_log_numeric_duration.sql` (new), `supabase/functions/generate-nutrition-plan-v3/plan-generation-log.ts`, `supabase/functions/generate-nutrition-plan-v3/plan-generation-log.test.ts` (new), `test/e2e/dev_cloud_e2e_test.dart`, `docs/dev_schema.txt`, `docs/prod_schema.txt`.

**Tests.**
- `deno test --allow-all supabase/functions/generate-nutrition-plan-v3/plan-generation-log.test.ts`: ok, 3 passed (5 steps). (a) `buildPlanGenerationLogRow` keeps `duration_minutes 18.64`. (b) The column-type map built from 20260721090000 + 20260903121000 + 20261008166200 accepts every top-level field of rows built from producer-shaped input (`duration_min` 18.64 and 117.9, phase totals with one decimal). (c) An insert error `22P02` gives one warn line whose JSON has `plan_id`, `code 22P02`, `duration_minutes 18.64`; a throwing insert gives one line with `code "threw"`; a clean insert writes nothing; none rejects. Red-checked with the migration file present but empty: (b) failed on `duration_minutes=18.64 into integer`, both (c) cases failed on the old message shape.
- The plan-v3 directory, run with `SUPABASE_URL`/`SUPABASE_ANON_KEY` unset: the 13 offline suites are ok, 43 passed (648 steps), 0 failed. The three remote suites (`index.test.ts`, `strict-macro-e2e.test.ts`, `during-invariant-remote-e2e.test.ts`) call the deployed functions over HTTP and fail at once without those env vars; they were not run against dev (they spend dev calls and need the deploy first). That box stays open for the lead's post-deploy run.
- `deno check` on `plan-generation-log.ts`, the new test, `index.ts` and `brick-handler.ts`: clean. `deno lint` on the two function files: clean.
- `flutter analyze test/e2e/dev_cloud_e2e_test.dart`: No issues found. The suite itself was not run.
- #116: `grep -rl "insertPlanGenerationLog\|buildPlanGenerationLogRow\|plan_generation_log" supabase/functions test` names `plan-generation-log.ts`, `brick-handler.ts`, `index.ts` (all type-checked, imported by the suites above), the new test, and `calculate-daily-macros-v6/recalculate.ts` (a comment only, no import). No Dart test names them.

**#117.** No Dart reporting helper or by-contract catch is added. The changed lines are Deno `console.warn` calls in an edge function; `source_guard.dart` covers Dart only, so it does not apply and is unchanged.

**Twice or after a refresh.** The ledger insert is append-only with a fresh `plan_id` per request, so two identical requests write two rows, as today; a failed write logs one line per request. The migration re-run is a no-op in effect. No retry or timeout is added (#82 does not apply).

**The lead deploys, in order (SQL first).** 1. Apply `20261008166200_plan_generation_log_numeric_duration.sql` on dev. 2. `./scripts/deploy_dev.sh generate-nutrition-plan-v3`. Prod: the same SQL at cutover (additive), for the close-out owed list. Then the retest box: `flutter test test/e2e/dev_cloud_e2e_test.dart --tags e2e` once.

**Review fixes (lead, 2026-10-08).**
- The migration's `alter column … type numeric` sits in a `do $$ … $$` block that runs it only while `information_schema.columns` reports `duration_minutes` as `integer`, so a re-run is a no-op (playbook §4). The comment statement is unchanged; `plan-generation-log.test.ts` still reads `numeric` from the file.
