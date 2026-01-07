# Macro Formulas Audit

**Source**: `supabase/functions/generate-macros/index.ts`
**Last Audited**: January 2026

---

## Definitions

- **MET** (Metabolic Equivalent of Task): Intensity measure where 1 MET = resting metabolic rate. Running at 6 mph ≈ 10 MET.
- **Gut training**: User's tolerance for consuming carbs during exercise (low/moderate/high). Higher = can absorb more carbs/hour.
- **Environment multiplier**: Scaling factor (0.85–1.3) based on temperature and humidity that adjusts hydration needs.
- **Absorption cap**: Maximum carbs the gut can absorb per hour, varies by carb source type and gut training level.
- **Dual source**: Using both glucose and fructose (e.g., maltodextrin + fructose), allowing higher absorption than glucose alone.

---

## Running

### Pre-Run

```
hours = min(time_before_min / 60, 4.0)

carbs_g = min(3.0, max(0.5, hours)) × weight_kg

protein_g:
  time_before ≤ 60 min:  0.15 × weight_kg
  time_before ≤ 90 min:  0.20 × weight_kg
  time_before > 90 min:  0.25 × weight_kg

fat_g:
  time_before ≤ 60 min:  0.10 × weight_kg
  time_before ≤ 90 min:  0.15 × weight_kg
  time_before > 90 min:  0.20 × weight_kg
```

### During-Run

```
carbs_g_per_h = base_from_band + gut_nudge + intensity_nudge

Duration bands (base g/h):
  ≤1h:   low=0,  high=30
  1-2h:  low=30, high=45
  2-3h:  low=45, high=60
  3-4h:  low=60, high=75
  >4h:   low=75, high=90

gut_nudge:
  low:      -5
  moderate:  0
  high:     +5

intensity_nudge (based on MET):
  MET < 7:  -5
  MET 7-9:   0
  MET > 9:  +5

mass_tilt (position within band):
  weight < 50kg: use low end
  weight > 80kg: use high end
  else: midpoint

floor_rule:
  if duration > 1.1h AND MET > 8: minimum 30 g/h

absorption_cap:
  glucose_only + low_gut:      60 g/h
  glucose_only + high_gut:     65 g/h
  dual_source + low_gut:       80 g/h
  dual_source + moderate_gut:  90 g/h
  dual_source + high_gut:     100 g/h

carbs_total_g = carbs_g_per_h × duration_h

protein_g_per_h:
  duration ≤ 3.5h: 0
  duration > 3.5h: 3.0

fat_g_per_h:
  duration ≤ 3.5h: 0
  duration > 3.5h: 2.0
```

### Post-Run

```
carbs_g:
  duration ≤ 2h: 1.0 × weight_kg
  duration > 2h: 1.2 × weight_kg

protein_g = 0.3 × weight_kg

fat_g = 0.2 × weight_kg
```

---

## Cycling

### Pre-Ride

```
hours = time_before_min / 60

carbs_g:
  hours ≥ 1.0:  hours × weight_kg (max 4.0 × weight_kg)
  hours ≥ 0.25: 0.5 × weight_kg
  hours < 0.25: 0.25 × weight_kg

protein_g = 0.25 × weight_kg

fat_g:
  hours > 2.0: 0.2 × weight_kg
  else:        0.1 × weight_kg
```

### During-Ride

```
carbs_g_per_h = base_target × gut_multiplier + intensity_bonus

Duration bands (base g/h):
  ≤1h:   low=0,   high=30
  1-2h:  low=30,  high=60
  2-3h:  low=60,  high=90
  3-4h:  low=75,  high=100
  >4h:   low=90,  high=120

base_target = (low + high) / 2

gut_multiplier:
  low:      0.85
  moderate: 1.0
  high:     1.1

intensity_bonus (based on MET):
  MET ≥ 12: +10
  MET ≥ 10: +5
  MET < 10:  0

absorption_cap:
  high_gut:  100 g/h
  else:       90 g/h

carbs_total_g = carbs_g_per_h × duration_h

protein_g_per_h:
  duration ≤ 3.5h: 0
  duration > 3.5h: 5.0

fat_g_per_h = 0 (not calculated for cycling during-ride)
```

### Post-Ride

```
carbs_g:
  duration ≤ 2h: 1.0 × weight_kg
  duration > 2h: 1.2 × weight_kg

protein_g = 0.3 × weight_kg

fat_g = not explicitly calculated (use running formula as fallback)
```

---

## Swimming

### Pre-Swim

```
hours = time_before_min / 60

carbs_g:
  hours ≥ 1.0:  hours × weight_kg (max 4.0 × weight_kg)
  hours ≥ 0.25: 0.5 × weight_kg
  hours < 0.25: 0.25 × weight_kg

protein_g = same as cycling (0.25 × weight_kg)

fat_g = same as cycling
```

### During-Swim

```
carbs_g_per_h = base_target × gut_multiplier

Duration bands (base g/h):
  ≤1h:     low=0,  high=0   (no during-swim carbs)
  1-1.5h:  low=0,  high=30
  1.5-2.5h: low=30, high=60
  >2.5h:   low=45, high=75

open_water_bonus (if >1.5h):
  open_water: high += 10
  pool:       0

base_target = (low + high) / 2

gut_multiplier:
  low:      0.85
  moderate: 1.0
  high:     1.1

absorption_cap = 60 g/h

carbs_total_g = carbs_g_per_h × duration_h

protein_g_per_h:
  duration ≤ 3.5h: 0
  duration > 3.5h: 3.0

fat_g_per_h = 0 (not calculated for swimming during)
```

### Post-Swim

```
carbs_g:
  duration ≤ 2h: 1.0 × weight_kg
  duration > 2h: 1.2 × weight_kg

protein_g = 0.3 × weight_kg

fat_g = not explicitly calculated
```

---

## Hydration & Sodium

### Environment Multiplier

```
temp_c ≤ 10:                    0.85 (cool)
temp_c 10-20, humidity ≤ 60%:   1.0  (temperate)
temp_c 20-25 OR humidity 60-75%: 1.1  (warm)
temp_c 25-30 OR humidity 75-85%: 1.2  (hot)
temp_c > 30 OR humidity > 85%:  1.3  (very_hot)
```

### Running Hydration

```
Pre-run:
  main_ml = (time_before ≥ 150min ? 6.0 : 4.0) × weight_kg
  if hot/very_hot: main_ml += 1.0 × weight_kg
  topoff_ml = hot/very_hot ? 300 : (time_before ≥ 45min ? 250 : 150)

During-run:
  base_band = 0.4–0.8 L/h
  adjustments:
    weight < 50kg: high -= 0.1
    weight > 80kg: low += 0.1
    MET > 9: both += 0.05
    MET < 7: both -= 0.05
  final = base_band × env_multiplier, clamped to 0.3–1.2 L/h

  If measured sweat_rate provided: plan = sweat_rate × 0.7
  Else: plan = typical_rate × env_multiplier × 0.8
    typical_rate: light=0.45, medium=0.75, heavy=1.1 L/h
```

### Running Sodium

```
Pre-run:
  base: light=300, medium=450, heavy=600 mg
  if hot/very_hot: +100 mg

During-run (if measured sweat rate):
  concentration: low=400, medium=800, high=1200 mg/L
  loss_mg_per_h = concentration × sweat_rate_lph
  target = loss × 0.6, clamped to [loss×0.5, loss×0.7]

During-run (category fallback):
  base: low=400, medium=650, high=1000 mg/h
  + env bump: warm=+50, hot=+100, very_hot=+150
```

### Cycling Hydration & Sodium

```
Hydration:
  base = 0.6 L/h (0.5 if <50kg, 0.7 if >80kg)
  if MET ≥ 12: +0.1
  final = base × env_multiplier, capped at 1.0 L/h

Sodium:
  base: low=400, medium=650, high=1000 mg/h
  + env bump: hot=+100, very_hot=+150
  capped at 1200 mg/h
```

### Swimming Hydration & Sodium

```
Hydration:
  base = 0.45 L/h (0.35 if <50kg, 0.55 if >80kg)
  if MET ≥ 11: +0.1
  water temp adjustment: >28°C ×1.2, <20°C ×0.8
  capped at 0.8 L/h

Sodium:
  base: low=300, medium=500, high=700 mg/h
  water temp: >28°C +50, <20°C -50
  capped at 800 mg/h
```

---

## Notes on Unused Parameters

The Flutter app sends age, gender, and height to the generate-macros edge function, but these parameters are never used in any calculation. The edge function has a `toCm()` converter function defined but it's never called. All macro formulas depend only on weight, not on age, gender, or height. These fields could be removed from the API to simplify the interface, or retained if there are future plans to implement age/gender-adjusted formulas (e.g., older athletes may need different recovery protein ratios).

Temperature and humidity ARE used - they feed into the environment multiplier which affects hydration recommendations. Sweat rate category IS used as a fallback when no measured sweat rate is provided. If a measured sweat rate (`optional_sweat_rate_lph`) is passed, it takes precedence over the category-based estimate.

The `carb_source` parameter (glucose_only vs dual) only affects the absorption cap for running, not the base carb calculation. Cycling and swimming don't use this parameter at all.
