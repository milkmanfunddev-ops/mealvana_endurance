# SSOT — Integrations: Garmin (data lifecycle & producer contract)

**Status: RATIFIED (Xuan, 2026-09-10, ruling desk).** Drafted 2026-09-08/09 from `app@c4abec2a`; `[observed]` clauses ratified; `[divergence]`/`[gap]` clauses carry the 2026-09-10 Q-INT rulings or remain OPEN per [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md). Cross-provider rules live in [`lifecycle.md`](lifecycle.md);
contested clauses reference [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md). App-repo-relative paths.

> Garmin is the only **push** provider and the only source of *measured* (retrospective)
> data: completed activities, wellness, body composition. It plans nothing. Its data
> upgrades or creates rows; it never imports a `planned` row.

## G-1 — Extraction `[observed]`
1. **OAuth 2.0 + PKCE (S256)**, scopes `ACTIVITY_EXPORT HEALTH_EXPORT`
   (`lib/features/integrations/application/garmin_oauth_service.dart:42-76`). The only
   provider using PKCE.
2. **Push-only**: Garmin POSTs to edge functions `garmin-push` (payload inline) and
   `garmin-ping` (callback URL to fetch); there is no client-side Garmin sync
   (`integration_sync_coordinator.dart:214-223`). Handled payload types: activities,
   activityDetails, manuallyUpdatedActivities, dailies, epochs, sleeps, bodyComps,
   stressDetails, userMetrics; userPermissionsChange is logged only
   (`supabase/functions/garmin-push/index.ts:16-25,1172-1186`).
3. **Backfill** is a request-to-be-pushed, JWT-authenticated, window ≤ 90 days, and
   deliberately excludes `activities` from its defaults (*"re-pushing months of activities
   is not something a routine 'refresh my weight' call should do"*,
   `supabase/functions/garmin-backfill/index.ts:48-67`). Invoked on connect for
   body-composition + user metrics, 90 days (`connect_training_controller.dart:789-815`).
   **Q-INT27 — RULED (Xuan, 2026-09-11, post-ratification addition): the connect-time
   request adds `activities` at 30 days** — one window at Garmin's per-request Activity
   max, no chaining (Q-INT18's "chained ≤30-day windows" is fixed at one window; chaining
   to 60–90 days stays a future additive option if the insight engine's live test finds a
   month too thin). The 90-day clamp above Garmin's 30-day Activity max remains the
   recorded bug to fix (Q-INT18 / handback §6).
4. **Inbound auth** is a bare `garmin-client-id` header comparison; a request with **no
   header at all is allowed through**, and the ping path GET-fetches a body-supplied URL
   (`supabase/functions/_shared/garmin/auth.ts:14-67`). Known, unfixed (manual findings
   S1/S2). Contract routing → **Q-INT9**.
5. Prod→dev fan-out exists because Garmin allows one webhook URL per data type
   (`GARMIN_FANOUT_URL`, `garmin-push/index.ts:121-160`); dev must never set it.

## G-2 — Stored: the rows Garmin writes `[observed]`
1. **Completion of a planned row** (the primary path, ordered gates per
   `_shared/garmin/activity_completion.ts`): tombstone check FIRST (L-4.1) → skipped match
   ("sync beats skip", G6) → planned match (window: Q-INT4) → atomic completion update
   guarded by `status IN ('planned','draft','skipped')`. The update writes
   `status='completed'`, overwrites `scheduled_date_time` with measured start (L-9.3),
   sets `actual_time`, `completed_at`, HR, `calories_burned` (= `activeKilocalories`),
   duration, distance (measured replaces planned, **including 0**; omitted leaves planned
   alone), `garmin_summary_id`, `garmin_device_name`. `planned_time` untouched
   (`activity_completion.ts:300-406`). Race losers only fill null/0 gaps and never flip
   status (`:434-537`).
2. **Auto-insert when nothing matches**: a completed row with
   `synced_from_provider='garmin'` — for endurance sports and the `'other'` import-only
   bucket; Garmin transition legs skipped (`activity_completion.ts:566-644`).
   `garmin_summary_id` is the authoritative "displays Garmin-sourced data" signal
   regardless of which provider planned the row (`activities_table.dart:186-191`).
3. **Wellness → `garmin_health_data`** (JSONB by `data_type`, upsert by globally-unique
   `summary_id`): `daily`, `sleep`, `body_composition`, `stress`, `epoch`, `user_metrics`,
   plus verbatim inbound payloads as `activity_raw`/`activity_detail_raw` (forensic log,
   deliberately shipped without a migration; push path only — ping does not log;
   `garmin-push/index.ts:251-309`).
4. **Body comp mirrors into `users`**: `weight_pounds`/`body_fat_pct` with latest-wins and
   a 30-day staleness cut (`garmin-push/index.ts:167-249`).
5. **Tokens in two stores** — `integrations` and `garmin_user_mappings` (the one the
   server actually uses/refreshes; mapping required because pushes identify athletes by
   Garmin userId). L-8 / **Q-INT8**.
6. Producer quirks proposed as contract: unknown sport → `'other'`; literal `"unknown"`
   device name dropped (brand guidelines); `duration_minutes` guarded `>= 0` so zero is
   valid and NaN is excluded; naive-local timestamps (L-9.2)
   (`_shared/garmin/mappers.ts:22-70,92-189`). The historical swim-swallowing and
   elevation-rounding defects are documented in-place and fixed (`:133-186`).

## G-3 — Discarded at ingest `[observed — the only true discards in the system]`
1. Per-second sample arrays, GPS tracks, HR series, power, lap splits arriving on every
   `activityDetails` push are **never persisted** — only `detail.summary` is read
   (`garmin-push/index.ts:878-880`; manual `api-exploration/README.md`). **Decided
   (Xuan, 2026-09-09): not recorded for now, as a dated temporary decision — revisit
   when an engine consumes sample streams.**
2. Duplicate `summaryId` takes the duplicate path and deliberately skips notification
   (`garmin_push_copy_rollout.md`).

## G-4 — Used `[by reference]`
- Engine: `calculate-daily-macros(-v6)` gates on `garmin_user_mappings`, reads
  `garmin_health_data` daily + body-comp (30-day staleness) and per-session
  `garmin_summary_id`/`calories_burned` (`…-v6/index.ts:47-116,158-296`). Ladders: F22–F27,
  `platform-resolution.md` — measured kcal beats F4, BMR beats Cunningham/Mifflin.
- Display: `DashboardAssembler` verified marks; `WorkoutStateResolver`
  `verified = done && garminSummaryId != null`. Wellness beyond daily/body-comp (sleep,
  stress, epochs, user_metrics) is ingested with **zero consumers** → Q-INT1 (retain why?).
- Onboarding prefill: weight = Garmin first, then TP; never identity (name is the literal
  `'Garmin Connect'`; Garmin userId carries no identity)
  (`onboarding_preview_providers.dart:175-277`).

## G-5 — Disconnect & deregistration `[divergence]`
App-side disconnect deletes the `garmin_user_mappings` row (verified `remaining == 0`),
soft-deactivates `integrations` (tokens retained), hard-purges imported workouts — but
leaves **all** `garmin_health_data` and the `users` mirrors behind (L-5 → **Q-INT2**).
Garmin-initiated deregistration deletes only the mapping and does not deactivate the
integration despite its own header comment (**Q-INT3**). Garmin platform facts: access
tokens live 3 months; the Garmin userId persists across disconnect+reauthorize;
deregistration is irreversible (`docs/integration/garmin/authentication.md`).

## Explicitly NOT ruled here
Engine-day bucketing after the `scheduled_date_time` overwrite
(`intake/2026-08-20-engine-session-bucketing-day-key.md`); HR-derived IF (Q-010, RULED
deferred — `garmin_avg_hr` collected but unused); the value ladders themselves (F22).
