# During-Workout Sodium — Transparency Copy V1

> **Status:** Design review — During-workout sodium section. Part of the Nutrition Transparency drawer series.

## Live Interactive Prototype

Hosted at claude.site (see Notion for live embed).

---

## Overview

This page documents the copy, structure, and interaction design for the **during-workout sodium section**. Sodium is the simplest of the three macro sections — it uses a 2-step calculation and inherits all gate, duration, floor, ceiling, and multi-segment logic from the fluid algorithm. Sodium just multiplies.

**Core principle:** Replace 100% of the sodium in the fluid you're drinking. Since fluid already determines how much to drink, sodium simply ensures the concentration of that fluid matches your sweat sodium concentration.

---

## Calculation Chain (2 Steps)

| Step | What it does | Source |
|------|-------------|--------|
| 1. Sodium concentration | From sweat test or salt type category (25th/50th/75th pct) | Baker 2016, n=506 |
| 2. Multiply by fluid rate | sodium_mg_hr = (fluid_ml_hr ÷ 1000) × sodium_conc | Tiller 2019, Mosler 2020 |

All gate logic, floor, ceiling, duration scaling, and multi-segment redistribution are inherited from the fluid algorithm. Sodium has no independent logic.

---

## Formula Display

```
① average salt        → 825 mg/L  (50th pct)
② (645 ml/hr ÷ 1000) × 825 = 532 mg/hr
────────────────────────────────────────
   532 mg/hr × 1.5 hr = 798 mg total

↓ floor   = (423 ml/hr ÷ 1000) × 825 = 349 mg/hr
↑ ceiling = (800 ml/hr ÷ 1000) × 825 = 660 mg/hr
  range   → 349–660 mg/hr
```

- 645 ml/hr is the fluid recommendation from the fluid section
- Floor and ceiling derive directly from fluid floor/ceiling × sodium concentration
- Inherited note shown below formula: "The 645 ml/hr fluid rate, floor, and ceiling all come from the Fluids section. Sodium automatically adjusts when fluid adjusts."

---

## Salt Type Tiers

| Type | Concentration | Percentile | Source |
|------|--------------|------------|--------|
| Low | 650 mg/L | 25th pct | Baker 2016 |
| Average | 825 mg/L | 50th pct | Baker 2016 |
| High | 1,000 mg/L | 75th pct | Baker 2016 |

Dataset: 506 athletes, whole-body predicted sweat Na+: 826 ± 239 mg/L. Percentiles estimated assuming normal distribution.

---

## Always-Visible Copy

Your sodium target is a simple multiplication of your fluid intake rate by your sweat sodium concentration. Dial in your test results if you have one.

---

## The Full Story Copy

### Why does sweat sodium concentration matter?

Sweat sodium concentration varies 10-fold between individuals — from roughly 200 to 2,000 mg/L. This isn't about fitness or diet; it's largely genetic and relatively stable within an individual. Getting your sodium category right has a bigger impact on your electrolyte strategy than any product choice.

**Salt type tiers:** Low · 650 mg/L · 25th pct | Average · 825 mg/L · 50th pct | High · 1,000 mg/L · 75th pct

*Baker et al. (2016) — Journal of Sports Sciences, n=506 · mean 826 ± 239 mg/L* · **High confidence**

---

### How do I know which type I am?

You can estimate your salt type from experience. A sweat sodium test (available through Precision Hydration or a sports lab) gives you a precise number.

**Indicators that suggest High:**
- White residue or crust on skin or clothing after exercise
- Eyes sting from sweat
- Strong craving for salty food after workouts
- Sweat tastes noticeably salty

**None of the above → Low or Average**

*Baker (2017) — clinical/practitioner consensus on self-report indicators* · **Medium confidence**

---

### Why isn't a standard sports drink enough?

Standard sports drinks are formulated at roughly 400–500 mg/L sodium — well below the average athlete's sweat sodium concentration of 825 mg/L. At 645 ml/hr fluid intake, a standard drink delivers ~290 mg/hr — about **54% of the target.**

| Source | Na (mg/L) | At 645 ml/hr |
|--------|----------|-------------|
| Standard sports drink | ~450 | ~290 mg/hr |
| High-sodium drink mix | ~825 | ~532 mg/hr |
| + Electrolyte tablet | +300–400 | +194–258 mg/hr |
| Salt capsule | +215 each | per capsule |
| **Your target** | **825** | **532 mg/hr ✓** |

---

### Where does the 349–660 mg/hr range come from?

Sodium inherits its range directly from the fluid algorithm's floor and ceiling — multiplied by your sodium concentration. There are no independent sodium floor or ceiling values. If the fluid algorithm raises or caps your intake, sodium adjusts automatically. The two are always synchronized.

**Range derivation:**
- Floor: fluid_floor_ml_hr ÷ 1000 × sodium_conc
- Ceiling: fluid_ceiling_ml_hr ÷ 1000 × sodium_conc

> ⚠️ **Transparency note:** The principle of replacing 100% of sodium in consumed fluid is supported by ISSN ultra guidelines (Tiller 2019) and DGE position stand (Mosler 2020), but rated **Medium confidence** — the evidence is stronger for the direction than for the exact percentage.

---

## Design Decisions

### Why only 2 steps?

Sodium is genuinely simpler than fluid and carbs — it has no duration gate, no independent floor/ceiling, no multi-segment redistribution. The 2-step formula chain accurately reflects the algorithm's simplicity. Inflating it with inherited steps would be misleading.

### Inherited note below formula

A small info callout explicitly links the fluid rate used in the formula to the Fluids section. This is the most important transparency element in this section — the athlete needs to understand why changing their sweat rate setting will also change their sodium target.

### Product comparison table

Instead of abstract mg numbers, the Full Story shows how real products map to the target at the athlete's specific fluid rate. This is the most actionable piece of information for product selection.

### Salt type + known concentration input

Same pattern as sweat rate in the fluid section: three chips (Low/Average/High) with mg/L and percentile shown, plus a numeric override for athletes who have tested. Mutually exclusive — selecting a chip clears the input and vice versa.

### No independent safety flag

Sodium has no independent safety check. The fluid section's 2% BW flag already captures the safety concern. Adding a separate sodium flag would duplicate information and create confusion.

---

## Evidence Strength Summary

| Component | Confidence | Source |
|-----------|------------|--------|
| Sodium concentration percentiles | High | Baker 2016, n=506 |
| Sodium concentration is genetically stable | High | Baker 2017 review |
| Self-report indicators | Medium | Clinical/practitioner consensus |
| 100% replacement of sodium in consumed fluid | Medium | Tiller 2019, Mosler 2020 |

---

## References

1. Baker et al. (2016) — [PubMed 26070030](https://pubmed.ncbi.nlm.nih.gov/26070030/)
2. Baker LB (2017) — [PubMed 28332116](https://pubmed.ncbi.nlm.nih.gov/28332116/)
3. Barnes & Baker et al. (2019) — [PubMed 31230518](https://pubmed.ncbi.nlm.nih.gov/31230518/)
4. Tiller NB et al. (2019) ISSN — [PubMed 31687085](https://pubmed.ncbi.nlm.nih.gov/31687085/)
5. Mosler S et al. (2020) DGE — [Link](https://www.germanjournalsportsmedicine.com/archive/archive-2020/issue-7-8-9/fluid-replacement-in-sports/)
