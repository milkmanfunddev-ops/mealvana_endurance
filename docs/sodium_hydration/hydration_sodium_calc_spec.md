# During-Workout and Pre-Workout Hydration Calculator — Spec

Build a hydration calculator with two modules: (1) during-workout fluid/sodium targets per segment with safe range, and (2) pre-workout fluid/sodium targets based on time available before exercise. Both modules share the same gate logic.

---

# PART 1: DURING-WORKOUT HYDRATION

---

## Inputs

### Athlete Profile

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `body_weight_kg` | float | Yes | |
| `sweater_type` | Enum: LIGHT, MEDIUM, HEAVY | Yes (if no known rate) | Self-reported |
| `known_sweat_rate_ml_hr` | float | No | From sweat test; overrides sweater_type |
| `salt_type` | Enum: LOW, AVERAGE, HIGH | Yes (if no known concentration) | Self-reported |
| `known_sodium_concentration_mg_L` | float | No | From sweat test; overrides salt_type |

### Workout (one or more segments)

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `sport` | Enum: RUNNING, CYCLING, SWIMMING | Yes | |
| `duration_min` | float | Yes | Segment duration in minutes |

For multi-segment workouts (triathlon, brick), provide an ordered array of segments. The algorithm detects transitions automatically from adjacent segment pairs.

### Environment

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `temp_celsius` | float | Yes | Ambient temperature |
| `humidity_percent` | float | Yes | Relative humidity (0–100) |
| `is_indoor` | boolean | Yes | Indoor training without outdoor airflow |

### Output

```
{
  segments: [
    { sport, duration_min, fluid_ml_hr, sodium_mg_hr, floor_ml_hr, ceiling_ml_hr }
  ],
  transitions: [
    { type: "T1"|"T2", fluid_ml, sodium_mg }
  ],
  total_fluid_ml,
  total_sodium_mg,
  deficit_pct,
  message
}
```

---

## Formulas

### 1. effectiveSweatRate → L/hr

#### Step 1: Base Sweat Rate

```
if known_sweat_rate_ml_hr provided:
  base_rate = known_sweat_rate_ml_hr / 1000
else:
  base_rate = { LIGHT: 0.90, MEDIUM: 1.28, HEAVY: 1.66 }[sweater_type]
```

Percentile source: Barnes/Baker et al. (2019), endurance athletes mean 1.28 ± 0.57 L/hr, n=1303. LIGHT=25th, MEDIUM=50th, HEAVY=75th.

#### Step 2: Environmental Multipliers

```
temp_mult = clamp(1.0 + (temp_celsius - 22) * 0.04, 0.50, 1.80)
humidity_mult = clamp(1.0 + max(0, (humidity_percent - 50)) * 0.002, 1.00, 1.10)
indoor_mult = 1.30 if is_indoor else 1.0
```

#### Step 3: Combine and Clamp

```
effective_sweat_rate = clamp(base_rate * temp_mult * humidity_mult * indoor_mult, 0.3, 3.0)
```

For SWIMMING segments, apply 0.4× modifier to effective_sweat_rate (water immersion reduces sweating).

### 2. sodiumConcentration → mg/L

```
if known_sodium_concentration_mg_L provided:
  sodium_conc = known_sodium_concentration_mg_L
else:
  sodium_conc = { LOW: 650, AVERAGE: 825, HIGH: 1000 }[salt_type]
```

Percentile source: Baker et al. (2016), whole-body predicted sweat [Na+] 35.9 ± 10.4 mmol/L (826 ± 239 mg/L), n=506. LOW=25th, AVERAGE=50th, HIGH=75th.

### 3. replacementPct → float (0–1)

Lookup from total workout duration (sum of all segment durations):

```
replacement_pct = lookup total_duration_min:
  < 60:        0.30
  >= 60, < 90:   0.50
  >= 90, < 150:  0.60
  >= 150, < 240: 0.70
  >= 240:      0.80
```

Duration < 60 AND temp_celsius < 30 → set `message = "No structured hydration plan needed. Drink to thirst and hydrate before and immediately after."` but still compute targets and range. Exception: if temp_celsius >= 30, bypass the gate even if duration < 60.

### 4. detectTransitions → array

```
transitions = []
for i in range(len(segments) - 1):
  if segments[i].sport == SWIMMING and segments[i+1].sport == CYCLING:
    transitions.append({ type: "T1", after_segment: i })
  if segments[i].sport == CYCLING and segments[i+1].sport == RUNNING:
    transitions.append({ type: "T2", after_segment: i })
```

Each transition: `fluid_ml = 300, sodium_mg = (300 / 1000) * sodium_conc`

### 5. singleSportHydration

For workouts with exactly one segment:

```
sweat_rate_ml_hr = effective_sweat_rate * 1000
recommended = sweat_rate_ml_hr * replacement_pct

// Floor override: keep athlete within 2% BW loss
total_loss = sweat_rate_ml_hr * (duration_min / 60)
max_deficit = body_weight_kg * 1000 * 0.02
floor_ml_hr = max(0, (total_loss - max_deficit) / (duration_min / 60))
recommended = max(recommended, floor_ml_hr)

// Ceiling override
gi_ceiling = { RUNNING: 800, CYCLING: 1200 }[sport]
ceiling_ml_hr = min(gi_ceiling, sweat_rate_ml_hr)
recommended = min(recommended, ceiling_ml_hr)

// Flag if ceiling < floor
if ceiling_ml_hr < floor_ml_hr:
  message += " Even at maximum intake, you will exceed 2% BW loss. Pre-hydrate aggressively."

fluid_ml_hr = recommended
sodium_mg_hr = (fluid_ml_hr / 1000) * sodium_conc
```

### 6. multiSegmentHydration

For workouts with 2+ segments:

```
// Step 1: Total workout loss
for each segment:
  sport_mult = 0.4 if segment.sport == SWIMMING else 1.0
  segment.loss = effective_sweat_rate * 1000 * sport_mult * (segment.duration_min / 60)
total_loss = sum of segment.loss

// Step 2: Required intake and transitions
required_total = total_loss * replacement_pct
transition_intake = len(transitions) * 300

// Step 3: Floor
max_deficit = body_weight_kg * 1000 * 0.02
floor_total = max(0, total_loss - max_deficit)
remaining_required = max(0, required_total - transition_intake)
remaining_floor = max(0, floor_total - transition_intake)

// Step 4: Distribute across drinkable segments
drinkable_segments = [s for s in segments if s.sport != SWIMMING]
drinkable_hours = sum(s.duration_min / 60 for s in drinkable_segments)
recommended_ml_hr = remaining_required / drinkable_hours
floor_ml_hr = remaining_floor / drinkable_hours

// Step 5: Apply floor and ceiling per segment
for each drinkable segment:
  s.fluid_ml_hr = max(recommended_ml_hr, floor_ml_hr)
  gi_ceiling = { RUNNING: 800, CYCLING: 1200 }[s.sport]
  s.ceiling_ml_hr = min(gi_ceiling, effective_sweat_rate * 1000)
  s.floor_ml_hr = floor_ml_hr
  s.fluid_ml_hr = min(s.fluid_ml_hr, s.ceiling_ml_hr)

for SWIMMING segments:
  s.fluid_ml_hr = 0
  s.floor_ml_hr = 0
  s.ceiling_ml_hr = 0

// Step 6: Redistribute run shortfall to bike
run_segments = [s for s in drinkable_segments if s.sport == RUNNING]
bike_segments = [s for s in drinkable_segments if s.sport == CYCLING]

for each run_segment:
  run_ceiling = min(800, effective_sweat_rate * 1000)
  if floor_ml_hr > run_ceiling:
    shortfall_per_hr = floor_ml_hr - run_ceiling
    shortfall_total = shortfall_per_hr * (run_segment.duration_min / 60)
    total_bike_hours = sum(b.duration_min / 60 for b in bike_segments)
    addition_per_hr = shortfall_total / total_bike_hours
    for each bike_segment:
      bike_ceiling = min(1200, effective_sweat_rate * 1000)
      bike_segment.fluid_ml_hr = min(bike_segment.fluid_ml_hr + addition_per_hr, bike_ceiling)
      if bike_segment.fluid_ml_hr == bike_ceiling:
        message += " Even at maximum intake, you will exceed 2% BW loss. Pre-hydrate aggressively."

// Step 7: Sodium for all segments and transitions
for each segment:
  s.sodium_mg_hr = (s.fluid_ml_hr / 1000) * sodium_conc
for each transition:
  t.sodium_mg = (300 / 1000) * sodium_conc
```

### 7. safetyCheck

Run after all recommendations are finalized.

```
total_intake = sum(s.fluid_ml_hr * s.duration_min / 60 for all segments)
             + sum(t.fluid_ml for all transitions)
net_deficit = total_loss - total_intake
deficit_pct = net_deficit / (body_weight_kg * 1000)

if deficit_pct > 0.03:
  message += " Significant dehydration expected (>{deficit_pct*100}% BW). Pre-hydrate aggressively and rehydrate immediately after."
elif deficit_pct > 0.02:
  message += " Even at the recommended intake, you may lose more than 2% body weight. Pre-hydrate aggressively and plan for post-workout rehydration."
```

### 8. assembleOutput (during-workout)

```
1. effective_sweat_rate = effectiveSweatRate(profile, environment)
2. sodium_conc = sodiumConcentration(profile)
3. replacement_pct = replacementPct(total_duration)
4. transitions = detectTransitions(segments)

5. if len(segments) == 1:
     result = singleSportHydration(...)
   else:
     result = multiSegmentHydration(...)

6. safetyCheck(result)
7. return output object with segments, transitions, totals, deficit_pct, message
```

---

# PART 2: PRE-WORKOUT HYDRATION

---

## Inputs

### Pre-Workout Specific Inputs

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `time_before_workout_min` | float | Yes | Minutes until workout starts |
| `body_weight_kg` | float | Yes | Shared with athlete profile |
| `workout_duration_min` | float | Yes | Total workout duration (for gate check) |
| `temp_celsius` | float | Yes | Shared with environment (for gate check) |

### Output

```
{
  fluid_ml,
  fluid_range: [min, max],
  sodium_mg,
  sodium_range: [min, max],
  message
}
```

---

## Formulas

### 9. preWorkoutGate

Same gate as during-workout. If the workout is short and conditions are mild, no structured pre-hydration is needed.

```
if workout_duration_min < 60 AND temp_celsius < 30:
  message = "No structured pre-hydration needed. Just make sure you're drinking normally throughout the day."
  EXIT (return message only, no fluid/sodium targets)
```

Exception: if temp_celsius >= 30, bypass the gate even if workout_duration_min < 60.

### 10. preWorkoutHydration

Three time-based tiers. Only one tier applies per call.

#### Tier 1: time_before_workout_min >= 120

Full ACSM protocol — enough time to drink, absorb, and urinate before start.

```
fluid_ml = body_weight_kg * 6
fluid_range = [body_weight_kg * 5, body_weight_kg * 7]
sodium_mg = 450
sodium_range = [300, 600]

message = "Sip {fluid_ml} ml gradually over the available window. Aim for pale yellow urine before start."
```

Tip (not a calculated recommendation): "If you haven't urinated by 2 hours before your workout, or your urine is still dark, consider drinking an additional 3–5 ml/kg."

#### Tier 2: time_before_workout_min >= 10 AND < 120

Not enough time for the full body-weight-scaled protocol. Fixed small top-up only.

```
fluid_ml = 250
fluid_range = [200, 300]
sodium_mg = 150
sodium_range = [100, 200]

message = "Small top-up only — not enough time for full pre-hydration. Rely on during-workout hydration to cover the gap."
```

If time_before_workout_min < 120, append: "For early morning workouts with limited time, consider hydrating well the evening before (extra 300–500 ml with dinner)."

#### Tier 3: time_before_workout_min < 10

Too late for meaningful pre-hydration.

```
fluid_ml = 0
fluid_range = [0, 0]
sodium_mg = 0
sodium_range = [0, 0]

message = "Too late for structured pre-hydration. A few small sips are fine for comfort."
```

### 11. preWorkoutWithTopUp

When time_before_workout_min >= 120, a final top-up in the last 10–20 minutes is common practice (e.g., with a pre-race gel). The algorithm can present the combined total:

```
tier1_fluid = body_weight_kg * 6
tier2_fluid = 250
total_fluid = tier1_fluid + tier2_fluid

tier1_sodium = 450
tier2_sodium = 150
total_sodium = tier1_sodium + tier2_sodium
```

This is informational — the tier 1 and tier 2 values are computed independently. The app can present them as a combined pre-workout plan when the athlete has enough time for both.

### 12. interactionWithDuringWorkout

The pre-workout algorithm is independent of the during-workout algorithm. It always prescribes the same volumes regardless of during-workout calculations. However:

```
if during_workout_deficit_pct > 0.03:
  pre_workout_message += " Your during-workout hydration can't fully keep up with your sweat losses. Starting well-hydrated is especially important for this workout."
```

---

# SHARED

---

## Constants

```
// During-workout constants
SWEAT_RATE_PERCENTILES = { LIGHT: 0.90, MEDIUM: 1.28, HEAVY: 1.66 }  // L/hr
SODIUM_PERCENTILES = { LOW: 650, AVERAGE: 825, HIGH: 1000 }           // mg/L
SWIMMING_SWEAT_MODIFIER = 0.4
TRANSITION_FLUID_ML = 300
TEMP_BASELINE_C = 22
TEMP_COEFFICIENT = 0.04          // per °C
HUMIDITY_BASELINE_PCT = 50
HUMIDITY_COEFFICIENT = 0.002
INDOOR_MULTIPLIER = 1.30
MIN_SWEAT_RATE = 0.3             // L/hr
MAX_SWEAT_RATE = 3.0             // L/hr
DEFICIT_THRESHOLD = 0.02         // 2% body weight
GI_CEILING_RUNNING = 800         // ml/hr
GI_CEILING_CYCLING = 1200        // ml/hr
REPLACEMENT_PCT = {
  60: 0.30,    // key = upper bound of tier
  90: 0.50,
  150: 0.60,
  240: 0.70,
  Infinity: 0.80
}

// Pre-workout constants
PRE_FLUID_ML_PER_KG = 6              // midpoint of 5–7 ml/kg
PRE_FLUID_ML_PER_KG_RANGE = [5, 7]
PRE_SODIUM_TIER1_MG = 450            // midpoint of 300–600 mg
PRE_SODIUM_TIER1_RANGE = [300, 600]
PRE_FLUID_TIER2_ML = 250             // midpoint of 200–300 ml
PRE_FLUID_TIER2_RANGE = [200, 300]
PRE_SODIUM_TIER2_MG = 150            // midpoint of 100–200 mg
PRE_SODIUM_TIER2_RANGE = [100, 200]
PRE_TIME_FULL_PROTOCOL_MIN = 120
PRE_TIME_TOPUP_MIN = 10
```

---

## Research References (for documentation, not code)

| Component | Source |
|-----------|--------|
| Sweat rate percentiles | Barnes/Baker 2019, n=1303 |
| Sodium concentration percentiles | Baker 2016, n=506 |
| Temperature coefficient (0.04 L/hr/°C) | Jenkins 2023 |
| Humidity minimal effect | Jenkins 2023, Che Muhamed 2016 |
| <60 min gate | Robinson 2003, McConell 1999, Backx 2003 |
| 50% at 60-90 min | Noakes 2007, ad libitum data |
| 60% at 90-150 min | ACSM 2007, 0.4-0.8 L/hr guideline |
| 70% at 150-240 min | Coyle 1992, "up to 80%" |
| 80% at 240+ min | DGE position (Mosler 2020), ISSN (Tiller 2019) |
| 2% BW threshold | ACSM 2007 (Sawka), Cheuvront 2014 |
| GI ceiling running 800 | Peters 1999, Pfeiffer 2012 |
| GI ceiling cycling 1200 | Coyle 1992, Lambert 1997 |
| Hyponatremia guard (<=100% sweat) | Hew-Butler 2015, Mosler 2020 |
| T1/T2 transition (300 ml) | Practitioner consensus |
| Sodium rides on fluid | Tiller 2019, McCubbin 2020 |
| Pre-workout 5-7 ml/kg, >=2 hr | ACSM 2007 (Sawka), Thomas 2016 |
| Pre-workout 200-300 ml, 10-120 min | NATA guidelines |
| Pre-workout sodium 300-600 mg | ACSM 2007 (Sawka) |

---

## Test Cases

Test cases are provided in a separate file (`hydration_sodium_calc_tests.md`) and should be run after implementation is complete.
