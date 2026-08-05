# Daily Macros — Open Questions Register

Contradictions, gaps and unstated rules found while distilling the Notion pages into
`spec/daily-macros/` on 2026-07-28. **These are spec-vs-spec problems, not code deviations** —
nothing here has been checked against the implementation yet. Code-vs-SSOT findings belong in
[`DEVIATIONS.md`](../../DEVIATIONS.md); these belong to Xuan as the SSOT author.

Each one blocks or shapes vectoring, so they should be ruled on before
[PLAN.md](../../PLAN.md) step 4.

| ID | Subject | Severity | Blocks vectors? |
|---|---|---|---|
| [Q-001](#q-001) | Rounding of intermediates | **high** | yes — every fat value |
| [Q-002](#q-002) | Multi-session path rounds, single-session path doesn't | medium | yes |
| [Q-003](#q-003) | Strength carb demand: 27 g vs 40 g | **high** | yes |
| [Q-004](#q-004) | `fat_mod` is specified but never applied | medium | no |
| [Q-005](#q-005) | Is `RACE_WEEK` forced when tomorrow is a race? | medium | yes |
| [Q-006](#q-006) | EA override can breach the carb ceiling | **high** (safety) | yes |
| [Q-007](#q-007) | Pre-race session kcal: 1050 vs 1479 | medium | yes |
| [Q-008](#q-008) | Two EA test rows don't reconcile | low | no |
| [Q-009](#q-009) | No recompute after the EA override | **high** (safety) | yes |
| [Q-010](#q-010) | HR-derived IF referenced but unspecified | low | no |
| [Q-011](#q-011) | `resolveRMR` is not mode-gated | low | no |
| [Q-012](#q-012) | `sources` / `delta` object shape underspecified | low | no |
| [Q-013](#q-013) | `yesterday_tss` when yesterday was a double | **RULED 2026-07-29** — sum | no |

---

## Q-001
### Are intermediate carb/protein values rounded before the fat residual?
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
**Where:** Iteration 5 input table (`garmin_avg_hr` — "can derive IF if TP unavailable") and the
edge case "TP planned IF exists but Garmin also has HR data → TP IF takes priority over Garmin
HR-derived IF", vs Formula 22's IF ladder, which has no Garmin rung at all. **Severity: low.**

As written, `garmin_avg_hr` is unused and the ladder falls straight from TP to `ZONE_DIST`.

**Recommendation:** confirm it is deferred (like CTL staleness) and mark it so, or specify the
derivation and add the rung between `TP_PLANNED` and `ZONE_DIST`.

---

## Q-011
### `resolveRMR` is not gated on `mode`
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
