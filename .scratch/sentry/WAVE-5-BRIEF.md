# Wave 5 brief: tickets 16-24, the Sentry backlog triage (read fully before touching code)

Branch of record: `sentry`. FIRST in your worktree: `git reset --hard sentry`, then
`flutter pub get --offline`, then copy `.env`, `.env.dev.local`, `.env.prod.local` from
`/Users/leemartin/development/mealvana_endurance/` (gitignored; never commit them). Never `git stash`.
Your scratch files go in `<scratchpad>/<ticket-number>/` — the scratchpad is shared across agents.

## The job
Each ticket names Sentry issues by short id (`MEALVANA-ENDURANCE-3W` = prod project
`mealvana-endurance`; `MEALVANA-ENDURANCE-DEV-5S` = dev project `mealvana-endurance-dev`; org `milkman-24`).
Read the real events, find the root cause in the code, fix it, prove it with a test, write the root
cause into the ticket file. Do NOT resolve anything in Sentry: the lead resolves after merge with the
final sha. Instead, end your ticket file with a `## Sentry resolution` table: issue id | action
(`resolve` / `resolve-as-degraded` / `leave-open: reason`) | one-line comment for Sentry.

## Reading Sentry (API; the sentry MCP tools also work if you have them)
Token: `TOKEN=$(grep -m1 token ~/.sentryclirc | sed 's/.*= *//')`, header `Authorization: Bearer $TOKEN`.
- Short id → issue: `GET https://sentry.io/api/0/organizations/milkman-24/shortids/MEALVANA-ENDURANCE-3W/`
  (`.groupId` is the numeric id).
- Latest event with stack + breadcrumbs + tags: `GET https://sentry.io/api/0/organizations/milkman-24/issues/<groupId>/events/latest/`
  (fields: `entries[].type == "exception"` → frames; `"breadcrumbs"`; `tags`; `contexts`; `release`).
- Event list: `GET .../issues/<groupId>/events/?full=true` (paginate with the `Link` header).
- Tags summary: `GET .../issues/<groupId>/tags/`.
Pipe through `python3 -c` / `jq`; save raw JSON under your scratch folder, never in the repo.
Older events were sent by the legacy reporter (pre-ticket-10 code); the frames point at code that has
since moved to `Report` — find the current equivalent with grep, don't assume the file still exists.

## Ground rules (CLAUDE.md applies in full; these are the ones this wave trips on)
- Errors are reported through `Report` (`lib/shared/services/report/report.dart`, read its header):
  `fault` (unexpected), `degraded` (expected failure, warning, never alerts), `note` (breadcrumb;
  promoted to warning in startup/push/payments/sync). Never import `sentry_flutter` outside that service.
- "Reclassify as Degraded" means: the catch site calls `report.degraded(...)` instead of `fault`, OR the
  exception type goes on the expected-failure allow-list in `lib/shared/services/report/expected_failures.dart`
  with a reason. Read how existing entries look first.
- Source guard: `test/shared/source_guard/` fails on any catch without report/rethrow; its allow-list is
  a `.md` with reasons. Run `flutter test test/shared/source_guard` after your change.
- Riverpod 3: after any `await` inside a provider/notifier, check `ref.mounted` before touching `ref`;
  read `ref.read(reportProvider)` BEFORE the first await (ticket 15 found this exact bug in
  `athlete_zones_provider.dart`, commit `d8a7c29d`, copy its shape). Controllers: `@riverpod` + `AsyncNotifier`
  + `AsyncValue.guard()`. Run codegen (`dart run build_runner build --delete-conflicting-outputs`) only if
  you touched an annotated file, and only for the packages you changed if possible.
- Tests: use `test/helpers/fakes/recording_report.dart` (`RecordingReport`) and
  `reportProvider.overrideWithValue(report)`. Seam test = through the real notifier/controller,
  producer-shaped data, never `assert` on data that crossed a process boundary (`docs/test/README.md`).
- Snackbars: `MealvanaSnackbar`. No hardcoded user-facing strings where a content system exists.
- D9: a new early return / swallow in startup, sync, push or payments must leave a `report.note` (promoted).
- Supabase (ticket 16/19/20/22 may need it): dev ref `vlmtsdzpnjnavdgytcmi`, prod `wvmvsodrvbkxfydabqed`.
  `export SUPABASE_ACCESS_TOKEN` from `secrets/supabase_management_api.env`; SQL via
  `POST https://api.supabase.com/v1/projects/<ref>/database/query` `{"query": "..."}`; edge logs via
  `GET https://api.supabase.com/v1/projects/<ref>/analytics/endpoints/logs.all?...` or the sentry MCP /
  Supabase MCP tools. **Read-only against prod. Dev schema changes go in a migration under
  `supabase/migrations/` AND are applied to dev** (`./scripts/deploy_dev.sh` for functions;
  `supabase db push --linked` or the Management API for SQL). Never touch prod `app_config`.

## Verification rule for this wave (Lee's standing rule, 2026-10-06)
- `dart analyze <every changed file>` clean.
- Run ONLY the test files you wrote or changed, plus `flutter test test/shared/source_guard`. No full
  `flutter test`, no `flutter build`. The lead runs the whole suite once after merging.
- A fix must come with a test that was red before and is green after; say which file in the ticket.
- If a device/emulator check is in your acceptance list and you cannot run it, say so plainly in the
  ticket under `## Owed` — never tick a box you did not verify.

## Finishing
1. Update your ticket file(s) in `.scratch/sentry/issues/`: tick what you verified, write
   `## Root cause` (per issue id), `## Fix` (files, test file), `## Owed`, `## Sentry resolution` table.
   Set `**Status:** done` or `done except <x>`.
2. One commit: `fix(sentry): ticket <NN> <short title>` ending with the attribution lines from your
   system reminder. Do not push. Do not merge.
3. Report back: branch, sha, per-issue root cause in one line each, test files, leftovers.
