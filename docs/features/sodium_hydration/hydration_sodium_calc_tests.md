# Hydration & Sodium Calculator — Test Cases

Run these against the implementation. Do not modify the implementation to match expected values — if a test fails, debug the formula logic.

Reference athlete: 70 kg, medium sweater, outdoor, 22°C, 50% humidity.
Tolerances: ml/hr values ±5%, sweat rate ±0.01 L/hr, deficit_pct ±0.1%.

---

## Effective Sweat Rate

### Base Rate Lookup

| Input | Expected (L/hr) |
|-------|-----------------|
| MEDIUM sweater, 22°C, 50% humidity, outdoor | 1.28 |
| known_sweat_rate_ml_hr=1300, 22°C, 50% humidity, outdoor | 1.30 (known rate overrides sweater_type) |

### Temperature Multiplier

| temp_celsius | Expected multiplier | Notes |
|-------------|--------------------|----|
| 22 | 1.00 | Baseline |
| 32 | 1.40 | (32-22)*0.04 + 1.0 |
| 14 | 0.68 | (14-22)*0.04 + 1.0 |
| 0 | 0.50 | Clamped at 0.50 (raw = 0.12) |
| 50 | 1.80 | Clamped at 1.80 (raw = 2.12) |

### Humidity Multiplier

| humidity_percent | Expected multiplier | Notes |
|-----------------|--------------------|----|
| 50 | 1.00 | Threshold, no effect |
| 100 | 1.10 | Clamped at 1.10 (raw = 1.10) |

### Indoor Multiplier

| is_indoor | Expected multiplier |
|-----------|-------------------|
| true | 1.30 |

### Combined Effective Sweat Rate

| Input | Expected (L/hr) | Breakdown |
|-------|-----------------|-----------|
| MEDIUM, 22°C, 50%, outdoor | 1.28 | 1.28 × 1.00 × 1.00 × 1.00 |
| MEDIUM, 22°C, 50%, indoor | 1.66 | 1.28 × 1.00 × 1.00 × 1.30 |
| HEAVY, 31°C, 65%, outdoor | 2.33 | 1.66 × 1.36 × 1.03 × 1.00 |
| LIGHT, 14°C, 50%, outdoor | 0.61 | 0.90 × 0.68 × 1.00 × 1.00 |
| known=1300, 26°C, 55%, outdoor | 1.52 | 1.30 × 1.16 × 1.01 × 1.00 |

### Swimming Modifier

| Effective Rate (L/hr) | Swimming Rate (L/hr) |
|-----------------------|---------------------|
| 1.28 | 0.51 |

### Clamp Tests

| Input | Expected | Notes |
|-------|----------|-------|
| HEAVY, 50°C, 100%, indoor | 3.00 | 1.66 × 1.80 × 1.10 × 1.30 = 4.27 → clamped to 3.0 |

---

## Replacement Percentage Lookup

| total_duration_min | Expected pct |
|-------------------|-------------|
| 59 | 0.30 |
| 89 | 0.50 |
| 140 | 0.60 |
| 180 | 0.70 |
| 600 | 0.80 |

---

## Short Workout Gate

| duration_min | temp_celsius | Gate triggered? | Notes |
|-------------|-------------|----------------|-------|
| 45 | 31 | No | <60 but temp >=30 → bypass gate |
| 59 | 29 | Yes | Just under both thresholds |

---

## Single-Sport Integration Tests

### Example 1: 45-min speedwork, nice day (gate triggered)

```
Athlete: 70 kg, MEDIUM sweater
Conditions: 22°C, 45% humidity, outdoor
Sport: RUNNING, 45 min

Effective sweat rate: 1.28 L/hr
Gate: duration < 60 AND temp < 30 → triggered

Conservative target: 1280 * 0.30 = 384 ml/hr
Floor: total_loss = 1280 * 0.75 = 960; max_deficit = 1400
  (960 - 1400) / 0.75 = negative → 0 ml/hr
Ceiling: min(800, 1280) = 800 ml/hr

Expected: recommended=384, floor=0, ceiling=800
Flags: ["No structured hydration plan needed."]
```

### Example 2: 90-min long run, cool morning

```
Athlete: 65 kg, LIGHT sweater
Conditions: 14°C, 50% humidity, outdoor
Sport: RUNNING, 90 min

Effective sweat rate: 0.90 * 0.68 = 0.612 L/hr
Replacement: 90 min → 0.50
Recommended: 612 * 0.50 = 306 ml/hr

Floor: total_loss = 612 * 1.5 = 918; max_deficit = 65*1000*0.02 = 1300
  (918 - 1300) / 1.5 = negative → 0 ml/hr
Ceiling: min(800, 612) = 612 ml/hr

Expected: recommended=306, floor=0, ceiling=612
Deficit: 918 - 459 = 459 ml → 0.7% BW ✓
```

### Example 3: 3-hour bike, hot day (floor > ceiling flag)

```
Athlete: 80 kg, HEAVY sweater
Conditions: 31°C, 65% humidity, outdoor
Sport: CYCLING, 180 min

Effective sweat rate: 1.66 * 1.36 * 1.03 = 2.325 L/hr
Replacement: 180 min → 0.70
Pct-based: 2325 * 0.70 = 1628 ml/hr

Floor: total_loss = 2325*3 = 6975; max_deficit = 80*1000*0.02 = 1600
  (6975 - 1600) / 3 = 1792 ml/hr
Floor overrides pct: 1792 > 1628
Ceiling: min(1200, 2325) = 1200 ml/hr

Ceiling < floor (1200 < 1792) → use ceiling
Expected: recommended=1200, floor=1792, ceiling=1200
Flags: ["Even at maximum intake, you will exceed 2% BW loss."]

Safety check: deficit = 6975 - 3600 = 3375 → 4.2% BW
Flags: ["Significant dehydration expected (>4.2% BW)."]
```

### Example 4: 60-min indoor trainer

```
Athlete: 75 kg, MEDIUM sweater
Conditions: 22°C, 50% humidity, indoor
Sport: CYCLING, 60 min

Effective sweat rate: 1.28 * 1.30 = 1.664 L/hr
Replacement: 60 min → 0.50
Recommended: 1664 * 0.50 = 832 ml/hr

Floor: total_loss = 1664; max_deficit = 1500
  (1664 - 1500) / 1 = 164 ml/hr
Ceiling: min(1200, 1664) = 1200 ml/hr

Expected: recommended=832, floor=164, ceiling=1200
Deficit: 1664 - 832 = 832 → 1.1% BW ✓
```

---

## Multi-Segment Integration Tests

### Example 5: Olympic triathlon, warm day

```
Athlete: 68 kg, known sweat rate 1300 ml/hr
Conditions: 26°C, 55% humidity, outdoor
Segments: Swim 25 min, Bike 65 min, Run 50 min

Effective sweat rate: 1.30 * 1.16 * 1.01 = 1.522 L/hr
Swim effective: 1.522 * 0.4 = 0.609 L/hr

Total duration: 140 min → replacement_pct = 0.60

Sweat losses:
  Swim: 609 * (25/60)  =  254 ml
  Bike: 1522 * (65/60) = 1649 ml
  Run:  1522 * (50/60) = 1268 ml
  Total:               = 3171 ml

Required: 3171 * 0.60 = 1903 ml
Transitions: T1 + T2 = 600 ml
Remaining: 1903 - 600 = 1303 ml

Drinkable hours: (65+50)/60 = 1.917 hr
Recommended: 1303 / 1.917 = 679 ml/hr

Floor: (3171 - 1360) = 1811; remaining = 1811-600 = 1211
  floor_ml_hr = 1211 / 1.917 = 631 ml/hr
679 > 631 → no floor override

Ceilings: Bike=1200, Run=800. 679 < both → no cap needed
No redistribution.

Expected per segment:
  Swim:  0 ml/hr
  T1:    300 ml
  Bike:  679 ml/hr
  T2:    300 ml
  Run:   679 ml/hr

Total intake: 300 + 733 + 300 + 564 = 1897 ml
Deficit: 3171 - 1897 = 1274 → 1.9% BW ✓
```

### Example 6: Brick workout (bike → run), warm day

```
Athlete: 72 kg, MEDIUM sweater
Conditions: 27°C, 50% humidity, outdoor
Segments: Bike 90 min, Run 45 min

Effective sweat rate: 1.28 * 1.20 = 1.536 L/hr

Total duration: 135 min → replacement_pct = 0.60

Sweat losses:
  Bike: 1536 * 1.50 = 2304 ml
  Run:  1536 * 0.75 = 1152 ml
  Total:             = 3456 ml

Required: 3456 * 0.60 = 2074 ml
Transitions: T2 only = 300 ml
Remaining: 2074 - 300 = 1774 ml

Drinkable hours: (90+45)/60 = 2.25 hr
Recommended: 1774 / 2.25 = 789 ml/hr

Floor: (3456 - 1440) = 2016; remaining = 2016-300 = 1716
  floor_ml_hr = 1716 / 2.25 = 763 ml/hr
789 > 763 → no floor override

Ceilings: Bike=1200, Run=800. 789 < both → no cap
No redistribution.

Expected per segment:
  Bike:  789 ml/hr
  T2:    300 ml
  Run:   789 ml/hr

Total intake: 1184 + 300 + 592 = 2076 ml
Deficit: 3456 - 2076 = 1380 → 1.9% BW ✓
```

---

## Edge Cases

| Test | Expected Behavior |
|------|-------------------|
| known_sweat_rate_ml_hr = 0 | Effective rate = 0 after multipliers → clamped to 0.3 L/hr |
| Negative temp_celsius (-10°C) | temp_multiplier = 1.0 + (-32)*0.04 = -0.28 → clamped to 0.50 |
| humidity_percent = 0 | humidity_multiplier = 1.00 (below 50 threshold) |
| Single swimming segment (30 min) | recommended = 0 ml/hr (can't drink); full loss is deficit |
| duration_min = 0 | REJECT or return zero recommendation (no workout) |
| body_weight_kg = 0 | REJECT — invalid input |
| Brick with run ceiling hit requiring redistribution | Run capped at 800, shortfall shifted to bike, bike capped at 1200 if needed |
| Triathlon where all ceilings hit and shortfall remains | Flag: "Even at maximum intake on all segments, you will exceed 2% BW loss." |
| 60-min workout at exactly 30°C | Gate NOT triggered (temp >= 30 bypasses gate even though duration < 60 is false since 60 is not <60) |
| 59-min workout at exactly 30°C | Gate NOT triggered (temp >= 30 bypasses gate) |
| 59-min workout at 29.9°C | Gate triggered (<60 AND <30) |

---

## Redistribution Test

Test case where run ceiling forces redistribution to bike.

```
Athlete: 60 kg, HEAVY sweater
Conditions: 35°C, 70% humidity, outdoor
Segments: Bike 60 min, Run 60 min

Effective sweat rate: 1.66 * 1.52 * 1.04 = 2.625 L/hr
  Clamped: 2.625 (within [0.3, 3.0])

Total duration: 120 min → replacement_pct = 0.60

Sweat losses:
  Bike: 2625 * 1.0 = 2625 ml
  Run:  2625 * 1.0 = 2625 ml
  Total:            = 5250 ml

Required: 5250 * 0.60 = 3150 ml
Transitions: T2 = 300 ml
Remaining: 3150 - 300 = 2850 ml

Drinkable hours: 2.0 hr
Recommended: 2850 / 2.0 = 1425 ml/hr

Floor: (5250 - 1200) = 4050; remaining = 4050-300 = 3750
  floor_ml_hr = 3750 / 2.0 = 1875 ml/hr
Floor overrides: 1875 > 1425

Ceilings: Bike=1200, Run=800
Run capped at 800. Shortfall: 1875 - 800 = 1075 ml/hr * 1.0 hr = 1075 ml
Bike absorbs: bike_intake = 1875 + 1075/1.0 = 2950 ml/hr
Bike capped at 1200.
Remaining shortfall exists → flag.

Expected:
  Bike: 1200 ml/hr (capped)
  T2:   300 ml
  Run:  800 ml/hr (capped)
  Flags: ["Even at maximum intake on all segments, you will exceed 2% BW loss."]

Total intake: 1200 + 300 + 800 = 2300 ml
Deficit: 5250 - 2300 = 2950 → 4.9% BW
Flags: ["Significant dehydration expected (>4.9% BW)."]
```

---

# PART 2: PRE-WORKOUT HYDRATION TESTS

---

## Pre-Workout Gate

| workout_duration_min | temp_celsius | Gate triggered? | Notes |
|---------------------|-------------|----------------|-------|
| 45 | 22 | Yes | <60 AND <30°C |
| 45 | 31 | No | <60 but temp >=30 → bypass gate |
| 60 | 22 | No | Not <60 |
| 59 | 29 | Yes | Just under both thresholds |
| 90 | 15 | No | Not <60 |

---

## Pre-Workout Tier Selection

| time_before_workout_min | Expected tier | Notes |
|------------------------|---------------|-------|
| 240 | Tier 1 (full protocol) | >= 120 |
| 120 | Tier 1 (full protocol) | Boundary: exactly 120 |
| 119 | Tier 2 (fixed top-up) | Just under 120 |
| 90 | Tier 2 (fixed top-up) | 10–120 range |
| 45 | Tier 2 (fixed top-up) | 10–120 range |
| 10 | Tier 2 (fixed top-up) | Boundary: exactly 10 |
| 9 | Tier 3 (too late) | Just under 10 |
| 5 | Tier 3 (too late) | < 10 |
| 0 | Tier 3 (too late) | Edge: zero time |

---

## Pre-Workout Integration Tests

### Pre-Test 1: 45-min speedwork, nice day (gate fires)

```
INPUT:
  body_weight_kg: 70, workout_duration_min: 45
  time_before_workout_min: 180
  temp_celsius: 22

Gate: 45 < 60 AND 22 < 30 → triggered

EXPECTED:
  fluid_ml: 0 (no targets computed)
  message contains: "No structured pre-hydration needed"
```

### Pre-Test 2: 90-min long run, 3 hours available (Tier 1)

```
INPUT:
  body_weight_kg: 65, workout_duration_min: 90
  time_before_workout_min: 180
  temp_celsius: 14

Gate: 90 >= 60 → not triggered
Tier: 180 >= 120 → Tier 1

EXPECTED:
  fluid_ml: 65 * 6 = 390
  fluid_range: [325, 455]
  sodium_mg: 450
  sodium_range: [300, 600]
```

### Pre-Test 3: 3-hour bike, woke up 90 min before (Tier 2)

```
INPUT:
  body_weight_kg: 80, workout_duration_min: 180
  time_before_workout_min: 90
  temp_celsius: 31

Gate: 180 >= 60 → not triggered
Tier: 90 >= 10 AND < 120 → Tier 2

EXPECTED:
  fluid_ml: 250
  fluid_range: [200, 300]
  sodium_mg: 150
  sodium_range: [100, 200]
  message contains: "consider hydrating well the evening before"
```

### Pre-Test 4: Olympic triathlon race, 4 hours available (Tier 1 + top-up)

```
INPUT:
  body_weight_kg: 68, workout_duration_min: 140
  time_before_workout_min: 240
  temp_celsius: 26

Gate: 140 >= 60 → not triggered
Tier: 240 >= 120 → Tier 1

EXPECTED:
  fluid_ml: 68 * 6 = 408
  fluid_range: [340, 476]
  sodium_mg: 450
  sodium_range: [300, 600]

  Combined with top-up (informational):
    total_fluid: 408 + 250 = 658
    total_sodium: 450 + 150 = 600
```

### Pre-Test 5: Early morning run, only 45 min available (Tier 2)

```
INPUT:
  body_weight_kg: 70, workout_duration_min: 90
  time_before_workout_min: 45
  temp_celsius: 22

Gate: 90 >= 60 → not triggered
Tier: 45 >= 10 AND < 120 → Tier 2

EXPECTED:
  fluid_ml: 250
  fluid_range: [200, 300]
  sodium_mg: 150
  sodium_range: [100, 200]
  message contains: "consider hydrating well the evening before"
```

### Pre-Test 6: Last-minute arrival, 5 min before (Tier 3)

```
INPUT:
  body_weight_kg: 75, workout_duration_min: 120
  time_before_workout_min: 5
  temp_celsius: 25

Gate: 120 >= 60 → not triggered
Tier: 5 < 10 → Tier 3

EXPECTED:
  fluid_ml: 0
  sodium_mg: 0
  message contains: "Too late for structured pre-hydration"
```

### Pre-Test 7: Short hot workout — gate bypassed (Tier 1)

```
INPUT:
  body_weight_kg: 72, workout_duration_min: 45
  time_before_workout_min: 150
  temp_celsius: 33

Gate: 45 < 60 BUT temp >= 30 → gate bypassed
Tier: 150 >= 120 → Tier 1

EXPECTED:
  fluid_ml: 72 * 6 = 432
  fluid_range: [360, 504]
  sodium_mg: 450
  sodium_range: [300, 600]
```

---

## Pre-Workout Edge Cases

| Test | Expected Behavior |
|------|-------------------|
| time_before_workout_min = 120 (exact boundary) | Tier 1 — full protocol applies |
| time_before_workout_min = 10 (exact boundary) | Tier 2 — fixed top-up applies |
| time_before_workout_min = 0 | Tier 3 — too late |
| time_before_workout_min negative | REJECT — invalid input |
| body_weight_kg = 0 | REJECT — invalid input |
| Interaction: during-workout deficit > 3% BW | Pre-workout message should include: "Starting well-hydrated is especially important for this workout." |
