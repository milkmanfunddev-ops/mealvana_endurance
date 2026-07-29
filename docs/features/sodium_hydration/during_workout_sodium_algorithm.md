# During-Workout Sodium Algorithm

**Mealvana Endurance — Algorithm Specification**
**Version:** 1.0
**Date:** April 8, 2026

---

## Overview

This document specifies the algorithm for calculating during-workout sodium intake recommendations. The sodium algorithm rides on top of the fluid algorithm — it uses the fluid recommendation as its input and calculates how much sodium should be in that fluid.

**Core principle:** Replace 100% of the sodium in the fluid you're drinking. Since the fluid algorithm already determines how much to drink (a percentage of sweat losses), the sodium algorithm simply ensures the sodium concentration of intake matches the sodium concentration of sweat.

---

## Inputs

| Input | Type | Required | Notes |
|-------|------|----------|-------|
| `recommended_fluid_ml_hr` | float | Yes | Output from the fluid algorithm |
| `salt_type` | enum: low, average, high | Yes (if no known concentration) | Self-reported |
| `known_sodium_concentration_mg_L` | float | No | From sweat test; overrides salt_type |

---

## Step 1: Sodium Concentration

If the athlete has a known sodium concentration from a sweat test, use it directly. Otherwise, use self-reported salt type mapped to population percentiles.

```
If known_sodium_concentration_mg_L is not null:
    sodium_conc = known_sodium_concentration_mg_L
Else:
    sodium_conc = lookup salt_type:
        low:       650 mg/L    // 25th percentile
        average:   825 mg/L    // 50th percentile
        high:     1000 mg/L    // 75th percentile
```

**Self-report indicators to help athletes choose:**

| Indicator | Suggests |
|-----------|----------|
| White residue/crust on skin or clothing after exercise | High |
| Eyes sting from sweat | High |
| Crave salty food after workouts | High |
| Sweat tastes noticeably salty | High |
| None of the above | Low or Average |

**Evidence:**
- Source: Baker et al. (2016), *Journal of Sports Sciences*, 34(4):358–368. [PubMed](https://pubmed.ncbi.nlm.nih.gov/26070030/)
- Dataset: 506 athletes, whole-body predicted sweat [Na+]: 35.9 ± 10.4 mmol/L
- Converted to mg/L (× 23 atomic weight of sodium): 826 ± 239 mg/L
- Percentiles estimated assuming normal distribution: 25th = 665 mg/L, 75th = 987 mg/L, rounded to 650/825/1000
- Sodium concentration is largely genetic and relatively stable within individuals compared to sweat rate (Baker, 2017)
- **Confidence: High** — large dataset, standardized methodology

---

## Step 2: Calculate Sodium Recommendation

```
sodium_mg_hr = (recommended_fluid_ml_hr / 1000) × sodium_conc
```

### Sodium Range

Since the fluid algorithm provides a floor and ceiling for fluid intake, sodium inherits the same range:

```
sodium_floor_mg_hr = (floor_ml_hr / 1000) × sodium_conc
sodium_ceiling_mg_hr = (ceiling_ml_hr / 1000) × sodium_conc
```

The sodium recommendation, floor, and ceiling move in lockstep with the fluid values. No independent sodium logic is needed.

---

## Worked Examples

### Example 1: 45-min speedwork, nice day

```
Athlete: 70 kg, medium sweater, average salt
Fluid algorithm output:
    message: "No structured hydration plan needed. Drink to thirst."
    recommended: 384 ml/hr (30% conservative)
    floor: 0 ml/hr
    ceiling: 800 ml/hr (running GI cap)

Sodium:
    sodium_conc: 825 mg/L (average)
    recommended: (384 / 1000) × 825 = 317 mg/hr
    floor: (0 / 1000) × 825 = 0 mg/hr
    ceiling: (800 / 1000) × 825 = 660 mg/hr

    → "No structured sodium plan needed. Drink to thirst.
       If you do drink, aim for around 317 mg/hr sodium.
       Don't exceed 660 mg/hr."

Practical: If you grab a sports drink during rest intervals,
the sodium in it is fine. No capsules or special mix needed.
```

### Example 2: 90-min long run, cool morning

```
Athlete: 65 kg, light sweater, average salt
Fluid algorithm output:
    recommended: 306 ml/hr
    floor: 0 ml/hr
    ceiling: 612 ml/hr (100% sweat rate)

Sodium:
    sodium_conc: 825 mg/L (average)
    recommended: (306 / 1000) × 825 = 252 mg/hr
    floor: 0 mg/hr
    ceiling: (612 / 1000) × 825 = 505 mg/hr

    → "We recommend ~252 mg/hr sodium. Safe range: 0–505 mg/hr."

Practical: A standard sports drink (500 mg/L sodium) at
306 ml/hr provides ~153 mg/hr — undershoots. Athlete
could add an electrolyte tablet or choose a higher-sodium
drink mix.
```

### Example 3: 3-hour bike ride, hot day

```
Athlete: 80 kg, heavy sweater, high salt
Fluid algorithm output:
    recommended: 1,200 ml/hr (at ceiling, floor overrode percentage)
    floor: 1,792 ml/hr (exceeds ceiling)
    ceiling: 1,200 ml/hr

Sodium:
    sodium_conc: 1,000 mg/L (high)
    recommended: (1,200 / 1000) × 1,000 = 1,200 mg/hr
    floor: (1,792 / 1000) × 1,000 = 1,792 mg/hr (unachievable)
    ceiling: (1,200 / 1000) × 1,000 = 1,200 mg/hr

    → Sodium ceiling matches fluid ceiling. Athlete should
      aim for 1,200 mg/hr — the max achievable given fluid limits.

Practical: Standard sports drinks (400–500 mg/L) at
1,200 ml/hr provide ~480–600 mg/hr — well under target.
Athlete needs a high-sodium mix (~1,000 mg/L) or
supplemental sodium capsules.
```

### Example 4: 60-min indoor trainer, no fan

```
Athlete: 75 kg, medium sweater, average salt
Fluid algorithm output:
    recommended: 832 ml/hr
    floor: 164 ml/hr
    ceiling: 1,200 ml/hr (cycling GI cap)

Sodium:
    sodium_conc: 825 mg/L (average)
    recommended: (832 / 1000) × 825 = 686 mg/hr
    floor: (164 / 1000) × 825 = 135 mg/hr
    ceiling: (1,200 / 1000) × 825 = 990 mg/hr

    → "We recommend ~686 mg/hr sodium. Safe range: 135–990 mg/hr."

Practical: About one electrolyte tablet (200–250 mg)
plus a sports drink per hour.
```

### Example 5: Olympic triathlon, warm day

```
Athlete: 68 kg, medium sweater, average salt
Fluid algorithm output (from fluid algorithm with T1/T2):
    Swim:  0 ml/hr
    T1:    300 ml (fixed)
    Bike:  679 ml/hr
    T2:    300 ml (fixed)
    Run:   679 ml/hr

Sodium:
    sodium_conc: 825 mg/L (average)

    Swim:  0 mg/hr
    T1:    (300 / 1000) × 825 = 248 mg
    Bike:  (679 / 1000) × 825 = 560 mg/hr
    T2:    (300 / 1000) × 825 = 248 mg
    Run:   (679 / 1000) × 825 = 560 mg/hr

    RESULT:
        Segment       | Fluid       | Sodium
        Swim (25 min) |    0 ml/hr  |     0 mg/hr
        T1            |  300 ml     |   248 mg
        Bike (65 min) |  679 ml/hr  |   560 mg/hr
        T2            |  300 ml     |   248 mg
        Run  (50 min) |  679 ml/hr  |   560 mg/hr

    Total sodium:
        T1:   248 mg
        Bike: 560 × 1.08 = 605 mg
        T2:   248 mg
        Run:  560 × 0.83 = 465 mg
        TOTAL:           1,566 mg

Practical:
    T1: Electrolyte drink (300 ml with ~825 mg/L concentration)
    Bike: Standard sports drink covers most of it
    T2: Same electrolyte drink as T1
    Run: Electrolyte drink at aid stations or 1 salt capsule
```

---

## Practical Guidance: Sodium Delivery

The algorithm outputs mg/hr. Athletes need to know how to hit that target. Common sources:

| Source | Approximate Sodium |
|--------|-------------------|
| Standard sports drink (500 ml) | 200–300 mg |
| High-sodium sports drink (500 ml) | 400–500 mg |
| Electrolyte tablet (e.g., SaltStick) | 200–250 mg |
| Gel with sodium | 50–100 mg |
| Salt capsule (e.g., SaltStick Cap) | 215 mg |
| 1/4 tsp table salt | 575 mg |

**Key insight:** Most standard sports drinks are formulated at 400–500 mg/L sodium. For an "average" salt athlete (825 mg/L sweat sodium), standard sports drinks replace only about 50–60% of sweat sodium. Athletes with high sweat sodium concentrations almost always need supplemental sodium beyond what's in their sports drink.

---

## Implementation Notes

### Relationship to Fluid Algorithm

The sodium algorithm has no independent gate, duration tiers, or floor/ceiling logic. It inherits all of those from the fluid algorithm:

- If fluid says "drink to thirst" with a conservative 30% target and range (short/mild workouts), sodium provides the same — a conservative target and range derived from those fluid numbers
- If fluid applies a floor override, sodium scales up with it
- If fluid applies a ceiling override, sodium scales down with it
- If fluid redistributes from run to bike in multi-segment, sodium follows
- If fluid includes T1/T2 transition volumes, sodium calculates for those too

This keeps the two algorithms perfectly synchronized.

### Sodium in Pre-Workout and Post-Workout

This document covers during-workout sodium only. Pre-workout sodium loading and post-workout sodium for rehydration are covered in separate algorithm specifications.

### Known Sweat Test Override

A sweat sodium test (e.g., from Precision Hydration, Gatorade Sweat Patch, or similar) provides the most accurate concentration value. Like the sweat rate test for the fluid algorithm, this eliminates the largest source of individual estimation error. Consider prompting athletes during onboarding to report test results if available.

---

## Evidence Strength Summary

| Component | Evidence Level | Source | Confidence |
|-----------|---------------|--------|------------|
| Sodium concentration percentiles | Strong | Baker 2016, n=506 | High |
| Sodium concentration is genetically stable | Strong | Baker 2017 review | High |
| Self-report indicators (white residue, etc.) | Moderate | Clinical/practitioner consensus | Medium |
| 100% replacement of sodium in consumed fluid | Moderate | Tiller 2019, McCubbin 2020, DGE 2020 | Medium |
| Sodium range inherits from fluid floor/ceiling | Strong | Derived from fluid algorithm | High |

---

## References

1. Baker LB, Barnes KA, Anderson ML, et al. (2016). Normative data for regional sweat sodium concentration and whole-body sweating rate in athletes. *Journal of Sports Sciences*, 34(4):358–368. [PubMed](https://pubmed.ncbi.nlm.nih.gov/26070030/)
2. Baker LB. (2017). Sweating rate and sweat sodium concentration in athletes: A review of methodology and intra/interindividual variability. *Sports Medicine*, 47(Suppl 1):111–128. [PubMed](https://pubmed.ncbi.nlm.nih.gov/28332116/)
3. Barnes KA, Anderson ML, Stofan JR, et al. (2019). Normative data for sweating rate, sweat sodium concentration, and sweat sodium loss in athletes: An update and analysis by sport. *Journal of Sports Sciences*, 37(20):2356–2366. [PubMed](https://pubmed.ncbi.nlm.nih.gov/31230518/)
4. Tiller NB, et al. (2019). ISSN Position Stand: Nutritional considerations for single-stage ultra-marathon training and racing. *Journal of the International Society of Sports Nutrition*, 16(1):50. [PubMed](https://pubmed.ncbi.nlm.nih.gov/31687085/)
5. Mosler S, et al. (2020). Fluid Replacement in Sports — Position of the Working Group Sports Nutrition of the German Nutrition Society (DGE). *German Journal of Sports Medicine*, 71(7-8). [Link](https://www.germanjournalsportsmedicine.com/archive/archive-2020/issue-7-8-9/fluid-replacement-in-sports-position-of-the-working-group-sports-nutrition-of-the-german-nutrition-society-dge/)
6. Sawka MN, et al. (2007). ACSM Position Stand: Exercise and fluid replacement. *Medicine and Science in Sports and Exercise*, 39(2):377–390. [PubMed](https://pubmed.ncbi.nlm.nih.gov/17277604/)
7. Holmes N, et al. (2016). The Effect of Exercise Intensity on Sweat Rate and Sweat Sodium and Potassium Losses in Trained Endurance Athletes. *Annals of Sports Medicine and Research*, 3(2):1063.
