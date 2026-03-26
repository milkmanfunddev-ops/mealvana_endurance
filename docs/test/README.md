# Testing Handbook (Repo Truth)

## Current State (Repo Truth)
- Flutter test suites live under `test/` with heavy coverage in:
  - `test/new_sync/`
  - `test/integration/flows/`
  - `test/features/`
  - `test/shared/`
- Migration and schema tests exist at `test/migrations/` and `test/generated_migrations/`.
- Edge-function TypeScript tests currently live under `supabase/functions/**` (Deno test files).
- CI test workflow is `.github/workflows/test.yml`.
- Current local Dart test files in repo: 60 (`*_test.dart`).

## Source of Truth
- Flutter tests: `test/`
- Edge function tests: `supabase/functions/**/*.test.ts`
- Algorithm test runner: `supabase/functions/run-algorithm-tests.sh`
- CI workflow: `.github/workflows/test.yml`
- Dev/Prod deploy workflows (also run tests):
  - `.github/workflows/deploy-dev.yml`
  - `.github/workflows/deploy-prod.yml`

## Runbook / Commands
- Run all Flutter tests:
```bash
flutter test
```
- Run sync-focused suites:
```bash
flutter test test/new_sync
```
- Run integration flow suites:
```bash
flutter test test/integration/flows
```
- Run migration tests:
```bash
flutter test test/migrations/v1_to_v2_migration_test.dart
```
- Run algorithm unit tests (Deno):
```bash
./supabase/functions/run-algorithm-tests.sh
```
- Run algorithm unit + E2E tests (requires env):
```bash
export SUPABASE_URL=https://<project-ref>.supabase.co
export SUPABASE_ANON_KEY=<anon-key>
./supabase/functions/run-algorithm-tests.sh --e2e
```
- Run a specific edge function integration test directly:
```bash
deno test --allow-net --allow-env supabase/functions/generate-macros-v4/index.test.ts
```

## Verification Checklist
- `flutter test` completes without failures.
- `flutter test test/new_sync` passes (sync architecture safety net).
- Nutrition algorithm tests pass via `run-algorithm-tests.sh`.
- Any changed edge-function logic has a matching `supabase/functions/**.test.ts` run.
- If deployment-related changes were made, confirm test workflow commands still match repository paths.

## Related Docs
- `/docs/technical/README.md`
- `/docs/deployment/README.md`
- `/docs/business_logic/README.md`
- `/docs/database/README.md`

## Deprecated/Legacy Notes
- Historical docs often reference `run-plan`, `generate-ai-nutrition-plan`, and `save-food-preferences`; current app code invokes a different set of functions (see `/docs/deployment/README.md`).
- `.github/workflows/test.yml` currently contains an `edge-function-tests` job pointing to `test/local_edge_functions/`, but that folder is not present in this repo. Treat this as CI configuration drift to be corrected separately.
