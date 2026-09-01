# Notes — Pre-Workout Sodium

Companion to [`pre-workout-sodium.md`](./pre-workout-sodium.md), which is the SSOT and is
deliberately kept to **the rule and the literature only**.

**Nothing in this file is ratified.** Where it disagrees with the SSOT, the SSOT wins.

---

## 1 · The decision (v2, 2026-07-30)

**Mealvana does not set a pre-workout sodium target.**

This follows the precedent already set for post-workout: where the answer is genuinely undecided in
the literature and personal to the athlete, the product declines to recommend rather than
manufacturing a number. It is a product decision made on evidence, not a gap to be filled later.

### Lineage

| Version | Date | Ratified by | Rule |
|---|---|---|---|
| v1 | 2026-07-26 | Xuan | Tier 1 `450 mg [300–600]`, tier 2 `150 mg [100–200]`, tier 3 `0` |
| **v2** | **2026-07-30** | **Xuan** | **No target. Fields emit `null`.** |

### The five reasons

**1 · Both current position statements decline to quantify it.** Thomas 2016 replaced Sawka 2007,
kept and *widened* the fluid figure, and dropped the sodium concentration — leaving only "Sodium
consumed in pre-exercise fluids and foods may help with fluid retention." NATA 2017, writing
independently a year later, also gave no number and said sodium "should be individualized." Two
expert panels revisited this and neither restated a figure. Declining to quantify what the field
declines to quantify is fidelity, not a gap.

**2 · Our band never reconciled with the one source that did give a number.** D-007: 300–600 mg is
not derivable from 20–50 mEq/L at *any* drink volume, because the band ratios don't match (2.0× vs
2.5×). Three different volumes were assumed across the stack — the SSOT said ~390 ml, the shipped
drawer string said 500 ml, and neither produces 300–600.

**3 · The documented limitation pointed at the wrong population.** At the 450 mg target the
concentration is `75000 / BW` mg/L, so 20–50 mEq/L held only for **65.2 kg ≤ BW ≤ 163 kg**. The
under-concentration case we documented needs BW > 163 kg and effectively never fired; the case that
*did* fire — over-concentration — hit **every athlete under ~65 kg** and was undocumented.

**4 · It was not actionable.** Ordinary pre-workout food overshoots any target we would set. An
RXBAR plus energy chews delivers **325 mg** against a 100–200 mg band (observed in-product); a bagel
with peanut butter is ~737 mg. Xuan's own observation in the 2026-07-29 session: *"there is no way
it can cut the sodium out, because the formula kit has so much sodium already."*

**5 · Nobody is left unserved.** `during-workout-sodium.md` is built on Baker 2016 (n=506) with
per-athlete concentration tiers, and is where sodium for hot or long sessions is handled. Dropping
the pre-workout target removes the weakest sodium claim while keeping the strong one.

### What we lose, stated plainly

The ability to flag *under*-sodium before a long hot session. Judged acceptable because
during-workout sodium covers that athlete, but it is a real loss and not waved away.

There is also a UX judgement — whether an endurance app showing carbs and fluid but no sodium target
before a workout reads as incomplete. That is a product question, not a science one.

### What was considered and rejected

**Deriving sodium from the fluid target** (`sodiumMg = fluidL × 460…1150 mg/L`). Structurally this
was attractive: it would have dissolved D-007 by construction, made the tier coupling to hydration
mechanical rather than declared, and removed the light-athlete over-concentration. It was rejected
because it inherits the deeper problem — it computes a precise per-athlete number (393 mg at 65 kg)
from a superseded figure the current statements chose not to restate, and it would have looked *more*
authoritative than the round 450 it replaced while resting on the same evidence.

---

## 2 · Purpose and mechanism (retained — still true, still uncomputed)

Before exercise, sodium **retains** the fluid you drink — it signals the kidneys to hold plasma
volume — rather than replacing sweat losses.

**Mechanism.** Plain water dilutes plasma sodium; the kidneys read the dilution and excrete the
excess as urine, often before it reaches working muscle. Sodium taken with the fluid signals the
kidneys to hold it, preserving plasma volume into the start of exercise.

**This mechanism is not in dispute** — it is the one part of the sodium story every source agrees
on, including both current statements, which affirm it *in words* while declining to attach a
number. That is precisely why v2 keeps the qualitative copy and drops the quantity.

---

## 3 · Sodium loading — the scope fence (verified 2026-07-30, retained)

The drawer's S4 panel draws a boundary between routine pre-workout sodium and sodium *loading*.
**The boundary remains useful under v2** — arguably more so, since a user who reads "no target" may
go looking for loading protocols online.

QA read both PubMed records. The drawer cited *"Sims et al. (2007)"* across two journals; these are
**two separate studies**:

- **Women** — Sims ST, Rehrer NJ, Bell ML, Cotter JD. *Preexercise sodium loading aids fluid balance
  and endurance for women exercising in the heat.* J Appl Physiol. 2007;103(2):534–541.
  doi:10.1152/japplphysiol.01203.2006. PMID 17463297. n = 13 trained cyclists. TTE **98.8 vs
  78.7 min**; plasma volume +4.4 % vs +1.9 %; core-temp rise 1.2 vs 1.6 °C/h.
- **Men** — Sims ST, van Vliet L, Cotter JD, Rehrer NJ. *Sodium loading aids fluid balance and
  reduces physiological strain of trained men exercising in the heat.* Med Sci Sports Exerc.
  2007;39(1):123–130. doi:10.1249/01.mss.0000241639.97972.4a. PMID 17218894. n = 8 trained runners.
  Capacity **96.1 vs 75.3 min**; plasma volume +4.5 % vs 0.0 %.

**The "+26 %" figure is accurate** — (98.8 − 78.7) / 78.7 = **25.5 %** — but comes from the women's
study only and must not be presented as a general finding. **High confidence is overstated** for two
single trials at n = 13 and n = 8; Medium is defensible.

**The protocol description is accurate:** 164 mmol Na⁺/L at 10 ml/kg, seven portions from 105 min
pre-exercise — **≈2,400–2,900 mg**, which is the number that makes the scope fence land.

---

## 4 · Explanation layer under v2

The archived drawer (`pre-workout-sodium.html`) was built to explain a target that no longer exists.
Under v2 it is **not a calculation drawer**. Required changes:

- **Remove the header target and range chip.** No `<target> mg`, no `300–600 mg` chip. If delivered
  sodium is shown, show it as an observed total with no range bar and no in-range state.
- **Remove the Calculation panel entirely.** There is no calculation.
- **Rewrite S2** ("Where does 300–600 mg come from?"). It should now explain *why there is no
  target* — the two current statements decline to quantify it, and ordinary pre-workout food already
  supplies sodium in this range.
- **Retain S1** (retention mechanism) — still true and still the reason the qualitative copy exists.
- **Retain S3 reframed.** "Why isn't sodium scaled to body weight?" becomes moot; the useful version
  is why we don't set a number at all.
- **Retain S4** (not sodium loading), with the citation split and confidence downgraded per §3.

---

## 5 · Deviations closed by v2

| ID | Effect |
|---|---|
| **D-007** — band not inside its cited source; limitation backwards | **Closed.** No band, no derivation, no limitation. Resolution taken was neither (a), (b) nor (c) as originally framed — the constant was removed rather than re-derived or re-justified. |
| **D-008** — confidence-badge and citation drift on the 10–120 min window | **Closed.** No windows, no confidence badges to drift. |
| **D-013** — sodium and hydration tier boundaries diverged | **Closed.** Sodium has no tiers, so there is nothing to keep in sync. Note the root cause still stands for other slices: a spec that *declares* a dependency on another spec needs it recorded somewhere mechanical. |
| **D-006** — drawers render tier 1 only | **Closed for sodium** (no tiers to branch on); **still open for hydration**, which now has four. |

---

## 6 · Question for Rachel — reframed

The earlier questions assumed we were choosing a band. We are not. The single question worth her
time now:

> **Both current position statements declined to quantify pre-exercise sodium, and ordinary
> pre-workout food already exceeds any target we would have set. We have decided to drop the target
> and keep only qualitative guidance — a salty snack or electrolyte drink with pre-run fluid. Talk
> us out of it?**

If she has a reason to keep a number, we will have learned something the literature did not tell us.
Worth attaching: the `75000 / BW` concentration table from §1 reason 3, and the in-product
observation that an RXBAR plus chews delivers 325 mg against our old 100–200 mg band.

---

## 7 · Historical record — what v1 rested on

Preserved so a future reader does not re-derive it.

| Source | Status | What it gave for pre-exercise sodium |
|---|---|---|
| Sawka 2007 (ACSM) | **Superseded** | 20–50 mEq/L — the *only* number, in the *Before Exercise* section, p. 384, verified verbatim by QA |
| Thomas 2016 (ACSM/AND/DC) | **Current** | **No number.** "may help with fluid retention" |
| NATA 2017 | **Current** | **No number.** Rec 18 (SOR: B): "should be individualized" |

A caveat once carried by D-007 — that the 20–50 mEq/L band might be a *during*-exercise figure,
which "could dissolve the whole finding" — was **closed on 2026-07-30**. QA read p. 384 directly; it
sits in the *Before Exercise* section, distinct from the during-exercise figure (20–30 mEq/L, from
the IOM) in the same document. The finding stood; the constant was dropped for other reasons.
