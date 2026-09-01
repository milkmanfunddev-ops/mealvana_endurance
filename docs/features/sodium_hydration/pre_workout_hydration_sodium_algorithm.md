# Pre-Workout Hydration & Sodium Algorithm

**Mealvana Endurance — Algorithm Specification**
**Version:** 1.0
**Date:** April 8, 2026

---

## Overview

This document specifies the algorithm for calculating pre-workout fluid and sodium intake recommendations. The goal of pre-workout hydration is to start exercise euhydrated — not to pre-load or hyperhydrate, but to ensure the athlete begins with normal fluid balance and plasma electrolyte levels.

---

## Inputs

| Input | Type | Required | Notes |
|-------|------|----------|-------|
| `time_before_workout_min` | float | Yes | Exact minutes until workout starts |
| `body_weight_kg` | float | Yes | For body-weight-scaled fluid volumes |
| `workout_duration_min` | float | Yes | For gate check |
| `temp_celsius` | float | Yes | For gate check |

---

## Gate: Does This Workout Need a Pre-Hydration Plan?

Same gate as the during-workout algorithm. If the workout is short and conditions are mild, a structured pre-hydration plan adds no value.

```
If workout_duration_min < 60 AND temp_celsius < 30:
    message = "No structured pre-hydration needed.
    Just make sure you're drinking normally throughout the day."
    EXIT
```

---

## Calculation

### If time >= 120 minutes before workout

The athlete has enough time for the full ACSM protocol: drink, absorb, urinate, and start euhydrated.

```
fluid_ml = body_weight_kg × 6          // midpoint of 5-7 ml/kg
fluid_range = [body_weight_kg × 5, body_weight_kg × 7]
sodium_mg = 450                          // midpoint of 300-600 mg
sodium_range = [300, 600]
```

Present as a total volume to consume over the available window, sipped gradually — not chugged.

- *If you haven't urinated by 2 hours before your workout, or your urine is still dark, the ACSM recommends drinking an additional 3–5 ml/kg (Sawka et al., 2007). The app cannot assess urine color, so this is presented as a tip rather than a calculated recommendation.*

**Evidence:**
- ACSM 2007 (Sawka et al.): "Prehydrating with beverages should be initiated when needed at least several hours before the activity to enable fluid absorption and allow urine output to return to normal levels." Recommends 5–7 ml/kg at least 4 hours before.
- Thomas et al. 2016 (AND/ACSM/DC position): 5–10 ml/kg in the 2–4 hours prior.
- Sodium with pre-hydration fluid: ACSM 2007 recommends 20–50 mEq/L (460–1,150 mg/L) in beverages, or sodium-rich foods, to help retain consumed fluids.
- **Confidence: High** — two major position stands, directly cited

### If time 10–120 minutes before workout

Not enough time for the full body-weight-scaled protocol. A small fixed top-up is all that's practical — larger volumes won't absorb in time and risk GI discomfort or the need to urinate during exercise.

```
fluid_ml = 250                           // midpoint of 200-300 ml
fluid_range = [200, 300]
sodium_mg = 150                          // midpoint of 100-200 mg
sodium_range = [100, 200]
```

**Evidence:**
- NATA guidelines: "10–20 minutes prior to exercise consume another 7–10 fl.oz. of water" (~200–300 ml)
- This is a fixed volume, not body-weight-scaled — the research does not provide a body-weight-scaled recommendation for this window
- **Confidence: Moderate** — widely cited across practitioner guidelines, but not from a single peer-reviewed intervention study

### If time < 10 minutes before workout

Too late for meaningful pre-hydration. Whatever the athlete drinks now won't absorb before exercise begins.

```
message = "Too late for structured pre-hydration.
A few small sips are fine for comfort."
```

---

## Sodium: Why It Matters Pre-Workout

Pre-workout sodium serves a different purpose than during-workout sodium. During exercise, sodium replaces what's lost in sweat. Before exercise, sodium helps **retain the fluid you drink** — without it, much of what you consume is excreted as urine before you even start.

The ACSM recommends including sodium in pre-exercise beverages or consuming salty foods/snacks to stimulate thirst and improve fluid retention (Sawka et al., 2007).

The Sims et al. (2007) sodium loading research demonstrated that a concentrated sodium beverage (164 mmol Na+/L, at 10 ml/kg) consumed 1–2 hours before exercise in the heat expanded plasma volume and improved time to exhaustion by 26%. However, this is a sodium *loading* protocol for hot conditions, not a standard pre-hydration recommendation. The algorithm uses the standard ACSM sodium range (300–600 mg with the primary fluid bolus) for general use.

---

## Worked Examples

### Example 1: 45-min speedwork, nice day

```
Workout: 45 min, 22°C
Gate: duration < 60 AND temp < 30
    → "No structured pre-hydration needed."
```

### Example 2: 90-min long run, 3 hours available

```
Athlete: 65 kg
Time before: 180 min (>= 120)

Fluid: 65 × 6 = 390 ml
Range: [325, 455] ml
Sodium: 450 mg
Range: [300, 600] mg

Sip 390 ml over the 3 hours before start.

Practical: A glass of water with breakfast + an electrolyte
tablet. Aim for pale yellow urine before you head out.
```

### Example 3: 3-hour bike ride, woke up 90 min before

```
Athlete: 80 kg
Time before: 90 min (10–120 window)

Fluid: 250 ml (fixed)
Range: [200, 300] ml
Sodium: 150 mg
Range: [100, 200] mg

Practical: A glass of water or electrolyte drink with
breakfast. Not enough time for the full protocol —
rely on during-workout hydration to cover the gap.
```

### Example 4: Olympic triathlon race, 4 hours available

```
Athlete: 68 kg
Time before: 240 min (>= 120)

Fluid: 68 × 6 = 408 ml
Range: [340, 476] ml
Sodium: 450 mg
Range: [300, 600] mg

Sip 408 ml over the first 2–3 hours after waking.

Final top-up at 10-20 min before:
    250 ml with last gel
    150 mg sodium

Total pre-race:
    Fluid: 408 + 250 = 658 ml
    Sodium: 450 + 150 = 600 mg

Practical: Sports drink with breakfast (covers Tier 1
fluid + sodium), small sips with pre-race gel (Tier 3).
```

### Example 5: Early morning run, only 45 min available

```
Athlete: 70 kg
Time before: 45 min (10–120 window)

Fluid: 250 ml (fixed)
Range: [200, 300] ml
Sodium: 150 mg

Practical: A glass of water when you wake up. Not ideal —
the app should note: "For early morning workouts with
limited time, consider hydrating well the evening before."
```

---

## Implementation Notes

### Evening-Before Hydration for Early Morning Workouts

When the athlete's time before workout is <120 min (common for 5–6 AM training), the algorithm should surface a note recommending evening-before hydration. This isn't a separate calculated protocol — just a practical tip:

"You don't have enough time for full pre-hydration before this workout. Drink an extra 300–500 ml with dinner the evening before to start the day better hydrated."

This is supported by ACSM's general recommendation to "consume a nutritionally balanced diet and drink adequate fluids during the 24-hour period before an event" (Sawka et al., 2007).

### Interaction with During-Workout Algorithm

The pre-workout algorithm is independent of the during-workout algorithm in its calculation — it always prescribes the same volumes regardless of what happens during the workout. However, when the during-workout algorithm flags that the athlete will finish significantly dehydrated (expected deficit > 3% BW), the app should emphasize pre-hydration compliance: "Your during-workout hydration can't fully keep up with your sweat losses. Starting well-hydrated is especially important for this workout."

### What Pre-Workout Hydration Does NOT Do

This algorithm ensures euhydration — starting at normal baseline. It does not:

- Hyperhydrate (deliberately exceeding normal fluid levels)
- Sodium-load (the Sims protocol for heat performance is a separate, more aggressive strategy)
- Replace during-workout hydration planning

---

## Evidence Strength Summary

| Component | Evidence Level | Source | Confidence |
|-----------|---------------|--------|------------|
| 5–7 ml/kg, >=2 hr before | Strong | ACSM 2007, Thomas 2016 | High |
| Conditional 3–5 ml/kg at 2 hr* | Strong | ACSM 2007 | High |
| 200–300 ml, 10–120 min before | Moderate | NATA guidelines | Medium |
| Sodium with pre-hydration (300–600 mg) | Strong | ACSM 2007 | High |
| <60 min gate | Strong | Multiple studies, consistent with during-workout gate | High |

- *Presented as a tip/asterisk, not a calculated recommendation, since the app cannot assess urine color.*

---

## References

1. Sawka MN, et al. (2007). ACSM Position Stand: Exercise and fluid replacement. *Medicine and Science in Sports and Exercise*, 39(2):377–390. [PubMed](https://pubmed.ncbi.nlm.nih.gov/17277604/)
2. Thomas DT, Erdman KA, Burke LM. (2016). Position of the Academy of Nutrition and Dietetics, Dietitians of Canada, and the American College of Sports Medicine: Nutrition and Athletic Performance. *Journal of the Academy of Nutrition and Dietetics*, 116(3):501–528. [PubMed](https://pubmed.ncbi.nlm.nih.gov/26920240/)
3. Sims ST, Rehrer NJ, Bell ML, Cotter JD. (2007). Preexercise sodium loading aids fluid balance and endurance for women exercising in the heat. *Journal of Applied Physiology*, 103(2):534–541. [PubMed](https://pubmed.ncbi.nlm.nih.gov/17463297/)
4. Sims ST, van Vliet L, Cotter JD, Rehrer NJ. (2007). Sodium loading aids fluid balance and reduces physiological strain of trained men exercising in the heat. *Medicine and Science in Sports and Exercise*, 39(1):123–130. [PubMed](https://pubmed.ncbi.nlm.nih.gov/17218894/)
5. Cheuvront SN, Kenefick RW. (2014). Dehydration: Physiology, assessment, and performance effects. *Comprehensive Physiology*, 4(1):257–285. [PubMed](https://pubmed.ncbi.nlm.nih.gov/24382024/)
