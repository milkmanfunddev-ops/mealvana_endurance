# Current Macro Generation Logic

**Source:** `/supabase/functions/generate-macros/index.ts`

---

## Architecture Overview

The macro generation system uses a **hybrid approach**:
1. **Edge Functions** (TypeScript on Supabase) - Calculate macro targets using evidence-based formulas
2. **Flutter Services** (Dart) - Orchestrate calls to edge functions and handle offline fallbacks
3. **Multi-Sport Support** - Separate calculation paths for running, cycling, swimming, and brick workouts

---

## Input Parameters

### Common (All Sports)
- `weight` (pounds or kg) + `weight_unit`
- `age`, `gender`, `height` + `height_unit`
- `gut_training` - Level: 'low', 'moderate', 'high'
- `time_before_run_min` - Pre-workout timing (default: 120 minutes)
- `temp_c`, `humidity_pct` - Environmental conditions
- `sweat_sodium` - Category: 'low', 'medium', 'high'
- `sweat_rate_category` - 'light', 'medium', 'heavy'
- `optional_sweat_rate_lph` - Measured sweat rate (liters/hour)
- `drink_sodium_mg_per_l` - Sodium concentration in drink (default: 500)

### Sport-Specific
- **Running:** `run_distance`, `run_pace`, `run_distance_unit`, `run_pace_unit`
- **Cycling:** `distance_miles`, `speed_mph`, `terrain`, `elevation_gain_ft`, `indoor_outdoor`
- **Swimming:** `distance_meters`, `pace_per_100m_seconds`, `pool_or_open_water`, `water_temp_c`
- **Brick:** `brick_segments` (array of segments with sport, duration, intensity)

---

## Running Formulas

### MET Calculation (ACSM Running Equation)

```
MET = VO2 / 3.5

For running (speed >= 4.0 mph):
  v = speed × 26.8224 (convert mph to m/min)
  VO2 = 0.2 × v + 3.5

For walking (speed < 4.0 mph):
  v = speed × 26.8224
  VO2 = 0.1 × v + 3.5
```

### Energy Expenditure

```
Gross kcal = MET × 3.5 × weight_kg / 200 × duration_min

Net kcal (transport cost) = 1.0 × weight_kg × distance_km
```

### Duration-Based Carb Bands

| Duration (h) | Low (g/hr) | High (g/hr) |
|--------------|------------|-------------|
| ≤1.0 | 0 | 30 |
| 1.0-2.0 | 30 | 45 |
| 2.0-3.0 | 45 | 60 |
| 3.0-4.0 | 60 | 75 |
| >4.0 | 75 | 90 |

### Gut Training Absorption Caps

| Gut Level | Single Carb (g/hr) | Dual Carb (g/hr) |
|-----------|-------------------|------------------|
| Low | 60 | 80 |
| Moderate | 60 | 90 |
| High | 65 | 100 |

### Carb Recommendation Algorithm

```
1. Get base band from duration
2. Floor condition: if duration > 1.1h AND MET > 8 AND low < 30, set low = 30
3. Intensity nudge: MET < 7 → -5g; MET > 9 → +5g
4. Gut nudge: low → -5g; high → +5g
5. Mass tilt: weight < 50kg → low; weight > 80kg → high; else midpoint
6. Raw = clamp(massTilt + intensityNudge + gutNudge, adjustedLow, high)
7. Final = min(raw, absorptionCap)
```

### Pre-Run Macros

```
Hours = min(time_before_min / 60, 4.0)

Carbs = min(3.0, max(0.5, hours)) × weight_kg

Protein:
  ≤60 min: 0.15 × weight_kg
  60-90 min: 0.2 × weight_kg
  >90 min: 0.25 × weight_kg

Fat:
  ≤60 min: 0.1 × weight_kg
  60-90 min: 0.15 × weight_kg
  >90 min: 0.2 × weight_kg
```

### During-Run Macros

```
Carbs/hr = calculated from algorithm above

Protein/hr = duration ≤ 3.5h ? 0 : 3g
Fat/hr = duration ≤ 3.5h ? 0 : 2g
```

### Post-Run Macros

```
Carbs = (duration > 2h ? 1.2 : 1.0) × weight_kg
Protein = 0.3 × weight_kg
Fat = 0.2 × weight_kg
```

---

## Hydration Formulas

### Environmental Multiplier

| Temp (°C) | Humidity (%) | Multiplier | Label |
|-----------|--------------|------------|-------|
| ≤10 | any | 0.85 | cool |
| 10-20 | ≤60 | 1.0 | temperate |
| 20-25 OR | 60-75 | 1.1 | warm |
| 25-30 OR | 75-85 | 1.2 | hot |
| >30 OR | >85 | 1.3 | very_hot |

### Fluid Band (L/hr)

```
Base: low = 0.4, high = 0.8

Weight adjustments:
  < 50kg: high -= 0.1
  > 80kg: low += 0.1

Intensity adjustments:
  MET > 9: low += 0.05, high += 0.05
  MET < 7: low -= 0.05, high -= 0.05

Apply environmental multiplier

Clamp: low = max(0.3, min(1.0)), high = max(low + 0.05, min(1.2))
```

### Sodium Target

**With measured sweat rate:**
```
Sodium concentration by category:
  low: 400 mg/L
  medium: 700 mg/L
  high: 1100 mg/L

Loss (mg/hr) = concentration × sweat_rate_lph

Low = max(300, loss × 0.5)   # Replace 50%
High = min(1200, loss × 0.7)  # Replace 70%
Target = clamp(loss × 0.6, low, high)
```

**Category-based fallback:**
| Category | Low | High | Target |
|----------|-----|------|--------|
| low | 300 | 500 | 400 |
| medium | 500 | 800 | 650 |
| high | 800 | 1200 | 1000 |

Environmental bump: warm +50, hot +100, very_hot +150

### Pre-Run Hydration

```
Main (ml/kg):
  ≥150 min before: 6.0
  <150 min: 4.0
  hot/very_hot: +1.0

Main = ml_per_kg × weight_kg

Top-off:
  hot/very_hot: 300ml
  ≥45 min before: 250ml
  <45 min: 150ml

Sodium loading:
  low: 300mg
  medium: 450mg
  high: 600mg
  hot/very_hot: +100mg
```

---

## Cycling Formulas

### MET from Speed

| Speed (kph) | Base MET |
|-------------|----------|
| ≤16 | 6.0 |
| 16-19 | 8.0 |
| 19-22 | 10.0 |
| 22-25 | 12.0 |
| 25-30 | 14.0 |
| >30 | 16.0 |

**Terrain adjustment:**
- Rolling: ×1.1
- Hilly: ×1.25

**Elevation adjustment (MET bonus):**
| Vertical (m/km) | Bonus |
|-----------------|-------|
| >100 | +4.0 |
| 60-100 | +3.0 |
| 30-60 | +2.0 |
| 10-30 | +1.0 |

**Indoor:** ×0.95

### Cycling Carb Bands (Higher than Running)

| Duration (h) | Min (g/hr) | Max (g/hr) |
|--------------|------------|------------|
| ≤1.0 | 0 | 30 |
| 1.0-2.0 | 30 | 60 |
| 2.0-3.0 | 60 | 90 |
| 3.0-4.0 | 75 | 100 |
| >4.0 | 90 | 120 |

**Gut multiplier:** low ×0.85, high ×1.1
**Intensity bonus:** MET ≥12 +10g, MET ≥10 +5g
**Max absorption:** high gut = 100g/hr, else 90g/hr

---

## Swimming Formulas

### MET from Pace

| Pace (sec/100m) | Base MET |
|-----------------|----------|
| ≥180 | 6.0 |
| 150-180 | 8.0 |
| 120-150 | 10.0 |
| 90-120 | 11.0 |
| <90 | 13.0 |

**Open water:** ×1.15
**Cold water (<20°C):** ×1.1
**Warm water (>28°C):** ×0.95

### Swimming Carb Bands (Lower - Feeding Difficulty)

| Duration (h) | Min (g/hr) | Max (g/hr) |
|--------------|------------|------------|
| ≤1.0 | 0 | 0 |
| 1.0-1.5 | 0 | 30 |
| 1.5-2.5 | 30 | 60 |
| >2.5 | 45 | 75 |

**Open water bonus (>1.5h):** max +10g
**Max absorption:** 60g/hr (practical limit)

### Swimming Hydration (Lower)

Base: 0.45 L/hr
Range: 0.35-0.55 L/hr based on weight
**Cap:** 0.8 L/hr

### Swimming Sodium (Lower)

| Category | mg/hr |
|----------|-------|
| low | 300 |
| medium | 500 |
| high | 700 |

**Warm water (>28°C):** +50
**Cold water (<20°C):** -50
**Cap:** 800 mg/hr

---

## Brick Workout Formulas

### Total Duration Carb Bands

Uses same bands as running but based on **cumulative duration**.

### Intensity Weighting

```
Multipliers:
  easy: 0.7
  moderate: 1.0
  hard: 1.2
  race: 1.3

Weighted intensity = Σ(segment_duration / total_duration × multiplier)
Adjusted carbs = base_carbs × weighted_intensity
```

### Segment Allocation

**Swimming:** 0g carbs during (cannot eat)
**Cycling:** Maximize intake, +20% if followed by run
**Running:** Cap at 35g/hr (reduced GI tolerance post-bike)

### Transition Targets

| Transition | Carbs | Sodium | Water |
|------------|-------|--------|-------|
| T1 | 20g | 150mg | 200ml |
| T2 | 25g | 100mg | 150ml |

---

## Summary: Current Gaps

1. **No intensity zones** - Uses single MET value, not zone distribution
2. **No fiber tracking** - Pre-workout fiber not calculated
3. **Fixed transition values** - Not personalized
4. **No sport-specific pre-workout** - Same formula for all sports
5. **Limited during-swim support** - Assumes no feeding
