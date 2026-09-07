# Feature test plan — Pre-Workout BEFORE card (math v2/v6/v3 + design family)

- **Feature:** the pre-workout BEFORE card — the engine's v2 carbs / v6 hydration / v3 sodium
  outputs (tiers, bands, the urine check) rendered through the ratified design family
  (surface `pre-workout-before-card` + components `fuel-stat` · `feeding-card` ·
  `hydration-check`). Scope = the **BEFORE** card only (surface S-G1); DURING / AFTER untouched.
  Food *suitability* (food-composition v3) is a sibling bundle and appears here only as the link
  that fills the food rows.
- **Status:** DRAFT (2026-08-26, drafted pre-freeze). **Terrain (§6, verified 2026-08-26):** the app's
  engine ALREADY implements carbs v2 / hydration v6 / sodium v3 and is green against these vectors in
  CI; what is new work is the design family (UI), the hydration-check input, and the PW-021 fold. The
  memory/branch notes that said "app implements v1 math" were stale — only the LEGACY map and the
  explanation layer still carry v1 numbers.
- **Source documents:** `spec/fueling/pre-workout-carbs.md` v2 · `pre-workout-hydration.md` v6
  (as amended by PW-021) · `pre-workout-sodium.md` v3 · `pre-workout-food-composition.md` v3 ·
  `pre-workout.notes.md` §6–§7 · `pre-workout.OPEN-QUESTIONS.md` (21 rows) · `spec/design/`
  (`surfaces/pre-workout-before-card.md`, `components/{fuel-stat,feeding-card,hydration-check}.md`,
  `tokens.md` Q-D8/Q-D9 — all RATIFIED v1, Xuan 2026-08-26) · reference rendering
  `spec/design/renderings/pre-workout@v2.html` (= `prototypes/pre-workout/v4.html`) ·
  reconciliation `docs/design-reconciliation/pre-workout-v2-vs-pre-workout.md` · vectors
  `vectors/fueling/pre-workout-{carbs 19, hydration 21, sodium 8, food-composition 87}.json` ·
  design manifests `conformance/design/pre-workout-before-card.{goldens 18, gestures 17}.yaml` ·
  bundles `pre-workout-macros@v1` (2026-08-04, to be superseded) and
  `pre-workout-food-composition@v1`.
- **App test taxonomy:** `$APP_ROOT/docs/test/README.md`; layers per `docs/test-layering-plan.md`
  (cheapest layer that executes the link for real wins).

## 0. Dimensions (the matrix the chains alone would miss — `docs/test-plan-dimensions.md` pattern)

Axes that change behaviour on this surface: **lead time at plan creation** (`timeBeforeWorkoutMin`
— the five membership scenarios) × **target state** (targets set / gated / fasted) × **hydration
answer** (NONE / PALE / DARK / NOT_YET / NOT_SURE) × **delivered vs target** (below / in / above).
Every cell is a manifest id or an explicit open.

| Contract | ≥ 2 h (3 h, 2 h 15) | 30 min – 2 h (90 min) | < 30 min (20 min) | t = 0 (start line) |
|---|---|---|---|---|
| Feeding membership (B-2) | goldens `before_3h_targets_set`, `before_2h15_meal_15min_window` | `before_90min` | `before_20min` | `before_start_line` (0 g card KEPT, FC-4) |
| Hydration check present | ✅ contract: present, all four answers (`h2_*`) | ✅ absent (`h_suppressed_below_2h`, `before_90min`) | absent (same test) | absent (same test) |
| Hydration check × **gated** fluid | **OPEN — owned by NONE (I5)** | n/a (absent) | n/a | n/a |
| Hydration check × **fasted** | contract implied (fasted card = fluid only, FC-4) — no manifest id, **add** | n/a | n/a | n/a |
| Carbs band | cited `[1·BW, 4·BW]` (`fs_two_markers`) | ±12.5 % design band | ±12.5 % | `[0,0]` suppressed (`fs_three_no_number_states`) |
| Fluids band | `[5·BW, 12·BW]`, check-independent (`h2_answer_writes_target`) | `[0, min(10·BW, ceiling)]` | same | same; M-2 no low-signal |
| Delivered out of band | `fs_fluid_one_way_carbs_two_way` | same test | same | carbs `[0,0]`: is 1 g delivered "above ceiling" (M-2 alarm) when the band is suppressed? **OPEN — no doc says; fold into the I11 erratum as a question** |
| Fine print `?` | **deferred S-G4** (all columns) | deferred | deferred | deferred |

## 1. Invariants

| # | Invariant (one sentence, testable) | Owning document | Pinned by |
|---|---|---|---|
| I1 | **Cross-spec pin:** `pre-workout-carbs.TIER_MEAL_MIN == pre-workout-hydration.T_REF == 120`; the engine asserts it at build time and fails loudly, never derives one from the other | carbs inv. 10 · hydration inv. 10 | ✅ app: `lib/features/nutrition_plan/data/offline_macro_calculator.dart:1368-1393` (const-ctor `_CrossSpecPin` + `assertCrossSpecPin()`), `test/qa_conformance/pre_workout_carbs_conformance_test.dart` ("cross-spec pin" group, CI), TS twin `supabase/functions/generate-macros-v4/pre-workout.ts:168-172` (module-load throw) |
| I2 | **Only `fluidMl` moves on a hydration answer.** `fluidLowMl`, `fluidHighMl`, `tiers[]` structure, `regime`, every carb figure and sodium are byte-identical across all four answers at the same `t`/`BW`; the engine is pure w.r.t. `hydrationCheck` (same inputs → same outputs, no clock, no call-order) | hydration inv. 8b + *The urine check* · design H-4 · surface B-3 | ⬜ vectors `pre-workout-hydration.json` (band-identity triple) + manifest `h2_answer_writes_target`, `s_answer_propagates` |
| I3 | **`null` ≠ `0` everywhere.** Gate → `fluidMl/Low/High: null`, `tiers: []`, `regime: gated`, `targetBasis: none`; sodium → `null` in every tier and on the gate path, never `0`; `fluidLowMl = 0` (not null) below `T_REF`; fasted → carbs `0` + `tiers: []` + `targetBasis: none`. The surface renders the three "no number" states as three distinct trees (F-1) | hydration inv. 11 + *Outputs* · sodium inv. 1–2 · carbs inv. 8 · fuel-stat F-1 | ⬜ vectors (gate ×2, sodium ×8, fasted characterization) + manifest `fs_three_no_number_states` + goldens `fuelstat_gated`, `fuelstat_fasted`, `before_start_line` |
| I4 | **Every displayed quantity traces to a named engine field; the surface invents no arithmetic.** Delivered = Σ over feeding rows (B-1); target/band = `carbsG`/`carbsLowG`/`carbsHighG`, `fluidMl`/`fluidLowMl`/`fluidHighMl`; sodium delivered only; oz is a display unit over ml (`round(ml/29.5735)`; band ends floor/ceil) | surface B-5 · fuel-stat *Traceability* + M-5 · R-01 (reconciliation §4, RULED) | ⬜ `s_delivered_is_surface_sum` + an oz-conversion golden (R-01 names 487.5 ml → 16 oz, 756 ml → 26 oz — **no manifest id yet, add**) |
| I5 | **Hydration check × gated fluid is unspecified.** On a `≥ 2 h` plan whose fluid is gated (`fluidMl: null`, `regime: gated`), does the check render, and what would a DARK answer add `4·BW` *to*? The check spec conditions existence only on `timeBeforeWorkoutMin >= T_REF`; the surface's gated golden says "carbs + feedings intact" and is silent on the check row | **NONE** — needs a ruling (proposed: suppress the check when `regime == gated`; a target that is "not stated" cannot be raised) | ⬜ — blocked on ruling; then a suppression negative test + a `fuelstat_gated` golden note |
| I6 | **Feeding membership and the check's availability depend only on `timeBeforeWorkoutMin` captured at plan creation — never on the wall clock.** No "NOW"/"PASSED"/live styling; identical render at any system time | surface B-2 / S-G2 · PW-021 · hydration-check *When it exists at all* | ⬜ manifest `h_no_live_clock` (run at two injected clock values) |
| I7 | **Delivered-out-of-band signalling is one-way for fluid, two-way for carbs**, and the *suggested* marker sitting on a band end is not an alarm | fuel-stat M-2, M-3 | ⬜ manifests `fs_fluid_one_way_carbs_two_way`, `fs_two_markers`; golden `fuelstat_fluid_overshoot` |
| I8 | **No basis signifier renders** (`targetBasis` stays engine data, still emitted and still traced) — no caption, no dashed rail, bands visually identical across `evidenced_band` / `design_choice` | fuel-stat M-4 (RULED) | ⬜ manifest `fs_no_basis_signifier` |
| I9 | **Undo symmetry of the check:** Change answer reverts the target to its pre-answer value **and** removes the tagged water row; nothing else changes | hydration-check H-3/H-4 | ⬜ manifest `h3_change_answer_reverts` |
| I10 | **The hydration answer, food-row edits and added rows survive a relaunch and a sync round-trip** (the plan is "computed at least twice"; what persists between the two computations, and under which row/column, is the durability link) | **NONE** — hydration v6 owns engine purity, hydration-check explicitly claims *no persistence contract*, feeding-card FC-G2 owns only the in-frame write | ⬜ — needs a spec home (proposed: a §"Persistence" row on the surface spec, or the app-side data SSOT) — see §6 producer inventory for the columns |
| I11 | **Carb display rounding is contradictory across documents:** notes §6 says "carbohydrate rounds to 5 g"; fuel-stat M-5 (ratified later, 2026-08-26) says "carbs to the gram on this surface" and the reference rendering shows whole grams (52 g, 43 g) | **TWO OWNERS DISAGREE** — erratum against notes §6 (the design ruling is newer and ratified) unless Xuan prefers 5 g | ⬜ — file as intake erratum; pin with an oz/g rounding golden once ruled |
| I12 | **The engine never rounds; rounding is presentational and introduces no visible jump** — `t` on the 15-min grid produces monotone displayed figures | carbs/hydration *Outputs are exact* · notes §6 · fuel-stat M-5 | ⬜ unit test over the 17-point grid (display layer), vectors for the engine |

**Seed-question findings:**
- **Durability — OWNED BY NONE (I10).** Three writes happen on this surface (answer, stepper,
  add-row) and no document says where they land or that they survive. The hydration-check spec
  says outright "no persistence contract is claimed here". This is the same class of hole that
  the macro-dashboard plan found for `planned_time`/`actual_time`.
- **Navigation — OWNED BY NONE, accepted as out of scope.** The design surface owns composition
  only; where the BEFORE card lives (plan detail? dashboard sheet?) and where back lands is the
  *host* screen's contract. Not a hole in this family, but the host surface has no design SSOT yet
  — record, don't pin here.
- **Symmetry — OWNED BY NONE:** FC-7 "+ Add Food" appends a row; **no gesture removes a row**
  (swipe? stepper to 0?). Every add implies its remove. Also: a user who steps the tagged water row
  (DARK copy says "adjust it like any other item") and then taps Change answer — is the *edited*
  row removed (H-4 says "removes the added water row")? Propose: yes, the tag governs, and the
  spec should say so.
- **Attribution — owned:** the added water row carries "added by hydration check" (hydration-check
  state table, FC-6). ✓
- **Identity — owned by the app's data model, not this family:** the plan is
  `activities.nutrition_plan_data` (see §6); edits must be written under the same activity id the
  card reads. Row added to the producer/consumer inventory.
- **Contracts spanning files:** the T_REF/TIER_MEAL_MIN pin (I1) and the shared
  `timeBeforeWorkoutMin` field ("the two specs MUST read one field", carbs *Inputs*) — pinned by I1
  and by the producer inventory row for lead time.
- **Stale prose (errata, not holes):** notes §6 still says "Stop offering it once the snack window
  closes" and "the urine cue rides with the number, in every tier" — both superseded by PW-021
  (athlete-timed; sub-2 h cue in the fine print). Notes §6 also says "Honour `renderAs`" while
  carbs v2 says "No `renderAs`" (the light-meal threshold is now feeding-card FC-1). File one
  erratum covering all three with I11.

## 2. Chains

### Chain: the plan is computed

`activity inputs (BW, lead, duration, tempC, isFasted, gutTolerance, hydrationCheck=unknown) → calculatePreWorkoutTargets (carbs v2) + calculatePreWorkoutHydration (hydration v6, sodium fields v3) → {carbsG, band, tiers[], targetBasis} + {fluidMl, band, tiers[], regime, gateTriggered, sodium null} → persisted plan → card`

| Link | Failure mode it can hide | Owning doc | Cheapest layer | Pinned by |
|---|---|---|---|---|
| inputs → engine (weight, lead, duration, temp) | stale/fallback weight (`?? 70`-class), 480-min lead outside the ratified grid (D-016), swim water temp ignored, `tempC` null → 22 | carbs/hydration *Inputs* · PW-011 · intake `2026-08-25-pre-workout-fluid-gate-thresholds.md` (adjacent) | contract | ⬜ — producer inventory §6; seam round-trip test |
| carbs math | any of inv. 1–11 regressing; tier boundary steps smoothed; floor reintroduced | carbs v2 | unit | ✅ app: `test/qa_conformance/pre_workout_carbs_conformance_test.dart` (19 vectors + property sweep over the 17-point grid × BW 30–160; CI gate `codemagic.yaml:57`) + TS `generate-macros-v4/pre-workout-vectors.test.ts`. **QA's own `conformance/pre_workout_carbs_conformance_test.dart` still calls the legacy `calculatePreWorkoutTargets` — §6.2** |
| hydration math | gate → `0` not `null`; anchor A `high = 10·BW` (the v5 error); dark step missing; clearance bound outside top-off | hydration v6 | unit | ✅ app: `test/qa_conformance/pre_workout_hydration_conformance_test.dart` (21 vectors + inv. 1–5, 8, 8a, 8b, 9, 11 property sweep; CI) + TS twin. **QA's own harness does not compile — §6.2, intake 2026-08-25 erratum** |
| sodium fields | any number emitted; the LEGACY map's 300/450/600 mg leaking into the card (PW-012 — §6.3) | sodium v3 | unit | ✅ app: `test/qa_conformance/pre_workout_sodium_conformance_test.dart` (8 vectors, null-only; CI). ⬜ for the *card*: nothing yet proves the BEFORE card reads v3's `null` and not the legacy `sodium_mg` |
| cross-spec pin | constants drift apart | carbs inv. 10 / hydration inv. 10 | unit (build-time) | ✅ (I1) |
| engine → persisted plan | `tier` integer still written; `gateTriggered`/`regime`/`tiers` dropped in serialization; old clients mis-render new integers (PW-013) | hydration *Outputs* (`tier` RETIRED) · PW-013 | payload-invariant | ⬜ — serialization vectors wanted (§3) |
| fasted path | zeros vs `null`; card shows a carb figure | D-001 (characterization) · carbs inv. 8 · FC-4 | unit + golden | ⬜ vector `fasted-*` (characterization) + golden `fuelstat_fasted` |

### Chain: the card renders the plan (membership, figures, bands)

`persisted plan → feeding membership by t (B-2) → per-tier feeding cards (FC-1 naming, FC-2 delivered header, window labels) → three fuel-stats (figure = Σ rows, band = engine, markers M-1) → tokens`

| Link | Failure mode it can hide | Owning doc | Cheapest layer | Pinned by |
|---|---|---|---|---|
| t → which feedings exist | membership from a clock; a snack-window card missing at t = 30 exactly; top-off dropped at t = 0 | surface B-2 · carbs inv. 6 | widget | ⬜ goldens `before_*` ×5 + `h_no_live_clock` |
| tier grams → card title | "Pre-Workout Snack" hardcoded; light-meal flip at the wrong threshold; MEAL renamed | feeding-card FC-1 (`LIGHT_MEAL_G_PER_KG·BW`) | widget | ⬜ `fc_naming_threshold`; goldens `feeding_snack_light_meal` |
| t → window label | "(15 MIN WINDOW)" absent at 2 h 15; "NOW UNTIL…" variants wrong when the first feeding is the snack/top-off | feeding-card *Tier × title × window label* | widget | ⬜ golden `before_2h15_meal_15min_window`; **the "NOW UNTIL 30 MIN OUT" / "NOW" variants have no manifest id — add** |
| rows → header delivered | header shows the aim, or a DONE/AIM pair (superseded F-07) | feeding-card FC-2 (RULED) | widget (negative) | ⬜ `fc_header_delivered_only` |
| rows → summary delivered | one stat re-totals, another doesn't; stale frame | surface B-1 | widget | ⬜ `s_delivered_is_surface_sum` |
| engine band → rail + markers | single marker; delivered marker pinned at a band end alarmed (M-3); sodium banded | fuel-stat M-1/M-3/F-2 | widget + golden | ⬜ `fs_two_markers`, `fs_sodium_never_banded`; goldens `fuelstat_*` |
| targetBasis → nothing | a caption or dashed rail creeps back | fuel-stat M-4 | widget (negative) | ⬜ `fs_no_basis_signifier` |
| ml → oz | 25-ml rounding shown as jumps; band ends rounded inward | R-01 (ruled) · M-5 — **notes §6 not yet folded (F-13 debt)** | unit | ⬜ (I4 golden to add) |
| colour meaning | teal on daily intake; magenta on anything but overshoot/destructive | tokens Q-D8/Q-D9 | golden | ⬜ goldens (token-resolved) |

### Chain: the hydration check individualises the target

`≥ 2 h plan → check row (first row of SNACK) collapsed TO-DO → expand → answer → hydrationCheck value (PALE/NOT_SURE→pale/unknown, DARK/NOT_YET→dark) → engine recompute (pure) → fluidMl +4·BW on dark → surface re-totals FLUIDS stat + inserts tagged water row unless covered → result line → Change answer reverts`

| Link | Failure mode it can hide | Owning doc | Cheapest layer | Pinned by |
|---|---|---|---|---|
| plan t ≥ 120 → row exists | control shown on a 90-min plan; hidden on 2 h 15; existence read from a clock | hydration-check *When it exists* · PW-021 | widget (negative) | ⬜ `h_suppressed_below_2h`, golden `before_90min` |
| chip → expanded | navigation instead of in-place expand | H-1 | widget | ⬜ `h1_expand`; golden `check_expanded` |
| four labels → three engine values | NOT_YET mapped to pale; NOT_SURE to dark | hydration-check state table · hydration v6 check table | unit (map) | ⬜ `h2_answer_writes_target` (map assertions) |
| answer → recompute → target | delivered moved instead of target (the F-01 inversion); band moves; carbs touched | hydration algorithm · inv. 8b · H-4 | widget + unit | ⬜ `h2_answer_writes_target`; vectors (dark step = `4·BW`) |
| new target vs delivered → row or no row | row added when already covered; sports-drink branch resurrected (R-02 deleted it) | hydration-check "already covered" · hydration *What `fluidMl` means* 2 · R-02 | widget | ⬜ `h2_already_covered` |
| emission → whole-card update | summary repainted by the component; two frames | H-5 · surface B-3 | widget | ⬜ `s_answer_propagates` |
| result copy | "25 oz" hardcoded (must interpolate `round(fluidMl/29.5735)`); caveat without "choose Not sure" | hydration-check *Copy register* | unit (string) | ⬜ `s_copy_registers` |
| Change answer → revert | target reverts but the row stays (or vice-versa); an *edited* tagged row survives | H-3/H-4 — **edited-row case owned by NONE (symmetry finding)** | widget | ⬜ `h3_change_answer_reverts` (+ the edited-row case once ruled) |
| answer → persisted `hydrationCheck` | answer lost on relaunch; plan regenerated with `unknown` after the athlete answered | **NONE** (I10) | db-flow | ⬜ blocked on I10 |
| check on a gated plan | `null + 4·BW`; a check that changes nothing | **NONE** (I5) | widget (negative) | ⬜ blocked on I5 |

### Chain: the athlete edits the plan

`expanded feeding → ± stepper (clamped to the row's cap/step) or + Add Food → row quantity/new row → delivered re-total (header + stat, same frame) → aim unchanged → out-of-band signalling per M-2 → persisted edit`

| Link | Failure mode it can hide | Owning doc | Cheapest layer | Pinned by |
|---|---|---|---|---|
| stepper → row quantity | cap/step ignored; chews step 1 not 0.5 | feeding-card FC-5/FC-G2 | widget | ⬜ (no manifest id names the clamp — `fc_header_delivered_only` covers the figure only; **add** `fc_stepper_clamp`) |
| row change → delivered only, aim fixed | the plan re-solves (H6 gap-fill) instead of reporting — F-14's question, answered by FC-G2 "does not move the aim" | feeding-card FC-G2 · surface B-1 | widget | ⬜ `s_delivered_is_surface_sum`, `fc_header_delivered_only` |
| + Add Food → what may be added | a food the composition SSOT rejects for the tier (fat/fibre gates; > 8 % drink in the top-off; zero-carb top-off) | food-composition v3 (sibling bundle, **no engine yet**) | contract | ⬜ vectors `pre-workout-food-composition.json` (87) — runner ⬜ (that bundle's task) |
| row removal | **no remove gesture specified** | **NONE** (symmetry finding) | widget | ⬜ blocked on ruling |
| sodium per row → delivered mg | sodium compared to a target; "helps retain" copy quantified | sodium v3 inv. 4 + *What is still produced* · FC-5 | widget + string | ⬜ `fs_sodium_never_banded` |
| edit → persisted plan → re-render | edits lost on relaunch; a sync overwrites the athlete's edit with a regenerated plan | **NONE** (I10) | db-flow | ⬜ blocked on I10 |

### Chain: fine print (deferred, S-G4 — recorded so the deferral is explicit)

`? control → "About these numbers" → notes §7 paragraphs verbatim`

| Link | Failure mode it can hide | Owning doc | Cheapest layer | Pinned by |
|---|---|---|---|---|
| `?` suppressed this iteration | control shipped inert (F-05 class) instead of absent | surface S-G4 | widget (negative) | ⬜ — no manifest id for "the `?` is ABSENT"; **add** `s_fine_print_absent` for this iteration, retire when B-4 goes live |
| `?` → §7 copy verbatim | paraphrased copy; missing the "aim for the number, not the ceiling" paragraph | surface B-4 · notes §7 | unit (string) | deferred (`s_copy_registers` fine-print clause, golden `before_fine_print`) |

## 3. Vectors wanted

| Contract | Vector file (in `vectors/`) | Consumed by |
|---|---|---|
| Carbs v2 (inv. 1–11, grid, boundaries) | ✅ `fueling/pre-workout-carbs.json` (19) | ✅ app `test/qa_conformance/pre_workout_carbs_conformance_test.dart` + TS `pre-workout-vectors.test.ts`; QA's `conformance/*.dart` copy stale (§6.2) |
| Hydration v6 (anchors, 8b band identity, clearance, gate) | ✅ `fueling/pre-workout-hydration.json` (21) | ✅ app `test/qa_conformance/pre_workout_hydration_conformance_test.dart` + TS; QA's copy does not compile (§6.2) |
| Sodium v3 (null ×3, never 0) | ✅ `fueling/pre-workout-sodium.json` (8) | ✅ app `test/qa_conformance/pre_workout_sodium_conformance_test.dart` + TS |
| Food suitability gates | ✅ `fueling/pre-workout-food-composition.json` (87) | ⬜ no runner, no engine (sibling bundle) |
| Goldens + gestures | ✅ `conformance/design/pre-workout-before-card.{goldens,gestures}.yaml` | app test tree ⬜ |
| **Plan serialization** (engine output → persisted `nutrition_plan_data` JSON incl. `tiers[]`, `regime`, `gateTriggered`, `targetBasis`, `hydrationCheckUsed`, **no `tier` int**) | ⬜ | payload-invariant tests; the PW-013 release-order guard |
| **Display rounding** (ml → oz target/band; g → g) — R-01 pairs: 487.5 → 16 oz, 756 → 26 oz; band `[floor, ceil]` | ⬜ (blocked on I11 for carbs) | display-layer unit test |
| **Four answers → three `hydrationCheck` values → `fluidMl`** (63 kg: 16 → 25 oz) | partly ✅ (hydration vectors carry pale/dark/unknown at `t ≥ 120`) — the label→value map is design-side | `h2_answer_writes_target` |

## 4. Known-unpinnable

- **Whether the athlete actually times the check "about two hours out"** — PW-021 traded the
  predicate for copy; by design nothing in the app can verify compliance. `/sim-explore` free play
  only.
- **Pixel fidelity beyond the goldens' pinned environment** — the port-prompt side-by-side owns it
  (source-authority §3.5–3.7).
- **Real `tempC` provenance** (weather vs pool) until the adjacent intake question is ruled.

## 5. Standing rules — status for this feature

*Drafted 2026-08-26, pre-freeze. No audit yet.* **Last audit:** ⬜ (never).

1. Every bug found after generation gets a row at the layer that should have caught it.
2. A test that cannot run is not a test — the QA-repo hydration harness is the standing example
   (§6.2). ✅ rows above cite the **app's** `test/qa_conformance/*`, which runs in the CI gate; the
   QA-side `run_dart.sh` path is red until §6.9 item 8 is done.
3. Audit on demand via `qa-test-plan`'s audit verb.
4. Verified-on-device is not pinned.
5. **Bundle coupling:** this plan pins nothing until the superseding bundle is tagged; rows that
   cite vectors resolve against that tag, not against `pre-workout-macros@v1`.

## 6. Terrain recon & conflict watchlist (stage 6b — verified against `$APP_ROOT` 2026-08-26, branch `feature/brick-on-macro-dashboard` @ `00fc59bd`, read-only)

**Headline: this is an UPDATE of a build whose ENGINE already implements the ratified math, and a
GREENFIELD build of the design family.** `flutter test test/qa_conformance` → **74/74 passed**
(2026-08-26) against a vector mirror byte-identical to `qa/vectors/fueling/pre-workout-*.json`.
Verify, don't rebuild, the engine; build the UI.

### 6.1 Update-vs-greenfield

| Piece | State | Where |
|---|---|---|
| Carbs v2 engine | **implemented** | `lib/features/nutrition_plan/data/offline_macro_calculator.dart:185-279` (`calculatePreWorkoutCarbs`, `_carbTier`; constants `:117-165` match the spec) |
| Hydration v6 + sodium v3 engine | **implemented** | `offline_macro_calculator.dart:1417-1545` (`calculatePreWorkoutHydration`); gate `:1431-1445` returns `null`/`[]`/`gated`/`none`; sodium permanently `null` `:1948-1953`; `k = 3.2/60` computed |
| Cross-spec pin | **implemented three ways** | `:1368-1393`, `:2025-2030` (const ctor), TS `pre-workout.ts:168-172` |
| `hydrationCheck` plumbing | **engine, wire, domain, server echo exist; NO producer** | param `:1422` (default `unknown`); `macro_repository.dart:173-178` does not pass it; echo `macro_generation_service.dart:790-791`; `HydrationCheck.fromWire` `:1876`. **No widget sets it — the hydration-check component is the new input.** |
| PW-021 (no live clock) | engine already frozen-lead (`offline_macro_calculator.dart:1413-1416` "MUST reuse the original value") | nothing to undo — the old `offerCheck` predicate was never built |
| BEFORE card UI | **OLD UI** — `before_phase_widget.dart` (523 L) with ctor `carbs/sodium/fluids + Low/High + *Overridden` | `lib/features/nutrition_plan/presentation/widgets/activity_detail/before_phase_widget.dart`, `macro_summary_row.dart` (`round5`/`round25` `:125-126`), `time_slot_row.dart`, `section_subtitle_widget.dart:50-51`; embedded by `nutrition_sections_builder.dart:206-212` → `activity_detail_screen.dart:601` and `brick_nutrition_sections.dart:229-231` |
| Feeding labels | partly built: `pre_workout_feeding_labels.dart` (`preWorkoutFeedingTitle` — **Pre-Run / Pre-Ride / Pre-Workout by sport**; `preWorkoutWindowLabel`) | **Conflict with FC-1:** the ratified MEAL title is "Pre-Run Meal" *always*; the code varies it by sport. Either the design spec is silently run-specific (raise via intake) or the sport variant is retired. Flag, don't decide. |
| Display rounding | built for ml/g: `pre_workout_display_rounding.dart` (`round25/floor25/ceil25/round5/roundFluidBand/roundCarbBand`) | **R-01 (fl oz) and M-5 (whole grams) are NOT implemented** — the existing helpers encode notes §6's 25 ml / 5 g rules. This is the I11 conflict in code form |
| Goldens / design manifests | **none for pre-workout** (13 PNGs, all macro-dashboard/daily-macros/meal-logging); `docs/ssot/conformance/design/` holds only the macro-dashboard manifests; `docs/ssot/spec/design/components/` has only `workout-card.md`, `energy-card.md` | mirror re-sync must bring `pre-workout-before-card.{goldens,gestures}.yaml` + the three component specs + surface + `renderings/pre-workout@v2.html` |
| Design-system components already exist | `FuelItem`, `FuelStep`, `PhaseCard`, `MacroStat`, `HeroNumber`, `StackedBar` in `ds-bundle/` (`_ds_sync.json` renderHashes) | port onto these; `/design-sync` (source-authority §3.5–3.7) is the fidelity loop |

### 6.2 Tests pinning superseded behaviour / harness state

1. **QA-repo harnesses are the broken half** (intake `2026-08-25-hydration-slice-stale-v1.md` confirmed):
   `qa/conformance/pre_workout_hydration_conformance_test.dart` and `..._sodium_...` reference the
   retired `out.tier` and use `int` helpers against `double?`/`int?` fields → **do not compile**;
   `qa/conformance/pre_workout_carbs_conformance_test.dart` compiles but calls the **legacy**
   `calculatePreWorkoutTargets(weightKg:, hoursBefore:)`. `run_dart.sh` (which reads
   `$QA_ROOT/vectors/...`) therefore fails for all three slices. **The trustworthy copies are
   `$APP_ROOT/test/qa_conformance/*` — the land-bundle gate must run those, or the QA copies must be
   replaced by them (verbatim) before ship.** `docs/ssot/conformance/*` mirrors the broken QA copies.
2. **Legacy-map tests pin v1 numbers deliberately:** `test/features/nutrition_plan/data/offline_macro_calculator_pre_workout_legacy_map_test.dart`,
   `pre_workout_hydration_tier_test.dart`, `pre_workout_windows_test.dart`. They pin
   `calculatePreWorkoutTargets` (§6.3) — they stay green *correctly* until that map is retired; do not
   read their green as the card's contract.
3. **Widget tests that will go red by design when the old UI is replaced:**
   `test/features/nutrition_plan/presentation/widgets/before_phase_collapsed_chips_test.dart`,
   `pre_workout_feeding_labels_test.dart` (sport-varying titles — see FC-1 conflict),
   `test/seeded_tests/nutrition_plan_content_test.dart`. Replace deliberately, citing the design spec.
4. **Layering-plan row disagrees with the tiers:** `docs/test-layering-plan.md:36` asserts H5
   occasion bands at "≤ 30 / 30–90 / ≥ 90" min; ratified tiers are 30 / 120. Patrol
   `integration_test/flows/recommendation_stacking_flow_test.dart` (branch `qa/patrol-recommendation-h5-stacking`)
   should be checked for the 90-min boundary.
5. **`docs/test/README.md` does not list `test/qa_conformance/` or `test/contracts/`** — stale;
   both run in CI (`codemagic.yaml:57` runs all of `test/` minus `integration || e2e` tags).

### 6.3 Twin implementations & the second engine in the same file

- **Dart ⇄ TS twin:** `supabase/functions/generate-macros-v4/pre-workout.ts` (constants `:137-163`
  identical; pinned by `pre-workout-vectors.test.ts` loading `docs/ssot/vectors/fueling/`, tol 1e-3;
  `run-algorithm-tests.sh` `QUARANTINE=()` empty). Parity is enforced today — keep it: any vector
  regeneration must land in the mirror for **both** harnesses.
- **The LEGACY int map `calculatePreWorkoutTargets` (`offline_macro_calculator.dart:316-470`) is
  a live second pre-workout engine**: protein/fat/**water 6.5 / 5.5 ml/kg / 250 ml flat** and
  **sodium 300/450/600 (+100 hot) split meal/snack/top-up** with bands [200,2000]/[100,1000]/[0,400]
  — PW-012's number. `_computeOfflineMacros` (`macro_generation_service.dart:648-…`) reaches it on
  every edge-call failure, with **no UI marker that the offline engine produced the plan**. A
  BEFORE card that reads `sodium_mg` from the plan reads *this*. Rule for the coding agent: the
  card's sodium is Σ food rows (FC-5, sodium v3 inv. 4) — never the plan's `sodium_mg`; and the
  legacy map's `water_ml` must not feed the FLUIDS stat.
- **A second, silent derivation to EXTRACT, not copy:** `macro_explanation_service.explanations.dart:14-23`
  back-derives `hoursBeforeEst` from carbs/weight and branches at **2.5 h / 1.0 h** (v1
  thresholds); `fluid.dart:147,172-173` hard-codes 7.5 ml/kg and [5,12] narrative;
  `fluid.dart:82` infers the gate as `isTier3 && durationMin < 60 && tempC < 30` instead of reading
  `gateTriggered` (PW-013 note). The explanation layer must consume `tiers[]`/`regime`/`gateTriggered`
  from the engine result, not re-derive.

### 6.4 Deploy-coupled API surfaces & runtime coexistence with installed versions

- **Dual wire shapes are intentionally live (PW-013):** `macro_generation_service.dart:772-775`
  accepts `pre_run_hydration_regime` (string) **and** the retired `pre_run_hydration_tier` (int),
  parsed in `lib/features/nutrition_plan/domain/pre_run_macros_wire.dart`; the edge function still
  emits the retired tier (`ca28f04a` "keep emitting the retired hydration tier"). Do not collapse
  until every installed client reads `regime` — there is **no feature flag and no min-version bump
  tied to this** (the only gates are `app_config.min_app_version` / `current_schema_version`,
  `app_database.dart:281` `schemaVersion => 18`).
- **Edge functions the pre-workout path calls:** `generate-macros-v4` (`macro_generation_service.dart:541`,
  `brick_macro_service.dart:88`), `generate-nutrition-plan-v3` (food explosion for the BEFORE
  phase — `nutrition_plan_service.dart:395`). Wire keys read `:769-791`: `pre_run_water_{low,high}_ml`,
  `pre_run_hydration_regime`, `pre_run_{fluid,carb}_target_basis`, `pre_run_{fluid,carb}_tiers`,
  `pre_run_hydration_check_used`, `pre_run_selections`.
- **The `hydrationCheck` recompute has no wire path.** The answer must reach the engine twice
  (I2/I10): offline via `macro_repository.dart:173-178` (add the param) and server-side via
  `generate-macros-v4` (a request field does not exist yet). Either the recompute is client-only
  (offline engine — fine, the engine is the authority per the file header `:5-26`) or the request
  gains a field and both deploy together. **Decide and write it down before coding (I10).**
- **Schema:** no migration is needed for the engine outputs (they live in `activities.nutrition_plan_data`
  JSON), but **the hydration answer, added water row and stepper edits have no column or JSON key
  today** — the durability hole (I10) is also a schema task.

### 6.5 Adjacent call sites the rulings touch

- **Brick:** `brick_nutrition_sections.dart:229-231` embeds the same BEFORE widget; H10 says a brick
  has one shared Before. D-004a (brick fluids ml labelled oz) lives on the brick macro-summary. The
  new fuel-stat's oz conversion (R-01) must be applied once, at the component, so the brick path
  cannot re-label ml. Brick eligibility itself is the open `intake/2026-08-26-brick-eligibility-logic-ssot.md`.
- **Formula kit's "before card"** (`formula_kit/presentation/widgets/before_formula_card.dart`,
  `formula_library_screen.dart:527`) is a *different* surface — untouched; do not port the design
  family onto it by name-match.
- **Fueling-window stepper (D-016 / PW-011):** `fueling_window_clamp_test.dart` exists — verify the
  cap is 240 on all tabs and persisted 300–480 values clamp on load.
- **Explanation drawers** (`macro_explanation_service.*`) — §6.3; and `docs/ssot/PRE-WORKOUT-BUNDLE-DIGEST.md`
  §5 owns the display-rounding rules the Dart cites → superseded by R-01/M-5 once I11 is ruled.

### 6.6 Fate of existing UI / goldens

Replace `before_phase_widget.dart` + `macro_summary_row.dart` + `time_slot_row.dart` with the three
components + surface; the old widgets have **no goldens to retire**. `pre_workout_display_rounding.dart`
is superseded (oz + whole-gram rules) — retire, don't extend, once I11 is ruled. Bless 18 new goldens
from the manifest (`before_fine_print` deferred, S-G4).

### 6.7 Mirror & ledger

`docs/ssot/SSOT_SOURCE.txt` pins pre-workout at `pre-workout-food-composition@v1 @ fe31443b`,
branch `qa/pre-workout-drawers`. Verified 2026-08-26: vectors ×4 IDENTICAL; `pre-workout-carbs.md`,
`-sodium.md`, `-food-composition.md`, `.notes.md` IDENTICAL; **`pre-workout-hydration.md` and
`pre-workout.OPEN-QUESTIONS.md` DIFFER** (PW-021 fold not yet synced); design family absent. The
mirrored spec headers still say "code implements v1" — that is the *QA* text being stale (the
engine is v2/v6/v3): **fix in qa, then re-sync; never app-side** (VERBATIM policy). Re-pin
`SSOT_SOURCE.txt` to the new bundle tag at handback.

### 6.8 Producer / consumer inventory — every domain field the BEFORE card reads

| Field | Producers (shape actually written) | Consumers today & how each resolves it | This surface's rule | Finding |
|---|---|---|---|---|
| `bodyWeightKg` | profile lb→kg (`daily_macro_service.dart:164-172`, factor `0.453592`; `macro_repository.dart:169` inline `0.45359237`); persisted `weight_kg` **deliberately null when unknown** (`daily_macro_targets_repository.dart:219`) | engine (required); `dashboard_assembler.dart:60-71` **absent ⇒ absent number** (the 2026-08-20 ruling); **`macro_generation_service.dart:652` `?? 70.0` (offline plan path)**; `athlete_detail_controller.dart:281` hardcoded 70; `nutrition_targets_help_bottom_sheet.dart:260` 70 | absent weight ⇒ no plan numbers, loudly (macro-dashboard I7 precedent) | **DEFECT-CLASS: `?? 70.0` at `:652` is the same bug fixed on the dashboard, unfixed on the plan path** — every offline plan for a weight-less athlete is a 70-kg plan. Two lb→kg factors coexist |
| `timeBeforeWorkoutMin` | `activities.time_before_minutes` (`activity_mapper.dart:119/459/534`); stepper 0–**480** (D-016) | engine (frozen at generation `:1413-1416`); wire as `hours_before` (`:284`) and `time_before_min` (`:365/444`); **`?? 2.0` h fallback `:653-654`**; explanation layer back-derives it (§6.3) | the ONE field both specs read; grid 0–240 | 480 cap (PW-011); a silent 2 h default; one field, three wire spellings |
| `workoutDurationMin` | imports (`final_surge_transformer.dart:362-394` `PlannedTime` then `ActualTime`, clamp 1–1440), `vdot_transformer.dart:77-81`, manual entry | engine gate (`< 60`) and cited-window (`>= 60`) legs | as spec | `< 60 AND tempC < 30` gates 29 % of prod plans — PW-003 ruling request pending |
| `tempC` | weather (`get-weather-forecast`) or null → engine default 22; `activities.swimming_water_temp_c` recorded and **unused** | engine gate only | as spec | which temperature for swims (intake adjacent item) |
| `isFasted` | fasted toggle (`fasted_toggle.dart`; swimming forces off) | engine short-circuit (D-001, characterization) | FC-4 fasted card | unratified (D-001) |
| `gutTolerance` | profile | carbs input (composition only) | n/a on this card | — |
| `hydrationCheck` | **NOBODY** | engine default `unknown`; echo `pre_run_hydration_check_used` | hydration-check component writes it | **greenfield producer; no column (I10)** |
| plan output (`tiers[]`, bands, `regime`, `gateTriggered`, `targetBasis`) | engine → `nutrition_plan_data` JSON via wire keys (§6.4) | `pre_run_macros_wire.dart`; **`macro_repository.dart:210` `fluidsMl: preHydration.fluidMl ?? 0`** — the gate's `null` collapses to `0` at the domain boundary; only `hydrationRegime`/`isHydrationGated` distinguish | fuel-stat F-1: gate ≠ 0 | **DEFECT-CLASS: any fuel-stat reading `fluidsMl` alone renders "0 oz" for a gated plan (the coach-complaint class)** |
| sport | activity type | `pre_workout_feeding_labels.dart:25-42` (title by sport) | FC-1: "Pre-Run Meal" always | conflict, see §6.1 |
| food rows (name, carbs, sodium, step/cap) | `generate-nutrition-plan-v3` explosion + `pre-workout-scoring.ts`; catalog has **no fibre field** (food-composition bundle note) | old BEFORE widget | FC-5 observation; Σ = delivered | composition gates unenforceable without fibre (sibling bundle) |
| sweat rate / sodium concentration / IF / timezone | various (`settings_controller.dart`, `user_preferences.dart`) | during-workout only; legacy map reads `sweatSodiumCat` for its sodium | **not inputs** to this card | confirm the card never reads them |
| user edits (stepper, add row), added water row, answer | **NOBODY** | — | FC-G2 / FC-7 / H-2 | **no column, no key — I10** |

### 6.9 Conflict watchlist (mandatory handoff section — carry verbatim into `ship-bundle`)

1. **Engine: verify, don't rebuild.** 74/74 in `test/qa_conformance/` on 2026-08-26. Add `hydrationCheck` to `macro_repository.dart:173-178`; nothing else in the engine changes.
2. **Fix the two boundary collapses before any UI reads them:** `macro_repository.dart:210` (`fluidMl ?? 0`) and `macro_generation_service.dart:652` (`?? 70.0`). Both are the class the dashboard already fixed.
3. **Never read `sodium_mg` / `water_ml` from the legacy map into the card.** Sodium = Σ rows; fluid = v6 `fluidMl`.
4. **FC-1 title vs sport-varying titles** — raise via intake if the run-only title is not intended.
5. **Rounding:** implement R-01 (oz) + M-5 (whole g); retire `pre_workout_display_rounding.dart`; **I11 (notes §6 5 g vs M-5 1 g) must be ruled first.**
6. **Check × gated plan (I5) and persistence (I10) must be ruled/written before the hydration-check write path is coded.**
7. **Do not collapse the dual wire shapes** (PW-013) without a coordinated deploy.
8. **Replace the QA-repo conformance harnesses with the app's `test/qa_conformance/*` (verbatim) or point `run_dart.sh` at them** — otherwise land-bundle's gate cannot run.
9. **Old widget tests go red by design** (§6.2 item 3) — replace citing the design spec; regenerate nothing (no goldens exist); bless 17 (18 − deferred).
10. **Mirror:** re-sync hydration spec + OPEN-QUESTIONS (PW-021), the design family, both manifests; fix the "code implements v1" headers in qa first.
