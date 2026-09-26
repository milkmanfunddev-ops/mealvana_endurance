# SSOT — Integrations: TrainingPeaks (data lifecycle & producer contract)

**Status: RATIFIED (Xuan, 2026-09-10, ruling desk).** Drafted 2026-09-08/09 from `app@c4abec2a`; `[observed]` clauses ratified; `[divergence]`/`[gap]` clauses carry the 2026-09-10 Q-INT rulings or remain OPEN per [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md). Cross-provider rules: [`lifecycle.md`](lifecycle.md); contested
clauses: [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md). App-repo-relative paths.

> TrainingPeaks is a **pull** provider of planned workouts, the app's **only identity
> source** (name, email, birth month, gender), the only provider supplying training zones,
> and the only platform Mealvana **writes back into** — which makes it the provider with
> the most consequential consent question (TP-5).

## TP-1 — Extraction `[observed]`
1. OAuth without PKCE (CSRF state only); scopes requested by the app:
   `athlete:profile events:read workouts:read workouts:plan nutrition:write nutrition:read`
   (`lib/features/integrations/application/training_peaks_oauth_service.dart:44-51`).
   Access tokens live 1 hour; proactive refresh 5 min before expiry plus a 401-triggered
   force refresh (`:201-320`).
2. **Sandbox-by-default in code**: `useSandbox = true` hard-coded in both OAuth service and
   API client, overridable via `TRAININGPEAKS_USE_SANDBOX`
   (`training_peaks_oauth_service.dart:24`, `training_peaks_api_client.dart:31-42`) →
   **Q-INT14** (what is the ratified prod posture?).
3. Pull on the shared 4-hour clock (L-9.1). Window: 45 days (vs 14 for FS). Endpoints:
   workouts by range with description, workout by id, events (races), athlete profile,
   zones — zones cached in `integrations.athlete_zones_json` with a 24 h staleness refresh
   (`training_peaks_sync_service.dart:65-67`, `training_peaks_api_client.dart:166-469`).
   **Q-INT27 — RULED (Xuan, 2026-09-11, post-ratification addition): the 45-day forward
   window stands; NO TP history import** — the range endpoint could look backward (45-day
   chunks) but by dated decision we don't: TP is fetched for the forward plan it is
   authoritative about; actuals history is Garmin's job (30-day backfill), and the only
   ratified history consumer (Q-INT18 insight→template) serves platform-less athletes.
   Revisit with a load-context feature. See Q-INT27 in the register.
4. The class docstring's claims ("only imports NEW workouts; deleted workouts remain") are
   **stale** — the code updates linked rows and soft-deletes provider-removed ones like FS
   (`training_peaks_sync_service.dart:16-31` vs `:216-241`).

## TP-2 — Stored: the rows TP writes `[observed — the producer contract]`

> **Provider facts (live-verified 2026-09-18; ruled into the record 2026-09-20):**
> 1. **Planned-load exposure is per-ACCOUNT**: premium-featured and training-plan athletes
>    receive decimal `TssPlanned`/`IFPlanned` on `/v2/workouts` (list and by-id); a basic
>    account receives present-but-null keys even for values the athlete hand-typed
>    (mirror-specimen proof, `runs/2026-09-18-tp-premium-trial-probe.md`).
> 2. **`IsPremium` does not track feature state**: reads `false` on a premium-featured
>    trial. Never a predicate (see payload-usage-map §6 item 7).
> 3. **`Structure` unreachable under our OAuth grant**, every route, every tier (§1.6 of
>    payload-usage-map); file-export scope requested 2026-09-20.
> 4. Access tokens live ~30 minutes; only a freshly-synced row authenticates.
> 5. Key sets vary per instance (46–48 keys): optional keys (`Description`,
>    `PreActivityComment`) are DROPPED when empty, while load keys are present-and-null —
>    the corpus fingerprint's three-state alphabet exists for this.
`TrainingPeaksTransformer` (`lib/features/integrations/application/training_peaks_transformer.dart`):
1. Row: `synced_from_provider='training_peaks'`, `provider_workout_id` = Int64-as-string,
   `provider_workout_url` synthesized against the **prod** host even in sandbox
   (`:418-423`), `status='planned'`.
2. Units contract: distance ALWAYS meters; `TotalTime` in **decimal hours**; pace never
   provided (derived). `duration_minutes` is always a non-null int — TP rows do **not**
   exhibit the FS NULL quirk (`:6-11,491+`).
3. Sport map: Run/Walk → `running`, Bike/MTB → `cycling`, Swim → `swimming`,
   **Rowing → `cycling`** (*"similar metabolic profile"*), else → `other`; nothing dropped
   except missing `WorkoutType` (`:250-254,430-446`). Rowing reclassification →
   **Q-INT15** (a sport-identity call QA should not inherit silently).
4. **Computed-then-discarded** `[divergence → Q-INT13]`: `workoutSubtype`,
   `distanceMeters`, `tssPlanned`, `ifPlanned`, `intensityDistribution`,
   `elevationGainMeters`, `caloriesPlanned`, `tags` are computed and never set on the
   `Activity` (elevation/calories/tags folded into free-text notes) (`:314-368`).
   Consequence: **`activities.tss` is never populated from TP** even though the engine's
   week-input query selects `tss`, and the zone-derived intensity distribution is thrown
   away.
5. Identity: TP is the only source of birth month + gender; weight ranked after Garmin;
   email available but deliberately not copied into onboarding
   (`onboarding_preview_providers.dart:175-277`; manual `athlete-profile-fields.md`).
   No provider exposes height. No raw payloads persisted.

## TP-3 — Discarded / retired `[observed]`
Dedup per L-1; resync merge per L-2; provider-removed → `provider_deleted_at` only
(L-4.2 → Q-INT5). Disconnect: `deactivateIntegration`, tokens retained; **deauthorize
exists but is never invoked** (`revokeAccess` defaults false and the UI passes nothing —
`training_peaks_oauth_service.dart:334-360`,
`connect_training_controller.dart:1832-1846`) → Q-INT3. Imported workouts hard-purged
(L-5).

## TP-4 — Zones & wellness
Zones cache: 24 h staleness, but **no expiry on disconnect** (manual finding C6). TP
contributes no wellness/measured data — completion comes from Garmin or mark-done.

## TP-5 — Write-back (the consent clause) `[divergence → Q-INT16]`
Mealvana writes the nutrition-plan summary into the athlete's TP calendar
(`PUT /v2/workouts/plan/{id}` via `tp_writeback_service.dart:53-92`; also
`POST /v1/athletes/{id}/nutrition`). Facts requiring ruling:
1. The design doc says **"Default: OFF (opt-in to avoid surprising users)"**
   (`docs/integration/tp_write/README.md:232`); the code defaults **ON**
   (`preferences_service.dart:39` returns `?? true`, manual finding C2). We may be writing
   into athletes' third-party calendars without consent. Latch anatomy (Xuan asked,
   2026-09-10): the **403 is TP-enforced** (non-premium capability rejection on the PUT); the
   **permanence is OURS** — a device-local SharedPreferences bool
   (`tp_writeback_premium_blocked`) that blocks all future pushes; it is NOT truly
   permanent: `refreshPremiumEligibility` (Connected Apps screen) re-checks TP
   `IsPremium` and clears/sets it, and it resets on reinstall.
2. The PUT is a **full-object replace** (any omitted field written null); the safe
   GET→merge→PUT pattern is documented but end-to-end confirmation of the Description PUT
   was **deferred** (`tp_write/api_discovery_results.md`, "Authenticated Testing
   (Deferred)").
3. Cleanup on plan-deletion and on disconnect (strip Mealvana blocks, delete write-back
   records) is documented in detail and **implemented nowhere** (tp_write Phases 1–3
   unchecked; manual finding D5).
4. **No write-back ledger exists** (verified 2026-09-10: `tp_writeback_log` absent from
   dev AND prod) — the phone PUTs directly to TP with no record on our side. **CONFIRMED
   FIRED (2026-09-10, evening):** coach Claudia's screenshot shows a client's TP workout
   description carrying the delimited block verbatim (`[Mealvana Fuel Plan] Pre: 20g carb
   · Post: 20g protein, 82g carb within 30min [/Mealvana]`) — and she LOVES it ("I can
   see her data from mealvana now"). So the unconsented-default risk and coach demand are
   both real. The Q-INT16 ruling (opt-in OFF + ledger required) stands as applied;
   Xuan may amend the consent posture given the demand signal — options recorded in the
   2026-09-10 handback (prominent consent-at-connect; migration prompt so already-pushing
   athletes don't silently stop when the default flips OFF).
RULED (Xuan, 2026-09-10) + AMENDED same day: opt-in OFF with a **prominent consent prompt at TP
connect** and the existing settings toggle; server-side ledger required before any push
(a LOCAL Drift `tp_writeback_log` already records per-push status+planHash — the server
ledger mirrors it); disconnect strips blocks and purges the ledger; full-object PUT
verified end-to-end before re-enable.
**AMENDED — RULED (Xuan, 2026-09-11, design-ratification pass): the consent posture
REVERSES to opt-out.** Xuan's words: "by default it is always sharing. The athletes
have to opt out of it." Write-back **defaults ON for every athlete, new connects
included** (today's `?? true` behavior becomes the ratified intent rather than the
divergence). The connect-time sheet becomes an opt-out NOTICE — it still appears
after every successful TP connect (transparency is unchanged), the toggle in the TP
row pre-set ON, dismiss = stays ON; already-sharing athletes get the same notice once
on first launch (the migration moment, now ruled — no one's flow stops). Unchanged by
this amendment: the server ledger is still required before any push, the premium
latch, disconnect strips blocks + purges the ledger, and the in-row toggle remains
the opt-out. The ratified sheet copy/actions (D-3.1) were designed for opt-in and
need one more Claude Design iteration for the opt-out framing.

**Write-back rendering — RULED (Xuan, 2026-09-10, option A single-block):** the
`[Mealvana Fuel Plan]` block has one lifecycle with two states, always structured
**Pre / During / Post**: (1) at plan time it carries the planned macro numbers per
phase; (2) when the athlete logs fuel for that plan, the SAME block is replaced
in-place with the combined form — each phase line showing planned · consumed (e.g.
`Pre: 80g carb planned · 60g consumed`). One block, never two, for the fuel story;
the `[Mealvana Feedback]` block (rating/notes) stays separate. **Macro register — RULED (Xuan, 2026-09-10):** the block carries **Pre and During only —
the Post line is REMOVED** (today's formatter emits one; it goes). Pre = carbs (g),
water (oz), timing. During = **carbs per hour (g/h — essential)**, water (**ml/h**),
and **sodium (mg/h) — added**. At fuel-log time each field gains its consumed
counterpart (planned · consumed) from `fuel_log_data`.
**Units amendment — RULED (Xuan, 2026-09-11, design ratification):** During water is
**ml/h**, not the oz/h first recorded — the Claude Design consent-sheet handover
rendered `60 g carbs/hr · 500 ml/hr · 400 mg sodium/hr` and Xuan ruled the design copy
overwrites the SSOT. The consent sheet's EXAMPLE preview is ratified as a stylized
illustration in this format (it need not reproduce the `[Mealvana Fuel Plan]`
delimiters verbatim).

**Overwrite investigation (2026-09-10, Xuan's planned-vs-actual question):** in-place update is
ALREADY the built mechanism — the service GETs the workout, regex-replaces its own
delimited block (`mergeBlockIntoDescription` strips `[Mealvana Fuel Plan]…[/Mealvana]`
and re-inserts), and PUTs; the coach's own text is untouched and duplication is
impossible by construction. A hash guard skips unchanged plans. Moreover a SECOND block
already ships post-completion: `pushCompletionFeedback` writes a `[Mealvana Feedback]`
block (rating + notes) after the athlete completes — so post-completion description PUTs
are already exercised. Xuan's planned-vs-actual extension (e.g. "Pre: 80g planned · 60g
logged") is therefore a formatter change: at fuel-log time, replace the Fuel Plan block
with the combined planned+consumed line. ONE cell still unverified live: that TP accepts
the plan-PUT after completion in production (the feedback path implies yes; confirm via
the sandbox probe, or by asking whether a [Mealvana Feedback] block has ever appeared in
a coach's TP view).

## Explicitly NOT ruled here
Value ladders (F22); TP CTL replacing weekly hours (`spec/daily-macros/neat-tef.md`); the
14-vs-3 granted-scopes discrepancy and committed client secrets (manual findings S3/S4,
web-bundle secret) — engineering/security remediation, flagged at Q-INT9 routing. The
Nov 2025–Jan 2026 docs under `docs/integration/training_peaks/` are claimed intent,
unverified; its "Clear all TrainingPeaks data on disconnect" is aspirational (L-5 governs).
