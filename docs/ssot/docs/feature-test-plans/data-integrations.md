# Feature test plan — Data Integrations (capture · matching · custody)

- **Feature:** the `data-integrations@v1` bundle scope — the RATIFIED `spec/integrations/`
  family (ruling desk 2026-09-10) + the two daily-macros rulings that rode with it
  (F4a, day-bucketing) + the staged F22 BMR change (ships @v4, excluded here).
- **Status:** IMPLEMENTED @v1 (2026-09-11); CORPUS/RETENTION rows DI-18..24 added 2026-09-20 (rulings bdfbc88..190948c, unimplemented; DI-16/17/13c numbering reserved on qa/data-integrations-v1.1, app feature/data-integration; red-first baseline 16/41 legacy → 41/41 both twins). Stage E sim + dev-half deploys tracked in the app runbook.
- **Source documents:** `spec/integrations/` (9 docs, RATIFIED) ·
  `vectors/integrations/matching.json` (39) · `vectors/daily-macros/session-demand.json`
  F4a rows (9) · handback `intake/2026-09-10-handback-data-integrations.md`
- **App test taxonomy:** `$APP_ROOT/docs/test/README.md`; layers per `docs/test-layering-plan.md`

## 0. Change-shape classification (what this bundle actually is)

Answering the "is this mostly schema?" question honestly, per handback section:

| Handback area | Shape | Risk | Why |
|---|---|---|---|
| Capture columns (tss/if planned+actual, parentSummaryId, IsPremium, calories, subtype/pace, unhandled push types, Metric fetch) | **additive schema + plumbing** | LOW | new nullable columns, new writes; no existing behavior changes; failure mode = nulls |
| Planned/actual split (stop double-writing) | **write-path behavior** | MEDIUM | small diff, but changes what `duration_minutes` MEANS post-completion; every consumer must read `actual ?? planned` |
| **Matching contract (M-1.2 triggers, guard, best-fit, day-wide upgrade, revert-rebind, tz)** | **ALGORITHM REWRITE** | **HIGH** | replaces earliest-first with scored selection; adds a tier that touches completed rows; adds re-matching. This is the largest code change in the bundle — edge function + Dart |
| **Brick verification (B-1..B-5, B-2′)** | **NEW ALGORITHM** | **HIGH** | sequential grouping, positional matching, parent stamping — code that has never existed |
| Disconnect soft-hide + revive | **state-machine change** | MEDIUM-HIGH | new hidden state threaded through matcher, engine queries, display; revive path |
| Write-back (default OFF, consent, ledger, block format) | UI + formatter + new table | MEDIUM | user-facing consent; delimiter fix; live coach visible (Claudia) |
| Engine: F4a + day-bucketing | **twin formula/query change** | MEDIUM | Dart + TS twins must move together (D-005 discipline); bucketing audits 4 queries |
| Hygiene batch (enums, dead columns, live migration) | schema migration | MEDIUM | touches live enum values on prod rows — rehearsal required |

**Net:** ~40% additive schema (low risk), ~60% behavioral — concentrated in matching/brick/
disconnect. "Not much algorithm work" is NOT correct; that is why 39 gate-verdict vectors
exist before a line of implementation.

Interfaces: correct — no published-interface refactor; `OfflineMacroCalculator` and the
engine functions keep their signatures; matching is an internal tier.

## 1. Invariants

| # | Invariant (testable) | Owning clause | Pinned by |
|---|---|---|---|
| DI-1 | One physical workout = one `activities` row, whatever combination of platforms reports it | matching.md M-0 | ✅ 2026-09-11 — 41/41 vectors green on BOTH twins: app `supabase/functions/_shared/garmin/matcher.test.ts` + `test/features/integrations/matching/match_decider_vectors_test.dart` |
| DI-2 | The plausibility guard refuses measured < 20% of planned OR < 2 min, strictly, on planned/skipped/upgrade tiers; refusal always falls to insert, never to silent drop | M-1.1 / Q-INT21 | ✅ 2026-09-11 — guard-* vectors green (both twins) + write-path `matcher_executor.test.ts` (refusal falls to insert, plan stays open) |
| DI-3 | A platform-keyed signal matches by plan ID with NO threshold | M-1.2 t1 | ✅ 2026-09-11 — vector green (both twins) |
| DI-4 | Late keyed evidence verifies or reverts-and-rebinds; displaced activities re-score; nothing ever prompts the user | M-1.2 t3 | ✅ 2026-09-11 — vectors green (both twins); DECISION tier only — the client rebind EXECUTOR is gated on the §7 FS completed-workout probe (runbook open item) |
| DI-5 | Upgrade tier reaches ONLY summary-id-less completed rows, day-wide, closest start; never a stamped row | M-3 / Q-INT24 | ✅ 2026-09-11 — vectors green (both twins) + atomic upgrade write test (`matcher_executor.test.ts`) |
| DI-6 | Brick verified ⇔ parent stamped AND all endurance legs matched; partial completes but never verifies; transitions never become rows | M-5 B-1..B-5 | ✅ 2026-09-11 — vectors green (both twins) + leg-stamp/fold/B-5 write tests + B-3 resolver states (`matching_stage_b_wiring_test.dart`) |
| DI-7 | Completion never writes into a planner column; `actual_*` only; consumers resolve `actual ?? planned` | lifecycle L-2 split | ✅ 2026-09-11 — `matcher_executor.test.ts` DI-7 seam (planner fields byte-identical) + `test/features/daily_macros/data_integrations_stage_c_seam_test.dart` (engine prices the measured pair) |
| DI-8 | Hidden-by-disconnect is a distinct state: excluded from display AND engine, revives on matching re-sync, never suppresses like a tombstone | lifecycle L-5 / Q-INT2 | ✅ 2026-09-11 — `test/features/integrations/disconnect_soft_hide_state_machine_test.dart` |
| DI-9 | Disconnect clears tokens from ALL stores; `integrations` is the only token custodian afterward | L-8 / Q-INT8 | ✅ 2026-09-11 — deactivate clears all token fields (same file); mapping copies stripped by migration 20260911160000; the stale user_metadata store died with sync-final-surge |
| DI-10 | No TP push without a ledger row; ledger row per push with status; default ON (opt-out, amended 2026-09-11) — the opt-out toggle takes effect immediately and the one-time notice fires exactly once per athlete | TP-5 / Q-INT16 | ✅ 2026-09-11 — `test/features/integrations/tp_writeback_di10_test.dart` (+ the consent-sheet gesture suite) |
| DI-11 | F4a: unknown sport → kcal exactly 0 + estimateFlag (never null, never a fallback rate); MOBILITY linear | session-demand F4a | ✅ 2026-09-11 — deno comparator gained legs/dominant/estimateFlag; 9/9 green + Dart twin runs the same rows (`daily_baseline_calculator_test.dart`) |
| DI-12 | Engine day == card day for every session (bucketing rule) | bucketing ruling | ✅ 2026-09-11 — `data_integrations_stage_c_seam_test.dart` (divergent row moves day on both surfaces; scheduled day no longer double-counts) |
| DI-13 | Every captured per-source column is nullable and null-tolerant: a provider omitting a field never errors and never fabricates | payload-usage-map + capture | ✅ 2026-09-11 — `test/features/integrations/data_integrations_capture_test.dart` (basic-athlete nulls, absent keys, wire-shaped payloads) |
| DI-13b | Producer payload → stored `activities` row matches the ratified field-map §2 (deliberate-NULL duration, discarded IF/TSS/zones stay null, raw kcal verbatim, measured start overwrites, brick parent linkage, unknown→other) | field-map.md §2 | ⬜ vectors `vectors/integrations/producer-shapes.json` (10, EXPECTED-RED) via `run_dart.sh producer-shapes`; oracle spec-derived, double-read; joined later by Q-INT1 de-identified real samples |
| DI-15 | Card numbers follow the state contract (verified=measured, else planned; never mixed pairs); settings values carry true provenance; no push without consent UI state matching prefs | integrations-data-display.md D-1..D-3 | ✅ 2026-09-11 — all three manifests realized: `workout_card_states_golden_test.dart`, `ftp_source_provenance_golden_test.dart`, `tp_writeback_consent_golden_test.dart` |
| DI-18 | Raw-row semantics: one row per (provider workout id, LastModifiedDate); unchanged lm re-fetch writes nothing; edit INSERTS a versioned row; TTL purges strictly-older-than-90d, per row (exactly-90.0d retained — stated convention) | lifecycle L-7 items 1–2 (RULED 2026-09-20) | ✅ 2026-09-20 — raw-retention 7/7 via run_dart.sh's new local-db arm (ephemeral supabase-local, the two app migrations applied VERBATIM, sweep driven at injected clocks; harness branch qa/real-payload-corpus-harness 3cd580e; app 57d2db55) |
| DI-19 | The sweep's meter is two-sided: audit row per run (sizes + counts); over-size alert (raw >2 GB collective / DB >60% plan) AND under-arrival alert (expected_flows row yields 0 in-window while precondition held); corpus novelty deliberately NOT a flow; preconditions never read last_sync_status | L-7 item 4 (two-sided fold 2026-09-20) | ✅ 2026-09-20 (local leg) — both-alerts scenario green in the local-db arm (arming sweep silent; under-arrival + over-size fire on one audit row; ffb51f5). Alert RECORD = the audit row (qa-70 acceptance); email delivery leg LANDED (app 2fed14df, human-confirmed received by Xuan) — runbook 2026-09-real-payload-corpus.md. OPEN REMAINDER: live liveness read via query-ledger retention after the FIRST PROD sweep |
| DI-20 | Scrubber properties: dropped keys absent; kept key set verbatim; nulls stay null (NEVER invented); fuzzed scalars differ same-type; ids synthetic with parent↔child link preserved; timestamp offsets exact post-shift; array cardinality verbatim | de-id standard (RULED as written, timestamps shifted) | ✅ 2026-09-20 — corpus-deid 3/3 via the pure-function Deno arm over _shared/corpus/scrub.ts (app 57d2db55); offset convention offsetSeconds = between[1]−between[0] recorded (handoff addendum 2) |
| DI-21 | Fingerprint identity: (endpoint × WorkoutType stratum, per-key ABSENT/NULL/VALUE:type over NON-optional keys, top-level JSON type); optional-classed keys OUT of identity entirely (ruled A 2026-09-20); NULL-vs-VALUE always splits (basic/premium) | corpus intake Addendum 2 + ruling A | ✅ 2026-09-20 — corpus-fingerprint 7/7 via the pure-function Deno arm over _shared/corpus/fingerprint.ts (app 57d2db55); cardinality-bucket convention recorded (handoff addendum 2) |
| DI-22 | Corpus export: novelty-gated, append-only, frozen exemplars; one file per fingerprint at `qa/vectors/integrations/samples/<provider>/`; an existing exemplar is edited only to correct a de-id leak | L-7 item 5 | ✅ 2026-09-20 — sampler behavioral tests 4/4 (duplicate collapse, novel split, registry respected, optional-collapse; app 38c256d3) + LIVE duplicate-run on dev (scanned 4, novel 0) + path check: exemplars at vectors/integrations/samples/training_peaks/ (qa 7c0c3fb, provenance-stamped sandbox-host + hand-typed) |
| DI-23 | No behavior keys on provider_is_premium: metrics fetch ungated (handles 401), write-back eligibility keys on TP's actual response only, column re-documented as connect-time snapshot | IsPremium ruling A1 (2026-09-20) | ✅ 2026-09-20 — five behavioral tests replacing the three gate paths (app bfceb8bf): metrics fetch attempted with flag=false, refreshPremiumEligibility writes no block state (both directions), 403 blocks with verifyNever on the profile read, success clears the block; manual_live pin flipped (f8fc94c2); intensity_distribution_test swept = not this bundle's (flips with the casing ticket) |
| DI-24 | Populated twins run LIVE against the real repository: after the trial account's first post-implementation sync, its raw rows exist in provider_raw_payloads AND their scrubbed exemplars landed; HARD DATE ~2026-10-02 (trial expiry) — after that this row is unsatisfiable for planned-load fields | DI-13c discipline applied to this bundle (13c row itself lives on qa/data-integrations-v1.1) | ✅ 2026-09-20 — populated twin OBSERVED 12 days before the hard date, via the SANDBOX premium athlete (handoff addendum 1 supersedes the trial-only framing): 4 raw rows in dev provider_raw_payloads with TssPlanned+IFPlanned numbers (field audit in runbook) AND their 4 scrubbed exemplars landed (qa 7c0c3fb). Standing leg rides the DI-19 under-arrival flow once seeded |
| DI-25 | Sample-level + HRV capture (L-7 item 3, RULED Q7): garmin-push persists full `activityDetails` (samples) size-guarded for ALL prod athletes; HRV subscription enabled + handled; both under the 90-day TTL — GPS sample points STRIPPED AT INGEST (ruled B, 2026-09-20 — routes never at rest); HRV portal action is Xuan's — TO-DO registered 2026-09-20: portal account is currently Lee's (handover or re-register); flow self-arms after subscription, no alarm meanwhile | L-7 item 3 · intake 2026-09-20-q7 | ⬜ RED (two-stage, latency visible by design): land-gate = capture code green + expected_flows seeds committed (`garmin_detail_full ≥1/48h given active Garmin athlete`; `hrv ≥1/week once subscribed`); post-land = the flows themselves prove the populated twin when a real activity arrives (real-world latency is the flow's job, never discovered-at-land) |
| DI-26 | BOTH fabricating fallback families are DELETED, not unused (qa-33 scope correction 2026-09-20): (a) `_classifyIntensity` ≤1.5⇒%FTP (`training_peaks_transformer.dart:977`) + conversational-default misuse; (b) unknown/distance length unit ⇒ `durationSeconds = lengthValue.round()` (`:899`/`:908` — a 1 km step weighed as 1000 s); + FS twins. An unparseable step makes the WHOLE structure unparseable ⇒ NULL, never a guessed bucket (DI-16's wording, which owns the assertion via v1.2; DI-16 is the pointer, e4590c1) | Q-INT29 narrowing (LANDED) | ⬜ RED: behavior tests — (a) threshold-pace-style input yields NO %FTP-derived zone; (b) a distance-length step yields NO seconds-weighted split; both ⇒ zone columns NULL, intensity via IF/TSS/title/default only |
| DI-27 | Dead-man check behaves: newest audit row older than 48h during sync ⇒ Sentry warning fired; fresh ⇒ silent | L-7 item 4 dead-man clause (LANDED, untested) | ⬜ RED: behavioral test over `raw_retention_dead_man_check.dart`, both directions |
| DI-28a | Garmin corpus wing exists: batch scan of stored DEV garmin raw promotes exemplars; `samples/garmin/` non-empty | L-7 item 5 (Garmin wing) | ⬜ RED: `samples/garmin/` contains ≥1 exemplar, leak-swept — satisfiable from dev TODAY (97 raw rows) |
| DI-28b | Multisport LINKED SET promoted coherently (C9, B-2/B-5): the exemplar whose fingerprint is novel EMBEDS the payloads its link fields reference (`linkedCompanions`, scrubbed + leak-swept to the identical standard, synthetic ids resolving WITHIN the file) — companions are context, never registry entries, so one-exemplar-per-novel-fingerprint stands unamended; reading ruled by the de-id table's own "preserving referential links between parent and children" (qa-70 interpretation 2026-09-20, revisable by Xuan) | C9 · de-id link row | ⬜ RED: `samples/garmin/` holds a MULTI_SPORT exemplar whose embedded children's `parentSummaryId` == the parent's `summaryId` (one coherent, loadable set for brick matching) — leak sweep covers companions at the same depth |
| DI-14 | Migrations are reversible and rehearsed: enum-casing + dead-column drops run green against a prod-schema shadow before dev deploy | Q-INT25 | ✅ 2026-09-11 — all four migrations (capture, token strip, ledger, Q-INT25 hygiene incl. per-casing counts 1+1→2, totals unchanged) rehearsed green on the prod-schema shadow, down + replay idempotent; NOTE: app docs/prod_schema.txt is stale (runbook item) |

## 2. Dimensions — matching triggers × row states

| Incoming ↓ / candidate → | planned | skipped | deleted | completed (no gid) | completed (gid) | hidden (disconnect) | brick parent |
|---|---|---|---|---|---|---|---|
| Garmin activity | ✅ vec ×6 | ✅ vec ×4 | ✅ vec ×5 | ✅ vec ×5 (upgrade) | ✅ vec (insert) | ⬜ revive-not-suppress | ✅ vec (B-1) |
| Garmin sequence | n/a | ⬜ open | ⬜ open | ⬜ open | n/a | ⬜ | ✅ vec ×5 (B-2′) |
| Platform keyed | ✅ vec (t1) | ⬜ keyed-beats-skip | ✅ RULED M-1.3 (2026-09-10): completion revives, plan re-import drops — vec ×2 | ✅ vec (t3) | ✅ vec (t3) | ⬜ revive | ⬜ |
| `other` sport | ✅ vec | ✅ vec | ✅ vec ×2 | ⬜ | ⬜ | ⬜ | n/a |

Open cells are current debt, tracked here rather than silent. The keyed-vs-tombstone hole
was ruled same-day (M-1.3 provable-fact primacy).

## 3. Staged rollout — each stage green-gated before the next

1. **Stage A — additive capture** (columns + transformer writes + push handlers + Metric
   fetch). No behavior change. Gate: migrations rehearsed (§4); `query-ledger.sh
   integrations`/`garmin-kcal` probes show new columns filling; existing suites stay green
   (was/expect counts reported).
2. **Stage B — harness before behavior**: build the matcher-tier runner and run the 39
   vectors RED against current code (proves the harness sees today's earliest-first
   behavior). Only then land the matching rewrite + brick path → vectors flip green.
   The red-first run is mandatory — a harness born green proves nothing.
3. **Stage C — planned/actual split + day-bucketing + F4a** (engine twins move together;
   deno + Dart parity suites; DI-7/DI-12 seam tests).
4. **Stage D — disconnect redesign + write-back** (state machine, ledger, consent UI;
   DI-8/9/10). Last because most user-facing.
5. **Stage E — sim verification**: `/qa-smoke` + `/sim-explore` on the dev build (matching
   charter: mark-done-then-sync, multi-plan day, brick separate-starts on a seeded
   athlete); Xuan's FS probe and TrainingInsightService live test ride here.

## 4. Migration rehearsal protocol (DI-14)
Dump prod schema (`docs/prod_schema.txt` refresh) → apply the full migration set to a
shadow database seeded with prod-shaped rows (both brick enum casings present, null-user
garmin rows, dual token stores) → assert row counts unchanged, enum values unified,
reads through both Drift and PostgREST → write the down-migrations and run them.
Only then dev deploy. The enum-casing migration is the one that rewrites live rows —
it gets an explicit before/after row-count assertion per casing.

## 5. Explicitly not covered here
Staged F22 BMR change (@v4, own plan when staged→active) · deferred rows Q-INT1/3/5/6/7/15
(no contracts to pin) · per-sample streams (dated non-capture decision) · producer-shape
payload vectors (follow Stage A, then join §1 as DI-15).
