# SSOT — Integration data lifecycle (cross-provider contract)

**Status: RATIFIED (Xuan, 2026-09-10, ruling desk).** Drafted 2026-09-08/09 from `app@c4abec2a`; `[observed]` clauses ratified; `[divergence]`/`[gap]` clauses carry the 2026-09-10 Q-INT rulings or remain OPEN per [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md). Contested clauses carry Q-INT references
([`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md)). All file paths are app-repo-relative.

> One lifecycle, three providers. A workout row is *born* (import or completion), *matched*
> (dedup, tombstone, skip, planned), *updated* (resync merge with fixed field ownership),
> *retired* (tombstone or provider flag), and *purged* (disconnect or account deletion).
> Every provider doc cites these clauses; none redefines them.

## L-1 — Row identity & deduplication `[observed]`
1. Provider-imported rows are unique per `UNIQUE(user_id, synced_from_provider,
   provider_workout_id)` (`lib/shared/database/tables/activities_table.dart:213`).
2. Garmin completions are additionally unique per `UNIQUE(user_id, garmin_summary_id)`
   (`supabase/migrations/_archived/20260506200000_activities_garmin_summary_unique.sql:42-43`);
   a 23505 on insert is treated as "duplicate", not an error
   (`supabase/functions/_shared/garmin/activity_completion.ts:610-612`).
3. When a payload lacks a provider id, dedup falls back to a fingerprint of
   type|title|scheduled|duration|distance (`final_surge_sync_service.dart:738-756`,
   `training_peaks_sync_service.dart:760-775`).
4. Cross-origin reconciliation: a provider import may claim a user-created row (same type,
   ±1 day, distance within 10%) only if that row has **no** existing provider linkage
   (`lib/features/activities/data/activities_repository.dart:1362-1413`, bug 385e3fdb).

## L-2 — Resync merge: field ownership `[observed]`
On re-import of an already-linked row (`activities_repository.dart:1417-1506`):
- **Provider owns** type, title, schedule, distance, duration, pace, intensity, notes —
  including the right to overwrite with NULL (the FS duration contract depends on this).
- **Local owns** completion state, nutrition plan, fuel log, reminders, brick metadata.
- `actual_time` and `calories_burned` are preserved across provider resyncs — in-code
  rationale: *"keeps a mark-done / Garmin-verified row from silently reverting to PLANNED
  on the next TP/FS re-sync"* (`:1448-1459`).
- `planned_time` follows a provider reschedule; `scheduled_date_time` semantics differ by
  provider (see L-9.3 and Q-INT11).
- **Planned/actual split (Xuan, 2026-09-10 — proposed):** the two-time model generalizes
  to every measurable field. Planner-owned columns (`duration_minutes`,
  `distance_miles`/`_meters`, pace targets) hold the PLANNED values and are never
  overwritten by completion; measured values land only in the actual columns
  (`actual_duration_minutes`, `actual_distance_miles` — both already exist — plus
  `calories_burned` and the measured HR/pace/power fields). Today's Garmin completion
  double-writes measured values into BOTH (`buildGarminCompletionUpdate` sets
  `duration_minutes` AND `actual_duration_minutes`), destroying the plan — live specimen:
  Xuan's 2026-09-10 run, whose FS planned duration is unrecoverable from the row.
  Consumers read `actual ?? planned` (the ratified two-time display rule, extended).
  Ships with the Q-INT26 capture handback.

## L-3 — Match windows `[divergence → Q-INT4]`
The ratified match key (`spec/daily-macros/platform-resolution.md`, RULED 2026-08-14) is:
(1) platform activity id, else (2) same platform + same sport + start within **±15 min** —
one definition for tombstone matching and re-sync dedup. The Garmin *planned-completion*
matcher instead searches **day-wide** on naive local bounds
(`_shared/garmin/activity_completion.ts:228-294`). Which window governs
planned-completion was pre-registered as
`intake/2026-08-18-skipped-row-sync-match-window.md` (unstamped) and is decided at Q-INT4,
in this family, once, for all providers.

## L-4 — Deletion signals `[observed + gaps]`
1. **Athlete deletes** → tombstone: `deleted_at` + `status='deleted'`; the row persists and
   the matcher MUST match against it so re-sync drops rather than re-imports
   (`activities_repository.dart:886-905`; ratified at `intraday-display.md` §4b).
2. **Provider removes** a workout (FS/TP resync no longer contains it) → the app sets
   `provider_deleted_at` only — NOT `deleted_at`, NOT `status='deleted'`
   (`activities_repository.dart:2082-2122`). What a `provider_deleted_at` row means for
   display and for the engine is nowhere stated → **Q-INT5**.
3. **Provider declares skipped** — whether a platform-declared skip is the same fact as the
   athlete's Skip press was pre-registered as
   `intake/2026-08-18-platform-declared-skip-semantics.md` (unstamped) → **Q-INT6**.
4. "Sync beats skip" (G6, ruled 2026-08-17) is already ratified and is honoured by the
   Garmin path (`activity_completion.ts:162-212`).

## L-5 — Disconnect `[divergence → Q-INT2, Q-INT3]`
1. **Imported workouts are hard-deleted** on disconnect — deliberately NOT tombstoned:
   *"a disconnect wipe must not leave status='deleted' rows around, or the matcher would
   suppress re-import when the athlete reconnects later"*
   (`connect_training_controller.dart:691-727`, rationale `:702-704`; per-row
   `activities_repository.dart:859-884`). The stated intent is strong and proposed as
   contract verbatim: *"Disconnecting removes what the provider gave us, not just the
   token"* (`:649-653`).
2. **But today three things survive** every disconnect, contradicting that stated intent:
   - the `integrations` row with `access_token`/`refresh_token` intact (soft
     `is_active=false`, `integrations_repository.dart:308-320`) — for all three providers;
   - all of `garmin_health_data` (dailies, sleeps, stress, epochs, body comp, raw
     activity payloads) — a Garmin disconnect purges workouts but no wellness;
   - the `users.weight_pounds`/`body_fat_pct` values Garmin mirrored in
     (`garmin-push/index.ts:186-249`).
   Contract for each → **Q-INT2**. **Xuan's proposed redesign (2026-09-10, intent-based):**
   the default disconnect HIDES rather than deletes — provider rows (and Garmin wellness)
   gain a hidden-by-disconnect flag: same records, excluded from display and engine, and
   REVIVED on reconnect when the same provider workout id (or `summary_id`) re-syncs.
   Tokens are cleared. A separate, explicit "also delete my synced data" choice at
   disconnect serves the removal-intent case (bad data / privacy) with a hard purge
   including wellness and the `users` mirrors. Two mechanics this requires: the hidden
   flag must be DISTINCT from `status='deleted'` — a tombstone suppresses re-import, a
   hidden row must match-and-revive, the opposite behavior; and F27 recalculation runs on
   hide/revive so totals deflate and reinflate correctly. This supersedes the current
   hard-purge code path and its "reconnect would be suppressed" rationale (which only
   holds because the tombstone was the sole hiding mechanism available).
3. **Provider-side revocation is asymmetric**: Garmin deletes the server mapping and
   verifies it (`garmin_oauth_service.dart:200-225`); TP *can* `POST /oauth/deauthorize`
   but the UI never passes `revokeAccess: true`
   (`connect_training_controller.dart:1832-1846`) so TP access is never revoked; FS has no
   revoke path at all. Garmin's own docs make deregistration an obligation ("must be called
   whenever the partner offers a Disconnect action" — `docs/integration/garmin/`); the
   Garmin-initiated `garmin-deregistration` function also fails to deactivate the
   `integrations` row despite its own header saying it should
   (`supabase/functions/garmin-deregistration/index.ts:10,86-100`) → **Q-INT3**.

## L-6 — Account deletion `[observed + divergence → Q-INT7]`
`delete-user` deletes `public.users` then the auth user; `integrations`,
`garmin_user_mappings`, `garmin_health_data`, `activities` all cascade via
`user_id REFERENCES users(id) ON DELETE CASCADE`
(`supabase/functions/delete-user/index.ts:77-87`). **Exception:** `garmin_health_data`
rows written with `user_id = NULL` (push received for an unmapped Garmin user,
`garmin-push/index.ts:298`) have no owner and never cascade — orphaned third-party health
data → **Q-INT7**.

## L-7 — Retention `[gap → Q-INT1]`
There is **no retention rule anywhere**: no TTL, no purge job, no pg_cron, no
data-minimisation statement — for `activities`, `garmin_health_data` (including verbatim
raw payloads), or deactivated `integrations` rows. The only age-based rule in the system
is Garmin body-comp **staleness** (a reading older than 30 days is never *used*:
`calculate-daily-macros*/formulas/resolve.ts:393-396`) — staleness is not retention; the
row remains. The privacy declaration (`docs/privacy/app_store_privacy_details.md`) names
no provider and no retention period. Ratify either "indefinite retention, deliberately" or
concrete windows → **Q-INT1**.

**L-7 — RULED (Xuan, 2026-09-20, post-ratification addition; corpus interview):**
Retention is now windowed for raw and permanent for the de-identified corpus:
1. **Raw provider payloads get a 90-day TTL** — `garmin_health_data` raw types
   (`activity_raw`/`activity_detail_raw`/future sample-level types) and the new
   `provider_raw_payloads` table (below). Transformed `activities` rows are unaffected.
2. **FS/TP raw IS retained** (revises the corpus intake's inline-only proposal): a separate
   server-side table — `provider_raw_payloads(user_id, provider, provider_workout_id,
   fetched_at, last_modified, data jsonb)` — fed by a phone→server upload during sync,
   **one row per (provider workout id, LastModifiedDate)** — an edited workout inserts a
   NEW versioned row rather than replacing the old (edits are rare; both corpus and
   forensics see every version); a re-fetch with an unchanged `LastModifiedDate` writes
   nothing (never one row per sync pass). *(Versioning clarified same-interview, Xuan
   2026-09-20, on qa-33's catch.)* Separate table, never a
   column on `activities`: TTL lifecycle differs, unmatched payloads must be kept, and
   the activities table syncs to devices.
3. **Sample-level `activityDetails` + HRV capture graduates to prod** under the same
   90-day TTL (extends the dev/self-consented capture of 2026-09-14).
   **AMENDED (Xuan, 2026-09-20, DI-25 halt — option B): GPS sample points are STRIPPED AT
   INGEST** — route-level location never rests on our servers, in any environment; the
   retained sample streams are the physiological curves (HR/pace/power, swim lengths),
   which is what fueling forensics uses. The corpus was already GPS-free by the de-id
   standard; this extends the same posture to the raw forensic store.
4. **The TTL purge job doubles as a TWO-SIDED meter** (second side ruled 2026-09-20,
   same interview): each sweep logs raw-table sizes and row counts to an audit table and
   ALERTS both ways —
   **over-size**: raw tables collectively exceed 2 GB or database storage exceeds 60% of
   plan (resurfaces this ruling for re-evaluation); and
   **under-arrival**: a declarative expected-flows table `(flow, precondition, min_rows,
   window)` — e.g. ≥1 `provider_raw_payloads` row per provider per 7 days given ≥1 active
   connection; ≥1 Garmin `activity_raw` per 48 h given ≥1 active Garmin athlete; once the
   casing fix ships, ≥1 populated `tss_planned` per 14 days given ≥1 exposure-observed
   athlete — fires the same alert when a flow yields zero rows in its window while its
   precondition held. This is DI-13c's populated twin ON A SCHEDULE, and the systemic fix
   for the silently-broken-sync class (`last_sync_status` lies; zero-rows-despite-active
   -connections cannot). **Deliberate exclusion:** corpus-exemplar novelty is NOT an
   arrival flow — novelty decaying to zero is the design working.
   `qa/scripts/query-ledger.sh` gains size-audit + liveness arms for on-demand reads.
   **Dead-man clause (ruled 2026-09-20):** the alert runs inside the sweep, so a dead
   scheduler silences its own alarm — the audit row's freshness is therefore watched from
   OUTSIDE the scheduler: a lightweight client-side check during sync fires a Sentry
   warning when the newest audit row is older than 48 h, and the land-bundle dev
   attestation includes observing the first real sweep row on dev.
5. **The permanent record is the de-identified corpus**: one exemplar per novel shape,
   scrubbed per the ratified standard (content destroyed, structure verbatim, timestamps
   shifted), promoted to `qa/vectors/integrations/samples/<provider>/`. Promotion runs
   NOW; the privacy-declaration line rides the next terms update rather than gating it.
   Scrubbing is server-side only; raw never leaves the server un-scrubbed.
Authority: `intake/2026-09-14-real-payload-test-corpus.md` + Addenda 1–3, Q-INT1.

## L-8 — Token custody `[divergence → Q-INT8]`
Proposed rule: **one custodian per provider** — `integrations` is the sole token store,
plaintext-in-Postgres is acknowledged and RLS on it is verified. Today:
1. Tokens live in plaintext columns of `integrations` (no secure storage;
   `integrations_table.dart:1-76`); the table exists precisely so tokens survive Drift
   resyncs (`supabase/migrations/_archived/20260506120000…sql:2-14`).
2. Garmin tokens are **duplicated** into `garmin_user_mappings` — the copy the server
   actually uses and refreshes (`garmin-backfill/index.ts:113-191`); refresh drift between
   the two stores is a known audit action (#9, `AUDIT_REPORT_2026-05-14.md`).
3. A **third, stale** FS token location exists in Supabase auth `user_metadata`, written by
   the dead `sync-final-surge` function (`supabase/functions/sync-final-surge/index.ts:277-295`
   — uncalled by any Dart code).
4. RLS on the two token-bearing tables is **unverified** (audit action #1: the schema dump
   shows full DML to `anon`; policies not rendered).

## L-9 — Cadence, triggers, and time semantics `[observed]`
1. Pull providers (FS, TP) sync via `IntegrationSyncCoordinator`: 4-hour staleness
   threshold, 5-minute failure cooldown, failures **silent** (logs only), per-provider
   in-flight dedup (`integration_sync_coordinator.dart:27-37,187-230`). Garmin is
   push-only; delivery IS the sync (`garmin-push/index.ts:1196-1246`). Last-sync time is
   tracked twice — SharedPreferences (`integration_{provider}_last_sync`) and
   `integrations.last_sync_at` — which are not the same clock (`:327-340`).
2. All provider timestamps are stored as **naive local wall-clock** (no zone suffix) —
   deliberate, with in-code rationale (`_shared/garmin/mappers.ts:51-70`, bug 3a6e3fdb);
   FS/TP workouts missing a time-of-day default to **07:00 local**
   (`final_surge_transformer.dart:316-349`, `training_peaks_transformer.dart:458-487`).
3. Garmin completion **overwrites `scheduled_date_time`** with the measured start
   (`activity_completion.ts:300-406`). **Engine day-bucketing — RULED (Xuan, 2026-09-10):**
   the engine buckets sessions by `actual_time ?? planned_time ?? scheduled_date_time`,
   matching the ratified display rule, so card-day and engine-day can never disagree
   (intake `2026-08-20-engine-session-bucketing-day-key.md`, option 1). Per-provider
   `scheduled_date_time` semantics ratified at Q-INT11.

## Explicitly NOT owned by this file
- The per-variable value ladders (F22–F27) — `spec/daily-macros/platform-resolution.md`.
- Session pricing (F3–F5) — `spec/daily-macros/session-demand.md`.
- The unknown-sport F4 fallback — `intake/2026-08-20-session-cost-unknown-activity-types.md`
  (unstamped), owned by session-demand.
- Webhook/inbound security hardening choices (Garmin header auth, SSRF) — surfaced at
  Q-INT9 for a *routing* ruling (contract clause here vs app-side engineering fix), not
  designed here.
