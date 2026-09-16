# Feature test plan — Data Integrations (capture · matching · custody)

- **Feature:** the `data-integrations@v1` bundle scope — the RATIFIED `spec/integrations/`
  family (ruling desk 2026-09-10) + the two daily-macros rulings that rode with it
  (F4a, day-bucketing) + the staged F22 BMR change (ships @v4, excluded here).
- **Status:** DRAFT (2026-09-10, pre-implementation; vectors landed `28a4347`)
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
| DI-1 | One physical workout = one `activities` row, whatever combination of platforms reports it | matching.md M-0 | ⬜ vectors `verify-confirm`, `brick-b5-no-double-import` + app matcher-tier suite |
| DI-2 | The plausibility guard refuses measured < 20% of planned OR < 2 min, strictly, on planned/skipped/upgrade tiers; refusal always falls to insert, never to silent drop | M-1.1 / Q-INT21 | ⬜ vectors `guard-*` (5) |
| DI-3 | A platform-keyed signal matches by plan ID with NO threshold | M-1.2 t1 | ⬜ vector `platform-keyed-no-threshold` |
| DI-4 | Late keyed evidence verifies or reverts-and-rebinds; displaced activities re-score; nothing ever prompts the user | M-1.2 t3 | ⬜ vectors `late-platform-*` |
| DI-5 | Upgrade tier reaches ONLY summary-id-less completed rows, day-wide, closest start; never a stamped row | M-3 / Q-INT24 | ⬜ vectors `upgrade-*` (5) |
| DI-6 | Brick verified ⇔ parent stamped AND all endurance legs matched; partial completes but never verifies; transitions never become rows | M-5 B-1..B-5 | ⬜ vectors `brick-*` (9) |
| DI-7 | Completion never writes into a planner column; `actual_*` only; consumers resolve `actual ?? planned` | lifecycle L-2 split | ⬜ seam test: complete a row, re-read planned fields byte-identical |
| DI-8 | Hidden-by-disconnect is a distinct state: excluded from display AND engine, revives on matching re-sync, never suppresses like a tombstone | lifecycle L-5 / Q-INT2 | ⬜ state-machine test: disconnect → hide → reconnect → revive (id-keyed) |
| DI-9 | Disconnect clears tokens from ALL stores; `integrations` is the only token custodian afterward | L-8 / Q-INT8 | ⬜ db assertion post-disconnect |
| DI-10 | No TP push without a ledger row; ledger row per push with status; default ON (opt-out, amended 2026-09-11) — the opt-out toggle takes effect immediately and the one-time notice fires exactly once per athlete | TP-5 / Q-INT16 | ⬜ ledger-gated push test + prefs default test + notice-once test |
| DI-11 | F4a: unknown sport → kcal exactly 0 + estimateFlag (never null, never a fallback rate); MOBILITY linear | session-demand F4a | ⬜ vectors `f4a-*` (9) via deno runner (comparator gains estimateFlag/legs) |
| DI-12 | Engine day == card day for every session (bucketing rule) | bucketing ruling | ⬜ paired assertion: `daily_macro_service` bucket vs `resolveWorkoutCardState` day, seeded divergent row (the ~25 kcal repro) |
| DI-13 | Every captured per-source column is nullable and null-tolerant: a provider omitting a field never errors and never fabricates | payload-usage-map + capture | ⬜ transformer tests with minimal payloads (real prod key-set variants — see run-audit finding: payload key sets vary by activity type) |
| DI-15 | Card numbers follow the state contract (verified=measured, else planned; never mixed pairs); settings values carry true provenance; no push without consent UI state matching prefs | integrations-data-display.md D-1..D-3 | ⬜ goldens/gestures manifests after Q-DID1..3 |
| DI-14 | Migrations are reversible and rehearsed: enum-casing + dead-column drops run green against a prod-schema shadow before dev deploy | Q-INT25 | ⬜ migration rehearsal protocol §4 |

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
