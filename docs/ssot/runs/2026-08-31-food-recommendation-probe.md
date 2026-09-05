# Food-Recommendation Probe — findings register

**Branch:** `qa/food-recommendation` · **Plan:** `docs/food-recommendation-probe-plan.md`
**App under probe:** develop @ d72d43c9 via read-only worktree `$MV_ROOT/.qa-probe-develop` (detached)
**Started:** 2026-08-31

Tags: S1 twin-engines · S2 face-overwrite · S3 standalone-powder · S4 catalog-data ·
S5 electrolyte-form-scoring · S6 unscaled-capsules · P10/P13/P17/P18 carried · NEW · MAP (not a defect)

| F# | Tag | Finding | Evidence | Status |
|----|-----|---------|----------|--------|
| F-1 | MAP | `generate-nutrition-plan-v3` is NOT legacy — it is the live food-plan generator. Client flow: v4 computes macro targets (`macro_generation_service.dart:563`, `brick_macro_service.dart:88`) → targets passed in v3 payload (`macro_targets` key) → v3 picks foods (`nutrition_plan_service.dart:396`, 90s timeout, 2 retries). `macro_targets.dart:42`: v3 "kept aligned to V4 ranges". v4 ALSO has food-pick code (pickdrink/pickelectrolyte/fallback-foods tests) — ownership split TBD | worktree file:line cites | OPEN — map v4's food role |
| F-2 | MAP | v3 during-phase is post-refactor clean (2026-07-21): one pool loaded once → personal-formula pin → template solver → rule solver → single closing pass (`finalizeDuringFoods`); LP tier deleted for during. Under-target ⇒ `shortfalls` populated. Spaghetti risk concentrates in before-phase (Algorithm C transform + explosion/reconcile/substitution) and brick-handler | `generate-nutrition-plan-v3/during-phase.ts:1-30` | mapped |
| F-3 | MAP | v3 index: phase validation vs targets is NON-FATAL (warnings only) — out-of-band plans ship to the client by design. This is the mechanism that let P13's 44 oz reach the screen | `index.ts:328-380` | mapped |
| F-4 | NEW/MAP | `plan_generation_log` DB ledger records targets-vs-delivered per plan (best-effort insert). Direct measurement source for S6 sodium-shortfall rates on dev — query before simming | `plan-generation-log.ts`, `index.ts:478` | OPEN — query dev DB |
| F-5 | S5 | Electrolyte scoring mechanically prefers liquid sodium (pickle juice) over capsules at higher targets: dry `supplement` sources take a progressive penalty above 2 servings (+0.05/serving) AND a hard cap of 4 (`MAX_SUPPLEMENT_SERVINGS`); liquids take neither. Also max TWO electrolyte items per fill (two-pass). Design choice, never ratified → ruling-needed candidate | `_shared/nutrition/during-utils.ts:352,410-415,447-530` | CONFIRMED in code — sim-reproduce |
| F-6 | S1 | Documented past twin divergence: Deno scored sodium undershoot floor-relative until 2026-07-29 while Dart mirror (`client_during_phase_solver.dart _pickBestElectrolyte`) "has always used the target". Fixed now, but proves S1 class is real; differential harness must cover electrolyte pick tie-breaks | `during-utils.ts:392-399` comment | class CONFIRMED (historical) |
| F-7 | S6 | During-phase sodium CAN scale capsules (candidates ×1..4) — an on-screen during-sodium shortfall therefore needs >4-capsule targets, an empty/filtered pool, ceiling conflicts, or lives in a DIFFERENT phase (before/brick). S6 root cause not yet located — check before-phase + brick next | `during-utils.ts` | OPEN |
| F-8 | P17 ROOT CAUSE | Fasted-with-foods traced: v4 `selectPreWorkoutFoods` skips only on `targets.meal_type==='fasted'` (`pre-workout.ts:1277`); v3's skip guard `noPreFuelTargets` needs ALL four targets ≤0 (`before-phase.ts:187-197`) but fasted plans keep water/sodium >0 → proceeds; v3 rebuilds meal_type with `isFasted = carbs≤0 && water≤0` (`before-phase.ts:139`) → water>0 ⇒ NOT fasted; then `scoreFormula` clamps ideal servings (0) UP to `min_servings` (`pre-workout-scoring.ts:96-99`) → food ships at zero carb target. Three stacked causes; fix direction depends on D-001 ruling | file:line cites in worktree @ d72d43c9 | CONFIRMED in code — sim-reproduce pending |
| F-9 | P18/S4 | Portion clamp EXISTS in code (`[min_servings,max_servings]`, `pre-workout-scoring.ts:96-99`); ×6.5 oatmeal therefore means the oatmeal template row's `max_servings ≥ 6.5` — catalog data, not missing code. Fluid rides `fluid_ml × servings` off the same row, so P18's 44 oz = bad `fluid_ml` × bad `max_servings`. DB audit will pull the actual row | code + P18 evidence | OPEN — confirm row values in dev DB |
| F-10 | S6 | Pre-workout Pass 3 (`pickElectrolyte`, `pre-workout.ts:1034`) adds AT MOST ONE electrolyte selection, servings bounded by the template row's `[min_servings,max_servings]`; no second source pass (unlike during's two-pass `fillElectrolytes`). A sodium gap larger than one template's max ⇒ reported shortfall while "more capsules" is arithmetically possible. Catalog max_servings values decide severity — audit | code cites | OPEN — needs catalog values |
| F-11 | S2 | `input.pre_run_selections` (client-supplied) bypasses Algorithm C wholesale in v3 (`before-phase.ts:210-215`) — if the client forwards v4's selections, food selection runs in v4 AND could run again in v3 with different pools; trace who populates it | `before-phase.ts` | OPEN — trace client |
| F-12 | S6 RELOCATED | Pre-workout electrolytes CANNOT be recommended at all: `loadPreWorkoutElectrolytePool()` returns `[]` by ruling (Lee 2026-08-06, sodium SSOT v3 — no pre-workout sodium target; engine action `none`). Pass 3 is inert in prod. Any observed pre-workout "sodium failure" is unfixable by capsule-scaling BY DESIGN — but the solver still carries numeric sodium internally (`solver_targets`) and trims overage vs sodium_high. Xuan's S6 observations must therefore be during-phase (capped: 2 sources, ≤4 caps) or brick. Verify which surface he saw | `ingredient-pools.ts:20-30,138-144` | OPEN — locate the observed surface |
| F-13 | S3 CONFIRMED | Water-pairing invariant covers ELECTROLYTE items only (`is_electrolyte` / supplement+sodium / timing_category), never carb drink mixes. A dry carb powder (fluid_ml=0, not electrolyte) ships standalone with no water row — nobody chews drink mix. Conversely a mix row with as-prepared fluid_ml>0 self-satisfies pairing AND counts as delivered fluid (P13/H6 family). Both catalog conventions produce a defect ⇒ needs a catalog-convention RULING (dry vs as-prepared) + pairing scope extension to powders | `electrolyte-water-pairing.ts:1-60` | CONFIRMED in code — ruling-request to draft |

## Catalog audit (source: v3 `fixtures/catalog-snapshot-dev.json`, dev DB snapshot 2026-07-21 — re-confirm against live DB)

| F# | Tag | Finding | Evidence | Status |
|----|-----|---------|----------|--------|
| F-14 | S4/S1 | EVERY numeric field in `template_foods` arrives as a STRING (`carbs_g: "27.0"`) — consistent with Postgres `numeric` columns via PostgREST. TS multiplication coerces silently but any `+` concatenates; Dart parsing differs by construction. A whole class of silent type-coercion divergence between the twins | snapshot rows; verify live API returns strings | RESOLVED 2026-08-31: live PostgREST returns real JSON numbers — strings are a snapshot-capture artifact. Residual: `during-invariant-real-catalog.test.ts` consumes string numerics prod never sees (test-fidelity note only) |
| F-15 | S4 CONFIRMED | "As-prepared" fluid baked into DRY supplement/mix rows: `electrolyte_tablet` fl=475ml (a TABLET), `electrolyte_packet` 480, `electrolyte_drink_mix` 500, `high_sodium_electrolyte_mix` 480, `carb_drink_mix` 500, `high_carb_drink_mix` 600, `oatmeal` 200 (= P18's 6.8oz/serving; ×6.5 = 44oz ✓ arithmetic closes). Code explicitly assumes the opposite: `pre-workout.ts:1080` "Electrolytes have 0 fluid_ml — they dissolve in the drink" | snapshot + P18 evidence | CONFIRMED LIVE 2026-08-31 (electrolyte_tablet fl=475, carb_drink_mix fl=500, oatmeal fl=200) |
| F-16 | S3/S4 | Convention is INCONSISTENT within one catalog: `sports_drink_mix` fl=0 (dry) vs `carb_drink_mix` fl=500 (as-prepared); `electrolyte_capsule` fl=0 vs `electrolyte_tablet` fl=475. Consequences: fl>15 rows DEFEAT the water-pairing pass (self-satisfying → tablet ships with no water row) and overcount delivered fluid (P13); fl=0 non-electrolyte powders (`sports_drink_mix`, elec=False) are INVISIBLE to the pairing pass → dry powder ships standalone (Xuan's S3 exactly) | snapshot vs `electrolyte-water-pairing.ts` epsilon=15ml | CONFIRMED LIVE 2026-08-31 (sports_drink_mix fl=0 vs carb_drink_mix fl=500; capsule fl=0 vs tablet fl=475) |
| F-17 | S5 ROOT CAUSE | Pickle-juice-over-capsules is the scoring's arithmetic: undershoot of target is penalized, overshoot below the CEILING is FREE (penalty only above sodium_upper), and dry supplements take the >2-servings capsule penalty. `pickle_juice_shot` Na=940 one-shot lands near target at zero penalty; `electrolyte_capsule` Na=190 needs ×4-5 (undershoot at cap + 0.10 capsule penalty). Big-hit liquids win structurally. Note `pickle_juice_shot` is itself `is_liquid=False, product_type=supplement` so it ALSO takes the capsule penalty >2 — but never needs >1 serving | `during-utils.ts` scoring + snapshot rows | CONFIRMED mechanically — sim-reproduce |
| F-18 | S6 | Capsule scaling caps in data: `electrolyte_capsule` maxD=8 topup=True; `electrolyte_tablet` maxD=12 topup=True; but `electrolyte_packet` topup=False, `electrolyte_drink_mix` topup=False (excluded from sodium top-up per `isSodiumTopUpFood` unless flag) and during fill picks ≤2 sources with supplement candidates hard-capped at 4 servings (`MAX_SUPPLEMENT_SERVINGS=4` < maxD=8!) — code cap tighter than data cap; 2×4×190=1520mg max from capsules via two-pass | code + snapshot | CONFIRMED — quantify vs targets in sim |
| F-19 | S4 | `oatmeal` row maxB=4 in `template_foods` — but P18 observed ×6.5, so the ×6.5 clamp came from the `pre_workout_templates` FORMULA row (different table, not in this snapshot), or scaling elsewhere. Need the pre_workout_templates row for the oatmeal meal formula | snapshot + P18 | OPEN — fetch pre_workout_templates |
| F-20 | P18 | Live dev DB today: standalone `Oatmeal` template ACTIVE (max_servings=3, 27g, fluid 200ml, window 2–4h) alongside new composed v3 formulas (`Oatmeal + Banana + Honey` max 2). Composition-v3 migrations only added/dropped specific rows — standalone Oatmeal survives. ×6.5 exceeds today's max=3: either (a) pin bypass (`bypassScaleClamp`) on the 2026-08-26 sim athlete, or (b) the row's max_servings was larger on 2026-08-26 (archived seed had a 15 cap). Explosion multiplies only (`selectionToFoodResults`); reconcile only trims. Sim reproduction decides | live PostgREST query + migrations + explosion/reconcile reads | OPEN — reproduce on sim |
| F-21 | MAP | Live dev DB reachable read-only from qa via `.env.dev.local` anon key + PostgREST — full Phase-2 audit can run against LIVE rows, not just the 2026-07-21 snapshot | query transcript | mapped |

## Twin diff — electrolyte pick (`during-utils.ts pickBestElectrolyte` ⇄ `client_during_phase_solver.dart _pickBestElectrolyte`)

| F# | Tag | Finding | Evidence | Status |
|----|-----|---------|----------|--------|
| F-22 | S6 ROOT CAUSE + S1 LIVE | Server still enforces `MAX_SUPPLEMENT_SERVINGS = 4` on dry supplements (`during-utils.ts:352-380`); the Dart twin REMOVED that synthetic ceiling as a bug fix (bug 3abe3fdb — "used to stop the top-up below the range floor even when more capsules were allowed", `client_during_phase_solver.dart:294-299`) and uses the food's gut-adjusted max (capsule maxD=8). The fix landed in ONE twin only. Server plans cap capsules at 4 (760mg via electrolyte_capsule) even when the catalog allows 8 — Xuan's "why not just more capsules" exactly | both files + catalog maxD | CONFIRMED — needs erratum/handback: port fix to TS (and a differential vector) |
| F-23 | S1 LIVE | Baseline score divergence: TS baseline weights sodium overshoot ×2 (`during-utils.ts:356-358`); Dart baseline omits the ×2 (`client_during_phase_solver.dart:270-273`) though both candidate scores use ×2. The accept/reject threshold (`best.score < baselineScore`) differs between twins when current sodium is above upper | both files | CONFIRMED — differential vector |
| F-24 | S1 LIVE | Candidate-cap divergence: Dart caps electrolyte servings by `_maxServingsForGut` (gut-level-adjusted); TS `getServingCandidates` uses raw `[min,max_servings]` with NO gut adjustment for electrolytes (`during-utils.ts:276-289`) | both files | CONFIRMED — differential vector |
| F-25 | MAP/S2 | Brick transition phase (T1/T2): template-0 with HARDCODED 60-min synthetic duration → LP solver (deleted from during, alive here; maxFoodItems=3, maxServingsCap=2) → greedy. Matches the brick branch's 3-gels candidate mechanisms (qa/brick-transition-nutrition 05d0cf4) — mechanism shared, observation owned by that branch | `brick-handler.ts:165-320` | cross-ref to brick branch |
| F-26 | BLOCKED | `plan_generation_log` (real targets-vs-delivered rates for S6) needs service-role read — anon RLS returns empty and the auto-mode classifier blocked local service-key use. Ask Xuan: run the query via dashboard, or approve the key for one read | — | BLOCKED on Xuan |

## Sim session 2026-08-31 (dev app on iPhone 17 sim, ravi@test.com 73kg gluten+dairy, develop-era build; PROBE- rows)

| F# | Tag | Finding | Evidence | Status |
|----|-----|---------|----------|--------|
| F-27 | NEW | Quick-create defaults a NULL user pace to 4:30/mi (world-record pace): 24mi → 1h48m duration; every downstream number (burn 2821kcal, during targets, fueling window) inherits the absurd duration | `sim/12-plan.png`; users.default_running_pace_min_per_mile IS NULL | CONFIRMED on sim |
| F-28 | NEW ROOT CAUSE | Marathon plan gets NO MEAL PHASE: `recommendedHoursBefore(running, easy-ish, 108min)` ≈ 1.5h (`meal_type.dart:42-67`) < 2h meal threshold → v4 activates [snack, top_up] only. A 24-mi run's pre-workout = "Banana ×3 + gel + coconut water". Fueling-window recommendation is UNRATIFIED client logic feeding the ratified tier engine | stored plan subPhases=[snack,top_up]; carbsTarget 82.5/27.5 = 110g snack-tier (1.5g/kg✓) | CONFIRMED on sim — ruling-request |
| F-29 | NEW | "3 Bananas" as the snack: correct greedy pick from the allergen-filtered snack pool (Banana maxS=3 27g beats Applesauce 11g/Rice Cake) — single-food ×3 quality question belongs to the food-recommendation ratification (same family as P18 portion caps) | live template query + card | CONFIRMED |
| F-30 | NEW | Card displays "NOW UNTIL 30 MIN OUT" while stored data says timing '2H TO 30 MIN OUT' — display layer rewrites feeding timing; also slot header 16oz vs banana's actual 9oz (P14 re-confirmed on current build) | `sim/14-15.png` vs stored plan JSON | CONFIRMED |
| F-31 | NEW | Ephemeral default-formula decision emitted as `used_pin: true` (`pinned_template_name: "Banana", pin_set_size: 0, ephemeral: true`) — wire semantics claim a pin was used when none exists; any consumer reading `used_pin` without checking `ephemeral` shows a false pin banner | stored plan pinDecision | CONFIRMED in data — check UI consumers |
| F-32 | MAP | Adjust-screen shows TARGETS (110g/16oz/— sodium) while the before-card header shows DELIVERED sums (115g/18oz/305mg incl. coconut-water sodium against a null target) — two adjacent surfaces, two semantics, no labeling | `sim/12` vs `sim/13` | CONFIRMED — spec/design question |

## Sim findings batch 2 (evidence: `runs/2026-08-31-food-recommendation-probe/*.png`)

| F# | Tag | Finding | Evidence | Status |
|----|-----|---------|----------|--------|
| F-33 | P18 REPRODUCED | Pinned Oatmeal meal formula honored for GLUTEN-ALLERGIC Ravi at ×3.5 servings (row max_servings=3) — "Oatmeal (½ cup dry) · 94g carbs · 24 oz" — pin override bypasses BOTH the allergen filter and the scale clamp (locked Formula Kit policy). The 2026-08-26 ×6.5 was the same mechanism at a larger carb target. Allergen bypass by pins is a SAFETY ruling question | `23.png` (Meal—Oatmeal honored), `25.png` (3.5 stepper, 94g·24oz) | REPRODUCED — ruling-request |
| F-34 | P17 REPRODUCED | Fasted 1h plan: "No carbs this session" header + "Pre-Workout Snack: Applesauce Pouch" ships anyway — F-8's triple mechanism live on develop | `33.png` `34.png` | REPRODUCED |
| F-35 | S6/F-22 LIVE | 4h run, during sodium target 2628mg: fill = 1 stick High-Sodium Electrolyte Mix (1000mg, one shot, zero penalty — F-17's big-hit arithmetic live; same class as pickle juice) + 2 capsules. Server picked big-hit item over capsule scaling exactly as predicted | `27.png` | CONFIRMED on sim |
| F-36 | S4/P13 LIVE | During fluid total 109oz COUNTS the electrolyte mix's phantom as-prepared 480ml — athlete actually drinks 93oz; 16oz of the "delivered" fluid is imaginary (catalog convention F-15/F-16 reaching the screen) | `27.png` + catalog rows | CONFIRMED on sim |
| F-37 | NEW | "10 cups Sports Drink" (2.4L) as a during row — no portability/carry-limit concept in selection; recommendation-quality question for ratification | `27.png` | CONFIRMED |
| F-38 | NEW | Pre-workout schedule not clamped to time-until-workout: plan 1h11m ahead renders "Pre-Run Meal — FINISH BY 2H OUT" (already in the past); fueling window (2h15m) silently exceeds available time | `24.png` | CONFIRMED |
| F-39 | P14 LIVE | Slot-header fluid ≠ row fluid in BOTH directions: snack header 16oz vs banana 9oz; meal header 19oz vs oatmeal row 24oz | `15.png` `25.png` | RE-CONFIRMED |
| F-40 | NEW | Pin banner copy: "1 honored · 4 skipped" where the 4 are scopes with NO pin ("No pin found" rows) — "skipped" misstates reality | `23.png` | CONFIRMED |
| F-41 | S3 LIVE | "0.5 packets Carb Drink Mix" during 1h fasted-day run and "0.5 servings Sports Drink Mix" at brick T1 — dry powders recommended as-is; sports_drink_mix (fl=0, elec=False) invisible to water pairing | `34.png` `43.png` | CONFIRMED on sim |
| F-42 | S4 | Half-unit servings of practically-indivisible items: "0.5 Energy Gels" at T1, "0.5 Bananas" post — catalog marks gel/banana divisible (is_indivisible=false); you cannot re-cork half a gel | `43.png` `44.png` | CONFIRMED — catalog fix |
| F-43 | NEW/BRICK | Brick post-workout fluid target 3150ml (band 2520–3780) while AFTER delivers ~324ml with NO water row — delivered ≈10% of floor, shipped via non-fatal validation; the 4-item after-template ignores the fluid target entirely. Also T1 sodium delivered 297 vs 248 target rendered without band context | `41.png` `44.png` + stored brick JSON | CONFIRMED — split: target math (brick branch) vs delivery (this branch) |
| F-44 | MAP | Run+Run brick offered and generated — CONFORMS to spec/domain/brick.md v1 R2 (same-sport allowed, ratified 2026-08-31). Not a defect | `38-39.png` | conforms |
| F-45 | NEW | Ravi's server-side pins invisible locally: local `formula_pins` table EMPTY while the plan honors a server pin ("1 honored") — pin state has no local mirror to audit; also two planned activities accepted at the identical timestamp with no conflict surfacing | DB query + `23.png` | CONFIRMED — minor |

---

## Session close-out (2026-08-31, overnight)

**Build:** dev-flavor app on iPhone 17 sim (develop-era build; code probed at develop @ d72d43c9 via worktree). **Account:** ravi@test.com (73kg, gluten+dairy, moderate gut, average sweat; carries a server-side Oatmeal meal pin). **Probe rows:** all deleted in-app and verified (`status=deleted`) — brick deleted first (legs restored), then all three activities.

### Verdicts vs the six suspected shapes
| Shape | Verdict |
|---|---|
| S1 twin engines | CONFIRMED LIVE — 3 divergences in the electrolyte pick alone (F-22/23/24); ops bug filed |
| S2 face overwrite | Largely retired for during (post-refactor); real residuals: v4-vs-v3 dual compute of before phase (F-11), brick T1 synthetic duration + LP (F-25) |
| S3 standalone powder | CONFIRMED code + sim (F-13/41); gated on the catalog-fluid ruling |
| S4 catalog data | CONFIRMED LIVE (F-15/16/42); phantom fluid reached the screen (F-36) |
| S5 pickle juice | CONFIRMED — scoring arithmetic, big-hit class reproduced as 1000mg mix (F-17/35); ruling filed |
| S6 sodium unfixed | ROOT CAUSE — server-only 4-cap, Dart already fixed (F-22); pre-workout electrolytes off BY RULING (F-12) |

P17 REPRODUCED (F-34) · P18 REPRODUCED + fully explained (pin bypasses allergen+clamp × catalog as-prepared fluid, F-33) · P13's fluid overcount mechanism confirmed live (F-36) · P14 re-confirmed (F-39).

### Dispatched
- qa `intake/`: 6 ruling-requests (catalog fluid convention & powder pairing · pin override vs allergens/clamp · electrolyte form & scaling policy · fueling-window tier authority · practicality constraints · fasted-suppression mechanism addendum to D-001).
- ops `data/bug-reports/`: 6 bugs (twin electrolyte divergence · fasted snack · 4:30/mi pace fallback · ephemeral used_pin:true · card timing labels/P14 · after-phase ignores fluid target).
- Brick branch cross-refs: F-25 (T1 60-min synthetic duration + LP), F-43 target half (3150ml post-brick fluid), F-44 (run/run conforms to brick.md R2).

### Still open on this branch
- F-26: `plan_generation_log` query (needs Xuan: dashboard or service-key approval) — real S6 shortfall rates.
- Differential harness (plan Phase 3) — now motivated by three concrete divergences to pin.
- Broader catalog audit vs LIVE DB (only offender rows spot-checked live).
- Charter draft for a `food-recommendation` sim-explore surface (none exists yet).

### Appendix — full live catalog audit (92 active `template_foods` rows, dev, 2026-08-31)
Mechanical rules over every row (anon-key PostgREST). Hits, deduplicated and triaged:
- **As-prepared fluid on dry rows (the F-15 family, live):** electrolyte_drink_mix 500 · electrolyte_packet 480 · electrolyte_tablet 475 · high_sodium_electrolyte_mix 480 · oatmeal 200. (mixed_berries 60 / white_rice 125 are intrinsic water — not defects.)
- **Water-pairing self-satisfiers among sodium top-up items (F-16 live):** electrolyte_tablet (475), high_sodium_electrolyte_mix (480), pickle_juice_shot (70 — genuinely a liquid shot, but ships with no chaser either).
- **Indivisible-in-practice marked divisible (F-42 family):** energy_gel, protein_powder, electrolyte_drink_mix.
- **High-sodium items not flagged `is_electrolyte`:** soy_sauce 879mg, teriyaki_sauce 690mg, plant_protein_powder 300mg — currently maxD=0 keeps sauces out of during, but any future pool widening inherits them silently.
All 16 raw hits + the query are reproducible from `scratchpad` transcript; the corrections ride the catalog-fluid ruling (`intake/2026-08-31-catalog-fluid-convention-and-powder-pairing.md`).

### Appendix — executable twin differential (`runs/2026-08-31-food-recommendation-probe/differential.ts`, deno)
Real server `pickBestElectrolyte` (imported from the worktree) vs a faithful transcription of the Dart `_pickBestElectrolyte`. Output 2026-08-31:
```
DIVERGE | F-22 cap: target 1520mg, capsule 190mg x8 allowed
         server: electrolyte_capsule x4 → 760mg     (HALF the target)
         dart:   electrolyte_capsule x8 → 1520mg    (on target)
DIVERGE | F-46/F-47 scenario: in-range 2000mg, 30mg-capsule min_servings=3
         server: ADD NOTHING                        (respects min_servings; floor-rescue gated)
         dart:   electrolyte_capsule x2 → 2060mg    (candidate loop ignores min_servings)
```
| F# | Tag | Finding |
|----|-----|---------|
| F-46 | S1 LIVE | Floor-rescue gate asymmetry — TS requires `startsBelowFloor` before accepting a non-improving in-band pick (2026-07-29 fix); Dart's tail is unconditional `if (best.sodiumAfter >= sodiumLower) return best` — accepts score-worsening additions from an already-in-range state (the exact bug TS fixed). Each twin carries a fix the other lacks |
| F-47 | S1 LIVE | Dart electrolyte candidate servings start at 1 (indivisible) / 0.5 regardless of `min_servings` (`client_during_phase_solver.dart:293-294`); TS starts at `max(1, ceil(min_servings))` (`during-utils.ts:279-282`) — demonstrated above |
Also analyzed: F-23 (baseline ×2 weight) is LATENT — it only matters when current sodium > upper, where every candidate is hard-filtered anyway; F-24 (gut cap) is masked today because all top-up electrolytes are supplements already capped harder by F-22's 4-cap. Port all five in one reconciliation pass; the differential doubles as the regression demo.

### Appendix — plan_generation_log analysis (F-26 CLOSED, 2026-09-01; `scripts/query-ledger.sh`)
PROD = 177 real plans (2026-07-21 → 2026-09-01) · DEV = 1000 most-recent (same window; QA-noise included).

| F# | Tag | Finding |
|----|-----|---------|
| F-48 | S6 QUANTIFIED | **21% of prod plans deliver <80% of the during-sodium target** (34/163; median 0.95; overshoot ≈0 — the ceiling holds, the floor doesn't). 31% of prod rows carry an explicit shortfall, dominated by `template_constraint` (53) + `all_disliked` (20). Real-world rate for the F-22 cap + 2-source limit family. Dev shows 7% — prod is ~3× worse (older deployed code and/or the prod catalog generation) |
| F-49 | SYSTEMIC — POSTPONED (Xuan 2026-09-01) | **After-phase fluid delivery is broken everywhere, not just bricks: prod median delivered/target = 0.28; 96% of prod plans (<80%), 91% of dev.** The recurring warning is the same 4-item recovery template delivering ~388ml against 1.0–1.5L targets — exactly the sim's AFTER card. The after solver simply has no water top-up step |
| F-50 | NEW — POSTPONED (Xuan 2026-09-01) | After-phase sodium is uncontrolled in BOTH directions on prod: 34% deliver <80%, 27% deliver >120% of target (`after: sodium=666 not in [210,390]` and `=305 not in [490,910]` both recur) — post-workout selection tracks neither floor nor ceiling |
| F-51 | MINOR | During carbs overshoot >120% in 13% of prod plans — serving granularity on tiny targets (`carbs=7.5 not in [4.5,5.5]`: one gel is ~5× a 30-min easy session's target band) |
All rates reproducible: `scripts/query-ledger.sh all` → `/tmp/plan_ledger_{dev,prod}.json` (device_id excluded by design).

### Appendix — prod catalog audit (2026-09-01; `scripts/query-ledger.sh catalog all`)
| F# | Tag | Finding |
|----|-----|---------|
| F-52 | PROD CONFIRMED | **Prod and dev catalogs are row-identical** — both `pre_workout_templates` (29 rows: new-generation windows `2-4 hours`/`30-120 min`, `sub_phase` populated, zero field diffs) and `template_foods` (93 rows, zero diffs). Xuan's belief confirmed: prod HAS the correct time windows. Consequences: (a) all 16 catalog audit hits (F-15/16/42 family — tablet 475ml, as-prepared mixes, divisible gels, unflagged sauces) ship on PROD today, and one correction pass fixes both; (b) the prod-vs-dev during-sodium gap (21% vs 7% under-delivery, F-48) is therefore NOT catalog — it is the deployed edge-function code version lagging develop; (c) `timeWindowToPhase`'s comment that prod still carries `1.5-3 hours` labels is stale — the legacy fallback is dead code on both projects |

### Scoping ruling (Xuan, 2026-09-01)
- **Post-workout (F-43 delivery half, F-49, F-50): POSTPONED.** The post-workout section has no ratified macro targets yet — the fluid/sodium delivery findings are real but belong to a LATER post-workout bundle, not this one. The ops bug stays filed with a deferred note; no post-workout ruling goes to the desk from this branch.
- **Transitions (F-25, F-41/F-42 at T1): IMPORTANT — owned by `qa/brick-transition-nutrition`,** which Xuan intends to land BEFORE this bundle. This probe's mechanism findings are that branch's inputs: transition selection = during-template candidates filtered to template_number 0, solved with a SYNTHETIC 60-MIN duration (confirming one of that branch's three candidate mechanisms for the 3-gels observation), else LP over curated transition foods (maxFoodItems=3, maxServingsCap=2, during weights), else greedy; transitions are not pinnable; observed T1 output was 4 items incl. half a gel and dry powder, sodium 297/248.

### Post-ship verification (2026-09-02, brick-transition@v1 + pre-workout-macros@v2.1 live)
Verified against live DBs (`scripts/query-ledger.sh catalog all`) and app develop @ 80230b59:
- **F-15/F-16 (as-prepared fluid) → FIXED-SHIPPED:** all six C1 dry-zeros live on dev AND prod; oatmeal 200 / pickle 70 correctly retained per the A3 ruling.
- **F-13/F-41 (powder pairing) → FIXED-SHIPPED:** C2 pairing-scope extension in both twins (`ee078341`), carb mixes included, derivation approach (no `requires_water` column — allowed by the ruling).
- **F-42 (half-gels) → FIXED-SHIPPED:** `energy_gel.is_indivisible=true` both DBs; C4 transition LP now maxFoodItems=2 + whole-serving rounding (`brick-handler.ts:297-299`).
- **F-36 (phantom fluid in delivered totals) → should be dead with the C1 zeros — sim re-verify on the next smoke pass.**
- Branch refreshed: main (post brick-transition@v1 + @v2.1 parity) merged in at b4f1c05; probe worktree moved to develop @ 80230b59.
- STILL OPEN for this branch: pin-confirm · electrolyte form & scaling policy (+ the F-22/46/47 twin port, ops bug) · fueling-window authority · fasted/D-001 addendum · meal-tier practicality (a)(b)(d) · F-51 gel granularity · P13-class fluid-band selection discipline.
