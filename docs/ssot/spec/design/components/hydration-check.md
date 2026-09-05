# Design SSOT — Component: Hydration Check

**Status: RATIFIED v1 (Xuan, 2026-08-26).** Extracted 2026-08-26 from the reference rendering; reviewed on the spec-review page (5/5 contracts checked).
**Component contract** — the inline urine-check control that individualises the pre-workout fluid
**target**. Owns its state machine, its answer→effect map and its copy register wherever it appears.
Its *placement* (inside the snack-window feeding card) and its cross-component write (the fluid
target and the added-water row) are the **surface's** business —
[`../surfaces/pre-workout-before-card.md`](../surfaces/pre-workout-before-card.md).
**Tokens:** [`../tokens.md`](../tokens.md). **Behaviour authority:**
[`../../fueling/pre-workout-hydration.md`](../../fueling/pre-workout-hydration.md) v6 *The urine
check* as amended by **PW-021** (athlete-timed; no live clock). This file contracts *presentation
and the state machine*; the numbers and the ±4 ml/kg effect are the math SSOT's.
**Reference rendering:** [`../renderings/pre-workout@v2.html`](../renderings/pre-workout@v2.html)
(ratified Xuan 2026-08-26; frozen copy of `prototypes/pre-workout/v4.html`; supersedes @v1).

## When it exists at all

**Present only when `timeBeforeWorkoutMin >= T_REF`** (the "2 h or more ahead" plans). On sub-2 h
plans the control does **not** render — its slot carries nothing on the surface, and the pale-yellow
cue lives in the fine print (surface S-4; PW-021 point 3). This is a **suppression contract**: a
screenshot of a 90-minute plan cannot show that the control is *absent by rule* rather than
scrolled-off. **No live clock** gates it (PW-021, reversing PW-020's `currentLeadMin` predicate):
once present it is available for the life of the plan; *when* to answer is carried by copy, not by
enabling/disabling the control.

## State model

```
answer ∈ { NONE, PALE, DARK, NOT_YET, NOT_SURE }     # NONE = the TO-DO state
```

Exactly one at a time. `NONE` renders collapsed as a chip (`TO-DO`); tapping expands the question in
place. Answering collapses to a result line with a **Change answer** affordance; Change answer
returns to `NONE` **and reverts every write** (H-4).

## States — answer × what shows × what it writes

| `answer` | Result line (63 kg mock) | Fluid-target effect | Added row |
|---|---|---|---|
| `NONE` | chip `TO-DO`; expands to the question + 4 answers + caveat | — | — |
| `PALE` | "Pale yellow · target unchanged" | **none** | none |
| `DARK` | "Dark · target raised to 25 oz" | **+`TOPUP_ML_KG·BW`** (rounds 16 → 25 oz) | 8 oz water, tagged *added by hydration check*, **unless already covered** |
| `NOT_YET` | "Not yet · target 25 oz[, already covered]" | **= DARK** | same as DARK |
| `NOT_SURE` | "Not sure · no change to your target" | **none** | none |

- `NOT_YET` maps to `DARK` (ACSM 2007: "does not produce urine" is the dark branch) — hydration v6
  check table. `NOT_SURE` maps to `unknown` → treated as pale (v6, PROVISIONAL). The four display
  answers collapse onto the spec's three `hydrationCheck` values; assert the map, not the labels.
- **"Already covered" is not a fourth effect — it is the stateless-consumer rule.** The target still
  rises by `4·BW`; the water row is added only when currently-delivered fluid is **below** the new
  target, per hydration v6 (*"the amount still to take is `fluidMl` minus that intake, floored at
  0"*). Verified: with 48 oz already in the meal, a Dark/Not-yet answer raises the target to 25 oz
  and adds **nothing**. The target moving is the contract; the row is the means.

## Copy register (ships as-is — held to accuracy, not regenerated)

| Slot | String |
|---|---|
| Question | "Is your urine pale yellow right now?" |
| Timing (no clock) | "Do this about two hours before you start, once you've finished your pre-run meal." |
| Riboflavin caveat | "On a multivitamin or B-complex? It turns urine yellow on its own — don't read that as dark — choose Not sure." |
| PALE body | "You're hydrated. Your fluid target is unchanged." |
| DARK body (add) | "Your fluid target rises to 25 oz. An 8 oz water entry was added to help you get there — adjust it like any other item." |
| DARK/NOT_YET body (covered) | "Treated as dark for now — update after you go. Your fluid target rises to 25 oz. What you already have planned covers it, so nothing was added." |
| NOT_SURE body | "Recorded with no change to your target. Check when you can and update your answer." |

The caveat and the timing line are the two copy claims that carry a physiological load
(riboflavin → false-dark; "finish ~2 h before" → Thomas's terminal edge); they answer to
hydration v6, not to the designer. The `25 oz` in the DARK/NOT_YET strings is illustrative
(63 kg); real copy interpolates `round(fluidMl / 29.5735)` oz.

## Gestures

| # | Gesture | Contract |
|---|---|---|
| H-1 | Tap the collapsed chip | Expands the question in place; never navigates |
| H-2 | Tap an answer | Sets `answer`; writes per the state table; collapses to the result line |
| H-3 | Tap **Change answer** | → `answer = NONE`; **reverts the target and removes the added water row** (H-4); re-expands |
| H-4 | (write/revert invariant) | Only `fluidMl` (the target) and, conditionally, the one tagged water row change. The **band never moves** on any answer (hydration inv. 8b); the tier structure, other feedings and the summary carbs/sodium are untouched |
| H-5 | State-change emission | The control **emits** the target change; it does not repaint the summary itself. What re-totals the FLUIDS stat is the surface (S-2) |

## Token usage

The control's ring icon and its accents render in **`electrolyte`** (rgb(28,249,207)) — permitted by
**Q-D8 (RULED Xuan 2026-08-26, option a)**, which widened `electrolyte` to the per-workout fuel side.
`tokens.md`.

## Conformance (design vectors)

- **Golden (L1):** one per state row — `NONE` (chip), `PALE`, `DARK` (with added water row),
  `NOT_YET` (already-covered variant), `NOT_SURE` — at token-resolved colors, from the 63 kg
  canonical mock. Plus the **absent** state: a 90-minute plan render showing **no control** (the
  suppression golden).
- **Widget/Patrol (L2):** H-1 expand; H-2 for each answer asserting the `fluidMl` write (target
  +`4·BW` on DARK/NOT_YET, unchanged on PALE/NOT_SURE) **and inv. 8b (band bytes identical across
  all answers)**; the **already-covered negative test** (deliver ≥ target first → target rises, no
  row added); H-3 revert (target back, tagged row gone); the **suppression negative test**
  (`timeBeforeWorkoutMin < T_REF` → no control node in the tree).
- Answer→`hydrationCheck` map test: PALE/NOT_SURE → no top-up; DARK/NOT_YET → `TOPUP_ML_KG·BW`.
- **A golden may only be regenerated after this spec changes** — never to make a red test pass.

## Do not encode as truth (prototype scaffold)

- Switching the `plannedAhead` prop resets `answer` to `NONE` and clears the added row. That is
  scaffold for the demo's scenario switcher; the shipping app has one plan, not a switcher — no
  persistence contract is claimed here.

---

## AMENDMENT A1 — DARK-path row = the shortfall, not a fixed 8 oz (Xuan, 2026-09-03)
**Authority:** RULING-DESK 2026-09-03 ("apply ADJ-1") on
`intake/2026-08-26-before-card-food-embedded-fluid-and-fixed-8oz-topup.md` Q2, option (b).
**Effective at the food-recommendation bundle's implementation — ratified text above stands until then.**
- The `DARK` (and therefore `NOT_YET`) row's added water entry becomes **the remaining shortfall,
  ceil'd to the nearest 0.5 cup** (`ceil((target − delivered) to 4 oz granularity)`), floored at 0 —
  **never a fixed 8 oz, never past the fluid ceiling**. (hydration v6's own arithmetic:
  `fluidMl − intake`, floored at 0; R-01 rounding gives the 0.5-cup granularity.)
- Copy register, DARK body (add): "Your fluid target rises to <target>. A <amount> water entry was
  added to close the gap — adjust it like any other item." (replaces the fixed "8 oz" sentence).
- Q1 of the same intake file was closed by catalog-conventions A3 (embedded water counts); band
  discipline lives in `spec/fueling/food-recommendation.md` §5/§6.
