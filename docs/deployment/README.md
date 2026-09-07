# Deployment Hub (Repo Truth)

## Current State (Repo Truth)
- **Edge-function deployment is manual.** No CI workflow runs `supabase functions deploy`.
  The GitHub Actions deploy workflows (`deploy-dev.yml`, `deploy-prod.yml`,
  `schema-drift-check.yml`) were deleted in `b2f86b4f` (2026-05-22) and are not coming back —
  the manual flow below is the process of record.
- Edge functions ship via the wrapper scripts `scripts/deploy_dev.sh` / `scripts/deploy_prod.sh`
  (or the `/deploy-edge` Claude skill, which wraps the same command with pre/post checks).
- Schema changes are applied by hand (DataGrip / `supabase db push` per
  `supabase/migrations/README.md`) — CI does not run `supabase db push` either.
- Web deployment is Vercel-based through `vercel.json` -> `scripts/build_web.sh`.
- Web runtime DB connection uses Drift Wasm (`sqlite3.wasm`, `drift_worker.js`) via `lib/shared/database/connection_web.dart`.

## Source of Truth
- Edge-function deploy scripts:
  - `scripts/deploy_dev.sh` (dev; reads the project ref from `.env.dev.local`)
  - `scripts/deploy_prod.sh` (prod; same, plus an interactive `yes` confirmation)
- Deploy skill (checklist + verification): `.claude/skills/deploy-edge/SKILL.md`
- Vercel config: `vercel.json`
- Web build script: `scripts/build_web.sh`
- Web entrypoint: `lib/main_web.dart`
- Web DB connection: `lib/shared/database/connection_web.dart`
- Available edge-function folders: `supabase/functions/`

## Supabase Edge-Function Deployment Runbook (Manual — Process of Record)
- Project refs:
  - Dev: `vlmtsdzpnjnavdgytcmi`
  - Prod: `wvmvsodrvbkxfydabqed`
- **Nothing deploys automatically.** Merging to `develop`/`main` does NOT ship edge functions.
  After changing anything under `supabase/functions/`, someone must run a deploy by hand.
- Preferred: the wrapper scripts (they pin the project ref explicitly, so a stale
  `supabase/.temp/project-ref` from a prior `supabase link` can't silently target the wrong env):
```bash
./scripts/deploy_dev.sh <function-name> [<function-name> ...]
./scripts/deploy_prod.sh <function-name> [<function-name> ...]   # asks for interactive 'yes'
```
- A function folder carrying an empty **`FROZEN`** marker file is a legacy version kept deployed for
  old installs (today: `calculate-daily-macros` = engine v5). The wrappers refuse to deploy it unless
  `--force-legacy` is passed — rollback only, never routine.
- Or the `/deploy-edge` Claude skill, which runs the same deploy plus schema/secret/cross-import
  pre-checks and post-deploy verification.
- Raw CLI equivalent (what the scripts/skill run under the hood):
```bash
supabase functions deploy <function-name> --project-ref vlmtsdzpnjnavdgytcmi --no-verify-jwt
supabase functions deploy <function-name> --project-ref wvmvsodrvbkxfydabqed --no-verify-jwt
```
- List deployed functions (verify version/updated_at bumped after a deploy):
```bash
supabase functions list --project-ref vlmtsdzpnjnavdgytcmi
supabase functions list --project-ref wvmvsodrvbkxfydabqed
```
- If `_shared` code changes, redeploy all impacted importing functions (shared modules are
  bundled into each function at deploy time; already-deployed functions do not pick up
  `_shared` edits).
- Version numbers shown by `functions list` are deploy counters, not code versions, and
  `ezbr_sha256` hashes are not comparable across projects — to audit staleness, download the
  deployed source (`supabase functions download <fn> --project-ref <ref>`) and diff file contents.

### Edge-Function Truth Model
#### App-invoked functions (derived from `lib/** functions.invoke(...)`)
- `analyze-meal-photo` (Mealvana AI AI — photo → meal analysis, via `meal_ai_service.dart`)
- `calculate-daily-macros-v6` (daily-macro engine, `algorithm_version` v6.0.0 — ratified
  `daily-macros-dashboard@v3`; via `daily_macro_service.dart`, schema-18 builds). **`_shared`**
  consumers: `garmin-push`, `garmin-ping` (Garmin completion matcher) — redeploy them with it.
- `calculate-daily-macros` — **LEGACY v5, FROZEN.** Still deployed for installs whose client pins
  `algorithm_version` v5.0.0 (pre-schema-18 builds, equality gate). Folder carries a `FROZEN` marker;
  `scripts/deploy_dev.sh` / `deploy_prod.sh` refuse it unless `--force-legacy` (rollback only).
  Delete folder + deployed function together once `min_supported_schema_version ≥ 18`.
  (`supabase/functions/calculate-daily-macros/README.md`; ruling Lee/Xuan 2026-08-19.)
- `create-user`
- `delete-user`
- `describe-meal` (Mealvana AI AI — text description → meal analysis, via `meal_ai_service.dart`)
- `jade-chat` (Mealvana AI AI — streaming conversation coach, Daily Macros tab; body: `{message, conversation_id?, timezone?, location?}`; response: NDJSON stream (`Content-Type: application/x-ndjson`) + header `x-conversation-id`; events: `{"type":"text","delta":"..."}`, `{"type":"ui","part":{...}}`, `{"type":"done"}`, `{"type":"error","message":"..."}`; UI part kinds: `meal_cards` (1–4 meal suggestion cards), `choices` (tappable option buttons); assistant metadata persisted as `jade_messages.metadata.ui_parts`)
- `generate-macros-v4`
- `generate-nutrition-plan` (V1 — legacy LLM pathway only, via `llm_nutrition_plan_service.dart`)
- `generate-nutrition-plan-v3` (V3 — main production flow, via `nutrition_plan_service.dart`)
- `get-foods`
- `get-weather-forecast`
- `lookup-product`
- `search-catalog`
- `search-public-events`
- `send-nutrition-plan-email`
- `upsert-user-profile`

#### Other repo functions (present in `supabase/functions/`, not currently invoked by app code)
- `garmin-oauth-callback`
- `generate-macros`
- `generate-macros-v3`
- `generate-nutrition-plan-v2`
- `save-user-food`
- `sync-all-data`
- `sync-final-surge`
- `upload-all-data`

## Web App (Vercel) Deployment Runbook
- Canonical build path:
  - `vercel.json` runs `chmod +x scripts/build_web.sh && ./scripts/build_web.sh`
- Required runtime env vars in Vercel:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - plus optional observability/analytics vars consumed by the script.
- Local build simulation:
```bash
./scripts/build_web.sh --local
```
- Build output target: `build/web/`
- Current script uses:
  - `flutter build web --release --pwa-strategy=none -t lib/main_web.dart --dart-define-from-file=.dart_defines.json`

## Verification Checklist
- `supabase/functions/` names referenced in docs exist on disk.
- App-invoked list matches current extraction from `lib/** functions.invoke(...)`.
- After any `supabase/functions/` change lands, a manual deploy (`scripts/deploy_dev.sh` /
  `scripts/deploy_prod.sh` or `/deploy-edge`) was actually run — there is no CI backstop.
- `vercel.json` still points to `scripts/build_web.sh`.
- `connection_web.dart` still references `sqlite3.wasm` and `drift_worker.js` and those files exist in `web/`.

## Related Docs
- **`supabase-deploy-playbook.md`** — the ordering rules (schema → functions → build → `app_config`
  last), the `app_config` two-step window, edge-function versioning / frozen functions, and the
  standing orders. This README is the mechanics; the playbook is the *why and in what order*.
- `bundle-runbook-template.md` — per-bundle runbooks live in `../ops/docs/deploys/`.
- `/docs/business_logic/README.md`
- `/docs/web_mode/README.md`
- `/docs/ci-cd/README.md`
- `/docs/test/README.md`

## Deprecated/Legacy Notes
- Legacy names frequently seen in older docs (`run-plan`, `generate-ai-nutrition-plan`, `save-food-preferences`) are not part of current app-invoked function set.
- Keep legacy references only in historical docs under `/docs/_archived/`.
