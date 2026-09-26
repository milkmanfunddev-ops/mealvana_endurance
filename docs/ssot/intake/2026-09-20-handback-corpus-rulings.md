# APP-SIDE HANDBACK — corpus/retention rulings, 2026-09-20 interview

Executor: the app coding agent, against `$APP_ROOT` (resolve via `mealvana_endurance/workspace.env`
/ `find_workspace` — never hardcode). Authority: qa branch `qa/real-payload-corpus`, this batch's
commit (see stamp refs in the three RESOLVED intake files). Inventory existing components first;
load the postgres best-practices skill before any schema work.

## 0 · Standard
- [ ] Re-sync `$APP_ROOT/docs/ssot` as a VERBATIM mirror of the qa batch commit; update
      `SSOT_SOURCE.txt` pin.
- [ ] Re-run conformance suites (deno vectors runner + Dart intraday/parity/design) and report
      the new green count.

## 1 · Retention infrastructure (L-7 ruling — the big one)
> **Do not lose at merge:** the corpus intake's Q6 was RULED **REVISED**, not as-written —
> Xuan chose the middle ground (FS/TP raw retained, 90-day window) over the inline-only
> proposal. Any doc still describing FS/TP capture as "no raw at rest" describes the
> pre-2026-09-20 design.
- [ ] **`provider_raw_payloads` table**: `user_id, provider, provider_workout_id, fetched_at,
      last_modified, data jsonb`; UNIQUE `(provider, provider_workout_id, last_modified)`; RLS
      verified; server-only (never in the phone sync set). A changed `LastModifiedDate`
      INSERTS a new versioned row (history kept — ruled A, 2026-09-20); an unchanged one
      writes nothing — never a row per sync pass. TTL applies per row.
- [ ] **Phone→server raw upload** in the FS and TP sync paths: async, never blocking sync;
      payload uploaded verbatim.
- [ ] **90-day TTL sweep** (pg_cron): purges `provider_raw_payloads` AND `garmin_health_data`
      raw types (`activity_raw`, `activity_detail_raw`, future sample types) past 90 days.
- [ ] **Two-sided meter + alert in the same job** (L-7 item 4 as amended 2026-09-20): log
      raw-table sizes AND row counts per run to a small audit table; alert (edge-function
      email pattern) on (a) over-size — raw tables collectively > 2 GB or DB > 60% of plan
      (text must say it RESURFACES the L-7 ruling) — and (b) under-arrival — any row of the
      declarative `expected_flows(flow, precondition, min_rows, window)` table yielding zero
      rows in-window while its precondition held (seed rows per L-7 item 4; corpus novelty
      deliberately NOT a flow). Preconditions read active-connection counts, never
      last_sync_status.
- [ ] **Dead-man check** (ruled 2026-09-20): during sync, if the newest sweep audit row is
      older than 48 h, fire a Sentry warning (existing Sentry wiring); land-bundle's dev
      attestation gains "first real sweep audit row observed on dev".
- [ ] **Sample-level graduation**: `garmin-push` retains full `activityDetails` (samples), HRV
      summary, per-length swim data for ALL prod athletes under a size-guarded data_type,
      subject to the same TTL (extends the 2026-09-14 dev/self capture).

## 2 · Corpus pipeline (L-7 §5)
- [ ] Server-side scrubber implementing the ratified de-id standard (content destroyed,
      structure verbatim, timestamps SHIFTED, sample arrays: cardinality+cadence kept, scalars
      fuzzed, GPS dropped).
- [ ] Fingerprint per the ratified design: three-state per-key alphabet (ABSENT/NULL/VALUE),
      strata = endpoint × WorkoutType, optional-key collapse for identity; novelty-gated,
      append-only, frozen exemplars.
- [ ] Export path → `qa/vectors/integrations/samples/<provider>/<fingerprint>.json`.
- [ ] Garmin wing: batch scan of stored raw. FS/TP wing: scrub from `provider_raw_payloads`.
- [ ] **SEQUENCING — HARD DATE:** the premium trial (athlete 6635555) expires ~2026-10-02 and
      its four specimens are the DI-13c populated-twin exemplars (they exist nowhere at rest
      today — field audits only). Land §1's raw table + one sync of the trial account BEFORE
      the trial lapses, even if the scrubber ships later; the raw row is the material.

## 3 · Q-INT29 narrowing (fabrication removal)
- [ ] Delete `_classifyIntensity`'s ≤1.5⇒%FTP and unknown-length⇒seconds default branches and
      the FS twin's equivalents; TP zone columns stay NULL; structure parser stays dormant for
      FS. The engine's zoneless default at computation time is UNCHANGED — do not touch it.

## 4 · IsPremium re-keying (A1)
- [ ] `training_peaks_sync_service.dart:757`: remove the `providerIsPremium != true` gate on
      the metrics fetch; the fetch attempts and handles the 401 gracefully (endpoint stays
      blocked-on-provider until the scope lands — see ops 2a28e4c rebirth trigger).
- [ ] `tp_writeback_service.dart:110`: eligibility keys on TP's ACTUAL write-back response,
      never on the flag; the :577 handler confirms from the response alone.
- [ ] Migration `20260911150000…sql:24` comment + `integration.dart:56` doc: re-document the
      column as "connect-time snapshot; false-negative on premium-featured trials; NEVER a
      behavioral predicate".
- [ ] Casing fix (`TSSPlanned`→accept both): ALREADY ops Critical
      (2026-09-17-…-key-casing-never-populates.md) — implement under that ticket, cite here.

## 5 · Bookkeeping
- [ ] Flip matching rows in `docs/feature-test-plans/data-integrations.md` per that plan's
      rules (incl. DI-13c populated-twin rows once §2's exemplars exist).
- [ ] Ops cross-updates: write-back bug (2026-09-18-…-ispremium-flag.md) — investigation list
      item 1 is superseded by the A1 attempt-and-observe ruling; casing bug — no change.
