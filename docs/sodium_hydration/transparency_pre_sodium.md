# Pre-Workout Sodium — Transparency Copy V1

> **Status:** Design review — Pre-workout sodium section. Part of the Nutrition Transparency drawer series.

## Overview

Pre-workout sodium serves a fundamentally different purpose from during-workout sodium. During exercise, sodium replaces sweat losses. Before exercise, sodium **retains the fluid you drink** — preventing kidneys from excreting it before exercise begins. This distinction is the most important educational element in this section.

---

## Calculation by Time Window

| Window | Sodium | Range | Confidence |
|--------|--------|-------|------------|
| >= 120 min | 450 mg (fixed midpoint) | 300–600 mg | High |
| 10–120 min | 150 mg (fixed midpoint) | 100–200 mg | Medium |
| < 10 min | None | — | — |

Sodium is **not body-weight-scaled** — the retention mechanism requires a fixed sodium presence in consumed fluid, not a weight-proportional amount.

---

## Formula Display (>= 120 min window)

```
① >= 2 hr window → 450 mg  (midpoint)
────────────────────────────────────
↓ floor   = 300 mg
↑ ceiling = 600 mg
  range   → 300–600 mg    sipped with fluid
```

For the 10–120 min window:

```
① 10–120 min window → 150 mg  (midpoint)
─────────────────────────────────────────
  range → 100–200 mg
```

---

## Always-Visible Copy

Pre-workout sodium keeps the fluid you drink in your body rather than sending it straight to your bladder. Without sodium, much of what you consume before exercise is excreted before you even start.

---

## The Full Story Copy

### How does sodium help retain fluid?

When you drink plain water before exercise, your kidneys detect the dilution of plasma sodium and respond by excreting the excess fluid as urine — often before it can benefit your muscles. Sodium consumed alongside fluid signals the kidneys to hold on to it, maintaining plasma volume and ensuring more of what you drink stays in circulation when exercise begins.

*Sawka et al. (2007) ACSM — recommends sodium-containing beverages or salty foods with pre-exercise fluids* · **High confidence**

---

### Where does 300–600 mg come from?

The ACSM recommends 20–50 mEq/L of sodium in pre-exercise beverages (equivalent to ~460–1,150 mg/L). For the fluid volumes in our pre-hydration protocol (~390 ml), a fixed range of 300–600 mg achieves concentrations within ACSM guidance without prescribing a specific beverage or format. A standard electrolyte drink, salty meal, or electrolyte tablet all get you there.

| Window | Range |
|--------|-------|
| >= 2 hours | 300–600 mg |
| 10–120 min | 100–200 mg |
| < 10 min | None |

*Sawka et al. (2007) ACSM Position Stand* · **High confidence**

---

### Why isn't sodium scaled to body weight like the fluid target?

The fluid target (5–7 ml/kg) is body-weight-scaled because larger athletes need more fluid to reach euhydration. Pre-workout sodium doesn't follow the same logic — the amount of sodium needed to signal fluid retention is not proportional to body weight in the same way.

> ⚠️ **Transparency note:** The 300–600 mg range is fixed across all athletes. For very heavy athletes consuming larger fluid volumes, this results in a lower sodium concentration per litre than the ACSM's 20–50 mEq/L recommendation. This is a known limitation.

---

### Is this the same as sodium loading?

No — sodium loading is a separate, more aggressive strategy for long, hot-weather events. Sims et al. (2007) showed a concentrated sodium beverage at 10 ml/kg consumed 1–2 hours before exercise in the heat can expand plasma volume and improve time to exhaustion by 26%. That protocol involves substantially higher sodium amounts and is a deliberate performance intervention. Mealvana's pre-workout sodium recommendation is for routine euhydration preparation only.

*Sims et al. (2007) — Journal of Applied Physiology · Medicine and Science in Sports and Exercise* · **High confidence**

---

## Design Decisions

**Time window** — the app determines which window applies from the logged workout start time. The user does not select it manually.

**No sweat type input** — pre-workout sodium is not personalised by sweat sodium concentration. The amount is determined by the fluid retention mechanism, not by individual sweat composition.

**Sodium loading note in Full Story** — explicitly distinguishes this protocol from Sims sodium loading, which coaches may ask about. Keeps it clearly in scope without dismissing the research.

---

## Evidence Strength Summary

| Component | Confidence | Source |
|-----------|------------|--------|
| Sodium with pre-hydration (300–600 mg) | High | ACSM 2007 |
| Fluid retention mechanism | High | ACSM 2007 |
| 100–200 mg at 10–120 min | Medium | NATA / practitioner consensus |
| Fixed (not BW-scaled) sodium | Known limitation | — |

---

## References

1. Sawka et al. (2007) ACSM — [PubMed 17277604](https://pubmed.ncbi.nlm.nih.gov/17277604/)
2. Thomas DT et al. (2016) AND/ACSM/DC — [PubMed 26920240](https://pubmed.ncbi.nlm.nih.gov/26920240/)
3. Sims ST et al. (2007) — [PubMed 17463297](https://pubmed.ncbi.nlm.nih.gov/17463297/) · [PubMed 17218894](https://pubmed.ncbi.nlm.nih.gov/17218894/)
