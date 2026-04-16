# During-Workout Hydration Algorithm

**Mealvana Endurance — Algorithm Specification**
**Version:** 2.1
**Date:** April 8, 2026

---

## Overview

This document specifies the algorithm for calculating during-workout fluid intake recommendations. The algorithm has three stages:

1. **Effective Sweat Rate Calculation** — estimates how much fluid the athlete is losing per hour
2. **Replacement Recommendation** — based on workout duration, provides a percentage of sweat losses to replace
3. **Safety Check** — verifies the recommendation doesn't result in >2% body weight loss

---

## Stage 1: Effective Sweat Rate Calculation

### Inputs

| Input | Type | Required | Notes |
|-------|------|----------|-------|
| `sweater_type` | enum: light, medium, heavy | Yes (if no known rate) | Self-reported |
| `known_sweat_rate_ml_hr` | float | No | From sweat test; overrides sweater_type |
| `temp_celsius` | float | Yes | Ambient temperature |
| `humidity_percent` | float | Yes | Relative humidity |
| `is_indoor` | boolean | Yes | Indoor training without outdoor airflow |

### Step 1: Base Sweat Rate

If the athlete has a known sweat rate from testing, use it directly. Otherwise, use self-reported sweater type mapped to population percentiles.

```
If known_sweat_rate_ml_hr is not null:
    base_rate = known_sweat_rate_ml_hr / 1000    // convert to L/hr
Else:
    base_rate = lookup sweater_type:
        light:    0.90 L/hr    // 25th percentile
        medium:   1.28 L/hr    // 50th percentile
        heavy:    1.66 L/hr    // 75th percentile
```

**Evidence:**
- Source: Barnes & Baker et al. (2019), *Journal of Sports Sciences*, 37(20):2356–2366. [PubMed](https://pubmed.ncbi.nlm.nih.gov/31230518/)
- Dataset: 1,303 athletes tested 2000–2017 using standardized methodology
- Endurance athletes: mean 1.28 ± 0.57 L/hr
- Percentiles estimated assuming normal distribution
- **Confidence: High**

### Step 2: Temperature Adjustment

```
temp_multiplier = 1.0 + (temp_celsius - 22) × 0.04
temp_multiplier = clamp(temp_multiplier, 0.50, 1.80)
```

**Evidence:**
- Source: Jenkins et al. (2023), *Experimental Physiology*. [PubMed](https://pubmed.ncbi.nlm.nih.gov/36537856/)
- Directly measured: sweat rate increased 0.04 L/h per °C
- **Confidence: Medium**

### Step 3: Humidity Adjustment

```
humidity_multiplier = 1.0 + max(0, (humidity_percent - 50)) × 0.002
humidity_multiplier = clamp(humidity_multiplier, 1.00, 1.10)
```

**Evidence:**
- Jenkins et al. (2023): humidity did not significantly increase sweat rate
- Small multiplier (max 1.10) retained for practical fluid loss accounting
- **Confidence: Medium**

### Step 4: Indoor Adjustment

```
indoor_multiplier = 1.0
If is_indoor:
    indoor_multiplier = 1.30
```

**Evidence:**
- Conceptually supported (no convective cooling); no direct quantification in literature
- **Confidence: Low** — refine with user data

### Step 5: Combine and Clamp

```
effective_sweat_rate = base_rate × temp_multiplier × humidity_multiplier × indoor_multiplier
effective_sweat_rate = clamp(effective_sweat_rate, 0.3, 3.0)
```

**Swimming modifier:** For swimming segments, apply a 0.4× modifier to the effective sweat rate. Water immersion provides conductive cooling that dramatically reduces sweating. This is an estimate — values of 0.3–0.5× land rates are consistent with available data.

---

## Stage 2: Replacement Recommendation

### Principle

The algorithm uses research-supported replacement percentages that scale with workout duration. The longer the workout, the more important it becomes to actively replace fluid losses. This approach matches how coaches think ("replace about 50–80% of what you lose") and aligns with how athletes naturally drink.

### Inputs

| Input | Type | Required | Notes |
|-------|------|----------|-------|
| `body_weight_kg` | float | Yes | For safety check |
| `effective_sweat_rate_L_hr` | float | Yes | Output from Stage 1 |
| `duration_min` | float | Yes | Planned workout duration |

### Gate: Does This Workout Need a Hydration Plan?

```
If duration_min < 60 AND temp_celsius < 30:
    message = "No structured hydration plan needed. Drink to thirst
    and hydrate before and immediately after."

    // Still calculate a conservative target and band as guardrails
    recommended_intake_ml_hr = effective_sweat_rate_L_hr × 1000 × 0.30
        // 30% — conservative, below the 50% structured tier

    // Floor: 0 (short workouts won't breach 2% for most athletes)
    floor_ml_hr = max(0,
        (effective_sweat_rate_L_hr × 1000 × (duration_min / 60)
         - body_weight_kg × 1000 × 0.02)
        / (duration_min / 60))

    // Ceiling: lower of GI tolerance or 100% sweat rate
    sweat_rate_ml_hr = effective_sweat_rate_L_hr × 1000
    gi_ceiling = lookup sport_type:
        running:    800 ml/hr
        cycling:    1,200 ml/hr
    ceiling_ml_hr = min(gi_ceiling, sweat_rate_ml_hr)

    // Present as: "No structured plan needed. Drink to thirst.
    // If you do drink, aim for around {recommended} ml/hr.
    // Don't exceed {ceiling} ml/hr."
```

**Evidence:**
- Multiple studies show no performance benefit from fluid replacement during 1-hour exercise in temperate conditions (Robinson et al., 2003; McConell et al., 1999; Backx et al., 2003)
- The 30% conservative target is not from a specific study — it simply provides a rough guideline for athletes who want a number without implying structured hydration is necessary
- The ceiling (100% sweat rate) prevents over-drinking, which is a real risk when athletes drink out of habit rather than need
- Exception: hot conditions (>30°C) bypass the gate entirely and use the standard percentage tiers

### Replacement Percentage by Duration

```
replacement_pct = lookup duration_min:
    < 60 min:      0.30    // 30% (conservative, drink-to-thirst)
    60–90 min:     0.50    // 50%
    90–150 min:    0.60    // 60%
    150–240 min:   0.70    // 70%
    240+ min:      0.80    // 80%
```

**Evidence by tier:**

| Duration | % | Source & Rationale |
|----------|---|-------------------|
| < 60 min | 30% | No performance benefit from structured replacement at this duration (Robinson et al., 2003; McConell et al., 1999). 30% is not from a specific study — it provides a conservative guideline and upper-bound guardrail for athletes who drink to thirst. |
| 60–90 min | 50% | Ad libitum drinking naturally produces ~50–60% replacement (Noakes, 2007). Drink-to-thirst performs comparably to programmed drinking at this duration. Total deficit stays small for most athletes. |
| 90–150 min | 60% | Cumulative deficit becomes meaningful. ACSM recommends 0.4–0.8 L/hr during intense endurance activity (Sawka et al., 2007), corresponding to roughly 50–70% replacement for typical sweat rates. |
| 150–240 min | 70% | Coyle (1992): performance improves the closer intake matches sweat rate, "at least up to 80% of sweating rate," during 2+ hour cycling in heat. 70% is the midpoint of the supported 60–80% range. |
| 240+ min | 80% | German Nutrition Society (DGE) position: "athletes should drink a maximum of 80% of the determined sweat loss during a longer period of exercise" (Mosler et al., 2020). ISSN supports aggressive replacement for ultra-endurance (Tiller et al., 2019). 80% is the upper practical limit — higher risks hyponatremia if sodium intake is insufficient. |

### Calculation: Single-Sport Workouts

```
replacement_pct = get_replacement_pct(duration_min)
recommended_intake_ml_hr = effective_sweat_rate_L_hr × 1000 × replacement_pct

// Floor override: if the percentage doesn't keep athlete within 2% BW loss, raise it
total_loss_ml = effective_sweat_rate_L_hr × 1000 × (duration_min / 60)
max_deficit_ml = body_weight_kg × 1000 × 0.02
floor_ml_hr = max(0, total_loss_ml - max_deficit_ml) / (duration_min / 60)

recommended_intake_ml_hr = max(recommended_intake_ml_hr, floor_ml_hr)

// Ceiling override: never exceed GI tolerance or 100% sweat rate
sweat_rate_ml_hr = effective_sweat_rate_L_hr × 1000
gi_ceiling = lookup sport_type:
    running:    800 ml/hr
    cycling:    1,200 ml/hr
ceiling_ml_hr = min(gi_ceiling, sweat_rate_ml_hr)

recommended_intake_ml_hr = min(recommended_intake_ml_hr, ceiling_ml_hr)

// If ceiling < floor, athlete cannot stay within 2% — flag it
If ceiling_ml_hr < floor_ml_hr:
    flag: "Even at maximum intake, you will exceed 2% BW loss.
    Pre-hydrate aggressively and rehydrate immediately after."
```

### Safe Range: Floor and Ceiling

In addition to the recommendation, provide the athlete with a safe range. The priority chain for the final recommendation is:

```
final = percentage-based recommendation
final = max(final, floor)      // floor overrides percentage
final = min(final, ceiling)    // ceiling overrides floor
```

If the ceiling is lower than the floor, the athlete physically cannot stay within 2% body weight loss during that segment. The ceiling wins (safety against hyponatremia and GI distress trumps the dehydration target), and the algorithm flags the need for aggressive pre-hydration.

**Floor** — the minimum intake to stay within the 2% body weight loss threshold (already calculated above as `floor_ml_hr`).

**Ceiling** — the lower of GI absorption capacity or 100% sweat replacement (to guard against hyponatremia):

```
sweat_rate_ml_hr = effective_sweat_rate_L_hr × 1000

gi_ceiling = lookup sport_type:
    running:    800 ml/hr     // GI comfort limit
    cycling:    1,200 ml/hr   // gastric emptying ceiling

ceiling_ml_hr = min(gi_ceiling, sweat_rate_ml_hr)
    // Never exceed 100% sweat replacement — drinking more
    // than you lose dilutes blood sodium and risks hyponatremia
```

**Presented to athlete:**

```
"We recommend ~{recommended} ml/hr.
 Safe range: {floor}–{ceiling} ml/hr."
```

**Evidence:**
- Floor: derived from ACSM 2% body weight threshold (Sawka et al., 2007)
- Ceiling (GI): gastric emptying ~1,200 ml/hr during moderate exercise (Coyle, 1992; Lambert et al., 1997); running GI symptom tolerance is lower (Peters et al., 1999; Pfeiffer et al., 2012)
- Ceiling (hyponatremia): over-drinking is a documented risk in endurance events; fluid intake should never exceed sweat rate (Hew-Butler et al., 2015; Mosler et al., 2020)

### Calculation: Multi-Segment Workouts (Triathlon, Brick)

For multi-segment workouts, the replacement percentage is based on **total workout duration**, not each leg individually. A 50-min run after a 65-min bike is fundamentally different from a standalone 50-min run — the cumulative deficit is what matters.

Each drinkable segment gets the same replacement percentage applied to its own sweat losses. Swimming segments are always zero intake (can't drink while swimming). **Transitions provide small fixed hydration windows** that reduce what the active segments need to cover.

**Supported multi-segment structures:**

| Structure | Segments | Transitions |
|-----------|----------|-------------|
| Triathlon | Swim → Bike → Run | T1 (swim→bike) + T2 (bike→run) |
| Brick | Bike → Run | T2 (bike→run) only |

```
// Detect transitions based on segment structure
transitions = []
FOR each adjacent pair of segments:
    If segment changes from swim to bike:
        transitions.append("T1")
    If segment changes from bike to run:
        transitions.append("T2")

// Transition hydration (fixed 300 ml each, practitioner consensus)
transition_fluid_per = 300 ml     // midpoint of 240-360 ml
transition_intake = len(transitions) × transition_fluid_per

total_workout_duration = sum of all segment durations
replacement_pct = get_replacement_pct(total_workout_duration)

// Calculate total workout loss and required intake
total_workout_loss = sum of all segment losses
    // swim segments use 0.4× sweat rate modifier
required_total_intake = total_workout_loss × replacement_pct

// Calculate workout-wide floor
max_deficit_ml = body_weight_kg × 1000 × 0.02
floor_total_ml = max(0, total_workout_loss - max_deficit_ml)

// Subtract transition intake from what active segments must cover
remaining_required = max(0, required_total_intake - transition_intake)
remaining_floor = max(0, floor_total_ml - transition_intake)

// Distribute remaining across drinkable segments
total_drinkable_hours = sum of drinkable segment durations / 60    // excludes swim
recommended_ml_hr = remaining_required / total_drinkable_hours
floor_ml_hr = remaining_floor / total_drinkable_hours

FOR each segment:
    segment_intake_per_hr = max(recommended_ml_hr, floor_ml_hr)
    // Ceiling override
    sweat_rate_ml_hr = effective_sweat_rate × 1000
    gi_ceiling = lookup segment sport:
        running:    800 ml/hr
        cycling:    1,200 ml/hr
    segment_ceiling_ml_hr = min(gi_ceiling, sweat_rate_ml_hr)
    segment_intake_per_hr = min(segment_intake_per_hr, segment_ceiling_ml_hr)
    // Swimming
    If segment is swimming:
        segment_intake_per_hr = 0

// Redistribute: if run was capped, shift the delta to the bike
run_shortfall_per_hr = max(0, floor_ml_hr - run_ceiling_ml_hr)
run_shortfall_total = run_shortfall_per_hr × (run_duration_min / 60)
bike_intake_per_hr += run_shortfall_total / (bike_duration_min / 60)
// Cap bike at its own ceiling
bike_intake_per_hr = min(bike_intake_per_hr, bike_ceiling_ml_hr)

// If bike can't absorb the full shortfall, flag it
If bike_intake_per_hr == bike_ceiling_ml_hr AND remaining shortfall > 0:
    flag: "Even at maximum intake on all segments, you will
    exceed 2% BW loss. Pre-hydrate aggressively."
```

**Transition hydration evidence:**
- Practitioner consensus: 240–360 ml (8–12 oz) of electrolyte solution at each transition
- T1 rationale: bridges the swim hydration gap; athlete exits water warm (wetsuit heat trapping) and already in deficit
- T2 rationale: last easy opportunity to drink before running GI tolerance drops
- **Confidence: Low** — practitioner consensus, not from a position stand or intervention study. However, 300 ml during a 2–5 minute transition is conservative and low-risk.

---

## Stage 3: Safety Check

After calculating the recommendation, verify it doesn't result in excessive dehydration.

```
total_intake = recommended_intake_ml_hr × (duration_min / 60)
total_loss = effective_sweat_rate_L_hr × 1000 × (duration_min / 60)
net_deficit = total_loss - total_intake
deficit_pct = net_deficit / (body_weight_kg × 1000)

If deficit_pct > 0.02:
    flag: "Even at the recommended intake, you may lose more
    than 2% body weight. Pre-hydrate aggressively and plan
    for post-workout rehydration."

If deficit_pct > 0.03:
    flag: "Significant dehydration expected (>{deficit_pct}% BW).
    Pre-hydrate aggressively and rehydrate immediately after."
```

---

## Worked Examples

### Example 1: 45-min speedwork, nice day

```
Athlete: 70 kg, medium sweater
Conditions: 22°C, 45% humidity, outdoor

Stage 1: effective_sweat_rate = 1.28 L/hr

Stage 2: duration < 60 AND temp < 30
    → "No structured hydration plan needed. Drink to thirst
       and hydrate before and immediately after."

    Conservative target: 1,280 × 0.30 = 384 ml/hr
    Floor: (1,280 × 0.75 - 1,400) / 0.75 = negative → 0 ml/hr
    Ceiling: min(800, 1,280) = 800 ml/hr (running GI cap)

    → "If you do drink, aim for around 384 ml/hr.
       Don't exceed 800 ml/hr."

    Practical: A few sips from a bottle during rest intervals
    is plenty. The main message is don't overdo it.
```

### Example 2: 90-min long run, cool morning

```
Athlete: 65 kg, light sweater
Conditions: 14°C, 50% humidity, outdoor

Stage 1:
    base: 0.90, temp_mult: 0.68
    effective: 0.61 L/hr

Stage 2:
    duration: 90 min → replacement_pct = 50%
    recommended: 612 × 0.50 = 306 ml/hr

    Range:
        floor: (918 - 1,300) = negative → 0 ml/hr (deficit stays under 2%)
        ceiling: min(800, 612) = 612 ml/hr (100% sweat rate, lower than GI cap)
    → "We recommend ~306 ml/hr. Safe range: 0–612 ml/hr."
    Practical: about half a standard bottle per hour

Stage 3:
    total_loss: 918 ml | total_intake: 459 ml
    net_deficit: 459 ml | deficit_pct: 0.7% ✓
```

### Example 3: 3-hour bike ride, hot day

```
Athlete: 80 kg, heavy sweater
Conditions: 31°C, 65% humidity, outdoor

Stage 1:
    base: 1.66, temp_mult: 1.36, humidity: 1.03
    effective: 2.33 L/hr

Stage 2:
    duration: 180 min → replacement_pct = 70%
    percentage-based: 2,325 × 0.70 = 1,628 ml/hr

    Floor override:
        floor: (6,975 - 1,600) / 3 = 1,792 ml/hr
        1,792 > 1,628 → floor overrides recommendation to 1,792 ml/hr

    Range:
        floor: 1,792 ml/hr
        ceiling: min(1,200, 2,325) = 1,200 ml/hr (GI cap)
    → Floor (1,792) exceeds ceiling (1,200). Even at max
      intake, this athlete will exceed 2% loss. Athlete should
      drink at ceiling (1,200 ml/hr) and pre-hydrate aggressively.
    Practical: two 750ml bottles per hour

Stage 3:
    total_loss: 6,975 ml | total_intake: 1,200 × 3 = 3,600 ml
    net_deficit: 3,375 ml | deficit_pct: 4.2%

    FLAG: "Significant dehydration expected (>4% BW).
    Pre-hydrate aggressively and rehydrate immediately after."
```

### Example 4: 60-min indoor trainer, no fan

```
Athlete: 75 kg, medium sweater
Conditions: 22°C room, 50% humidity, indoor

Stage 1:
    base: 1.28, indoor_mult: 1.30
    effective: 1.66 L/hr

Stage 2:
    duration: 60 min → replacement_pct = 50%
    recommended: 1,664 × 0.50 = 832 ml/hr

    Range:
        floor: (1,664 - 1,500) / 1 = 164 ml/hr
        ceiling: min(1,200, 1,664) = 1,200 ml/hr (GI cap)
    → "We recommend ~832 ml/hr. Safe range: 164–1,200 ml/hr."
    Practical: just over one standard bottle

Stage 3:
    total_loss: 1,664 ml | total_intake: 832 ml
    net_deficit: 832 ml | deficit_pct: 1.1% ✓
```

### Example 5: Olympic triathlon, warm day (multi-segment)

```
Athlete: 68 kg, medium sweater, known sweat rate 1,300 ml/hr
Conditions: 26°C, 55% humidity, outdoor

Stage 1:
    base: 1.30 (known), temp_mult: 1.16, humidity: 1.01
    effective: 1.52 L/hr
    swimming effective: 1.52 × 0.4 = 0.61 L/hr (reduced in water)

Stage 2 — Multi-Segment:

    total_race_duration: 140 min → replacement_pct = 60%

    Total race sweat loss:
        Swim (25 min): 0.61 × 0.42 hr   =   254 ml
        Bike (65 min): 1.52 × 1.08 hr   = 1,649 ml
        Run  (50 min): 1.52 × 0.83 hr   = 1,268 ml
        TOTAL                            = 3,171 ml

    Required total intake: 3,171 × 0.60 = 1,903 ml

    Transition hydration:
        T1 (swim → bike): 300 ml
        T2 (bike → run):  300 ml
        Total transitions: 600 ml

    Remaining for bike + run: 1,903 - 600 = 1,303 ml

    Floor (race-wide):
        floor_total: 3,171 - 1,360 = 1,811 ml
        remaining_floor: 1,811 - 600 = 1,211 ml
        drinkable_hours: (65 + 50) / 60 = 1.92 hr
        floor_ml_hr: 1,211 / 1.92 = 631 ml/hr

    Recommended (remaining / drinkable hours):
        recommended_ml_hr: 1,303 / 1.92 = 679 ml/hr

    Floor override: 679 > 631 → no override needed, recommendation stands

    Ceiling (per segment):
        Bike: min(1,200, 1,522) = 1,200 ml/hr
        Run:  min(800, 1,522)   =   800 ml/hr

    679 < 800 (run ceiling) → no ceiling override needed
    679 < 1,200 (bike ceiling) → no ceiling override needed
    No redistribution needed.

    RESULT:
        Segment       | Intake
        Swim (25 min) |     0 ml/hr
        T1            |   300 ml (fixed)
        Bike (65 min) |   679 ml/hr
        T2            |   300 ml (fixed)
        Run  (50 min) |   679 ml/hr

    Total intake:
        T1:   300 ml
        Bike: 679 × 1.08 = 733 ml
        T2:   300 ml
        Run:  679 × 0.83 = 564 ml
        TOTAL:           1,897 ml

Stage 3 — Safety Check:
    net_deficit: 3,171 - 1,897 = 1,274 ml
    deficit_pct: 1,274 / 68,000 = 1.9% → under 2% ✓

    The transitions absorb 600 ml that previously had to come
    from bike and run. This drops both segment rates from
    943 ml/hr (previous version) to 679 ml/hr — well within
    both ceilings, no redistribution needed, and a much more
    comfortable race hydration plan.
```

### Example 6: Brick workout (bike → run), warm day

```
Athlete: 72 kg, medium sweater
Conditions: 27°C, 50% humidity, outdoor

Stage 1:
    base: 1.28 (medium), temp_mult: 1.20, humidity: 1.00
    effective: 1.28 × 1.20 = 1.54 L/hr

Stage 2 — Multi-Segment (Brick):

    Segments: Bike (90 min) → Run (45 min)
    Transitions detected: T2 (bike → run) only
    transition_intake: 1 × 300 = 300 ml

    total_workout_duration: 135 min → replacement_pct = 60%

    Total workout sweat loss:
        Bike (90 min): 1,536 × 1.50 hr = 2,304 ml
        Run  (45 min): 1,536 × 0.75 hr = 1,152 ml
        TOTAL                           = 3,456 ml

    Required total intake: 3,456 × 0.60 = 2,074 ml

    Floor:
        floor_total: 3,456 - (72 × 10 × 0.02) = 3,456 - 1,440 = 2,016 ml
        remaining_floor: 2,016 - 300 = 1,716 ml
        drinkable_hours: (90 + 45) / 60 = 2.25 hr
        floor_ml_hr: 1,716 / 2.25 = 763 ml/hr

    Remaining for bike + run: 2,074 - 300 = 1,774 ml
    recommended_ml_hr: 1,774 / 2.25 = 789 ml/hr

    Floor override: 789 > 763 → no override, recommendation stands

    Ceiling:
        Bike: min(1,200, 1,536) = 1,200 ml/hr
        Run:  min(800, 1,536)   =   800 ml/hr

    789 < 800 (run ceiling) → no ceiling override
    789 < 1,200 (bike ceiling) → no ceiling override
    No redistribution needed.

    RESULT:
        Segment       | Intake
        Bike (90 min) |   789 ml/hr
        T2            |   300 ml (fixed)
        Run  (45 min) |   789 ml/hr

    Total intake:
        Bike: 789 × 1.50 = 1,184 ml
        T2:   300 ml
        Run:  789 × 0.75 = 592 ml
        TOTAL:           2,076 ml

Stage 3 — Safety Check:
    net_deficit: 3,456 - 2,076 = 1,380 ml
    deficit_pct: 1,380 / 72,000 = 1.9% → under 2% ✓

    Note: Without T2, the recommended rate would be
    2,074 / 2.25 = 922 ml/hr — above the run ceiling (800),
    requiring redistribution. The single T2 transition
    absorbs enough to keep both segments comfortable.
```

---

## Implementation Notes

### When Known Sweat Rate Is Available

A known sweat rate from a simple weigh-before-weigh-after test eliminates the largest source of estimation error. Consider prompting athletes during onboarding:

1. Empty bladder, weigh nude or in minimal clothing
2. Exercise for 60 minutes at moderate intensity
3. Towel off, weigh again in same clothing
4. Weight lost (kg) = sweat rate (L/hr), adjusted for any fluid consumed

### Future Refinements

- **Personalization from feedback:** Logged workout data with hydration feedback can narrow the athlete's optimal replacement percentage over time.
- **Indoor multiplier validation:** Collect user data on indoor vs. outdoor sweat losses to refine the 1.30 estimate.

---

## Evidence Strength Summary

| Component | Evidence Level | Source | Confidence |
|-----------|---------------|--------|------------|
| Base sweat rate (percentiles) | Strong | Barnes/Baker 2019, n=1303 | High |
| Temperature coefficient | Moderate | Jenkins 2023 | Medium |
| Humidity effect (minimal) | Moderate | Jenkins 2023, Che Muhamed 2016 | Medium |
| Indoor multiplier | Weak | Conceptual, no direct quantification | Low |
| <60 min gate | Strong | Multiple studies, no benefit to replacement | High |
| 30% conservative target (<60 min) | Weak | Not from a specific study; provides guardrails for drink-to-thirst | Low |
| 50% at 60–90 min | Moderate | Noakes ad libitum data | Medium |
| 60% at 90–150 min | Moderate | ACSM 0.4–0.8 L/hr guideline | Medium |
| 70% at 150–240 min | Moderate | Coyle 1992, "up to 80%" | Medium |
| 80% at 240+ min | Strong | DGE position stand, ISSN ultra guidelines | High |
| 2% BW safety threshold | Strong | ACSM 2007, Cheuvront 2014 | High |
| Floor (2% BW derivation) | Strong | ACSM 2007, Sawka et al. | High |
| Ceiling — running GI (800) | Moderate | Peters 1999, Pfeiffer 2012 | Medium |
| Ceiling — cycling GI (1,200) | Strong | Coyle 1992, Lambert 1997 | High |
| Ceiling — hyponatremia guard | Strong | Hew-Butler 2015, Mosler 2020 | High |
| T1/T2 transition hydration (300 ml) | Weak | Practitioner consensus | Low |

---

## References

1. Barnes KA, Anderson ML, Stofan JR, et al. (2019). Normative data for sweating rate, sweat sodium concentration, and sweat sodium loss in athletes: An update and analysis by sport. *Journal of Sports Sciences*, 37(20):2356–2366. [PubMed](https://pubmed.ncbi.nlm.nih.gov/31230518/)
2. Baker LB, Barnes KA, Anderson ML, et al. (2016). Normative data for regional sweat sodium concentration and whole-body sweating rate in athletes. *Journal of Sports Sciences*, 34(4):358–368. [PubMed](https://pubmed.ncbi.nlm.nih.gov/26070030/)
3. Baker LB. (2017). Sweating rate and sweat sodium concentration in athletes: A review of methodology and intra/interindividual variability. *Sports Medicine*, 47(Suppl 1):111–128. [PubMed](https://pubmed.ncbi.nlm.nih.gov/28332116/)
4. Jenkins DJ, et al. (2023). Delineating the impacts of air temperature and humidity for endurance exercise. *Experimental Physiology*. [PubMed](https://pubmed.ncbi.nlm.nih.gov/36537856/)
5. Che Muhamed AM, et al. (2016). The effects of a systematic increase in relative humidity on thermoregulatory and circulatory responses during prolonged running exercise in the heat. *Temperature*, 3(3):455–464. [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC5079215/)
6. Sawka MN, et al. (2007). ACSM Position Stand: Exercise and fluid replacement. *Medicine and Science in Sports and Exercise*, 39(2):377–390. [PubMed](https://pubmed.ncbi.nlm.nih.gov/17277604/)
7. Mosler S, et al. (2020). Fluid Replacement in Sports — Position of the Working Group Sports Nutrition of the German Nutrition Society (DGE). *German Journal of Sports Medicine*, 71(7-8). [Link](https://www.germanjournalsportsmedicine.com/archive/archive-2020/issue-7-8-9/fluid-replacement-in-sports-position-of-the-working-group-sports-nutrition-of-the-german-nutrition-society-dge/)
8. Coyle EF. (1992). Benefits of fluid replacement with carbohydrate during exercise. *Clinical Journal of Sport Medicine*, 2(3). [PubMed](https://pubmed.ncbi.nlm.nih.gov/1406205/)
9. Tiller NB, et al. (2019). ISSN Position Stand: Nutritional considerations for single-stage ultra-marathon training and racing. *Journal of the International Society of Sports Nutrition*, 16(1):50. [PubMed](https://pubmed.ncbi.nlm.nih.gov/31687085/)
10. Peters HP, et al. (1999). Gastrointestinal symptoms in long-distance runners, cyclists, and triathletes. *American Journal of Gastroenterology*, 94(6):1570–1581. [PubMed](https://pubmed.ncbi.nlm.nih.gov/10364014/)
11. Pfeiffer B, et al. (2012). Nutritional intake and gastrointestinal problems during competitive endurance events. *Medicine and Science in Sports and Exercise*, 44(2):344–351. [PubMed](https://pubmed.ncbi.nlm.nih.gov/21775906/)
12. Hew-Butler T, et al. (2015). Statement of the Third International Exercise-Associated Hyponatremia Consensus Development Conference. *Clinical Journal of Sport Medicine*, 25(4):303–320. [PubMed](https://pubmed.ncbi.nlm.nih.gov/26102445/)
13. Cheuvront SN, Kenefick RW. (2014). Dehydration: Physiology, assessment, and performance effects. *Comprehensive Physiology*, 4(1):257–285. [PubMed](https://pubmed.ncbi.nlm.nih.gov/24382024/)
14. Shirreffs SM, et al. (1996). Post-exercise rehydration in man: effects of volume consumed and drink sodium content. *Medicine and Science in Sports and Exercise*, 28(10):1260–1271. [PubMed](https://pubmed.ncbi.nlm.nih.gov/8897382/)
15. Lambert GP, et al. (1997). Simultaneous determination of gastric emptying and intestinal absorption during cycle exercise in humans. *Journal of Applied Physiology*. [PubMed](https://pubmed.ncbi.nlm.nih.gov/8775576/)
