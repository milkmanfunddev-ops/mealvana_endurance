# Pre-Workout Hydration — Transparency Copy V1

> **Status:** Design review — Pre-workout hydration section. Part of the Nutrition Transparency drawer series.

## Overview

Pre-workout hydration has one goal: **euhydration** — starting at the athlete's normal baseline, not dehydrated or over-hydrated. The algorithm is time-gated by how much time is available before the workout, and body-weight-scaled for the primary window (>= 2 hours).

---

## Calculation by Time Window

| Window | Fluid | Range | Confidence |
|--------|-------|-------|------------|
| >= 120 min | BW × 6 ml/kg | BW × 5–7 ml/kg | High |
| 10–120 min | 250 ml (fixed) | 200–300 ml | Medium |
| < 10 min | Sips only — no recommendation | — | — |

Same gate as during-workout: workouts < 60 min in conditions < 30°C receive no structured pre-hydration plan.

---

## Formula Display (>= 120 min window, 65 kg athlete)

```
① 65 kg × 6 ml/kg = 390 ml
────────────────────────────
↓ floor   = 65 × 5 ml/kg = 325 ml
↑ ceiling = 65 × 7 ml/kg = 455 ml
  range   → 325–455 ml   sipped over available window
```

For the 10–120 min window:

```
① 10–120 min window → 250 ml (fixed)
────────────────────────────────────
  range → 200–300 ml
```

---

## Always-Visible Copy (>= 120 min window)

The goal before a workout is to start **euhydrated** — at your normal baseline, not loaded or depleted. With 3 hours available, you have time for the full protocol: sip 390 ml gradually, let it absorb, and aim for pale yellow urine before you head out.

## Always-Visible Copy (10–120 min window)

Not enough time for the full protocol. 250 ml is all that can meaningfully absorb before exercise begins. Sip it steadily — don't chug it just before you start.

## Always-Visible Copy (< 10 min window)

Too late for structured pre-hydration. A few small sips are fine for comfort, but fluid taken now won't absorb before exercise begins. Focus on the during-workout plan instead.

---

## Urine colour tip (shown in >= 120 min window)

> If your urine is still dark at 2 hours before your workout, the ACSM recommends an additional **3–5 ml/kg**. Aim for pale yellow — straw coloured — before you start.

This is surfaced as a tip, not a calculated recommendation — the app cannot assess urine colour.

---

## The Full Story Copy

### What is euhydration and why does it matter?

Euhydration is your body's normal fluid balance — not dehydrated, not over-hydrated. Starting a workout even mildly dehydrated (1–2% body weight) measurably impairs performance, increases perceived effort, and accelerates cardiovascular strain. The goal of pre-workout hydration is simply to reach your baseline — no more, no less.

*Cheuvront & Kenefick (2014) · Sawka et al. (2007) ACSM* · **High confidence**

---

### Where does 5–7 ml/kg come from?

The ACSM recommends 5–7 ml/kg consumed at least 4 hours before exercise. We use 6 ml/kg as the midpoint target with 5–7 ml/kg as the acceptable range. The upper bound matters: drinking significantly more than 7 ml/kg provides no additional benefit and may require an inconvenient bathroom stop mid-warmup.

*Sawka et al. (2007) ACSM · Thomas et al. (2016) AND/ACSM/DC Position* · **High confidence**

---

### Why does the recommendation change with time available?

Fluid absorption takes time. The body-weight-scaled protocol (5–7 ml/kg) requires at least 2 hours for fluid to absorb and for urine output to normalize. With less time, a smaller fixed volume is all that can meaningfully absorb before exercise — larger volumes would arrive in your bladder mid-race.

| Window | Protocol | Confidence |
|--------|----------|------------|
| >= 2 hours | BW × 5–7 ml/kg (ACSM) | High |
| 10–120 min | 200–300 ml fixed (NATA) | Medium |
| < 10 min | Sips only | — |

---

### What about early morning workouts?

If you're training at 5–6 AM, you won't have 2 hours before your workout. The most effective strategy is to hydrate the evening before — an extra 300–500 ml with dinner. You wake up better hydrated and the small top-up before your run is all you need.

> ⚠️ **Transparency note:** The evening-before recommendation is based on ACSM's general guidance to maintain adequate hydration during the 24-hour period before exercise. It is a practical tip, not a separately calculated protocol.

---

## Design Decisions

**Time window** — the app determines which window applies from the logged workout start time. The user does not select it manually.

**Urine colour tip** — shown as a green info callout below the formula in the >= 2 hr window only. Not shown in shorter windows where the urine check is irrelevant.

**No sweat rate inputs** — pre-workout hydration is not personalised by sweat rate. Body weight is the only personalisation variable.

**Evening-before tip** — surfaced when the selected window is 10–120 min, as a separate amber callout. Not shown in >= 2 hr window.

---

## Evidence Strength Summary

| Component | Confidence | Source |
|-----------|------------|--------|
| 5–7 ml/kg >= 2 hr before | High | ACSM 2007, Thomas 2016 |
| Urine colour check at 2 hr | High | ACSM 2007 |
| 200–300 ml 10–120 min before | Medium | NATA guidelines |
| < 60 min gate | High | Consistent with during-workout gate |

---

## References

1. Sawka et al. (2007) ACSM — [PubMed 17277604](https://pubmed.ncbi.nlm.nih.gov/17277604/)
2. Thomas DT et al. (2016) AND/ACSM/DC — [PubMed 26920240](https://pubmed.ncbi.nlm.nih.gov/26920240/)
3. Cheuvront & Kenefick (2014) — [PubMed 24382024](https://pubmed.ncbi.nlm.nih.gov/24382024/)
