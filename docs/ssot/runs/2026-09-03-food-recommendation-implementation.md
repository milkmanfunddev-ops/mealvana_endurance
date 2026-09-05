# Run report — food-recommendation@v1 implementation (2026-09-03)

Implementer: coding agent, session claude.ai/code/session_016LcwAKtBM94gzNXUcC8nW9.
Bundle: tag `food-recommendation@v1` (c902ee6, treated immutable). App branch
`feature/food-recommendation-v1` (off develop 80230b59); qa branch `qa/food-recommendation`.
Landing NOT done — separate green-gated step after Xuan's attestation.

## done_when status

| Gate | Result |
|---|---|
| `run_dart.sh food-recommendation` | GREEN — 26/26 on the Dart engine AND 26/26 on the TS engine; §8 twin differential **byte-equal on all 26 canonical selection results** (new twin arm in run_dart.sh: Dart copy-in harness → Deno runner → cmp) |
| `run_dart.sh pre-workout-food-composition` | GREEN — 87/87 (P10 runner built; new published entry point `lib/features/nutrition_plan/domain/pre_workout_food_composition.dart`) |
| `run_dart.sh create-flow-fueling-controls` | GREEN — 20 tests + 3 goldens, mirror-checked (manifest written at implementation) |
| `run_dart.sh formula-pin-surface` | GREEN — 17 tests + the 5 manifest goldens, mirror-checked. FP-4a inline warning (Choose another filled / Pin anyway outline), FP-4b collapsible dragonfruit label + conflict dot (never auto-unpinned), FP-7 S-04 emphasis chips, FP-8 save-time disclosure (Save never disabled), FP-2 wire-derivation through the real rows builder; FP-9 absent from every golden. formula_kit suite 212/212. |
| Dev attestation (Xuan) | **GIVEN 2026-09-03: "I attest for v1"** — simulator smoke of the dev flavor against the deployed dev backend (server half verified deployed independently: `solvent_min_ml` live on `template_foods`, §10 ledger columns present). **Scope limit, recorded honestly:** the attestation covers the build Xuan smoked. FOUR client commits post-date it and have run in NO build — `7418566f` (fueling-window per-activity reset, D-018), `ad3ec376` + `18a3c160` + `2c615d7d` (FP-4d personal-formula pin parity). Both are test-green (create-flow 28/28, formula_kit 216/216) but device-unverified. Carried into the landing record as such unless re-smoked. |
| Bench re-run (handoff) | DONE — step-4 share of the 23 cascade scenarios **17.4% → 13.0%** (S22 5h-bike resolved 4→3; the other three named shapes unchanged; **no 3→4 regressions**; warnings identical scenario-for-scenario). `bench/results-dev-post-implementation-20260903-1752.json` |

Regression sweep: pre-workout carbs/hydration/sodium, transition-nutrition,
brick-eligibility, during-hydration, during-sodium arms all green. Deno local
suite 86/86. App: nutrition_plan/migrations/activities 841+ green,
qa_conformance 74 green, analyzer clean.

## What was built (handoff build order)

1. **Conformance arms** — both fueling slices (engine was null): composition arm
   (copy-in Dart) + the food-recommendation twin arm exposing the SELECTION
   RESULT (window+tiers, pick+servings+delivered, allowed+reason, step,
   conflict label) with the byte-equal differential in the runner itself.
2. **Catalog v1.1** (migration 20260903120000): `solvent_min_ml`/`solvent_max_ml`
   label-derived backfills (high-carb mix 600 · carb mix/elec mix/packet/
   high-Na mix 475 · gel 150; tablet + sports_drink_mix deliberately NULL →
   250 fallback), `pre_workout_templates.single_food_sufficient`, and the
   pickle `is_liquid=true` correction (it read as "carryable" and inverted W5).
   Drift v19 mirrors `min_servings_during`/`is_indivisible`/`solvent_min_ml`.
   **Applied to dev + verified 2026-09-03; prod pending (runbook).**
3. **§4 twin port** (F-22/23/24/46/47) — one commit, both engines: symmetric
   target-seeking sodium score; ONE cap = the row's max_servings_during,
   gut-adjusted identically (low ×0.5 floor 1; high never exceeds the row);
   carryable-first within the ruled 10%-of-target tolerance (capsulePenalty
   retired); floor rescue unified on the 2026-07-29 server form; baseline =
   candidate formula; §4.5 capsule-over-salt backfill ranking.
4. **§3/§3a window authority** — sport-neutral table + early-start (<07:00
   training → 60) + clamp (≤ time-until-start, floor 15) in
   `fueling_window_authority.dart` ⇄ `fueling-window.ts`; preset mapping as
   ruled (Long ⇒ +1 row, Race Pace ⇒ race row). `recommendedHoursBefore`
   DELETED with its four call sites rewired; manual sets now cap at the clamp.
5. **§6 practicality** — solvent session-total in the pairing pass (declared
   minima per serving supersede the flat 250; drinks don't satisfy declared
   solvent; plain water counts, no double demand; pins exempt) + §6(a)
   meal-tier kernel (2× single-item cap, ≥2 components unless flagged) wired
   into the v4 meal face and the Dart before solver — whose tier boundaries
   were also repinned 120/30 (was ≥2h/≥1h, a live twin divergence).
6. **§7 fasted retirement** — tolerate-and-ignore: v4 accepts+drops is_fasted
   (400 removed; post-workout boosts gone); client toggle/state/wire deleted;
   AMENDMENT A1 applied (fuel-stat CARBS·NONE retired, F-1 narrowed to the
   pair; feeding-card `none` arm gone); fuelstat_fasted golden + manifest row
   retired same-commit citing A1; activities.is_fasted column DORMANT (W-3).
7. **§10 ledger** (migration 20260903121000): before_path / after_path /
   source (x-mealvana-test header) / during_segment_paths (fixes bench B-2);
   after-phase now stamps generation_path; verified populating on dev.
8. **Design slices** — both manifests written from the CF-/FP- rows
   (transition-card unsplit format), mirrored, suites implemented.

Final sweep (post-commit, 2026-09-03): all four arms re-run green; Deno local
suite 87/87; tree clean apart from pre-existing local iOS/pubspec edits.

Pin-surface judgment calls recorded by the implementer: FP-4b diet collapsed
line follows the allergy pattern ("Pinned despite your keto preference" — the
spec only exemplifies allergy); PersonalFormulaCard has no conflict wiring yet
(no allergen metadata pre-FP — the FP-8 component snapshot starts populating
it, follow-up candidate); FP-8 detection is fail-quiet for components added
before the snapshot existed.

## Findings & raised questions (for Xuan's ruling desk)

1. **Fasted engine branch retained** in calculatePreWorkoutCarbs/Targets (both
   engines): pre-workout-carbs@v2's FROZEN vectors pin D-001's zero path
   (fasted-180-65 + invariant 8). Product state fully retired; full branch
   removal needs a carbs-v2 vector amendment. (The tag was not edited.)
2. **during-workout-carbs arm is RED on develop — pre-existing, not this
   branch**: app commit a1b7b9ae caps band_low/band_high at the sport ceiling;
   the ratified spec caps only the rate. 3/11 vectors fail. Ruling needed
   (amend spec+vectors or revert the band half). Ops intake:
   `ops/data/bug-reports/2026-09-03-during-carb-band-caps-diverge-from-ratified-vectors.md`.
3. **W-10 brick mapping (raised, not invented)**: brick = one session — class
   from TOTAL leg duration + hardest leg's distribution; the empty-legs path
   takes the table's own <60 row (45 min) as a provisional default until legs
   carry durations. Confirm or re-rule.
4. **§4.5 needs a catalog curation act**: the ruled capsule-over-salt ranking
   is live, but the live essentials pool (legacy `foods`, is_essential) may
   contain no capsule — W6 only bites in prod once one is curated in.
5. **CF residuals**: CF-4 untested (device-permission harness + artboard owed,
   D-02); CF-6 bike/swim usual-pace chip equivalents ([design]) not yet
   mounted; CF-7 brick per-leg AUTO-badge manual-clear needs per-segment flags.
6. **Residual twin asymmetry (unruled)**: Dart still lacks the max_per_hr_*
   pool pruning (columns not in Drift) — the picker itself is now identical.
7. **Deviations D-001 / F-22-46-47 / telemetry-baseline**: D-001 closed by
   removal; the five electrolyte divergences closed by the port; the funnel
   is now measurable per §10 (distance-to-target remains the follow-on
   formula-library work).

8. **FIXED same day (commit dd8d9646, both engines, redeployed to dev)** —
   original finding below. §6(e) now binds at PICK time: declared-solvent
   candidates are only pickable up to the servings their dilution water can
   still claim; the outstanding declared deficit is a lien on the fluid
   ceiling when sizing non-plain fluid carriers; the plain-water requirement
   counts DECLARED rows only (capsules keep C2 semantics); a sub-100 ml
   declared shortfall next to plain water is accepted, not a conflict ("gels
   chase ~150"). Dart also gained the TS rounding rescue in _cappedServings
   (divergence #5 partially closed). Twin regression pair on the S29 segment
   shape (TS 25 randomized runs ⇄ Dart pool rotations). Verified live on
   dev: the mix now ships with ≥ its plain water; bench re-run
   (results-dev-post-solvent-fix-20260903-1839.json) — funnel identical
   (step-4 13.0%, no regressions; after-phase warning churn is weighted-pick
   variety in the excluded post-workout phase). Original finding:
   a step-4 rule-solver segment can still ship a concentrated mix with no
   solvent water — the solver spends the fluid band on a sports drink first,
   then the §6(e) post-pass hits the segment's water_high ceiling (101 ml
   headroom vs a 237.5 ml requirement), reports `fluid_ceiling` in the logs
   only, and ships unchanged. Pre-bundle behaviour was identical but silent
   (C2 no-opped on any drink). §6(e) likely needs to bind at PICK time (a
   feasibility filter on concentrated candidates, both engines) and/or the
   ceiling ruled soft for solvent water; conflict should reach the wire. Ops
   intake: `ops/data/bug-reports/2026-09-03-rule-solver-picks-drink-mix-with-no-solvent-headroom.md`.

## Deploy state

Dev: schema + both functions live (2026-09-03); §10 columns populating
(`source='bench'`, brick segment paths recorded). Prod: untouched. Runbook:
`ops/docs/deploys/2026-09-food-recommendation.md`.

## Post-landing find — fueling-window legibility (Xuan on-device, 2026-09-03 evening)
A session ~63 min out exposed three stacked issues: (1) the clamp-seeded stepper
propagated its off-grid offset (63→48→33) — CF-1 never ruled grid alignment and all
§3a values are grid-aligned, so no test could produce the state; (2) the clamp-bound
stepper carried no explanation — the "Capped:" caption was deferred to D-02 by the
spec itself, so the suite faithfully pinned the illegible state as correct; (3) the
RULED Q-CF1 class caption was never implemented — the manifest had no contract row
for it (manifest-writing omission), so green proved nothing about it. All three
fixed + ruled same day: CF-1/CF-2 amended, Q-CF1 row added (app 65130005, qa
5000614). Lesson recorded: rulings living in an "Open questions" table must be
lifted into contract rows at manifest writing, or they silently drop.

## v1.1 verification run (2026-09-03 21:20, coding agent)
Bundle food-recommendation@v1.1 (tag 9723fa3) re-verified on app feature/food-recommendation-v1
@ 2c615d7d — nothing remained to build; this is the point-release gate run:
- run_dart.sh: food-recommendation 28/28 (Dart 27 + Deno arm; twin differential byte-equal on
  all 26 vectors) · pre-workout-food-composition 88/88 · create-flow-fueling-controls 28/28
  (3 goldens) · formula-pin-surface 21/21 (5 goldens).
- Bench re-run `run-bench.sh dev post-implementation` (results-dev-post-implementation-
  20260903-2120.json): single-sport cascade 23 scenarios → step 3 = 20 (87.0%), step 4 = 3
  (13.0%) vs baseline 17.4% — delta unchanged from the v1 post-implementation run (dev
  functions untouched since the solvent-fix redeploy), no 3→4 regressions; brick 5, swim n/a 2.
  Corpus untouched.
- **Correction to the freeze's `device-unverified-tail` deviation:** the four post-attestation
  client commits DID run in dev-sim builds the same evening — 7418566f rode the 20:2x rebuild
  (with 7d97e95b), ad3ec376/18a3c160 the 20:5x rebuild, 2c615d7d the ~21:00 rebuild — and Xuan
  hand-smoked after each round, saying "It passes my smoke test" AFTER the final (2c615d7d)
  build, having exercised the FP-4d card/editor pin flow and the window captions directly.
  Evidence: coding-session build log (Claude session 016LcwAKtBM94gzNXUcC8nW9). The deviation
  can be retired at landing if Xuan's v1.1 attestation confirms; his explicit word is still the
  open done_when item.
