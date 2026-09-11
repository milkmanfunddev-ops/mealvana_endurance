# SSOT — Integrations: Final Surge (data lifecycle & producer contract)

**Status: RATIFIED (Xuan, 2026-09-10, ruling desk).** Drafted 2026-09-08/09 from `app@c4abec2a`; `[observed]` clauses ratified; `[divergence]`/`[gap]` clauses carry the 2026-09-10 Q-INT rulings or remain OPEN per [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md). Cross-provider rules: [`lifecycle.md`](lifecycle.md); contested
clauses: [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md). App-repo-relative paths.

> Final Surge is a **pull** provider of *planned* workouts. It is the origin of the
> family's founding defect: the deliberate `duration_minutes = NULL` producer contract that
> four consumers each resolved differently (PLAN.md Phase 5;
> `intake/2026-08-22-data-ssot-producer-shapes.md`). Completion data has never been
> observed from FS — every FS import lands and stays `planned` until the athlete or Garmin
> completes it.

## FS-1 — Extraction `[observed]`
1. Plain OAuth, **no PKCE, no scopes**; hyphenated params (`client-id`, `redirect-uri`);
   `client-id` header required alongside the bearer token; HTTP 200 can still carry an
   error body (checked)
   (`lib/features/integrations/application/final_surge_oauth_service.dart:42-46`,
   `lib/features/integrations/data/final_surge_api_client.dart:40-120`).
2. Pull via `IntegrationSyncCoordinator` on the shared 4-hour staleness clock (L-9.1) —
   the sync service's own "MANUAL SYNC ONLY (MVP decision)" header
   (`final_surge_sync_service.dart:18-33`) is stale relative to its wiring.
3. Window: 14 days upcoming, clamped 1..14; fetched as `UpcomingWorkouts` + date-range
   chunks with a 404 fallback; structured-workout detail fetched only when flagged,
   non-blocking (`final_surge_sync_service.dart:141-236`).
   **Q-INT27 — RULED (Xuan, 2026-09-11, post-ratification addition): the forward window
   becomes 28 days** (the 14 was always our clamp, not an FS cap), aligning FS with the
   ~1-month hot window (§6 races design) and with what TP athletes get. GATED on the FS
   date-range server-cap probe (handback §7) plus one live check of the 404-fallback
   path (`UpcomingWorkouts` at `NumDays` > 14). **No FS history import** — dated
   decision, see Q-INT27 in the register; revisit with a load-context feature.
4. Token refresh: 400/401 → `requiresReauth`; the client writes
   `last_sync_status='requires_reauth'`, a value the **server CHECK does not permit**
   (`_archived/20260506120000…sql:44` vs `final_surge_sync_service.dart:380`) → **Q-INT10**.
5. A complete but **uncalled** edge function `sync-final-surge` still exists, storing FS
   tokens in auth `user_metadata` and filtering to RUNNING only — dead code and a stale
   token store (L-8.3, → Q-INT8; the manual itself calls it "the most misleading file in
   the Final Surge surface").

## FS-2 — Stored: the rows FS writes `[observed — the producer contract]`
`FinalSurgeTransformer` (`lib/features/integrations/application/final_surge_transformer.dart`):
1. Row: `synced_from_provider='final_surge'`, `provider_workout_id=WorkoutKey`,
   `provider_workout_url=WorkoutURL`, `status='planned'` (*"confirmed by external
   platform"*), `last_synced_at`, `notes` = cleaned `WorkoutDescription`.
2. Sport map: Run/Walk → `running` (Walk forced `IntensityLevel.easy`), Bike → `cycling`,
   Swim → `swimming`, **everything else → `other`** (*"imported for visibility/deletion,
   never misclassified as a run"*); only `Rest Day` (and a missing type) is never imported
   (`:86,121-125,282-294`).
3. **The load-bearing NULL**: `duration_minutes` is left NULL whenever the payload carries
   any distance **or** pace — *"keep duration null and let the UI estimate"* — asserted
   ten times in `final_surge_transformer_test.dart`; for `other` it is NULL
   unconditionally (`:158-160,429-458`). Proposed as ratified contract **jointly with**
   the single consumer ladder (FS-4.1): the NULL is only safe if exactly one ladder
   resolves it → **Q-INT12**.
4. `PlannedTime` is seconds → minutes clamped 1..1440; swims force `distance_miles=NULL`
   and compute `distance_meters`; midnight-with-no-time defaults to 07:00 local (L-9.2)
   (`:316-395,471-473`).
5. **Computed-then-discarded** `[divergence → Q-INT13]`: the transform result carries
   `workoutSubtype`, `paceMin/MaxMinutesPerMile`, `distanceMeters`,
   `intensityDistribution` — and the constructed `Activity` sets **none of them**
   (`:185-251`; sync uses only `result.activity`). Consequence: FS pace ranges and swim
   meters never reach the row, and `CarbsPerHourService._isSpeedWork` (which reads
   `workoutSubtype`) is blind to every FS workout — while Runna/VDOT do populate it.
6. FS supplies no weight/birth/gender/zones; identity contribution is name+email only,
   ranked after TP (`onboarding_preview_providers.dart:175-277`). No raw payloads are
   persisted for FS — transform in memory, discard.

## FS-3 — Discarded / retired `[observed]`
Dedup per L-1 (id, else fingerprint; plus cross-chunk dedup `:191-199`). Provider-removed
workouts get `provider_deleted_at` only (L-4.2 → Q-INT5). Resync merge ownership per L-2.
Disconnect: `deactivateIntegration` only — **no revoke path exists at FS** — tokens
retained; imported workouts hard-purged (L-5 → Q-INT2).

## Explicitly NOT ruled here
The duration ladder itself (owned by `SessionInputResolver` / F22 — FS-2.3 only ratifies
the producer side); the four-ladders unification history (PLAN.md Phase 5 / DEVIATIONS
D-005/D-008). The Dec-2025 design docs under `app/docs/integration/final_surge/` are
**claimed intent, unverified** — where they contradict this file (delete behaviour, swim
units, walk handling, sync trigger — four decisions, three answers each), the code as
cited here is the observed truth and this file is the proposed contract.
