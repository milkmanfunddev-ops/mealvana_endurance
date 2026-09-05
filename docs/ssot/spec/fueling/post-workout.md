# SSOT — Post-Workout Recovery Fueling

**Status: RATIFIED v1 (Xuan, 2026-08-13).** §6's two design questions ruled same day; §6 Q3
(the `hoursToNextSession` resolution ladder) is post-ratification wiring in
`platform-resolution.md`, not part of this contract.
**Origin:** F-16 of the macro-dashboard design reconciliation — the dashboard ships a recovery
window and a recovery feeding, and no document owned either. Literature pass 2026-08-13.
**Engine:** none yet. Consumed by the dashboard's After-Ride window and recovery copy; the numbers
below also bound what any future recovery-feeding selector may claim.
**Placement:** `spec/fueling/` because this is a *workout-anchored window*, like pre- and
during-workout — not a daily quantity. Its boundary with the daily engine is contractual (§5).

## The rule
> How urgently you refuel is decided by ONE variable: **when the next fuel-demanding session is.**
> Close (< 8 h): refuel aggressively, starting now. A day away (the recreational default): no
> urgency — hit the day's totals, eat normally. Protein is the same in both branches.

**The claim this spec exists to kill:** the unconditional "refuel within 30 minutes." The
30-minute figure survives only as a *rate* observation (delaying carbohydrate halves the early
glycogen-resynthesis rate — Ivy 1988), and that rate only matters when recovery time is short.
Both position stands explicitly relax timing to preference when a full day separates sessions.
Universal urgency is the one claim the literature actively rejects.

---

## Inputs

| Input | Type | Notes |
|---|---|---|
| `hoursToNextSession` | double? | to the next **fuel-demanding** session (§6 Q2). `null` → relaxed branch |
| `bodyWeightKg` | double | |
| `sessionJustCompleted` | session | must itself be fuel-demanding for any branch to fire (§6 Q2) |

## The algorithm

```
POST_URGENT_THRESHOLD_H = 8.0          # below this, the aggressive protocol applies
POST_URGENT_CARB_RATE   = 1.0..1.2     # g/kg/h
POST_URGENT_DURATION_H  = 4.0          # aggressive refeeding window length
POST_FALLBACK_CARB_RATE = 0.8          # g/kg/h, appetite-limited alternative...
POST_FALLBACK_PROT_RATE = 0.2..0.4     # ...with co-ingested protein at this rate
POST_PROTEIN_DOSE_GKG   = 0.3          # g/kg (~20–40 g band), both branches
POST_PROTEIN_WINDOW_H   = 2.0          # deliver the dose within this
POST_PROTEIN_REPEAT_H   = 3..5         # then repeat every 3–5 h

if hoursToNextSession != null and hoursToNextSession < POST_URGENT_THRESHOLD_H:
    # URGENT branch
    carbs   = POST_URGENT_CARB_RATE × bodyWeightKg per hour, for POST_URGENT_DURATION_H,
              starting as soon as practical after the session
    # appetite-limited fallback: POST_FALLBACK_CARB_RATE carbs + POST_FALLBACK_PROT_RATE protein
else:
    # RELAXED branch — the recreational default, and the branch for unknown
    carbs   = no timing requirement; the day's total (daily-macros bands) is the target
    anchor  = first post-workout meal within ~2 h — a habit anchor, not a physiological window

protein (both branches) = POST_PROTEIN_DOSE_GKG × bodyWeightKg within POST_PROTEIN_WINDOW_H,
                          repeated every POST_PROTEIN_REPEAT_H hours
```

**`null` → relaxed, deliberately.** Urgency is the claim that needs evidence; the absence of
schedule information licenses the default, not the exception.

**The 8–24 h band** is unratified territory in the literature (the studies contrast < 8 h with
~24 h). Ruling recorded here: the band follows the **relaxed** branch with copy softened toward
"earlier rather than later today." `[design]` — see §6 Q1.

## Copy contract (the F-07 fix, made durable)

| State | Badge | Copy direction |
|---|---|---|
| urgent | `START NOW · refuel through the next 4 h` | "Back at it within 8 hours — start refueling right away and keep carbs coming for the next 4 hours." |
| relaxed / unknown | `WITH YOUR NEXT MEAL` | "No rush — your next normal meal covers it. Aim for your carb total today and ~20–30 g of protein within a couple of hours." |

**No surface may ship an unconditional refueling deadline.** "Within 30 minutes" and "within the
hour" are both retired; a deadline may only appear under the urgent branch.

---

## §5 · Boundary with the daily engine — contractual, prevents double-counting

**Post-workout carbohydrate is a TIMING redistribution of the day's total, never an addition to
it.** The daily-macros pipeline already prices today's sessions into `carb_g` (session demand) and
tomorrow's recovery into tomorrow's plan (recovery debt, Q-013). The urgent branch says *when* a
slice of today's already-computed total should be eaten; it adds zero grams. A consumer that adds
`1.2 g/kg × 4 h` on top of the daily total is double-counting — that is the conformance check that
matters most here.

Division of labor: **recovery debt** (multi-day-context) = tomorrow's plan remembering today;
**this spec** = today's plan, sequenced. The two never touch the same day's number.

## Constants — basis and confidence

| Constant | Value | Basis | Confidence |
|---|---|---|---|
| Urgent threshold | < 8 h | Thomas 2016 Table 2, verbatim: *"Speedy refuelling: <8 h recovery between 2 fuel-demanding sessions"*; A&S 2013 | **High** |
| Urgent carb rate | 1.0–1.2 g/kg/h | Thomas 2016: *"~1–1.2 g/kg/h during the first 4–6 hours"*; Table 2: *"1–1.2 g/kg/h for first 4 h"* | **High** |
| Urgent duration | 4 h | Table 2's figure (body text says 4–6; the table is the safer citation) | **High**, edge `[design]` |
| Appetite fallback | 0.8 CHO + 0.2–0.4 protein g/kg/h | Kerksick 2017 (explicit substitute); Betts & Williams 2010; Jentjens 2001 (protein adds nothing at ≥ 1.2) | **High** |
| Protein dose | 0.3 g/kg (20–40 g) | Moore 2009 (20 g max-stimulation, n=6 resistance — extrapolated); Thomas 2016 *"0.25–0.3 g/kg... 15–25 g"*; Kerksick up to 0.40 | **High** for the range; 0.3 flat is `[design]` inside it |
| Protein window / repeat | ~2 h, then 3–5 h | Thomas 2016 (*"0–2 h after"*, *"every 3–5 hours"*) | **High** |
| Rate penalty for delay | ~50 % lower early resynthesis | Ivy 1988 — the true kernel of the 30-min myth | **High** (as mechanism) |
| 8–24 h band → relaxed-softened | — | **`[design]`** — the literature is silent between its two endpoints | Low |
| `null` schedule → relaxed | — | **`[design]`** — urgency requires evidence | Medium |
| Relaxed-branch ~2 h meal anchor | — | **`[design]`** — adherence scaffold, not physiology; must never be presented as a window | Medium |
| Universal 30-min window | **rejected** | A&S 2013 (MPS: timing effect vanishes when total protein controlled — Schoenfeld meta 2013; sensitization ≥ 24 h — Kerksick 2017) | **High** |

## What is deliberately NOT in this spec

- **High-GI requirement under the urgent branch** (Kerksick mentions GI > 70): omitted — GI is not
  a selection filter anywhere in this repo (pre-workout precedent), and food choice belongs to a
  future recovery-feeding selector.
- **Caffeine co-ingestion** (3–8 mg/kg, Kerksick): a performance-context tool, out of scope for a
  recreational recovery default.
- **Rehydration and sodium**: owned by the hydration/sodium specs; a future post-workout fluid
  section must land there, not here.

## §6 · Formerly open questions — 1 and 2 RULED (Xuan, 2026-08-13)

1. **The 8–24 h band — RULED: relaxed branch with copy softened** toward "earlier rather than
   later today." `[design]` — the literature contrasts < 8 h with ~24 h and is silent between; a
   future pass on twice-daily-adjacent schedules could firm it.
2. **"Fuel-demanding session" — RULED: an endurance session ≥ 60 min, or any session the
   during-workout spec fuels. A strength-only hour does NOT trigger the urgent branch** (consistent
   with Q-003's finding that a strength hour costs ~27 g — there is nothing to speed-replenish).
   Applies to both the gate on `sessionJustCompleted` and the meaning of `hoursToNextSession`.
   `[design]`.
3. **Source of `hoursToNextSession`** (open): TP calendar → athlete's stated plan → null. The
   resolution ladder belongs in `platform-resolution.md` once this spec ratifies — a wiring task,
   not a blocker.

## Conformance

No engine implements this yet. When one does: (1) branch selection across the threshold
(7.99/8.0/null); (2) the urgent branch's grams are a subset-in-time of the day's total, never an
addition (§5 — the highest-value check); (3) no output surface carries an unconditional deadline
string; (4) protein dose identical across branches; (5) fallback engages only under the urgent
branch. Vectors: `qa/vectors/fueling/post-workout.json` (after ratification, via spec-to-vectors).

## Literature

- **Thomas DT, Erdman KA, Burke LM.** *Position of the Academy of Nutrition and Dietetics,
  Dietitians of Canada, and the ACSM: Nutrition and Athletic Performance.* Med Sci Sports Exerc.
  2016;48(3):543–568. PMID 26891166 / JAND 26920240. Refueling: *"the rate of glycogen resynthesis
  is only ~5% per hour"*; *"~1–1.2 g/kg/h during the first 4–6 hours"*; Table 2 *"<8 h recovery
  between 2 fuel-demanding sessions — 1–1.2 g/kg/h for first 4 h then resume daily fuel needs"*;
  and the relaxation: *"As long as total intake of carbohydrate and energy is adequate... meals
  and snacks can be chosen... according to personal preferences of type and timing."* Protein:
  *"0.25–0.3 g/kg body weight or 15–25 g"*, 0–2 h, every 3–5 h.
- **Aragon AA, Schoenfeld BJ.** *Nutrient timing revisited: is there a post-exercise anabolic
  window?* J Int Soc Sports Nutr. 2013;10:5. PMID 23360586. Window support *"far from
  definitive"*; expedited glycogen repletion matters only when *"the duration between
  glycogen-depleting events is limited to less than approximately 8 hours."*
- **Schoenfeld BJ, Aragon AA, Krieger JW.** *The effect of protein timing on muscle strength and
  hypertrophy: a meta-analysis.* J Int Soc Sports Nutr. 2013;10:53. PMID 24299050. The timing
  effect disappears once total protein is controlled.
- **Kerksick CM, et al.** *ISSN position stand: nutrient timing.* J Int Soc Sports Nutr.
  2017;14:33. PMID 28919842. Rapid-restoration protocol (< 4 h recovery): 1.2 g/kg/h high-GI or
  0.8 CHO + 0.2–0.4 protein; protein sensitization ≥ 24 h; 20–40 g (0.25–0.40 g/kg) every 3–4 h.
- **Ivy JL, et al.** *Muscle glycogen synthesis after exercise: effect of time of carbohydrate
  ingestion.* J Appl Physiol. 1988;64(4):1480–1485. PMID 3132449. The delay-halves-the-rate
  finding — the kernel of truth inside the 30-minute myth.
- **Moore DR, et al.** *Ingested protein dose response of muscle and albumin protein synthesis
  after resistance exercise in young men.* Am J Clin Nutr. 2009;89(1):161–168. PMID 19056590.
  MPS maximal at 20 g (n=6, resistance — extrapolated to endurance with that caveat).
- **Jentjens RL, et al.** *Addition of protein and amino acids to carbohydrates does not enhance
  postexercise muscle glycogen synthesis.* J Appl Physiol. 2001;91(2):839–846. PMID 11457801.
- **Betts JA, Williams C.** *Short-term recovery from prolonged exercise.* Sports Med.
  2010;40(11):941–959. DOI 10.2165/11536900. Protein co-ingestion helps only when CHO is
  suboptimal. *(PMID not independently verified.)*
- **Margolis LM, et al.** Meta-analysis, 2020. PMID 32826640. Consistent with the conditional
  co-ingestion finding.
