# data-integrations@v1 — coding-agent handoff (standing contract)

Pinned target: tag `data-integrations@v1` (commit 284566f). Authority order:
`bundles/data-integrations.yaml` → this handoff → the pinned specs. Definition of done:
the manifest's `done_when`, verbatim. Stages and gates: `docs/feature-test-plans/
data-integrations.md` (A capture → B red-first matching → C split/F4a → D disconnect+
write-back → E sim). Checklist detail: `intake/2026-09-10-handback-data-integrations.md`
+ its THREE addenda (Q-INT27 windows; **Q-INT16 AMENDED TO OPT-OUT — sharing defaults ON,
do NOT ship an opt-in flip**; design close-out incl. brick border fix + chip
applications). Implementer: Xuan's coding agent. Never push the app trunk — feature
branch; Xuan pushes.

## Deferred ledger (first version — carried forward from the manifest's excludes)
Resolves: nothing prior (v1). Carries: staged F22 BMR (→daily-macros-dashboard@v4);
Q-INT1/3/5/6/7/15 (deferred, no contracts); Q-INT28 computed-Z2 fallback (staged);
per-sample streams (dated non-capture); producer-shape payload vectors (post-Stage A);
coach athlete-detail provenance map (needs coach login).

## Verified conflict watchlist (terrain recon — each row checked this session, not recalled)

1. **Update, not greenfield.** All transformers/sync services exist and are live:
   `final_surge_sync_service.dart` (141-236 window logic), `training_peaks_sync_service.dart`
   (65-676 zones/window), `training_peaks_transformer.dart` (_inferIntensity 676-724),
   `garmin-push/index.ts`, `garmin-backfill/index.ts` (48-67 clamp), `tp_writeback_service/
   formatter.dart`, `preferences_service.dart` (`?? true`). The matching rewrite REPLACES
   earliest-first inside an existing tier — read it before touching it.
2. **Twins:** F4a + day-bucketing exist as Dart + TS pairs (D-005 discipline) — move
   together, parity suites both sides. The write-back formatter is Dart-only.
3. **Deploy-coupled surfaces:** garmin-push / garmin-backfill / upsert-user-profile edge
   fns ship separately from the app binary. Capture columns are additive-nullable so old
   clients survive; the backfill `window_days` clamp fix (90→30 for activities) must land
   server-side BEFORE the client starts requesting `activities`.
4. **Tests pinning superseded behavior (will go red — that is correct):**
   `final_surge_transformer_test.dart` asserts `durationMinutes, isNull` repeatedly (the
   deliberate-NULL producer contract — keep the contract, update assertions only where a
   ruling changed them); any matcher tests assuming earliest-first; TP sync docstring
   tests ("only imports NEW workouts") already stale vs code.
5. **Adjacent call sites:** disconnect soft-hide threads through matcher, engine queries,
   display; `resolveWorkoutCardState` + `daily_macro_service` must share the day-bucket
   (DI-12 paired assertion); zone2PaceMinPerMileProvider consumers (running/swimming
   input controllers) predate the provenance chips.
6. **Existing UI/goldens whose fate is decided:** workout card renders planner columns
   today (the mixed-pair bug DI-DEV-1) — the three NEW goldens manifests
   (`conformance/design/{workout-card-states,ftp-source-provenance,tp-writeback-consent}
   .goldens.yaml`) name every state; realize them as app golden suites against the
   ratified renderings; regeneration only ever cites a spec change. Brick card's
   solid-on-create border is ruled WRONG (D-1b) — fix, don't preserve.
7. **Producer/consumer inventory** — the data-seam table:

| Field | Producers | Shapes actually written | Existing consumers + resolution | New consumer's rule |
|---|---|---|---|---|
| `duration_minutes` | FS/TP transformers (planned); completion writes TODAY (bug class) | FS writes NULL deliberately (transformer tests assert it) — consumers derive | card display; F4 pricing; TP write-back block | L-2: NEVER overwritten by completion; consumers read `actual ?? planned` AS A PAIR with distance |
| `distance_miles` / `distance_meters` / `actual_distance_miles` | FS planned (miles); Garmin measured (meters); completion (actual_) | mixed families in one row TODAY (prod row 3beb1c3) | card "8 mi · 44 min" (mixed-pair bug); F4 duration derivation | one family per read; verified display = actual_* only |
| `scheduled_date_time` | FS/TP planned time; Garmin completion OVERWRITES with measured start (Q-INT11 ruled) | naive-local wall clock (L-9.2) — never add tz | day-bucketing; matching windows; editor | bucketing = `actual ?? planned ?? scheduled` (ruled); matcher compares instants timezone-defensively |
| `calories_burned` | Garmin activeKilocalories (BMR-embedded — staged erratum) | raw verbatim (ruled: store raw) | F22 measured rung; Active Energy sheet | keep raw; correction is @v4, NOT this bundle |
| `tss_planned/actual`, `if_planned/actual` | TP only (basic athletes: null) | NEW columns — nullable, null-tolerant (DI-13) | none yet; F22 IF ladder reads if_actual>planned | never fabricate; null ≠ 0 |
| `garmin_summary_id` / `parentSummaryId` | garmin-push; brick verification stamps parent | summary-id-less completed rows exist (upgrade tier M-3 key) | verified-state resolution; dedupe | one-row invariant M-0; provable-fact primacy M-1.3 |
| `intensity_level` | all transformers (_inferIntensity ladders §7) + manual | bucketed + raw kept (ruled) | engine; Vana `is_race` | bucketing methods are pinned in payload-usage-map §7 — do not re-derive |

   Seam tests: every stored≠recomputed seam gets producer-shaped fixtures (producer's own
   constants + wire rounding, never engine-output-on-both-sides); tolerance + log, never
   hard assert (the 2026-08-26 BEFORE-card lesson); one test through the real
   controller per write path. Prefer extracting the existing resolver over writing a
   second one — unreachability is a finding, not a license to copy.

## Baseline (step 4c answers — recorded, mostly "no")
1. Ruled numeric target? **No** — this bundle's contracts are binary (match verdicts,
   column presence, display states). 2. Measurable pre-code? The one number worth
   keeping: today's capture nulls are total (columns absent) and the mixed-pair bug is
   live in prod (row pinned in intake 3beb1c3) — both already documented; a formal bench
   corpus would measure nothing the 41 vectors don't. 3. Persuade anyone? No.
   **Decision: no bench corpus.** Read-only probes exist if wanted:
   `scripts/query-ledger.sh integrations|garmin-kcal|run-audit` (keys from workspace
   secrets file only — never inline).

## Completion steps beyond green tests
- Re-sync `$APP_ROOT/docs/ssot` as a verbatim mirror of tag `data-integrations@v1`;
  update `SSOT_SOURCE.txt` to 284566f.
- Flip test-plan rows ⬜→✅ with the pinned test file per row.
- Report conformance counts before/after (matching 0/41 → 41/41 expected; session-demand
  incl. 9 f4a; Dart design suites).
- Run the sim-explore charter (`.claude/skills/sim-explore/references/
  charter-integrations-surfaces.md`) on the dev build at Stage E.

## Design implementation: component reuse rule (Xuan, 2026-09-11 — standing)
Before building ANY widget the design slice calls for, inventory what already exists and
reuse it — never invent a parallel component:
1. Look up the app's existing component library first: `$APP_ROOT/lib/shared/widgets/`
   and the owning feature's `presentation/widgets/` — e.g. the glass surface (home-shell
   liquid-glass) IS the glass surface to use; the existing status/verified pill IS the
   pill; the workout card is extended in place, never forked.
2. Check the QA design tree for the component's contract: `spec/design/components/*.md`
   (workout-card.md is RATIFIED — the card-states work EXTENDS its data contract) and
   the ratified renderings' component usage (they compose StatusPill / WorkoutCard /
   SecondaryButton from the design system — mirror that composition in Flutter).
3. The provenance/source chip is ONE component, parameterized: FTP/CSS, Body
   Composition (D-2b), and Events (D-2c) all use the SAME chip widget with different
   sources/windows — three call sites, one implementation. Same for the stale chip and
   the tap-to-use affordance.
4. If a needed component exists but is private/coupled, EXTRACT it (that unreachability
   is a finding) — do not copy it. If a component is genuinely new, register it: one
   widget in the shared library + a stub row proposed for `spec/design/components/`,
   never an inline one-off. New visual inventions that bypass the library clutter the
   design tree and are review findings, not style choices.
