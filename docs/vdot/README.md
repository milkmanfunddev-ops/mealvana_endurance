# V.O2 (VDOT) Integration

V.O2 (vdoto2.com) is a running-training platform built around Jack Daniels'
VDOT metric. This integration consumes their **BETA** REST API.

- Wiki: https://github.com/VDOT-O2/V.O2-API/wiki
- Partner contact: info@vdoto2.com

---

## Implementation status

| Layer | File | Status |
|-------|------|--------|
| Env config | `lib/shared/services/app_config.dart` | ✅ `vdotClientId`, `vdotClientSecret`, `vdotUseSandbox`, `vdotAuthBaseUrl`, `vdotApiBaseUrl` |
| API client | `lib/features/integrations/data/vdot_api_client.dart` | ✅ token exchange, refresh, workouts-by-event-id, workouts-by-date-range |
| OAuth service | `lib/features/integrations/application/vdot_oauth_service.dart` | ✅ `authenticate`, `disconnect`, `isConnected`, `getIntegration` |
| Transformer | `lib/features/integrations/application/vdot_transformer.dart` | ✅ VDOT workout JSON → `Activity` (eventDate parsed as local time; supports easyPace / qualitySession / crossTraining-bike / swim) |
| Sync service | `lib/features/integrations/application/vdot_sync_service.dart` | ✅ 60-day chunked range fetch, change detection via `ChangeDetectionService`, token-refresh-on-401, sync status writeback |
| Providers | `lib/features/integrations/presentation/providers/integrations_providers.dart` | ✅ `vdotApiClientProvider`, `vdotOAuthServiceProvider`, `vdotTransformerProvider`, `vdotSyncServiceProvider`, `vdotIntegrationProvider(userId)`, `isVdotConnectedProvider(userId)` |
| Controller | `lib/features/integrations/presentation/providers/connect_training_controller.dart` | ✅ `connectVdot()`, `disconnectVdot()`, `importVdotWorkouts()`, state fields (`isVdotConnected`, `vdotAthleteName`, `vdotLastSyncAt`) |
| Sync helper | `lib/features/integrations/presentation/integration_sync_helpers.dart` | ✅ `syncVdot()` (mirrors `syncFinalSurge`) |
| Settings + onboarding UI | `lib/features/settings/presentation/screens/connected_apps_screen.dart` | ✅ V.O2 card in both views; removed from coming-soon list |
| Coach-notes display | `lib/features/nutrition_plan/presentation/widgets/activity_detail/activity_coach_notes_widget.dart` | ✅ renders V.O2-attributed notes (incl. the structured-step summary the transformer writes) |
| Integration sync coordinator | `lib/features/integrations/application/integration_sync_coordinator.dart` | ✅ V.O2 wired into the staleness-driven auto-sync switch alongside FS / TP |
| Provider lookup variants | `lib/features/activities/data/activities_repository.dart` | ✅ `vdot` accepts `v.o2` / `v02` / `vo2` / `vdoto2` aliases for case-insensitive lookup |
| GPS upload (writeback analog) | `lib/features/integrations/data/vdot_api_client.dart` | ✅ API surface implemented, ⚠️ no automatic trigger — Mealvana doesn't produce GPS files (see below) |
| DB CHECK constraint migration | `supabase/migrations/20260514100000_add_vdot_to_integrations_provider_check.sql` | ✅ file committed, ❌ NOT yet applied to dev/prod (see below) |

---

## VDOT partner registration

Already registered with VDOT (2026-05-15):

- **Redirect/Callback URL:** `com.milkman.mealvanaendurance://callback`
- **Logo URL:** `https://endurance.mealvana.io/icons/Icon-512.png`

The redirect URI is shared with Training Peaks, Final Surge, and Garmin. VDOT distinguishes its callback from other providers' callbacks via the OAuth `state` parameter (generated and validated inside `VdotOAuthService`), not the URL path. If we ever need a path-scoped callback, both the registered URI and `_vdotRedirectUri` in `integrations_providers.dart` would need to be updated together.

## What still needs to happen before the flow works end-to-end

1. **Apply the migration.** `supabase db push` is currently blocked because the remote `supabase_migrations.schema_migrations` table holds 46 entries for migrations that live under `supabase/migrations/_archive/` locally. Until that's reconciled, apply the SQL by hand:

   ```sql
   ALTER TABLE integrations
     DROP CONSTRAINT IF EXISTS integrations_provider_check;
   ALTER TABLE integrations
     ADD CONSTRAINT integrations_provider_check
     CHECK (provider IN ('final_surge', 'training_peaks', 'strava', 'garmin', 'vdot'));
   ```

   Run against both projects:
   - Dev: `vlmtsdzpnjnavdgytcmi`
   - Prod: `wvmvsodrvbkxfydabqed`

   Without this, `IntegrationsRepository.upsertIntegration` will fail with a CHECK violation when the OAuth flow tries to store a `vdot` row.
2. **(Optional) Add a V.O2 logo asset.** The integration card falls back to text rendering of "V.O2" because no logo path is wired. Drop a PNG/SVG into `assets/images/integrations/` and set `iconPath` on the two `IntegrationProviderCard` instances (search the screen for `vdot_connect_button`).
3. **(Optional) Wire GPS upload.** Only the two read endpoints are scaffolded. The two `POST /v1/vdot-workouts/upload-gps[/{eventId}]` endpoints would need to be added to `VdotApiClient` if we ever want to push completed sessions back to V.O2.

---

## OAuth shape

VDOT uses standard OAuth 2.0 authorization-code grant with HTTP Basic auth at
the token endpoint.

- Authorize: `GET {authBase}/oauth/authorize?client_id=…&redirect_uri=…&response_type=code&scope=read:workouts&state=…`
- Token: `POST {authBase}/oauth/token` with `Authorization: Basic base64(clientId:clientSecret)` and form body `grant_type=authorization_code&code=…&redirect_uri=…`
- Refresh: same endpoint, `grant_type=refresh_token&refresh_token=…`

Token response:

```json
{
  "access_token": "…",
  "expires_in": 3600,
  "token_type": "Bearer",
  "refresh_token": "…"
}
```

Scopes:
- `read:workouts` — required for both workout endpoints
- `write:upload-gps` — required for the upload-GPS endpoints (not scaffolded yet)

### Hosts

| | Sandbox | Production |
|-|---------|------------|
| OAuth (`authBase`) | `https://app.vdoto2.com` (no sandbox host exists) | `https://app.vdoto2.com` |
| REST API (`apiBase`) | `https://api.sandbox.vdoto2.com` | `https://api.vdoto2.com` |

Controlled by the `VDOT_USE_SANDBOX` env var (default `true`).

⚠️ **DNS gotcha (2026-05-18):** The wiki documents `https://app.sandbox.vdoto2.com` as the sandbox OAuth host, but that hostname does not resolve — only `app.vdoto2.com` exists. The `vdotAuthBaseUrl` getter in `app_config.dart` ignores `VDOT_USE_SANDBOX` and always returns production. Only the API base toggles with the sandbox flag.

---

## REST endpoints currently wired

- `GET /v1/vdot-workouts/{eventId}` — single workout by id
- `GET /v1/vdot-workouts/{fromDate}/{toDate}` — date-range fetch (max 60 days)
- `POST /v1/vdot-workouts/upload-gps` — generic GPS upload (VDOT matches event itself)
- `POST /v1/vdot-workouts/upload-gps/{eventId}` — GPS upload bound to a specific event

The sync service requests a window of `today - 7d` to `today + 14d` by default. Longer windows are chunked into 60-day requests automatically.

### Why there's no automatic writeback trigger

TrainingPeaks has a "writeback" service that pushes Mealvana nutrition-plan summaries into the workout description (`tp_writeback_service.dart`). VDOT has no analog because the V.O2 API does **not** accept descriptions, notes, or nutrition data — its only write surface is the two `upload-gps` endpoints, which require an actual FIT/TCX/GPX file.

Mealvana doesn't produce GPS files of its own, and the Garmin push pipeline currently stores only parsed activity data (not the raw FIT file). So:
- `VdotApiClient.uploadGps` / `uploadGpsForEvent` exist for completeness and can be called by future features, edge functions, or scripts that have a GPS file to push.
- No controller or completion-hook triggers it today.

---

## Workout payload (relevant shape)

```jsonc
{
  "eventId": "78edbf80-30ef-40ba-ac93-d8661ebb2b49",
  "eventName": "Quality Session",
  "eventDate": "2024-03-29T00:00:00",       // tz-naive local
  "eventType": "easyPace|qualitySession|crossTraining",
  "status": "planned|completed|skipped|modified",
  "plannedTime": 3600,                       // seconds (optional)
  "plannedDistance": 8000,                   // meters (optional)
  "crossTrainingType": "bike|swim|strength|…", // only when crossTraining
  "crossTrainingEffort": "easy|moderate|hard", // optional, only when crossTraining
  "steps": [
    { "type": "step",       "intensity": "warmup|cooldown|recovery|interval|active|rest", "duration": {…}, "target": {…}, "order": 1 },
    { "type": "repeatStep", "repeatValue": 4, "steps": [...], "order": 4 }
  ]
}
```

Duration: `{ "type": "time" | "distance", "value": number }` — seconds / meters.
Target: `{ "type": "speed" | "heartRate" | "swimStroke" | "exercise", "value", "valueLow", "valueHigh" }`.

⚠️ `eventDate` is tz-naive — same gotcha as TP/FinalSurge. When matching to
Mealvana `activities.scheduled_date_time`, treat it as local time, not UTC.

---

## Where credentials live

| File | Keys |
|------|------|
| `.env` | `VDOT_CLIENT_ID`, `VDOT_CLIENT_SECRET` (prod-style fallback) |
| `.env.dev.local` | same — dev builds |
| `.env.prod.local` | same — prod builds |

To flip to production once approved:
```
VDOT_USE_SANDBOX=false
```
