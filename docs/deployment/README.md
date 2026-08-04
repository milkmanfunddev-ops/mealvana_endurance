# Deployment Hub (Repo Truth)

## Current State (Repo Truth)
- Backend deployment targets Supabase via GitHub Actions:
  - `develop` -> `.github/workflows/deploy-dev.yml`
  - `main` / `release/*` -> `.github/workflows/deploy-prod.yml`
- CI deploy workflows run tests first, then `supabase db push` and `supabase functions deploy`.
- Web deployment is Vercel-based through `vercel.json` -> `scripts/build_web.sh`.
- Web runtime DB connection uses Drift Wasm (`sqlite3.wasm`, `drift_worker.js`) via `lib/shared/database/connection_web.dart`.

## Source of Truth
- Supabase deploy workflows:
  - `.github/workflows/deploy-dev.yml`
  - `.github/workflows/deploy-prod.yml`
- Vercel config: `vercel.json`
- Web build script: `scripts/build_web.sh`
- Web entrypoint: `lib/main_web.dart`
- Web DB connection: `lib/shared/database/connection_web.dart`
- Available edge-function folders: `supabase/functions/`

## Supabase Edge-Function Deployment Runbook
- Project refs used in existing docs/workflows:
  - Dev: `vlmtsdzpnjnavdgytcmi`
  - Prod: `wvmvsodrvbkxfydabqed`
- Deploy one function manually:
```bash
supabase functions deploy <function-name> --project-ref vlmtsdzpnjnavdgytcmi --no-verify-jwt
supabase functions deploy <function-name> --project-ref wvmvsodrvbkxfydabqed --no-verify-jwt
```
- List deployed functions:
```bash
supabase functions list --project-ref vlmtsdzpnjnavdgytcmi
supabase functions list --project-ref wvmvsodrvbkxfydabqed
```
- If `_shared` code changes, redeploy all impacted importing functions.

### Edge-Function Truth Model
#### App-invoked functions (derived from `lib/** functions.invoke(...)`)
- `analyze-meal-photo` (Mealvana AI AI — photo → meal analysis, via `meal_ai_service.dart`)
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
- Deploy workflows still contain test -> db push -> functions deploy sequence.
- `vercel.json` still points to `scripts/build_web.sh`.
- `connection_web.dart` still references `sqlite3.wasm` and `drift_worker.js` and those files exist in `web/`.

## Related Docs
- `/docs/business_logic/README.md`
- `/docs/web_mode/README.md`
- `/docs/ci-cd/README.md`
- `/docs/test/README.md`

## Deprecated/Legacy Notes
- Legacy names frequently seen in older docs (`run-plan`, `generate-ai-nutrition-plan`, `save-food-preferences`) are not part of current app-invoked function set.
- Keep legacy references only in historical docs under `/docs/_archived/`.
