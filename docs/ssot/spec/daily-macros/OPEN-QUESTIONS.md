# Daily Macros — Open Questions Register

Contradictions, gaps and unstated rules found while distilling the Notion pages into
`spec/daily-macros/` on 2026-07-28. **These are spec-vs-spec problems, not code deviations** —
nothing here has been checked against the implementation yet. Code-vs-SSOT findings belong in
[`DEVIATIONS.md`](../../DEVIATIONS.md); these belong to Xuan as the SSOT author.

**ALL THIRTEEN ARE NOW RULED (Xuan: Q-013 on 2026-07-29; Q-001–Q-012 on 2026-08-13).** Nothing in
this register blocks vectoring any longer. Each ruling is folded into its spec file; the entries
below keep the full original analysis plus the ruling, so the reasoning survives. The specs remain
`RECORDED — awaiting ratification` as documents — ruling the register was the prerequisite, not the
ratification itself.

| ID | Subject | Ruling |
|---|---|---|
| [Q-001](#q-001) | Rounding of intermediates | **RULED** — R1: unrounded through, round once at return |
| [Q-002](#q-002) | Multi-session path rounds mid-pipeline | **RULED** — F19 `round()` deleted; step 12 rounds |
| [Q-003](#q-003) | Strength carb demand: 27 g vs 40 g | **RULED** — strength = flat 27 g/hr, IF ignored (literature-backed) |
| [Q-004](#q-004) | `fat_mod` never applied | **RULED** — vestigial; retained as documentation, do not implement |
| [Q-005](#q-005) | `RACE_WEEK` forced when tomorrow is a race? | **RULED** — guidance only; no computed override |
| [Q-006](#q-006) | EA override can breach the carb ceiling | **RULED** — ceiling branch added to F18 |
| [Q-007](#q-007) | Pre-race session kcal: 1050 vs 1479 | **RULED** — 1479; TDEE 4202; stale cell corrected |
| [Q-008](#q-008) | Two EA test rows don't reconcile | **RULED** — cells recomputed (52.2, 42.7) |
| [Q-009](#q-009) | No recompute after the EA override | **RULED** — no recompute; `energy_basis` flags it |
| [Q-010](#q-010) | HR-derived IF unspecified | **RULED** — deferred; ladder has no Garmin rung |
| [Q-011](#q-011) | `resolveRMR` not mode-gated | **RULED** — intentionally source-first, documented |
| [Q-012](#q-012) | `sources` / `delta` underspecified | **RULED** — 7-tag enum pinned; `delta = null` outside retro |
| [Q-013](#q-013) | `yesterday_tss` for a double | **RULED 2026-07-29** — sum; last session's end time |
| [Q-014](#q-014) | Does fat have a ceiling? | **RULED 2026-08-13** — 30 %E cap, excess → carb |
| [Q-015](#q-015) | NEAT model rigor (tier × day × lifestyle) | **DEFERRED 2026-08-13** — future work, by ruling |
| [Q-016](#q-016) | Manual profile edits: which cached days recalculate? | **RULED 2026-08-17** — today + future; past days are history |
| [Q-017](#q-017) | Carb cycling is unobservable under the Q-014 fat cap | **RULED 2026-08-17** — no-op accepted for v1; 10b exemption staged for a LATER bundle version (**excluded from @v2**, Xuan 2026-08-17) |

---

## Q-001
### Are intermediate carb/protein values rounded before the fat residual?
> **RULED — Xuan, 2026-08-13: R1 stands.** Intermediates carried unrounded; one rounding at
> return. The strength-day evidence was decisive (only the unrounded reading reproduces the
> published fat), independently re-verified before ruling. The Iteration 3 rest-day "81" is a stale
> cell. Fat is vectored exact-match, not ±15 %. Folded into [README.md R1](README.md#cross-cutting-rules)
> and [assembly.md](assembly.md). **Notion not updated** — push-back needed.
**Where:** Iteration 1 assembly step 9 ("all rounded") vs the Iteration 1 and Iteration 3 test
tables. **Severity: high — it changes almost every fat number.**

The spec says only "return … (all rounded)". It never says whether rounding happens *before* the
fat residual is computed. The two readings disagree, and the source's own test pages disagree with
each other:

| Case | unrounded intermediates | rounded intermediates | Iter 1 page says | Iter 3 page says |
|---|---|---|---|---|
| Rest day fat | `(2385 − 1200 − 460.8)/9 = 80.5` → **80** | `(2385 − 1200 − 460)/9 = 80.6` → **81** | **80** | **81** |
| Strength day fat | `(2735 − 1360 − 550.8)/9 = 91.6` → **92** | `(2735 − 1360 − 552)/9 = 91.4` → **91** | **92** | — |

The strength-day row is decisive: only the **unrounded** reading produces the published 92. So the
distillation records **R1 — carry unrounded, round once at return** as the rule, and treats the
Iteration 3 rest-day "81" as a stale cell.

**Needs a ruling** because it is a derived inference on a number that appears in every plan, and
because `fat ±15 %` tolerance in the source tests is loose enough that both readings pass — so the
source tests cannot settle it.

**Recommendation:** ratify R1 explicitly in the SSOT and correct the Iteration 3 cell, then vector
fat exact-match rather than ±15 %.

---

## Q-002
### The multi-session path rounds its outputs; the single-session path does not
> **RULED — Xuan, 2026-08-13: drop the rounding.** Formula 19 returns unrounded; assembly step 12
> is the only rounding site, consistent with R1. `prot_bump = 22.5` now survives to the total.
> Folded into [session-demand.md](session-demand.md). **Notion not updated** — push-back needed.
**Where:** Formula 19 returns `{ session_carb: round(total_carb), prot_bump: round(max_prot_bump) }`;
the Iteration 1 single-session path adds unrounded values. **Severity: medium.**

Under R1 (Q-001) this is an inconsistency: a 2-session day rounds mid-pipeline while a 1-session
day does not, so the two paths are not continuous with each other. Also note `round(max_prot_bump)`
rounds 22.5 → 22 or 23 depending on the tie-break, while the single-session path carries 22.5 into
a protein total that later reconciles at 138.

**Recommendation:** drop the rounding from Formula 19's return and let step 12 round, consistent
with R1. Needs a ruling because it changes published multi-session expectations by ~1 g.

---

## Q-003
### Strength session carb demand: the test table says 27 g, the formula says 40 g
> **RULED — Xuan, 2026-08-13: resolution (2) — strength has a reduced, intensity-independent
> rate: `27 g/hr × duration_hr × (weight/75)`, IF ignored, no ×1.15.** Research (2026-08-13)
> vindicated the 27 g cell: RT glycogen depletion tracks duration and set count, not load (Robergs
> 1991 PMID 2055849; Hamidvand 2025 meta-analysis PMC12717450 — 20 studies, ~21 % worked-muscle
> depletion, ≈25–45 g whole-body per hard hour), and IF is an endurance construct with no gym
> meaning (TrainingPeaks scores strength flat). Structure: research-derived, confidence B−. The
> number 27: design choice inside the 15–40 g/hr defensible band, confidence C. **This inverts the
> register's original recommendation** (which favoured "27 is wrong → 109"): the Iteration 4 row was
> right, and Iteration 1's full-day strength carb 340 was the stale cell (now 327, fat 97). Folded
> into [session-demand.md](session-demand.md) and [assembly.md](assembly.md). **Notion not
> updated** — both source pages need the rule pushed back.
**Where:** Iteration 4 multi-session test table, row "strength 1 hr IF 0.70, run 1.5 hr IF 0.74".
**Severity: high — it implies an unstated rule.**

That row states `strength = 27 g + run = 69 g = 96 g`. But `carbDemand(IF 0.70, 1.0 hr, 75 kg)` is
`40 g/hr × 1.0 × 1.0 = 40 g`, with no multiplier (IF ≤ 0.85, dur ≤ 1.5) and no compounding
(strength is ×1.0). That gives **40 + 69 = 109 g**, not 96.

The Iteration 1 full-day table agrees with the formula: the same strength session yields carb
`300 + 40 = 340`. So Iteration 4's own row is the outlier.

Three possible resolutions, and they are not equivalent:
1. The 27 g figure is simply wrong → total is 109 g.
2. Strength sessions get a **reduced** carb demand not stated anywhere (27/40 ≈ 0.675) → a missing
   formula.
3. Strength uses a different IF or rate table → also a missing formula.

**Recommendation:** confirm (1). If (2) or (3) is intended, the rule needs writing before this
engine can be vectored at all — a hidden 33 % reduction on strength days is not something a
conformance run should discover.

---

## Q-004
### `phaseModifiers` returns `fat_mod`, and nothing ever uses it
> **RULED — Xuan, 2026-08-13: vestigial — not applied, retained as documentation of intent.**
> The residual already delivers the column's direction (carb up → fat down), so `RACE_WEEK`'s 0.85
> intent is achieved by other means. Annotated so no implementer activates it; doing so would need
> a new ruling on floor interaction and would change every published fat number. Folded into
> [multi-day-context.md](multi-day-context.md#formula-10--phasemodifiersphase).
**Where:** Formula 10 vs every assembly version. **Severity: medium.**

`fat_mod` ranges 0.85–1.10 across phases, so it *looks* meaningful — but fat is a pure residual
computed in step 10, after phase modifiers have already been applied to carb and protein only. No
assembly step multiplies fat by anything.

Either the column is vestigial (harmless, but should be marked as such so nobody implements it), or
fat was intended to be scaled — in which case the interaction with the residual and the fat floor
is undefined. Note `RACE_WEEK`'s `fat_mod = 0.85` reads like a deliberate carb-load intent that is
currently inert.

**Recommendation:** rule "vestigial, do not implement" and annotate the table, or specify where it
applies.

---

## Q-005
### Is `training_phase` forced to `RACE_WEEK` when tomorrow is a race?
> **RULED — Xuan, 2026-08-13: guidance only — no computed override.** `training_phase` stays a
> pure athlete setting; the conflict-table line is athlete-facing advice. Only this reading
> reproduces the published 798; an override would silently rewrite an athlete's setting; and
> `tomorrow_is_race` already drives the 9 g/kg pre-load regardless of phase, so a TAPER racer loses
> only the carb_mod delta. If that matters, the fix is a visible UI nudge, never a silent override.
> Folded into [multi-day-context.md](multi-day-context.md).
**Where:** Iteration 2 conflict-resolution table ("Phase = TAPER but tomorrow = race → Phase must
be `RACE_WEEK`, not `TAPER`") vs the absence of any such rule in the formulas, and vs the
Iteration 2 integration test which runs `PEAK` with `tomorrow_is_race = true`. **Severity: medium.**

`training_phase` is documented as an athlete setting. If the conflict table describes a **computed
override**, it is a missing formula and it contradicts the pre-race integration example (which
would then have to use `carb_mod = 1.00`, not `PEAK`'s 1.12, and would not land on 798). If it
describes **guidance to the athlete**, it is not a rule and should not be in a conflict-resolution
table.

The distillation records **no override**, because that is what reproduces the published 798.

**Recommendation:** confirm "guidance only", and consider whether a TAPER+race day genuinely should
lose 12 % of its carb load — that is the substantive question underneath.

---

## Q-006
### The EA override can push carb past the 12 g/kg ceiling
> **RULED — Xuan, 2026-08-13: the ceiling branch is added to Formula 18.** If the 60 % carb share
> would push carb past `12.0 × weight`, carb caps at the ceiling and the overflow kcal reroute to
> fat; EA still lands at exactly 30 (energy conserved at 9 kcal/g). Protein untouched — its ceiling
> cannot bind. The source's edge-case table asserted exactly this; the formula body now matches it.
> Folded into [energy-availability.md](energy-availability.md#formula-18--eaoverridecarb-prot-fat-session_kcal-ffm_kg-weight_kg).
> **Notion not updated** — push-back needed.
**Where:** Formula 18 vs the clamp in pipeline step 9, and vs Iteration 4's own edge-case row.
**Severity: high — safety-relevant.**

Step 11 runs *after* the clamp and adds `deficit × 0.6 / 4` grams of carb unconditionally. Nothing
re-clamps. The source's edge-case table asserts the intended behaviour — "EA override with carb at
ceiling (900 g) → cannot add more carb; override adds to fat only" — but **Formula 18 contains no
such branch**.

So the spec is internally contradictory, and the two readings differ in a way that matters: if all
the deficit goes to fat, the athlete needs `deficit / 9` grams of fat instead of a 60/40 split, and
the resulting EA still lands at 30 either way — but the macro split does not.

**Recommendation:** add the explicit branch to Formula 18: if carb is at (or would exceed) the
ceiling, cap carb at the ceiling and route the remaining deficit entirely to fat. Also confirm
whether the protein ceiling can ever bind here (it cannot — protein is untouched by the override).

---

## Q-007
### Pre-race session kcal: 1050 (Iteration 3) vs 1479 (Iteration 4)
> **RULED — Xuan, 2026-08-13: 1479 kcal is correct; the Iteration 3 row is corrected to
> session 1479 / TDEE 4202.** Independently recomputed: `11 × 75 × (0.82/0.75)² × 1.5 = 1479.3`;
> Iteration 4's intake 4368 → EA 45.1 only reconciles with 1479. Fat and TEF unaffected (fat at
> floor pins intake). Folded into [neat-tef.md](neat-tef.md). **Notion not updated** — the
> Iteration 3 page carries the stale 1050/3773.
**Where:** Iteration 3 TDEE table, row "Pre-race all layers" (`session_kcal = 1050`) vs Iteration 4
EA table row 1 (`session 1479`, `intake 4368`). **Severity: medium.**

The pre-race scenario's session is `run 1.5 hr IF 0.82`, which costs
`11 × 75 × (0.82/0.75)² × 1.5 = 1479 kcal`. The 1479 figure is correct and Iteration 4 uses it.
Iteration 3's 1050 is inconsistent, and it propagates: with 1479 the pre-race TDEE is
`1908 + 378 + 436.8 + 1479 = 4202`, not the published **3773**.

Fat and TEF are unaffected (fat is at its floor, so intake is fixed at 4368 — which is exactly the
figure Iteration 4 uses, confirming 1479 is the intended session cost).

**Recommendation:** correct the Iteration 3 row to session 1479 / TDEE 4202 before it becomes a
vector.

---

## Q-008
### Two EA-override test rows don't reconcile with the formula
> **RULED — Xuan, 2026-08-13: cells recomputed — 52.2 and 42.7** (from intakes 3640 and 2930 at
> FFM 64; independently re-verified). Outcomes unchanged. Folded into
> [energy-availability.md](energy-availability.md). **Notion not updated.**
**Where:** Iteration 4 EA override table, rows 3 and 4. **Severity: low — outcomes unaffected.**

| Row | intake | EA at FFM 64 | page says |
|---|---|---|---|
| 500 / 140 / 120, session 300 | 3640 | **52.2** | 46.3 |
| 400 / 130 / 90, session 200 | 2930 | **42.7** | 40.3 |

Both stated values are lower than the formula gives, and neither corresponds to a plausible
alternative FFM. The classification outcome ("no change") is the same either way, so nothing
downstream breaks — but the numbers should not be vectored as published.

**Recommendation:** recompute the two cells; low priority.

---

## Q-009
### Are TDEE, TEF and fat recomputed after the EA override?
> **RULED — Xuan, 2026-08-13: no recompute.** TDEE/TEF/fat-residual are not re-run after the EA
> override. The override enforces a floor; it is not an energy estimate, and recomputing opens a
> fat→intake→TEF→TDEE→fat loop with no stopping rule. The returned energy figures describe the
> pre-override macros, and the output gains **`energy_basis: "pre_override" | "as_computed"`** so
> the explanation layer can never present `tdee` as describing the delivered plan — intake above
> stated TDEE on a gated day is correct, not a bug. Folded into
> [energy-availability.md](energy-availability.md), [assembly.md](assembly.md) step 11–12, and the
> [README output shape](README.md).
**Where:** pipeline step 11. **Severity: high — safety-relevant.**

`eaOverride` raises carb and fat. TDEE and TEF were computed in step 10 from the *pre-override*
macros. The spec never says whether to re-run `calculateTDEE`. Taken literally, an overridden plan
returns a `tdee` and `tef_kcal` that describe macros the athlete was never given, and
`intake > tdee` silently.

Re-running is not free either: a higher fat raises intake, which raises TEF, which raises TDEE,
which would raise the fat residual again — a second convergence loop wrapped around the first, with
no stated stopping rule.

**Recommendation:** state explicitly that TDEE/TEF are **not** recomputed and that the returned
energy figures are pre-override (simplest, and defensible since EA is a floor being enforced, not
an energy estimate) — or specify the outer loop. Either way it must be written down, because the
two readings produce different `tdee` values for the same athlete on the exact days where the
safety gate fires.

---

## Q-010
### HR-derived IF is referenced but never specified
> **RULED — Xuan, 2026-08-13: deferred**, exactly like CTL staleness. `garmin_avg_hr` is collected
> and unused; the ladder has no Garmin rung; the priority edge-case is vacuously satisfied. If ever
> added, the rung slots between `TP_PLANNED` and `ZONE_DIST` and requires a derivation spec first.
> Folded into [platform-resolution.md](platform-resolution.md).
**Where:** Iteration 5 input table (`garmin_avg_hr` — "can derive IF if TP unavailable") and the
edge case "TP planned IF exists but Garmin also has HR data → TP IF takes priority over Garmin
HR-derived IF", vs Formula 22's IF ladder, which has no Garmin rung at all. **Severity: low.**

As written, `garmin_avg_hr` is unused and the ladder falls straight from TP to `ZONE_DIST`.

**Recommendation:** confirm it is deferred (like CTL staleness) and mark it so, or specify the
derivation and add the rung between `TP_PLANNED` and `ZONE_DIST`.

---

## Q-011
### `resolveRMR` is not gated on `mode`
> **RULED — Xuan, 2026-08-13: intentionally source-first regardless of mode**, now documented. BMR
> describes the athlete, not the day, so the mode gate has nothing to gate; prospective runs fall
> back to the formula through data availability, which is now the stated contract rather than an
> accident. Folded into [rmr.md](rmr.md).
**Where:** Formula 24. **Severity: low.**

Every other resolver checks `mode == RETROSPECTIVE` before preferring platform data; `resolveRMR`
does not. In practice the Garmin daily summary does not exist before the day syncs, so prospective
runs fall back to the formula anyway — which is exactly what the end-to-end table shows (1908
prospective, 1920 retrospective). But that is data availability doing the work, not the spec.

**Recommendation:** either add the mode gate for consistency, or note explicitly that RMR is
intentionally source-first regardless of mode (defensible — BMR is not a same-day measurement).

---

## Q-012
### `sources` and `delta` object shapes are underspecified
> **RULED — Xuan, 2026-08-13: enum pinned to seven tags** (`GARMIN`, `TP_ACTUAL`, `TP_PLANNED`,
> `TP_CALENDAR`, `ZONE_DIST`, `FORMULA`, `MANUAL`); the bare `TP` normalises to `TP_PLANNED`.
> **`delta = null`** on every path except retrospective recalculation — null, not absent, not
> zeros. A tag outside the enum is a conformance failure. Folded into
> [platform-resolution.md](platform-resolution.md#sources-object--ruled-xuan-2026-08-13-q-012).
**Where:** Iteration 5 output. **Severity: low.**

`sources` is required to contain `rmr`, `neat`, `session_kcal` (array), `IF` (array), `tomorrow`,
`weekly_ratio` — but the tag vocabulary is only implied by the ladders (`GARMIN`, `TP_ACTUAL`,
`TP_PLANNED`, `TP`, `TP_CALENDAR`, `ZONE_DIST`, `FORMULA`, `MANUAL`), and `TP` vs `TP_PLANNED` for
the weekly ratio is inconsistent naming. `delta` is only defined for the
`recalculateAfterSync` path; the spec does not say what it is on a normal prospective run (absent?
null? zeros?).

**Recommendation:** pin the enum and state `delta = null` outside retrospective recalculation.

---

## Q-013
### How is `yesterday_tss` derived when yesterday had more than one session?

> **RESOLVED — ruled by Xuan, 2026-07-29: SUM.** `yesterday_tss` is the **sum** of the TSS of all
> of yesterday's sessions, each resolved by the normal TSS ladder (TP actual → TP planned →
> `duration_hr × IF² × 100`). The decay input `hours_since` is measured from the **last** session's
> end time — recommended by QA alongside the ruling, since summing does not by itself settle which
> end time to use. Folded into [`multi-day-context.md`](multi-day-context.md#aggregation-when-yesterday-had-multiple-sessions).
> This was a deliberate evolution of the SSOT by its author, not an absorption of observed
> behaviour. **The Notion source page has not been updated** — `qa/spec/` and Notion now differ on
> this point; see the follow-up note at the end of this entry.

**Where:** Iteration 2 input table ("Yesterday's **Session**", singular, with one `yesterday_tss`
and one `yesterday_end_time`) vs Iteration 4, which makes multi-session days first-class, and
Iteration 5's `resolveSessionData`, which resolves TSS **per session**. **Severity: medium.**

The engine models a double for *today* (Formula 13 has a `DOUBLE` day type at 1.15) but carries a
single-session model for *yesterday*. Nothing states whether yesterday's sessions sum, take the
max, take the last, or are handled individually.

**Where the readings diverge.** `recoveryDebt` is a step function — a gate at TSS ≥ 150, and above
the gate the magnitude does not scale with TSS. So sum-vs-max is **invisible except in one band:
when no single session reaches 150 but the day total does.** That band is the ordinary
double day:

| Yesterday | sum | max | debt under *sum* | debt under *max* |
|---|---|---|---|---|
| 2 × (2 hr bike @ IF 0.72) | 207 | 104 | 94 g carb, 7.5 g prot | **0** |
| 4 hr bike @ 0.72 + 30 min jog | 230 | 207 | 94 g carb | 94 g carb (identical) |

At 75 kg that first row is a 94 g carbohydrate swing — ~376 kcal, which then propagates into fat
via the residual. The same ≥ 150 threshold gates `REST_AFTER_HARD` in Formula 13, so both
consumers flip together.

**Four candidate readings, not equivalent:**
1. **Sum** the session TSS values. TSS is additive by construction — the metric is defined so that
   a day's TSS is the sum of its sessions', which is how TrainingPeaks itself reports it.
2. **Max** single session. Under-counts doubles; makes a hard double cheaper than one long ride.
3. **Last** session only. Pairs naturally with the single `yesterday_end_time` field, but discards
   real stress.
4. **Per-session debt, summed.** The only reading that handles `hours_since` correctly (each
   session carries its own end time), but two qualifying sessions would produce ~188 g of carb
   debt before clamping — likely far too much.

**Sub-question — `yesterday_end_time`.** There is only one field, so whichever aggregation is
chosen, the decay input is ambiguous for a double. Using the **last** session's end time maximizes
the debt (smaller `hours_since` → larger factor). The choice is not second-order: a morning session
ending 08:00 and an evening session ending 18:00, evaluated at 10:00 the next day, give
`factor = 0.556` and `factor = 1.0` respectively — a near-2× swing in the debt.

**Recommendation (accepted):** **sum**, with the last session's end time. Sum is what TSS means, and
it is the only reading under which a double yesterday costs more than a single — which the
existence of the `DOUBLE` day-type modifier suggests the team already believes.

**Follow-ups created by this ruling:**
- The **Notion source page still says "Yesterday's Session" (singular)** and carries no aggregation
  rule. `qa/spec/` is now ahead of it. Someone should push the rule back to Notion so the two do
  not drift — QA has not edited Notion.
- Reading 4 (per-session debt, summed) was **rejected** by implication: debt is computed once, from
  the summed TSS, not once per session.
- The end-time rule is the **generous** reading — it maximizes the decay factor and therefore the
  debt. Flip candidates if that proves wrong in practice: duration-weighted mean end time, or
  earliest end time (most conservative).
- No existing worked example in `spec/daily-macros/` changes: every published scenario has a
  single yesterday session, so sum and max coincide.

---

## Q-014
### Does fat have a ceiling, or only a floor?

> **RULED — Xuan, 2026-08-13: fat is capped at 30 %E of the day's target energy; excess energy
> redistributes to carbohydrate up to the 12 g/kg clamp; in the corner case where both caps
> saturate, fat exceeds its cap rather than energy being dropped.** Implemented as assembly step
> **10b** (after `calculateTDEE`, before the EA gate), mirroring the EA override's position as a
> documented post-clamp adjustment. Redistribution conserves energy, so intake, TEF, TDEE and the
> EA result are unchanged and **target ≡ TDEE is preserved** — F-03's display contract needs no new
> divergence state. The 30 %E figure is ISSN's recommendation and sits inside the AMDR band; at
> this cap fat binds on all five worked-example days, so in practice **fat is a ~30 %E fraction and
> carbohydrate carries all day-to-day variation** — which is exactly the model the periodization
> literature prescribes. Chosen over 35 %E with that consequence explicit. Folded into
> [assembly.md](assembly.md) (step 10b, invariants, worked examples), [neat-tef.md](neat-tef.md)
> (cap subsection + literature), and [README.md R3](README.md#cross-cutting-rules).
> **Notion not updated** — this rule does not exist there at all; push-back needed.
**Where:** raised 2026-08-13 during design reconciliation (macro-dashboard F-03), by Xuan's
observation that "fat should have a floor and a ceiling; between them target = TDEE, outside they
diverge." **Status: OPEN — the first register entry raised from design work rather than from the
Notion distillation.**

**What the SSOT says today (verified):**
- **Floor: yes.** `fat_floor = 0.8 × weight_kg` (F15, R3, invariant I8). 60 g at 75 kg.
- **Ceiling: none.** `fat = max(residual, fat_floor)` — unbounded above. No formula, invariant or
  worked example caps it.
- **Divergence states as written:** fat above floor → intake ≡ TDEE (I9, F15 closed form). Fat
  pinned AT the floor → intake = carb×4 + prot×4 + floor×9 **exceeds** TDEE, "which the SSOT calls
  correct" (assembly, pre-race 798 example). EA override → intake > TDEE with
  `energy_basis = "pre_override"` (Q-009). Both existing divergences point the same direction:
  **target > TDEE**. A ceiling would create the first target-below-TDEE state.

**Why the question has teeth:** the ratified worked examples produce **fat 177 g** (90-min run day)
and **fat 262 g** (4-hr bike day) at 75 kg — 45–55 % of energy from fat on the heaviest training
days, an artifact of fat absorbing the entire energy residual. A ceiling has real work to do.

**What a ruling must decide (they are not one decision):**
1. The ceiling value — g/kg, % of energy, or % of TDEE. (No position-stand number exists for an
   athlete daily-fat *maximum*; any figure will be a `[design]` constant.)
2. **Where the excess energy goes.** (a) Dropped → intake < TDEE, a deliberate deficit on big days;
   (b) redistributed to carbohydrate → interacts with the 12 g/kg carb clamp, and on a 262 g-fat
   day would add ~180 g carb; (c) redistributed pro-rata. Option (b) is closest to sports-nutrition
   practice (big training days are carb days) but must specify the order vs step 9's clamp.
3. **EA interaction.** A ceiling that lowers intake lowers EA. It must run BEFORE the EA gate so
   the gate still catches the result — the one ordering that cannot ship is a cap that silently
   pushes an athlete into the HARD_WARNING band after the gate has already passed them.
4. Display contract (F-03): with a ceiling, "target = TDEE" holds only between the bounds, exactly
   as Xuan stated; the dashboard needs a third divergent state.

**Research pass (2026-08-13) — the literature answers decisions 1 and 2; QA recommendation
follows. Still OPEN pending Xuan's ruling.**

- **No source scales fat with training load; chronic high fat actively harms.** Thomas 2016:
  fat "in accordance with public health guidelines" (AMDR 20–35 %E), discourage < 20 %E; no upper
  number of its own. ISSN 2018 recommends ~30 %E (its "up to 50 %E safely" line is a tolerance
  statement, not a recommendation). Burke's Supernova studies (PMID 28012184; replicated 2020):
  high-fat adaptation worsens exercise economy and negates training gains. Nothing anywhere
  recommends the 45–55 %E days the residual currently produces.
- **Carbohydrate is what carries high-expenditure days.** Thomas bands verified verbatim (3–5 /
  5–7 / 6–10 / 8–12 g/kg by volume; 12 g/kg the framework's top). Impey 2018 "fuel for the work
  required": the day-to-day dial is CHO only — fat is absent from the periodization framework.
  Observed elite practice agrees: Tour de France riders at ~6,000 kcal/day held fat near 23 %E
  with the surplus in CHO (Saris 1989); elite microperiodization moves CHO, not fat, on hard days
  (Heikura 2017, PMID 28387576).
- **Dropping the excess is anti-supported.** Deleting energy on the heaviest day is
  single-day/within-day low energy availability by construction — the exact pattern the RED-S
  (Mountjoy 2018) and within-day-deficiency literature (Fahrenholtz 2018, PMID 29205517: hours
  below −300 kcal ↔ elevated cortisol, menstrual dysfunction) warns against.
- **Spec-internal check.** The 4-hr bike worked example currently sits at 6.64 g/kg CHO — *below*
  the 8–12 band its own load implies — with 48 %E fat. Capping fat at 35 %E and redistributing
  lands it at 8.8 g/kg (mid-band, no clamp collision); a 30 %E cap gives 9.6 g/kg. Tight g/kg
  ceilings (1.0 g/kg) overshoot the 12 g/kg clamp — the %E parameterization is also the one the
  literature uses.

**QA recommendation:** `FAT_CEILING = 0.35 × target kcal` (top of AMDR; `[design]` within a
research-derived band — 30 %E is the defensible alternative). Excess energy **redistributes to
carbohydrate up to remaining headroom under the 12 g/kg clamp**; in the corner case where both
caps saturate, **let fat exceed the ceiling rather than drop energy** — energy adequacy (RED-S)
outranks macronutrient distribution. Ordering: cap and redistribute inside the energy-accounting
step, before the EA gate. Keep the existing 0.8 g/kg floor; note Thomas's 20 %E floor guidance as
the floor's citation opportunity. Redistribution **preserves target ≡ TDEE** — no third display
state needed except in the corner case.

---

## Q-015
### The NEAT model's rigor — flagged as future work
**Where:** raised 2026-08-13 by Xuan while reviewing pipeline runs across personas.
**Status: DEFERRED by ruling (Xuan, 2026-08-13) — not blocking; revisit when the model earns
attention.**

**The concern.** `NEAT = rmr × base_neat[tier] × day_modifier × lifestyle_mod` (F12–F14) is three
multiplicative constant tables, every constant uncited. The factors compound: a
recreational-tier athlete with an `ACTIVE` lifestyle reaches `0.30 × 1.10 × 1.15 = 0.38 × RMR`,
which in the persona runs produced ~2,600 kcal maintenance for a 60 kg recreational woman with a
45-minute jog — plausible for a genuinely active person, likely 200–300 kcal generous for a
sedentary-plus-jogging one. No leg of the model has a source; the whole thing is `[design]`.

**Fact check recorded with the flag (2026-08-13):** the app **does** currently collect and use
lifestyle — `nutrition_profile_screen.dart` offers the selector (default `mixed`) and
`calculate-daily-macros/pipeline.ts` threads it into NEAT, with lifestyle-variation tests in the
edge function. So this entry flags *model rigor*, not a missing or unused input. Many comparable
products treat activity level as a secondary parameter on a validated TDEE equation rather than a
multiplicative NEAT factor of their own design; ours is home-grown.

**Paths when revisited (recorded now, not chosen):**
1. Validate the constants against weight-stability data from real users (the honest empirical fix).
2. Lean on measured NEAT — retrospective mode already replaces the model with the Garmin daily
   summary (F23); the model only governs prospective days. Narrowing its job narrows the risk.
3. Replace with a published activity-factor scheme (e.g. PAL-based) so the constants are at least
   citable.
4. Damp the tier × lifestyle compounding (the corner that produced the generous number).

Nothing here blocks vectoring: the model is deterministic and vectorable as-is; the question is
whether its outputs are *calibrated*, which no vector can answer.
---

## Q-016
### When an athlete manually edits an engine input in Settings, which cached daily plans recalculate?
> **RULED — Xuan, 2026-08-17: today + future cached days only; past days are never recalculated.**
> Source-independent (any MANUAL write to an engine input, Settings merely the surface). Past
> plans are the historical record of what the athlete was told to eat. Folded into
> [platform-resolution.md](platform-resolution.md) "Athlete profile auto-update" as a dated
> post-ratification addition. Gates the app-side stale-targets fix + a behavioral chain test.
**Where:** raised 2026-08-17 via intake —
[`intake/2026-08-17-manual-input-change-invalidation.md`](../../intake/2026-08-17-manual-input-change-invalidation.md)
(full options, trade-offs and gates live there; this entry is the register hook, not a restatement).

The Garmin body-comp rung is ruled (raw propagation, `platform-resolution.md` "Athlete profile
auto-update"); the MANUAL rung — weight/height/BF/lifestyle/weekly-hours/opt-in/phase edited in
Settings — is specified nowhere. Options on file: today+future cached days (producer-recommended) /
all cached days / today only. Suggested home: `platform-resolution.md`, extending the profile
auto-update section to a source-independent policy. Gates the app-side fix for the stale-targets
bug (`ops/data/bug-reports/2026-08-17-profile-save-macro-cache-stale.md`).

---

## Q-017
### Carb cycling (F20) no longer changes the returned plan — the fat cap redistributes it away
> **RULED — Xuan, 2026-08-17, two-part.** (1) **Interim, this bundle version:** the no-op is the
> accepted v1 contract — F20 gates and pre-cap worked examples stand, implementations must not
> compensate; documented as a dated post-ratification addition in
> [baseline-macros.md](baseline-macros.md). (2) **Staged contract change, next bundle version:**
> qualifying carb-cycled days become exempt from assembly step 10b redistribution — fat absorbs
> the easy day (which is what "train low" physiologically means) — restoring the opt-in's
> observable effect. This partially reverses Q-014's redistribute-to-carb rule for exactly the
> cycled-day case; it alters the ratified pipeline, so it ships via `ship-bundle` as the next
> bundle version, never folded into v1. Spec text for the exemption is written THEN, not now.
> **2026-08-17, later the same day (Xuan): excluded from `daily-macros-dashboard@v2`** — v2 is the
> design-side skip contract (Q-D6) only; the 10b exemption waits for a later engine-side version.
**Where:** raised 2026-08-17 via intake —
[`intake/2026-08-17-carb-cycling-unobservable-under-fat-cap.md`](../../intake/2026-08-17-carb-cycling-unobservable-under-fat-cap.md).

QA reproduced the producer's finding independently: on any qualifying easy day the raw fat
residual exceeds the 30 %E cap in both branches, and because TDEE is carb-independent when fat is
above its floor, step 10b converges the post-cap carb to `(TDEE − prot×4 − fat_cap×9)/4` — the
identical plan with or without the 3.0 g/kg cycled baseline (reference athlete easy day: ~420 g
carb both ways in QA's rerun). F20's published gates and pre-cap worked examples stay true; only
end-of-pipeline observability is lost. Question on file: accept as a no-op (keep the setting),
exempt qualifying cycled days from 10b (fat absorbs the day), or retire/hide the opt-in. Note the
impact split: accepting/documenting is a post-ratification addition; exempting cycled days from
10b alters the ratified pipeline (contract change → next bundle version).
