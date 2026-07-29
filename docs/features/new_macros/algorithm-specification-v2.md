# Mealvana Nutrition Algorithm Specification v2

**Purpose:** Calculate carbs, protein, fat, fiber, sodium, and hydration targets for endurance workouts.
**Output Format:** Range (low-high) with target value for each macro.
**Source:** Blog post "How Mealvana Calculates Your Fueling" (Jan 21, 2026)

---

## 1. Input Variables

### Required Inputs
| Variable | Symbol | Unit | Example |
|----------|--------|------|---------|
| Body weight | `W` | kg | 70 |
| Workout duration | `D` | minutes | 90 |
| Sport type | `S` | enum | run, bike, swim |
| Intensity: % in zones 1-2 | `I_low` | decimal (0-1) | 0.40 |
| Intensity: % in zone 3 | `I_med` | decimal (0-1) | 0.35 |
| Intensity: % in zones 4-5 | `I_high` | decimal (0-1) | 0.25 |
| Time before workout | `T_pre` | minutes | 120 |

**Note:** `I_low + I_med + I_high = 1.0`

### Environmental Inputs (Optional)
| Variable | Symbol | Unit | Default |
|----------|--------|------|---------|
| Temperature | `T_env` | °C | 20 |
| Humidity | `H_env` | % | 60 |

### Personalization Inputs (Optional)
| Variable | Symbol | Values | Default |
|----------|--------|--------|---------|
| Gut training level | `G` | low, moderate, high | moderate |
| Sweat rate category | `SR` | light, medium, heavy | medium |
| Sweat sodium category | `SN` | low, medium, high | medium |

---

## 2. Derived Values

### 2.1 Duration in Hours
```
D_h = D / 60
```

### 2.2 Intensity Carb Nudge (g/hr)

From blog: intensity affects carbohydrate oxidation rate. Higher intensity shifts fuel source toward carbs.

```
# Calculate weighted intensity nudge
# Low intensity (Z1-2): -5g/hr nudge
# Moderate intensity (Z3): 0g/hr nudge
# High intensity (Z4-5): +5g/hr nudge

I_nudge = (I_low × -5) + (I_med × 0) + (I_high × +5)
```

Range: -5g/hr (100% low) to +5g/hr (100% high)

### 2.3 Environmental Factor

```
if T_env ≤ 10:
    E_factor = 0.85
    E_label = "cool"
elif T_env ≤ 20 AND H_env ≤ 60:
    E_factor = 1.00
    E_label = "temperate"
elif T_env ≤ 25 OR H_env ≤ 75:
    E_factor = 1.10
    E_label = "warm"
elif T_env ≤ 30 OR H_env ≤ 85:
    E_factor = 1.20
    E_label = "hot"
else:
    E_factor = 1.30
    E_label = "very_hot"
```

### 2.4 Gut Training Absorption Cap (g/hr)

From blog: trained gut can absorb up to 120 g/hr with optimal glucose:fructose ratios.

```
if G = "low":
    G_cap = 70
elif G = "moderate":
    G_cap = 90
else:  # high
    G_cap = 110
```

### 2.5 Sweat Rate Estimate (L/hr)

```
if SR = "light":
    SR_base = 0.5
elif SR = "medium":
    SR_base = 0.8
else:  # heavy
    SR_base = 1.2

# Environmental adjustment
SR_actual = SR_base × E_factor
```

### 2.6 Sweat Sodium Concentration (mg/L)

From blog: Range 200-2,000 mg/L (10x individual variation). Baker et al. 2017 data: mean 826 mg/L.

```
if SN = "low":
    SN_conc = 400    # Lower quartile
elif SN = "medium":
    SN_conc = 800    # Near mean
else:  # high
    SN_conc = 1200   # Upper quartile
```

---

## 3. Pre-Workout Nutrition

**Source:** Blog Table - Pre-Workout Timing Windows

### 3.1 Carbohydrates (g)

From blog:
- 3-4 hr before: 1-4 g/kg
- 1-2 hr before: 1-2 g/kg
- 30-60 min before: 0.5-1 g/kg
- <30 min before: Not recommended (emergency 25-50g)

```
if T_pre ≥ 180:  # 3-4 hours before
    C_pre_low = 1.0 × W
    C_pre_high = 4.0 × W
    C_pre_target = 2.0 × W   # Midpoint
elif T_pre ≥ 60:  # 1-2 hours before
    C_pre_low = 1.0 × W
    C_pre_high = 2.0 × W
    C_pre_target = 1.5 × W
elif T_pre ≥ 30:  # 30-60 min before
    C_pre_low = 0.5 × W
    C_pre_high = 1.0 × W
    C_pre_target = 0.75 × W
else:  # <30 min (emergency only)
    C_pre_low = 25
    C_pre_high = 50
    C_pre_target = 30
```

### 3.2 Protein (g)

From blog: Not explicitly specified per window. Using research-based extrapolation from pre-workout meal composition.

```
if T_pre ≥ 180:  # Full meal window
    P_pre_low = 0.20 × W
    P_pre_high = 0.35 × W
    P_pre_target = 0.25 × W
elif T_pre ≥ 60:  # Snack window
    P_pre_low = 0.10 × W
    P_pre_high = 0.20 × W
    P_pre_target = 0.15 × W
else:  # <60 min - minimal protein
    P_pre_low = 0
    P_pre_high = 5
    P_pre_target = 0
```

### 3.3 Fat (g)

From blog:
- 3-4 hr before: 0.3-0.5 g/kg
- 1-2 hr before: <10g
- 30-60 min before: 0g

```
if T_pre ≥ 180:
    F_pre_low = 0.3 × W
    F_pre_high = 0.5 × W
    F_pre_target = 0.4 × W
elif T_pre ≥ 60:
    F_pre_low = 0
    F_pre_high = 10
    F_pre_target = 5
else:  # <60 min
    F_pre_low = 0
    F_pre_high = 0
    F_pre_target = 0
```

### 3.4 Fiber (g)

From blog:
- 3-4 hr before: Moderate
- 1-2 hr before: Low
- 30-60 min before: 0g

```
if T_pre ≥ 180:
    Fb_pre_low = 3
    Fb_pre_high = 8
    Fb_pre_target = 5
elif T_pre ≥ 60:
    Fb_pre_low = 0
    Fb_pre_high = 3
    Fb_pre_target = 1
else:  # <60 min
    Fb_pre_low = 0
    Fb_pre_high = 0
    Fb_pre_target = 0
```

### 3.5 Sodium (mg)

From blog: Pre-exercise sodium loading beneficial in hot conditions. Sims et al. 2007: 10-25 mg/kg.

```
# Base sodium by sweat category
if SN = "low":
    Na_pre_base = 300
elif SN = "medium":
    Na_pre_base = 450
else:  # high
    Na_pre_base = 600

# Environmental adjustment
if E_label in ["hot", "very_hot"]:
    Na_pre_bump = 150
elif E_label = "warm":
    Na_pre_bump = 75
else:
    Na_pre_bump = 0

Na_pre_target = Na_pre_base + Na_pre_bump
Na_pre_low = round(Na_pre_target × 0.75)
Na_pre_high = round(Na_pre_target × 1.25)
```

### 3.6 Hydration (mL)

From blog: Prehydrate with beverages several hours before activity.

```
# Main hydration (2-4 hours before): 5-7 ml/kg
if T_pre ≥ 150:
    H_pre_ml_per_kg = 6.0
else:
    H_pre_ml_per_kg = 5.0

# Hot weather adjustment
if E_label in ["hot", "very_hot"]:
    H_pre_ml_per_kg = H_pre_ml_per_kg + 1.0

H_pre_main = H_pre_ml_per_kg × W

# Top-off (30-60 min before): 150-300ml
if E_label in ["hot", "very_hot"]:
    H_pre_topoff = 300
elif T_pre ≥ 45:
    H_pre_topoff = 250
else:
    H_pre_topoff = 150

H_pre_target = H_pre_main + H_pre_topoff
H_pre_low = round(H_pre_target × 0.80)
H_pre_high = round(H_pre_target × 1.20)
```

---

## 4. During-Activity Nutrition

### 4.1 Base Carbohydrate Band by Duration (g/hr)

**Source:** Blog Table - Duration-Based Carbohydrate Targets

| Duration | Blog Range |
|----------|------------|
| <60 min | 0-30 g total |
| 60-90 min | 30-60 g/hr |
| 90 min - 2.5 hr | 45-60 g/hr |
| 2.5 - 4 hr | 60-90 g/hr |
| 4+ hr | 80-100 g/hr |

```
if D_h < 1.0:
    # <60 min: 0-30g TOTAL (not per hour)
    C_base_low = 0
    C_base_high = 30 / D_h  # Convert to rate for consistency
    C_base_mid = 15 / D_h
elif D_h < 1.5:
    # 60-90 min: 30-60 g/hr
    C_base_low = 30
    C_base_high = 60
    C_base_mid = 45
elif D_h < 2.5:
    # 90 min - 2.5 hr: 45-60 g/hr
    C_base_low = 45
    C_base_high = 60
    C_base_mid = 52.5
elif D_h < 4.0:
    # 2.5 - 4 hr: 60-90 g/hr
    C_base_low = 60
    C_base_high = 90
    C_base_mid = 75
else:
    # 4+ hr: 80-100 g/hr
    C_base_low = 80
    C_base_high = 100
    C_base_mid = 90
```

### 4.2 Sport-Specific Carb Ceiling (g/hr)

**Source:** Blog Table - Sport-Specific Differences

| Sport | Practical Carb Ceiling |
|-------|----------------------|
| Running | 50-70 g/hr |
| Cycling | 80-120 g/hr |
| Swimming | Pre/post only (0 g/hr) |

```
if S = "run":
    C_sport_low = 50
    C_sport_high = 70
elif S = "bike":
    C_sport_low = 80
    C_sport_high = 120
elif S = "swim":
    C_sport_low = 0
    C_sport_high = 0  # Cannot eat while swimming
```

### 4.3 Intensity-Adjusted Carb Target

Apply intensity nudge (±5g/hr) to midpoint of duration band.

```
C_intensity_adjusted = C_base_mid + I_nudge
```

### 4.4 Final During-Activity Carbs (g/hr)

Apply all constraints: duration band, sport ceiling, gut training cap.

```
# For swimming: always 0
if S = "swim":
    C_during_target = 0
    C_during_low = 0
    C_during_high = 0
else:
    # Clamp to sport ceiling
    C_during_raw = min(C_intensity_adjusted, C_sport_high)

    # Clamp to gut training cap
    C_during_raw = min(C_during_raw, G_cap)

    # Clamp to duration band
    C_during_target = max(C_base_low, min(C_during_raw, C_base_high))

    # Range: ±10g from target, within all constraints
    C_during_low = max(C_base_low, C_during_target - 10)
    C_during_high = min(C_base_high, min(C_sport_high, min(G_cap, C_during_target + 10)))
```

### 4.5 Total During-Activity Carbs (g)

```
C_during_total_target = C_during_target × D_h
C_during_total_low = C_during_low × D_h
C_during_total_high = C_during_high × D_h
```

### 4.6 During-Activity Protein (g/hr)

From blog: Protein not typically needed during activity except ultra-endurance (>4 hours).

```
if D_h ≤ 4.0:
    P_during_rate = 0
else:
    P_during_rate = 3  # ~10g every 3 hours for muscle preservation
```

### 4.7 During-Activity Fat (g/hr)

```
if D_h ≤ 4.0:
    F_during_rate = 0
else:
    F_during_rate = 2  # Small amounts in ultra-endurance
```

### 4.8 During-Activity Fiber (g/hr)

```
Fb_during_rate = 0  # Always zero - fiber causes GI distress during activity
```

### 4.9 During-Activity Sodium (mg/hr)

**Source:** Blog - Sodium Individualization
- Target 50-80% replacement during exercise
- Hot conditions: 300-600 mg/hr minimum

```
# Calculate sodium loss rate
Na_loss_rate = SR_actual × SN_conc

# Target 50-80% replacement (using 60% as target)
Na_during_low = max(300, round(Na_loss_rate × 0.50))
Na_during_high = min(1200, round(Na_loss_rate × 0.80))
Na_during_target = round(Na_loss_rate × 0.60)

# Clamp target to range
Na_during_target = max(Na_during_low, min(Na_during_target, Na_during_high))

# Hot weather minimum
if E_label in ["hot", "very_hot"]:
    Na_during_low = max(Na_during_low, 400)
    Na_during_target = max(Na_during_target, 500)
```

### 4.10 Total During-Activity Sodium (mg)

```
Na_during_total_target = Na_during_target × D_h
Na_during_total_low = Na_during_low × D_h
Na_during_total_high = Na_during_high × D_h
```

### 4.11 During-Activity Hydration (mL/hr)

**Source:** Blog - Fluid Requirements

```
# Base fluid rate: 400-800 mL/hr
H_during_base = 600  # Midpoint

# Weight adjustment
if W < 55:
    H_weight_adj = -100
elif W > 85:
    H_weight_adj = +100
else:
    H_weight_adj = 0

# Environmental adjustment
H_during_base = (H_during_base + H_weight_adj) × E_factor

# Target: match ~70-80% of sweat losses
H_sweat_match = SR_actual × 1000 × 0.75

# Use higher of calculated rate or sweat match
H_during_target = max(H_during_base, H_sweat_match)

# Clamp to practical limits
H_during_low = max(300, round(H_during_target × 0.80))
H_during_high = min(1200, round(H_during_target × 1.20))
H_during_target = round(H_during_target)
```

### 4.12 Total During-Activity Hydration (mL)

```
H_during_total_target = H_during_target × D_h
H_during_total_low = H_during_low × D_h
H_during_total_high = H_during_high × D_h
```

---

## 5. Post-Workout Nutrition

**Source:** Blog Table - Post-Workout Recovery

### 5.1 Post-Workout Carbohydrates (g)

From blog: Glycogen resynthesis 1.0-1.2 g/kg/hr, maximal within 4 hours post.

```
if D_h > 2.0:
    C_post_per_kg = 1.2  # Extended depletion
else:
    C_post_per_kg = 1.0

C_post_target = C_post_per_kg × W
C_post_low = round(C_post_target × 0.85)
C_post_high = round(C_post_target × 1.15)
```

### 5.2 Post-Workout Protein (g)

From blog: 0.25-0.4 g/kg (20-40g), ~3g leucine threshold. Moore 2009: 20g plateau for MPS.

```
P_post_per_kg = 0.3  # Midpoint of 0.25-0.4 range

P_post_target = P_post_per_kg × W
P_post_low = max(20, round(P_post_target × 0.85))  # Minimum 20g for MPS
P_post_high = min(40, round(P_post_target × 1.15)) # Maximum 40g
```

### 5.3 Post-Workout Fat (g)

From blog: Not explicitly specified. Fat doesn't impair recovery.

```
F_post_per_kg = 0.2

F_post_target = F_post_per_kg × W
F_post_low = round(F_post_target × 0.75)
F_post_high = round(F_post_target × 1.25)
```

### 5.4 Post-Workout Fiber (g)

```
Fb_post_low = 0
Fb_post_high = 5
Fb_post_target = 2  # Light fiber OK in recovery
```

### 5.5 Post-Workout Sodium (mg)

From blog: Rehydration with 500-700 mg/L sodium.

```
# Estimate remaining deficit
Na_total_lost = SR_actual × SN_conc × D_h
Na_replaced_during = Na_during_total_target
Na_deficit = Na_total_lost - Na_replaced_during

# Replace 50-70% of remaining deficit
Na_post_target = max(300, round(Na_deficit × 0.50))
Na_post_low = round(Na_post_target × 0.75)
Na_post_high = min(700, round(Na_post_target × 1.25))
```

### 5.6 Post-Workout Hydration (mL)

From blog: 150% of fluid losses.

```
# Calculate fluid deficit
H_total_lost = SR_actual × D_h × 1000
H_replaced_during = H_during_total_target
H_deficit = H_total_lost - H_replaced_during

# Replace 150% of deficit (range: 125-175%)
H_post_target = round(H_deficit × 1.50)
H_post_low = max(500, round(H_deficit × 1.25))
H_post_high = round(H_deficit × 1.75)

# Minimum recovery hydration
H_post_target = max(500, H_post_target)
```

---

## 6. Transition Nutrition (Brick Workouts Only)

From blog: 20-30% reduction in run carb targets after bike leg due to reduced GI tolerance.

### 6.1 Transition Context Variables

For each transition:
- `S_prev`: previous sport (swim, bike)
- `S_next`: next sport (bike, run)
- `D_remaining`: remaining workout duration (minutes)

### 6.2 T1 (Swim → Bike or Swim → Run)

```
# Base carbs: 0.3 g/kg
C_T1_target = 0.3 × W

# Environmental sodium bump
if E_label in ["hot", "very_hot"]:
    Na_T1_target = 250
elif E_label = "warm":
    Na_T1_target = 175
else:
    Na_T1_target = 150

# Environmental hydration bump
if E_label in ["hot", "very_hot"]:
    H_T1_target = 300
elif E_label = "warm":
    H_T1_target = 225
else:
    H_T1_target = 200

# Protein/Fat/Fiber
P_T1 = 0
F_T1 = 0
Fb_T1 = 0

# Ranges
C_T1_low = round(C_T1_target × 0.80)
C_T1_high = round(C_T1_target × 1.20)
Na_T1_low = round(Na_T1_target × 0.80)
Na_T1_high = round(Na_T1_target × 1.20)
H_T1_low = round(H_T1_target × 0.80)
H_T1_high = round(H_T1_target × 1.20)
```

### 6.3 T2 (Bike → Run)

```
# Base carbs: 0.35 g/kg (slightly higher - last chance before run)
C_T2_target = 0.35 × W

# Environmental sodium bump
if E_label in ["hot", "very_hot"]:
    Na_T2_target = 175
else:
    Na_T2_target = 100

# Environmental hydration bump
if E_label in ["hot", "very_hot"]:
    H_T2_target = 225
else:
    H_T2_target = 150

# Protein/Fat/Fiber
P_T2 = 0
F_T2 = 0
Fb_T2 = 0

# Ranges
C_T2_low = round(C_T2_target × 0.80)
C_T2_high = round(C_T2_target × 1.20)
Na_T2_low = round(Na_T2_target × 0.80)
Na_T2_high = round(Na_T2_target × 1.20)
H_T2_low = round(H_T2_target × 0.80)
H_T2_high = round(H_T2_target × 1.20)
```

---

## 7. Brick Workout: Segment Allocation

### 7.1 Calculate Total During-Workout Needs

Use **cumulative duration** of all segments for the duration-based carb band.

```
D_total = Σ(all segment durations in minutes)
D_total_h = D_total / 60

# Apply Section 4 formulas using D_total_h
# This gives: C_during_total_target, Na_during_total_target, H_during_total_target
```

### 7.2 Post-Bike Run Penalty

**Source:** Blog - 20-30% reduction in run carb targets after bike leg

```
# Run segment after bike gets reduced carb ceiling
if segment is run AND previous segment was bike:
    C_run_penalty = 0.25  # 25% reduction (midpoint of 20-30%)

    # Apply penalty to sport ceiling
    C_run_ceiling_adjusted = C_sport_high × (1 - C_run_penalty)
    # C_run_ceiling_adjusted = 70 × 0.75 = 52.5 g/hr

    # Also apply gut training cap
    C_run_ceiling_adjusted = min(C_run_ceiling_adjusted, G_cap)
```

### 7.3 Subtract Transition Allocation

```
C_segments_pool = C_during_total_target - C_T1_target - C_T2_target
Na_segments_pool = Na_during_total_target - Na_T1_target - Na_T2_target
H_segments_pool = H_during_total_target - H_T1_target - H_T2_target
```

### 7.4 Allocate to Each Segment

```
for each segment i:
    D_i_h = segment_duration_minutes / 60

    if S_i = "swim":
        # Cannot eat while swimming
        C_segment_i = 0
        Na_segment_i = 0
        H_segment_i = 0

    elif S_i = "bike":
        # Calculate bike's share of non-swim duration
        D_non_swim_h = Σ(duration of bike + run segments) / 60
        bike_share = D_i_h / D_non_swim_h

        # Front-load if followed by run (+15%)
        if next_segment is run:
            bike_boost = 1.15
        else:
            bike_boost = 1.00

        C_segment_i = C_segments_pool × bike_share × bike_boost
        Na_segment_i = Na_segments_pool × bike_share
        H_segment_i = H_segments_pool × bike_share

    elif S_i = "run":
        # Calculate run's share
        D_non_swim_h = Σ(duration of bike + run segments) / 60
        run_share = D_i_h / D_non_swim_h

        # Apply post-bike penalty if applicable
        if previous_segment was bike:
            C_run_max_rate = 70 × (1 - 0.25)  # = 52.5 g/hr
        else:
            C_run_max_rate = 70

        C_run_max = C_run_max_rate × D_i_h
        C_run_proportional = C_segments_pool × run_share

        # Use minimum of proportional share and capped max
        C_segment_i = min(C_run_max, C_run_proportional)
        Na_segment_i = Na_segments_pool × run_share
        H_segment_i = H_segments_pool × run_share
```

### 7.5 Rebalance Excess

If run cap reduces carbs below proportional share, add excess to bike segment.

```
C_allocated = Σ(C_segment_i for all segments)
C_excess = C_segments_pool - C_allocated

if C_excess > 0:
    # Add excess to bike segment(s)
    for each bike_segment:
        C_segment_bike += C_excess × (D_bike / D_total_bike)
```

---

## 8. Output Format

For each phase, output:

```json
{
  "phase": "pre_workout | during_run | during_bike | during_swim | transition_T1 | transition_T2 | post_workout",
  "timing": "2 hours before | during | within 30 min after",
  "macros": {
    "carbs_g": { "low": 70, "target": 105, "high": 140 },
    "protein_g": { "low": 7, "target": 10, "high": 14 },
    "fat_g": { "low": 21, "target": 28, "high": 35 },
    "fiber_g": { "low": 0, "target": 1, "high": 3 },
    "sodium_mg": { "low": 338, "target": 450, "high": 563 },
    "hydration_ml": { "low": 464, "target": 580, "high": 696 }
  }
}
```

---

## 9. Worked Example: 2-Hour Run

### Inputs
- Weight: 70 kg
- Duration: 120 minutes (2 hours)
- Sport: run
- Intensity: 30% low, 50% medium, 20% high
- Time before: 120 minutes
- Temperature: 25°C, Humidity: 65%
- Gut training: moderate
- Sweat rate: medium
- Sweat sodium: medium

### Derived Values
```
D_h = 2.0
I_nudge = (0.30 × -5) + (0.50 × 0) + (0.20 × 5) = -0.5 g/hr
E_factor = 1.10 (warm)
G_cap = 90
SR_actual = 0.8 × 1.10 = 0.88 L/hr
SN_conc = 800 mg/L
```

### Pre-Workout (2 hours before)
```
C_pre: 1.5 × 70 = 105g (range: 70-140g)
P_pre: 0.15 × 70 = 10.5g ≈ 11g (range: 7-14g)
F_pre: 5g (range: 0-10g)
Fb_pre: 1g (range: 0-3g)
Na_pre: 450 + 75 = 525mg (range: 394-656mg)
H_pre: (5 × 70) + 250 = 600ml (range: 480-720ml)
```

### During-Run
```
Duration band (90min-2.5hr): 45-60 g/hr
Sport ceiling: 50-70 g/hr
Intensity-adjusted midpoint: 52.5 + (-0.5) = 52 g/hr

C_during: 52 g/hr (range: 45-60 g/hr)
C_total: 52 × 2 = 104g (range: 90-120g)

P_during: 0 g/hr
F_during: 0 g/hr
Fb_during: 0 g/hr

Na_loss = 0.88 × 800 = 704 mg/hr
Na_during: 704 × 0.60 = 422 mg/hr (range: 352-563 mg/hr)
Na_total: 844mg (range: 704-1126mg)

H_during: max(600 × 1.10, 0.88 × 1000 × 0.75) = max(660, 660) = 660 ml/hr
H_total: 1320ml (range: 1056-1584ml)
```

### Post-Workout
```
C_post: 1.0 × 70 = 70g (range: 60-81g)
P_post: 0.3 × 70 = 21g (range: 20-24g)
F_post: 0.2 × 70 = 14g (range: 11-18g)
Fb_post: 2g (range: 0-5g)

Na_deficit: (704 × 2) - 844 = 564mg
Na_post: 564 × 0.50 = 282mg (range: 212-353mg)

H_deficit: (0.88 × 2 × 1000) - 1320 = 440ml
H_post: 440 × 1.50 = 660ml (range: 550-770ml)
```

---

## 10. Constants Reference

| Constant | Value | Source |
|----------|-------|--------|
| SGLT1 cap (single carb) | 60 g/hr | Jeukendrup 2004 |
| Gut cap (low training) | 70 g/hr | Research extrapolation |
| Gut cap (moderate) | 90 g/hr | Research consensus |
| Gut cap (high training) | 110 g/hr | Hearris 2022 |
| Run carb ceiling | 50-70 g/hr | Blog table |
| Bike carb ceiling | 80-120 g/hr | Blog table |
| Swim carb ceiling | 0 g/hr | Blog (pre/post only) |
| Post-bike run penalty | 25% | Blog (20-30% range) |
| Protein MPS threshold | 20g | Moore 2009 |
| Protein MPS ceiling | 40g | Moore 2009 |
| Sodium replacement | 50-80% | Blog |
| Hot weather Na minimum | 300-600 mg/hr | Blog |
| Rehydration factor | 150% | Blog |
| Sweat Na range | 200-2000 mg/L | Baker 2017 |
