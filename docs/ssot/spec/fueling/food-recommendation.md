# SSOT — Food Recommendation (selection contract)

**Status: RATIFIED (Xuan, 2026-09-03).** Every section and constant carries his dated per-item
ratification (§1–§8 stamps, §3a table + early-start rule, §4.3 tolerance, worked examples W1–W9);
this line records the completed whole. Fasted retirement (§7) remains a class-c change staged for
this bundle's implementation.
**Scope:** how the engine turns ratified macro TARGETS into named foods with quantities — the
faces, their precedence, the scoring, and the quality constraints — for the pre-workout and
during-workout phases, plus brick transitions by reference. **Post-workout selection is
explicitly OUT (Xuan, 2026-09-01): no ratified post targets yet; later bundle.**
**Evidence base:** `docs/food-recommendation-pipeline-map.md` + probe register
`runs/2026-08-31-food-recommendation-probe.md` (F-1..F-52). Targets themselves are owned by the
per-macro SSOTs (carbs v2, hydration v6, sodium v3, transition-nutrition v1) — never restated here.

## 1 · Faces and precedence — RULED (Xuan, 2026-09-03; ratified after in-session review of the cascade, filters, and solver vocabulary)
For every phase, selection resolves in this order, first match wins:
1. **Personal formula pin** (in scope: phase × activity × duration bracket) — bypasses the solver;
   carb-scaled; fluid/sodium backfilled from essentials.
2. **Pinned system template** — candidate set restricted to pinned templates.
3. **Default-formula tier** — template solver over the ranked eligible set (the COMMON path).
4. **Rule solver** (during) / **LP** (after-phase, brick transitions) / greedy (last resort).
Honesty contract: an unrenderable pin downgrades explicitly (`pinned_template_unrenderable`);
skipped personal formulas ride the wire; a system pick never claims `used_pin` (F-31 fix ⏳ app).
**Clarifications ratified with this section (2026-09-03):**
- *Filters:* bypassed at faces 1–2 (with the §1a conflict label), applied at 3–4 (diet+allergy
  hard; dislikes soft).
- *Mechanisms, precisely:* face 1 uses NO solver (pure uniform arithmetic scaling + deterministic
  water/salt backfill). Faces 2–3 use the TEMPLATE solver — a bounded discrete search over
  component serving combinations (gut caps, ratio constraints), face 2 restricted to pinned
  candidates with shortfall tolerated, face 3 over the full filtered, preference-ranked set.
  Face 4 uses the cruder mechanisms: the rule solver (during — an ordered heuristic recipe, no
  optimization) and the true LINEAR PROGRAM only in after-phase and brick transitions (never
  pins), then greedy last.
- *Ratios are data:* pre-workout `component_quantities` (fixed per serving), during
  `component_carb_ratios` + structural constraints (solver-quantized), personal-formula
  `components` (authored, scaled uniformly).
- §1a **Pin override scope — RULED (Xuan, 2026-09-03): labeled override.** Pins are honored
  unconditionally — bypassing allergen/diet/dislike filters and the scale clamp — AND the card
  must label any conflict visibly ("pinned despite your gluten allergy"): informed, never silent.
  Conflict-label UX goes to a Claude Design iteration; warn-timing (pin-time / plan-generation /
  both) is that iteration's open question. Allergies-changed-after-pin: the label covers it (the
  pin persists, labeled) — no silent unpinning.

## 2 · Eligibility filters — RULED (Xuan, 2026-09-03, with §1)
Diet + allergies are hard inputs; likes/dislikes are soft (shortfall over empty plan — the
2026-07-08 re-enable contract); gut level is a constraint input, never an engine switch.
Category dedup and cross-phase food dedup per Algorithm C. (Subject only to §1a's pin override.)

## 3 · Fueling-window authority — clamp RULED, authority ⏳
**Clamp — RULED (Xuan, 2026-09-02, dossier thread db654def):** the fueling window is capped at
the actual time remaining before session start. A tier whose minimum window exceeds the remaining
gap (e.g. MEAL at ≥ 120 min with 60 min left) is NOT offered — never scheduled in the past. An
athlete 1 h out can hold only windows ≤ 60 min and receives the snack/top-up tiers. Closes F-38
directly and bounds F-28's failure mode at short notice.
**Window authority — mechanism RULED (Xuan, 2026-09-03, option 1):** a ratified timing table
provides the DEFAULT window (user-adjustable within the clamp), surfaced at creation. The current
`recommendedHoursBefore` formula is retired in favor of the table.

### §3a — Default fueling-window table — RULED (Xuan, 2026-09-03; research-derived, incl. the early-start rule)
Sources: ACSM/AND/DC position stand (Thomas et al., MSSE 2016) — pre-exercise meal of 1–4 g/kg CHO
taken 1–4 h before; ISSN nutrient-timing position (Kerksick et al., JISSN 2017) — full meals 3–4 h
out, smaller CHO feedings closer in; Burke et al. race-nutrition practice (marathon/70.3 fueling:
race-day breakfast ~3 h pre-start is the practitioner norm; closer feedings top up). The table
maps to the ratified tier thresholds (meal ≥ 120 min, snack ≥ 30 min):

| Session class | Default window | Rationale |
|---|---|---|
| Race effort / key session, any duration | **3 h** | full pre-event meal, digestion margin (ACSM 1–4 h; practitioner norm 3–4 h) |
| Long session ≥ 2.5 h (non-race) | **3 h** | meal-tier dose (2–4 g/kg) wants the 3–4 h end |
| 1.5–2.5 h | **2.5 h** | meal tier reachable with lighter dose (1–2 g/kg) |
| 60–90 min, moderate+ | **2 h** | light meal or large snack; keeps meal tier available |
| 60–90 min, easy | **1 h** | snack tier suffices |
| < 60 min | **45 min** | snack/top-up only (0.5–1 g/kg class) |
| Early-morning / short-notice (clamp binds) | time available, floor 15 min | ruled clamp: never past, unreachable tiers not offered |

**Early-start rule (practicality overlay — Xuan, 2026-09-03):** the table's defaults are the
no-constraint ideals; a 5 a.m. Saturday long run must not default to a window that implies a
2 a.m. breakfast. For **training** sessions starting before **07:00**, the default window drops
to **60 min** (snack tier — the literature's own fallback: when time is short, a smaller ~1 g/kg
snack ≈1 h out substitutes for the full meal, with during-workout fueling compensating; overnight
sleep depletes ~30–40 % of liver glycogen, so *something* beats nothing on long runs). **Races
keep the table default regardless of start time** — race morning is the case where athletes do
wake early, per universal practice. The athlete's manual override always wins within the clamp.
Inputs needed: session start time + the existing race-effort intensity — nothing new.

Notes: intensity nudges one row up — **mapping RULED (Xuan, 2026-09-03): the Long Run preset ⇒ +1 row; Race Pace ⇒ the race row (180 min) directly; all other presets ⇒ no nudge**; the athlete's saved
override, once set manually, wins within the clamp (existing `preRunMinutesManuallySet`
semantics). Values are Mealvana design choices anchored to the cited ranges — not themselves
literature constants; the 3 h race default is Xuan's stated anchor and sits inside every cited
range. Early-morning fallback sources: ISSN nutrient-timing position (small tolerated CHO snack
for early-morning trainees), practitioner guidance (RunnersConnect / TrainingPeaks / USATF:
~1–2 g/kg 1–2 h out if feasible, else smaller + closer + fuel during).

## 4 · Sodium-source selection (during) — RULED (Xuan, 2026-09-03)
1. **Symmetric target-seeking:** overshoot above the TARGET is penalized (not only above the
   ceiling) — one big-hit source no longer beats honest scaling for free.
2. **Supplement serving cap = the catalog row's `max_servings_during`** — one number, both
   engines; the synthetic server-side 4-cap is retired (scopes the F-22/46/47 twin port).
3. **Carryable-first form preference:** capsule/tablet/gel outrank liquid/mix volume when fits
   are *comparable* — **RULED (Xuan, 2026-09-03): fits are comparable when their
   distances-to-target differ by ≤ 10 % of the target** (e.g. 90 mg at a 900 mg target); within
   that width carryable wins, outside it closeness wins.
4. **Max 2 electrolyte sources per fill** (unchanged).
5. **Backfill/top-up sodium essential prefers electrolyte capsule/tablet; salt packet is last
   resort** (2026-09-03 thread).

## 5 · Fluid semantics & water pairing ✅ (ratified — cite, don't restate)
`spec/domain/catalog-conventions.md` v1: C1 fluid-as-consumed (dry zeros; embedded water counts),
C2 pairing extends to all dry requires-water items. Delivered-fluid accounting follows C1/A3.

## 6 · Practicality constraints
- ✅ C3 whole-unit semantics + C4 transition rules (≤2 items + water) — catalog-conventions v1.
- **Meal-tier — RULED (Xuan, 2026-09-03, thread-refined):** (a) the meal tier prefers composed
  templates — single-item scaling capped at 2× before another template is preferred; a meal-tier
  feeding has ≥2 components unless flagged single-food-sufficient. (b) Container-sized rows only
  (no mega-rows); totals stay the macro SSOTs'; per-sport form preference (capsules/gels for
  running; mixes acceptable for cycling); no carry budget. (e) **Solvent contract, selection
  paths only (pins unchanged):** new catalog column `solvent_min_ml` (label-derived values;
  250 ml pairing fallback for undeclared rows); session-total constraint — plain water ≥ Σ
  solvent minima of scheduled concentrated products; solvent water counts toward the hydration
  total; gels chase ~150 ml. Supersedes C2's flat pairing constant → catalog-conventions v1.1.

## 7 · Fasted path — RULED (Xuan, 2026-09-03): RETIRED
The fasted toggle stops being a product state. **Class-c contract change staged for this bundle:**
remove the toggle, deprecate `is_fasted` on the wire (tolerate-and-ignore during migration),
remove fasted branches from the target engines and FC-4 rendering. D-001 and deferred-ledger
P17/P11 close by removal; the three-cause suppression mechanism becomes moot.

## 8 · Two-engine parity (the twin contract) — RULED (Xuan, 2026-09-03; confirmed explicitly in-session same day)
The Dart client solvers are a MIRROR, not a fork: every selection rule in this spec binds both
engines; a fix landing in one twin is a defect until ported (F-22/23/24/46/47 precedent).
Differential vectors accompany every ruled constant (the probe's executable differential is the
template).

## 9 · Conformance
Vectors: `vectors/fueling/food-recommendation.json` via spec-to-vectors once §§3-4-6-7 are ruled
(oracle from this spec; worked examples to be added with the rulings). Two-layer: engine ⇄ spec
via the vectors; explanation ⇄ engine via qa-smoke on the drawer numbers. Sim charter:
`references/charter-food-recommendation.md` (to be drafted for sim-explore).

## Worked examples (the oracle checks these before any vector is emitted)
Catalog fixtures = the live rows verified 2026-09-02 (capsule 190 mg maxD 8 · pickle shot 940 mg
maxD 3 · high-sodium mix 1000 mg maxD 4 · high-carb mix 90 g, solvent_min 600 ml label · water
240 ml/cup). 73 kg athlete unless stated.

| # | Input | Expected | Section exercised |
|---|---|---|---|
| W1 | Gluten-allergic athlete, pinned `Oatmeal` meal template, race run, window 3 h, meal-slot carb target 94 g | Meal slot = Oatmeal ×3.5 (94 ÷ 27, unclamped), **conflict label present**; eligible unpinned meals NOT substituted | §1 cascade · §1a |
| W2 | Race-effort run, start 09:00, generated the evening before | Default window **180 min** → phases [meal, snack, top_up] | §3a table |
| W3 | Training run 90 min moderate, start **06:00** | Table default 2 h **overridden to 60 min** (early-start rule) → [snack, top_up]; no feeding before wake | §3a early-start |
| W4 | Any session, plan generated **45 min** before start | Window clamped to 45 min → **[snack, top_up]** (snack activates at ≥ 30 min); no past-scheduled feeding, no "finish by 2 h out" label — *corrected per RULING (Xuan, 2026-09-03); original said [top_up] only, a drafting slip against §3's own threshold* | §3 clamp |
| W5 | During sodium: current 0, target 900, band [810, 990]; pool = capsule vs pickle shot | Capsule ×5 = 950 (dist 50) vs pickle = 940 (dist 40): fits are **comparable** (see tolerance below) → **capsules win** (carryable-first). Old behavior (pickle, free sub-ceiling overshoot) is the retired characterization | §4.1 + §4.3 |
| W6 | Pinned personal formula leaves a 300 mg sodium deficit at close | Backfill appends **electrolyte capsule ×2** (380 mg) — never a salt packet | §4.5 |
| W7 | During plan schedules high-carb mix ×2 | Plain water across the session ≥ 2 × solvent_min (1200 ml); that water counts toward the hydration total (no double demand) | §6(e) |
| W8 | Meal tier, no pins; pool holds composed templates + single foods | A composed template renders; a single food is never scaled beyond 2× to fake a meal (the Banana-×3 case returns a composed pick or an honest shortfall) | §6(a) |
| W9 | Identical inputs, TS engine and Dart engine | Byte-equal selections (the probe differential is the harness template) | §8 |

**§4.3 tolerance — RULED (Xuan, 2026-09-03): 10 % of target.** Surfaced by W5; folded into §4.3
above. With this, every constant in the spec is ruled.

## 10 · Selection-quality telemetry — RULED (Xuan, 2026-09-03, post-ratification addition)
**The step-resolution funnel** is the standing quality metric for this contract. Terminology:
*phase* = before/during/after; *step* = cascade position (§1: 1 personal formula · 2 pinned
template · 3 default template · 4 rule/LP/greedy fallbacks).
- Per phase, tracked over time (weekly): % of plans resolved at each step + fallthrough-reason
  histogram + practicality tripwires (§6 violations, expected 0 post-implementation).
- **Ruled targets:** steps 1+2 combined ≥ **60 %** (athletes actually pinning formulas),
  step 3 ≈ **40 %**, and **any step-4 resolution is a defect signal** — it reveals the formula
  library lacks coverage for that workout shape, and files against the library, not the athlete.
- **Telemetry contract:** the engine already emits `generation_path` + `pin_decision` per phase;
  the ledger (`plan_generation_log`) must record enough to compute the funnel per step — during
  today needs `during_path × pin_decision.used_pin` to split step 2 from step 3; `before_path`
  and `after_path` columns are added by this bundle's migration. **Test traffic is excluded:**
  remote e2e suites mark their calls (an `x-mealvana-test` header the function records into a
  ledger `source` column — same migration); the 2026-09-02 prod burst (484 synthetic rows from
  the brick-ship e2e verification) is the precedent. `qa/scripts/query-ledger.sh funnel` is the
  reference computation.
- Baselines (2026-09-03, during-phase, TEST TRAFFIC EXCLUDED — human prod, 179 plans, of
  step-resolvable): steps 1+2 = **6.8 %** (target ≥ 60), step 3 = 51.6 %, step 4 = **41.6 %**
  (target: 0, defect signal). The distance to target is the bundle's quality headline.

## Open questions
| Q | Question | Blocks |
|---|---|---|
| Q-FR1 | RULED 2026-09-03 — labeled override (§1a); warn-timing open to design | — |
| Q-FR2 | FULLY RULED 2026-09-03 — mechanism + clamp + §3a table values + early-start rule | §3 vectors |
| Q-FR3 | RULED 2026-09-03 (§4) | twin port ships against it |
| Q-FR4 | RULED 2026-09-03 (§6, thread-refined) | — |
| Q-FR5 | RULED 2026-09-03 — fasted RETIRED (§7, class-c staged) | — |
