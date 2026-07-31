# Mealvana Nutrition Algorithm v3

## Introduction

This algorithm calculates personalized nutrition targets for endurance athletes across six macros: carbohydrates, protein, fat, fiber, sodium, and hydration. It covers four workout phases: pre-workout (with three timing windows), during exercise, post-workout, and transitions (for brick workouts).

The algorithm is built primarily from guidelines published in the Mealvana blog ("How Mealvana Calculates Your Fueling"), which synthesizes evidence from 66+ peer-reviewed sports nutrition studies. Where the blog provides specific values or formulas, we use them directly. Where the blog mentions a variable but doesn't provide a formula (such as how intensity affects during-exercise carbs), we've designed our own approach and marked it clearly.

The core principle is that nutrition needs scale with three main factors: (1) workout duration determines the base carbohydrate band, (2) sport type determines the practical ceiling due to gastrointestinal tolerance differences, and (3) individual factors like gut training, sweat rate, and environmental conditions personalize the recommendations within those bounds.

For intensity, the blog states that "duration, intensity (TSS/IF), sport type, environmental conditions, personal tolerance, and training context all influence recommendations simultaneously" but doesn't specify the formula. We've implemented intensity as a "range slider" that positions the athlete within the duration-based carb band—higher intensity aims toward the upper end of the range, lower intensity toward the lower end.

---

## Example Personas

Throughout this document, we calculate examples for three personas to illustrate how the formulas work across different athlete profiles.

| Persona | Description | Weight | Gut Training | Sweat Rate | Sweat Sodium |
|---------|-------------|--------|--------------|------------|--------------|
| **Elena** | Elite female runner, 28 years old, competitive marathoner | 52 kg | high | medium | medium |
| **Marcus** | Male age-grouper, 42 years old, experienced triathlete | 75 kg | moderate | medium | medium |
| **Sarah** | Female beginner, 35 years old, training for first half-marathon | 82 kg | low | light | low |

---

## Example Workouts

We use three different workouts to show how the algorithm adapts across duration, intensity, and sport type. Combined with three personas, this gives 9 example calculations per phase.

### Workout A: Moderate 2-Hour Run
- **Duration:** 120 min
- **Sport:** run
- **Intensity:** 30% Z1-2, 50% Z3, 20% Z4-5
- **Temperature:** 22°C
- **Humidity:** 55%
- **Use case:** Typical weekend long run with tempo segments

### Workout B: Easy 45-Minute Recovery Run
- **Duration:** 45 min
- **Sport:** run
- **Intensity:** 90% Z1-2, 10% Z3, 0% Z4-5
- **Temperature:** 18°C
- **Humidity:** 50%
- **Use case:** Recovery day, candidate for fasted training

### Workout C: Long 4-Hour Bike Ride
- **Duration:** 240 min
- **Sport:** bike
- **Intensity:** 40% Z1-2, 45% Z3, 15% Z4-5
- **Temperature:** 28°C
- **Humidity:** 70%
- **Use case:** Century ride prep, hot conditions

---

## Input Variables

| Variable | Unit | Description |
|----------|------|-------------|
| `weight` | kg | Athlete's body weight |
| `duration` | min | Total workout duration |
| `sport` | enum | `run`, `bike`, or `swim` |
| `pct_zone_low` | 0-1 | Fraction of workout spent in zones 1-2 (easy/recovery) |
| `pct_zone_mid` | 0-1 | Fraction of workout spent in zone 3 (tempo) |
| `pct_zone_high` | 0-1 | Fraction of workout spent in zones 4-5 (threshold/VO2max) |
| `temperature` | °C | Environmental temperature (default: 20) |
| `humidity` | % | Relative humidity (default: 60) |
| `gut_training` | enum | `low`, `moderate`, or `high` (default: moderate) |
| `sweat_rate` | enum | `light`, `medium`, or `heavy` (default: medium) |
| `sweat_sodium` | enum | `low`, `medium`, or `high` (default: medium) |
| `has_full_meal` | bool | Whether athlete will eat a full meal 3-4h before (default: true) |
| `has_snack` | bool | Whether athlete will eat a snack 1-2h before (default: true) |
| `has_topup` | bool | Whether athlete will have a top-up 30-60 min before (default: true) |
| `is_fasted` | bool | Whether athlete is training fasted (default: false) |

**Constraints:**
- `pct_zone_low + pct_zone_mid + pct_zone_high = 1.0`
- `is_fasted = true` implies `has_full_meal = false AND has_snack = false AND has_topup = false`

---

## Lookup Tables

These tables are referenced throughout the algorithm. Use them to look up values based on input parameters.

### TABLE 1: Duration → Carb Band (g/hr) — DURING EXERCISE

Used in Phase 2 (During Exercise) to determine base carbohydrate targets.

| Duration | carb_band_low | carb_band_high | Source |
|----------|---------------|----------------|--------|
| < 60 min | 0 | 30 | Blog: "0-30g total, mouth rinse sufficient" |
| 60-90 min | 30 | 60 | Blog: "30-60 g/hr, maintain blood glucose" |
| 90 min - 2.5 hr | 45 | 60 | Blog: "45-60 g/hr, delay glycogen depletion" |
| 2.5 - 4 hr | 60 | 90 | Blog: "60-90 g/hr, multiple transportable carbs" |
| > 4 hr | 80 | 100 | Blog: "80-100+ g/hr, maximum sustainable" |

### TABLE 2: Sport → Carb Ceiling (g/hr) — DURING EXERCISE

Used in Phase 2 to cap carbohydrate intake based on GI tolerance by sport.

| Sport | carb_ceiling | Source |
|-------|--------------|--------|
| run | 70 | Blog: "Running 50-70 g/hr, GI jostling" |
| bike | 120 | Blog: "Cycling 80-120 g/hr, stable platform" |
| swim | 0 | Blog: "Swimming pre/post only, no during-activity" |

### TABLE 3: Gut Training → Absorption Cap (g/hr)

Used in Phase 2 to cap carbohydrate intake based on trained gut capacity.

| gut_training | absorption_cap | Source |
|--------------|----------------|--------|
| low | 40 | MEALVANA: Conservative for untrained gut |
| moderate | 60 | Blog: "60 g/hr single transporter ceiling" |
| high | 100 | Blog: "90-120 g/hr with trained gut + dual carbs" |

### TABLE 4: Pre-Workout Timing → Carb Target (g/kg) — CUMULATIVE WINDOWS

Used in Phase 1 (Pre-Workout). **These windows are CUMULATIVE** — athletes may eat at multiple windows, and targets are additive. Each window uses its standard blog-specified range regardless of which other windows are used.

| Window | Time Before | carb_per_kg_low | carb_per_kg_high | Source |
|--------|-------------|-----------------|------------------|--------|
| Full Meal | 3-4 hours | 1.0 | 4.0 | Blog: "1-4 g/kg, full gastric emptying" |
| Snack | 1-2 hours | 1.0 | 2.0 | Blog: "1-2 g/kg, snack window" |
| Top-Up | 30-60 min | 0.5 | 1.0 | Blog: "0.5-1 g/kg, simple carbs only" |
| Emergency | < 30 min | 0.0 | 0.5 | Blog: "Emergency only, 25-50g" |

### Cumulative Pre-Workout Carbohydrate Considerations

When all three windows are used, cumulative carbs can theoretically reach 2.5-7 g/kg. This raises important questions about whether such high totals are appropriate.

**What the Research Says:**

The ISSN Position Stand on Nutrient Timing recommends "consuming carbohydrate quantities of 1 to 4 g/kg body mass in the 1 to 4 hours before exercise" for events lasting >60 minutes (Kerksick et al., 2017). Critically, this recommendation assumes a **single feeding window**, not stacked meals. No peer-reviewed research directly validates cumulative intake across multiple windows exceeding 4 g/kg.

Elite athlete practices support more conservative totals. Marathon and Ironman athletes typically consume 2-3 g/kg total pre-race: a substantial breakfast (1.5-2 g/kg) plus a small top-off (0.3-0.5 g/kg). Even aggressive carb-loading protocols (10-12 g/kg/day) spread intake across 24-48 hours, not concentrated in a 4-hour pre-exercise window (Burke et al., 2011).

**Additional Concerns:**

The 30-60 minute "top-up" window carries reactive hypoglycemia risk. Research shows hypoglycemic events peak when carbs are consumed 30-90 minutes before exercise, as insulin response coincides with exercise onset (Jeukendrup, 2017). Athletes consuming large amounts in this window without gut training may experience blood glucose crashes.

**Our Approach:**

This algorithm provides each window's blog-specified range without enforcing a cumulative cap, allowing flexibility for different athlete needs. However, we recommend athletes **target 2-4 g/kg total** across all windows for most training and racing scenarios, reserving higher intakes (4-5 g/kg) only for ultra-endurance events (>4 hours) with practiced gut training. Athletes should build toward higher totals gradually over training cycles rather than attempting maximum intake on race day.

**Sources:**
- Kerksick et al. (2017). ISSN Position Stand: Nutrient Timing. JISSN. https://pmc.ncbi.nlm.nih.gov/articles/PMC5596471/
- Burke et al. (2011). Carbohydrates for training and competition. J Sports Sci.
- Jeukendrup (2017). Training the gut for athletes. Sports Med.

### TABLE 5: Sweat Rate → Base Rate (L/hr)

Used in Phase 2 for hydration and sodium calculations.

| sweat_rate | sweat_base | Source |
|------------|------------|--------|
| light | 0.75 | Baker et al. 2017: lower quartile |
| medium | 1.25 | Baker et al. 2017: median |
| heavy | 2.0 | Baker et al. 2017: upper quartile |

### TABLE 6: Sweat Sodium → Concentration (mg/L)

Used in Phase 2 for sodium loss calculations.

| sweat_sodium | sodium_concentration | Source |
|--------------|---------------------|--------|
| low | 550 | Baker et al. 2017: ~25th percentile |
| medium | 925 | Baker et al. 2017: ~50th percentile |
| high | 1150 | Baker et al. 2017: ~75th percentile |

---

## Derived Values

```
duration_hours = duration / 60

intensity_position = (pct_zone_low × 0) + (pct_zone_mid × 0.5) + (pct_zone_high × 1.0)

env_sweat_multiplier = 1.0 + max(0, (temperature - 20) × 0.04)

actual_sweat_rate = sweat_base × env_sweat_multiplier
```

**Derived values for all workouts:**

| Workout | duration_hours | intensity_position | env_sweat_multiplier |
|---------|----------------|-------------------|---------------------|
| A (2hr run) | 2.0 | 0.45 | 1.08 |
| B (45min easy) | 0.75 | 0.05 | 0.92 |
| C (4hr bike) | 4.0 | 0.375 | 1.32 |

**Actual sweat rates by persona and workout:**

| Persona | Sweat Base | Workout A | Workout B | Workout C |
|---------|------------|-----------|-----------|-----------|
| Elena | 1.25 L/hr | 1.35 L/hr | 1.15 L/hr | 1.65 L/hr |
| Marcus | 1.25 L/hr | 1.35 L/hr | 1.15 L/hr | 1.65 L/hr |
| Sarah | 0.75 L/hr | 0.81 L/hr | 0.69 L/hr | 0.99 L/hr |

---

## Phase 1: Pre-Workout

### How Pre-Workout Windows Work

Pre-workout nutrition consists of three timing windows that are **CUMULATIVE** when used together. Athletes may use one, two, or all three windows depending on their schedule.

**The Three Windows (from blog):**

| Window | Timing | Carbs (g/kg) | Fat | Fiber | Notes |
|--------|--------|--------------|-----|-------|-------|
| Full Meal | 3-4 hr before | 1-4 | 0.3-0.5 g/kg | Moderate | Full gastric emptying |
| Snack | 1-2 hr before | 1-2 | <10g | Low | Snack window |
| Top-Up | 30-60 min before | 0.5-1 | 0g | 0g | Simple carbs only |

**Cumulative Scenarios:**

| Scenario | Windows Used | Calculation |
|----------|--------------|-------------|
| Full Fuel | Meal + Snack + Top-up | Standard calculations for each window |
| No Full Meal | Snack + Top-up only | Standard snack + standard top-up |
| Top-Up Only | Top-up only | Standard top-up calculation |
| Fasted | None | See Fasted Training Guidelines |

**No Adjustment Factors:** Each window uses its standalone blog-specified range regardless of which other windows are used. The blog does not specify adjustment factors for skipped windows, and no research validates specific multipliers. Athletes naturally self-adjust based on hunger and experience.

**Design Decision:** We initially explored 25% and 50% adjustment factors for skipped windows but removed them due to lack of research support. See "Cumulative Pre-Workout Carbohydrate Considerations" above for guidance on total intake limits.

### Sport-Specific Pre-Workout Adjustments

| Sport | Pre-Workout Buffer | Adjustment | Source |
|-------|-------------------|------------|--------|
| Running | 3-4 hours minimum | Standard formulas | Blog: "GI jostling, vertical impact" |
| Cycling | 2-3 hours acceptable | Can eat closer to start | Blog: "Stable platform, no impact" |
| Swimming | 2-3 hours minimum | Reduce fat/fiber more | Blog: "Horizontal position" |

**Cycling adjustment:** Athletes can use the 1-2 hour window even for high-carb intake (up to 2 g/kg) because cycling's stable position allows faster gastric emptying.

**Swimming adjustment:** Prioritize easily digestible carbs; the horizontal position can cause discomfort with heavy meals.

---

### Fasted Training Guidelines

Fasted training can enhance metabolic adaptations (fat oxidation, mitochondrial biogenesis) when strategically implemented, but must be limited to appropriate workout types.

**Eligibility by Workout Type (from blog):**

| Workout Type | Suitability | Duration Limit | Rationale |
|--------------|-------------|----------------|-----------|
| Easy/Recovery (Z1-2) | ✅ Excellent | <60 min | Fat oxidation dominant |
| Moderate steady-state (Z3) | ⚠️ Acceptable | <75 min | Marginal, glycogen starting to deplete |
| Long workouts (any zone) | ❌ Not recommended | >90 min | Glycogen depletion problematic |
| Tempo/Threshold (Z4) | ❌ Not recommended | Any | High-quality work impaired |
| Intervals/VO2max (Z5) | ❌ Avoid | Any | Glycolytic work severely impaired |

**Justification:** Blog table "Fasted Training by Intensity" provides these guidelines. Research from Van Proeyen et al. (2010) and Impey et al. (2018) confirms fasted training benefits are limited to low-intensity work.

**Algorithm Check for Fasted Eligibility:**

```
fasted_eligible:
    if pct_zone_high > 0.1:      false   # Any significant Z4-5 work
    if pct_zone_mid > 0.3:       false   # >30% tempo work
    if duration > 75:            false   # >75 minutes
    if sport = swim:             false   # Swimming has unique demands
    else:                        true

fasted_warning:
    if duration > 60 AND fasted_eligible: "Consider light fueling for sessions >60 min"
```

**If `is_fasted = true` AND `fasted_eligible = false`:**
Show warning: "This workout is not suitable for fasted training. High intensity or long duration workouts require pre-workout nutrition for performance and safety."

**Post-Fasted Workout Priority:**
When training fasted, post-workout nutrition becomes MORE critical:
- Consume carbs within 30 minutes (1.2 g/kg instead of 1.0 g/kg)
- Protein within 30 minutes (0.35 g/kg instead of 0.3 g/kg)

---

### Window A: Full Meal (3-4 hours before)

This window allows complete gastric emptying. Athletes can eat a full meal with carbs, protein, fat, and moderate fiber.

#### Carbs (g)

**Formula:**
```
meal_carb_grams = weight × carb_per_kg
```

**Chain:**
```
carb_per_kg = (pct_zone_low × 0.75) + (pct_zone_mid × 1.5) + (pct_zone_high × 1.75)

meal_carb_target = weight × carb_per_kg
meal_carb_low = weight × 1.0
meal_carb_high = weight × 4.0
```

**Justification:** Blog table "Pre-Workout Timing Windows" specifies 1-4 g/kg for 3-4 hours before. Blog table "Pre-Workout Carbs by Intensity Zone" specifies Z1-2: 0.5-1 g/kg, Z3-4: 1-2 g/kg, Z4-5: 1.5-2 g/kg. We use midpoints weighted by zone percentages.

**Examples (3 personas × 3 workouts = 9 combinations):**

| Persona | Workout A (2hr run) | Workout B (45min easy) | Workout C (4hr bike) |
|---------|--------------------|-----------------------|---------------------|
| Elena (52 kg) | **66g** (1.28 g/kg) | **41g** (0.78 g/kg) | **61g** (1.17 g/kg) |
| Marcus (75 kg) | **96g** (1.28 g/kg) | **59g** (0.78 g/kg) | **88g** (1.17 g/kg) |
| Sarah (82 kg) | **105g** (1.28 g/kg) | **64g** (0.78 g/kg) | **96g** (1.17 g/kg) |

*Workout B has low carb_per_kg (0.78) because 90% Z1-2 intensity.*

---

#### Protein (g)

**Formula:**
```
meal_protein_grams = weight × 0.25
```

**Justification:** Blog table shows protein is part of the full meal window. Values based on typical pre-workout meal composition (0.2-0.35 g/kg).

**Examples:**

| Persona | All Workouts |
|---------|--------------|
| Elena (52 kg) | **13g** |
| Marcus (75 kg) | **19g** |
| Sarah (82 kg) | **21g** |

*Protein does not vary by workout intensity.*

---

#### Fat (g)

**Formula:**
```
meal_fat_grams = weight × 0.4
```

**Justification:** Blog table "Pre-Workout Timing Windows" specifies 0.3-0.5 g/kg fat for 3-4 hours before.

**Examples:**

| Persona | All Workouts |
|---------|--------------|
| Elena (52 kg) | **21g** |
| Marcus (75 kg) | **30g** |
| Sarah (82 kg) | **33g** |

---

#### Fiber (g)

**Formula:**
```
meal_fiber_grams = 5
```

**Justification:** Blog table specifies "Moderate" fiber for 3-4 hours before. We interpret moderate as 3-8g.

**Examples:** All personas, all workouts: **5g** (range: 3-8g)

---

#### Sodium (mg)

**Formula:**
```
meal_sodium_mg = sodium_base + env_sodium_bump
```

**Chain:**
```
sodium_base:
    if sweat_sodium = low:    300
    if sweat_sodium = medium: 450
    if sweat_sodium = high:   600

env_sodium_bump:
    if temperature > 25: 150
    if temperature > 20: 75
    else:                0
```

**Justification:** Blog cites Sims et al. 2007 recommending sodium loading before exercise, particularly in hot conditions.

**Examples:**

| Persona | Workout A (22°C) | Workout B (18°C) | Workout C (28°C) |
|---------|-----------------|-----------------|-----------------|
| Elena (medium) | **525mg** | **450mg** | **600mg** |
| Marcus (medium) | **525mg** | **450mg** | **600mg** |
| Sarah (low) | **375mg** | **300mg** | **450mg** |

---

#### Hydration (mL)

**Formula:**
```
meal_hydration_ml = weight × hydration_per_kg
```

**Chain:**
```
hydration_per_kg = 6
if temperature > 25: hydration_per_kg = 7
```

**Justification:** Blog recommends "prehydrate with beverages several hours before activity." Standard guidance is 5-7 mL/kg.

**Examples:**

| Persona | Workout A (22°C) | Workout B (18°C) | Workout C (28°C) |
|---------|-----------------|-----------------|-----------------|
| Elena (52 kg) | **312mL** | **312mL** | **364mL** |
| Marcus (75 kg) | **450mL** | **450mL** | **525mL** |
| Sarah (82 kg) | **492mL** | **492mL** | **574mL** |

---

### Window B: Snack (1-2 hours before)

This window is for a light snack. Reduce fat and fiber to allow faster digestion.

#### Carbs (g)

**Formula:**
```
snack_carb_grams = weight × snack_carb_per_kg
```

**Chain:**
```
snack_carb_per_kg = (pct_zone_low × 0.75) + (pct_zone_mid × 1.25) + (pct_zone_high × 1.5)

snack_carb_target = weight × snack_carb_per_kg
snack_carb_low = weight × 1.0
snack_carb_high = weight × 2.0
```

**Justification:** Blog table "Pre-Workout Timing Windows" specifies 1-2 g/kg for 1-2 hours before. Intensity affects the target within this range.

**Examples:**

| Persona | Workout A (2hr run) | Workout B (45min easy) | Workout C (4hr bike) |
|---------|--------------------|-----------------------|---------------------|
| Elena (52 kg) | **57g** (1.10 g/kg) | **41g** (0.78 g/kg) | **53g** (1.02 g/kg) |
| Marcus (75 kg) | **82g** (1.10 g/kg) | **59g** (0.78 g/kg) | **77g** (1.02 g/kg) |
| Sarah (82 kg) | **90g** (1.10 g/kg) | **64g** (0.78 g/kg) | **84g** (1.02 g/kg) |

---

#### Protein (g)

**Formula:**
```
snack_protein_grams = weight × 0.15
```

**Justification:** Blog shows protein should be reduced in the snack window. Light protein (0.1-0.2 g/kg) is acceptable.

**Examples:**

| Persona | All Workouts |
|---------|--------------|
| Elena (52 kg) | **8g** |
| Marcus (75 kg) | **11g** |
| Sarah (82 kg) | **12g** |

---

#### Fat (g)

**Formula:**
```
snack_fat_grams = 5
```

**Justification:** Blog table "Pre-Workout Timing Windows" specifies <10g fat for 1-2 hours before.

**Examples:** All personas, all workouts: **5g** (range: 0-10g)

---

#### Fiber (g)

**Formula:**
```
snack_fiber_grams = 1
```

**Justification:** Blog table specifies "Low" fiber for 1-2 hours before. We interpret low as 0-3g.

**Examples:** All personas, all workouts: **1g** (range: 0-3g)

---

#### Sodium (mg)

**Formula:**
```
snack_sodium_mg = (sodium_base × 0.5) + env_sodium_bump
```

**Justification:** Reduced sodium compared to full meal, but still beneficial for preloading.

**Examples:**

| Persona | Workout A (22°C) | Workout B (18°C) | Workout C (28°C) |
|---------|-----------------|-----------------|-----------------|
| Elena (medium) | **300mg** | **225mg** | **375mg** |
| Marcus (medium) | **300mg** | **225mg** | **375mg** |
| Sarah (low) | **225mg** | **150mg** | **300mg** |

---

#### Hydration (mL)

**Formula:**
```
snack_hydration_ml = weight × hydration_per_kg
```

**Chain:**
```
hydration_per_kg = 5
if temperature > 25: hydration_per_kg = 6
```

**Justification:** Slightly less hydration than full meal window, but still important for preloading.

**Examples:**

| Persona | Workout A (22°C) | Workout B (18°C) | Workout C (28°C) |
|---------|-----------------|-----------------|-----------------|
| Elena (52 kg) | **260mL** | **260mL** | **312mL** |
| Marcus (75 kg) | **375mL** | **375mL** | **450mL** |
| Sarah (82 kg) | **410mL** | **410mL** | **492mL** |

---

### Window C: Top-Up (30-60 minutes before)

This window is for simple, fast-absorbing carbs only. No fat, no fiber, minimal protein.

#### Carbs (g)

**Formula:**
```
topup_carb_grams = weight × topup_carb_per_kg
```

**Chain:**
```
topup_carb_per_kg = (pct_zone_low × 0.5) + (pct_zone_mid × 0.75) + (pct_zone_high × 1.0)

topup_carb_target = weight × topup_carb_per_kg
topup_carb_low = weight × 0.5
topup_carb_high = weight × 1.0
```

**Justification:** Blog table "Pre-Workout Timing Windows" specifies 0.5-1 g/kg for 30-60 minutes before.

**Examples:**

| Persona | Workout A | Workout B | Workout C |
|---------|-----------|-----------|-----------|
| Elena (52 kg) | **38g** | **27g** | **35g** |
| Marcus (75 kg) | **55g** | **39g** | **51g** |
| Sarah (82 kg) | **60g** | **43g** | **56g** |

---

#### Protein (g)

**Formula:**
```
topup_protein_grams = 0
```

**Justification:** Blog table shows 0g protein for 30-60 min window. Protein slows digestion.

**Examples:** All personas, all workouts: **0g**

---

#### Fat (g)

**Formula:**
```
topup_fat_grams = 0
```

**Justification:** Blog table "Pre-Workout Timing Windows" specifies 0g fat for 30-60 minutes before.

**Examples:** All personas, all workouts: **0g**

---

#### Fiber (g)

**Formula:**
```
topup_fiber_grams = 0
```

**Justification:** Blog table specifies 0g fiber for 30-60 minutes before.

**Examples:** All personas, all workouts: **0g**

---

#### Sodium (mg)

**Formula:**
```
topup_sodium_mg = env_sodium_bump + 100
```

**Justification:** Final sodium top-up before exercise, especially important in warm conditions.

**Examples:**

| Persona | Workout A (22°C) | Workout B (18°C) | Workout C (28°C) |
|---------|-----------------|-----------------|-----------------|
| All | **175mg** | **100mg** | **250mg** |

---

#### Hydration (mL)

**Formula:**
```
topup_hydration_ml = topup_base + env_topup_bump
```

**Chain:**
```
topup_base = 200
env_topup_bump:
    if temperature > 25: 100
    else:                50
```

**Justification:** Final fluid top-up 30-60 minutes before workout. Blog mentions final hydration before activity.

**Examples:**

| Persona | Workout A (22°C) | Workout B (18°C) | Workout C (28°C) |
|---------|-----------------|-----------------|-----------------|
| All | **250mL** | **250mL** | **300mL** |

---

### Pre-Workout Total Summary

For an athlete using all three windows, here are the cumulative pre-workout totals. See "Cumulative Pre-Workout Carbohydrate Considerations" in the Lookup Tables section for guidance on appropriate total intake.

**Total Pre-Workout Carbs (Workout A - 2hr run, moderate intensity):**

| Persona | Full Meal | + Snack | + Top-up | **TOTAL** | **g/kg** |
|---------|-----------|---------|----------|-----------|----------|
| Elena (52 kg) | 66g | 57g | 38g | **161g** | 3.1 |
| Marcus (75 kg) | 96g | 82g | 55g | **233g** | 3.1 |
| Sarah (82 kg) | 105g | 90g | 60g | **255g** | 3.1 |

**Total Pre-Workout Carbs (Workout B - 45min easy):**

| Persona | Full Meal | + Snack | + Top-up | **TOTAL** | **g/kg** |
|---------|-----------|---------|----------|-----------|----------|
| Elena (52 kg) | 41g | 41g | 27g | **109g** | 2.1 |
| Marcus (75 kg) | 59g | 59g | 39g | **157g** | 2.1 |
| Sarah (82 kg) | 64g | 64g | 43g | **171g** | 2.1 |

**Total Pre-Workout Carbs (Workout C - 4hr bike, hot):**

| Persona | Full Meal | + Snack | + Top-up | **TOTAL** | **g/kg** |
|---------|-----------|---------|----------|-----------|----------|
| Elena (52 kg) | 61g | 53g | 35g | **149g** | 2.9 |
| Marcus (75 kg) | 88g | 77g | 51g | **216g** | 2.9 |
| Sarah (82 kg) | 96g | 84g | 56g | **236g** | 2.9 |

*All totals fall within the recommended 2-4 g/kg range. Athletes should build toward these totals gradually and may use fewer windows based on schedule and tolerance.*

---

## Phase 2: During Exercise

### Sport-Specific During-Exercise Rules

**CRITICAL:** The sport type fundamentally changes during-exercise nutrition:

| Sport | Carbs | Hydration | Sodium | Source |
|-------|-------|-----------|--------|--------|
| **Running** | 50-70 g/hr max | Standard | Standard | Blog: "GI jostling, vertical impact" |
| **Cycling** | 80-120 g/hr max | Standard | Standard | Blog: "Stable platform, no impact" |
| **Swimming** | **0 g/hr** (pre/post only) | Lower (0.35-0.55 L/hr) | Lower | Blog: "No during-activity fueling" |

**Swimming Exception:** Athletes cannot eat during swimming. All carbohydrate fueling must happen pre-workout and post-workout. However, for very long open-water swims (>2.5 hours), brief feeding stops at aid stations are possible—see Brick section.

---

### Carbs (g/hr)

**Formula:**
```
if sport = swim:
    during_carb_rate = 0    # Cannot eat while swimming
else:
    during_carb_rate = min(carb_in_band, carb_ceiling, absorption_cap)
```

**Chain (for run/bike):**
```
carb_band_low, carb_band_high = lookup from TABLE 1 (Duration)
carb_ceiling = lookup from TABLE 2 (Sport)
absorption_cap = lookup from TABLE 3 (Gut Training)

carb_in_band = carb_band_low + intensity_position × (carb_band_high - carb_band_low)

during_carb_target = min(carb_in_band, carb_ceiling, absorption_cap)
during_carb_low = max(carb_band_low, during_carb_target - 10)
during_carb_high = min(carb_band_high, carb_ceiling, absorption_cap, during_carb_target + 10)

during_carb_total = during_carb_target × duration_hours
```

**Justification:** Blog table "Duration-Based Carbohydrate Targets" (TABLE 1) provides the duration bands. Blog table "Sport-Specific Differences" (TABLE 2) provides the sport ceilings (run: 50-70 g/hr, bike: 80-120 g/hr, swim: pre/post only). Blog mentions gut training enables higher absorption (TABLE 3). **Intensity effect (MEALVANA):** Blog states intensity affects recommendations but provides no formula; we use intensity to position within the duration band.

**Workout Parameters:**

| Workout | Duration Band | Carb Band | Sport Ceiling | Intensity Position |
|---------|--------------|-----------|---------------|-------------------|
| A (2hr run) | 90min-2.5hr | 45-60 g/hr | 70 g/hr | 0.45 |
| B (45min run) | <60min | 0-30 g/hr | 70 g/hr | 0.05 |
| C (4hr bike) | >4hr | 80-100 g/hr | 120 g/hr | 0.375 |
| D (1hr swim) | 60-90min | 30-60 g/hr | **0 g/hr** | N/A |

**Examples (including swim):**

| Persona | Workout A (2hr run) | Workout B (45min run) | Workout C (4hr bike) | Workout D (1hr swim) |
|---------|--------------------|-----------------------|---------------------|---------------------|
| Elena (high gut) | **52 g/hr** (104g) | **2 g/hr** (1g)* | **88 g/hr** (350g) | **0 g/hr** (0g) |
| Marcus (mod gut) | **52 g/hr** (104g) | **2 g/hr** (1g)* | **60 g/hr** (240g)** | **0 g/hr** (0g) |
| Sarah (low gut) | **40 g/hr** (80g)** | **2 g/hr** (1g)* | **40 g/hr** (160g)** | **0 g/hr** (0g) |

*Workout B: <60 min = mouth rinse sufficient; minimal carbs needed
**Capped by absorption_cap (Sarah's low gut = 40g/hr, Marcus moderate = 60g/hr)

---

### Protein (g/hr)

**Formula:**
```
during_protein_rate:
    if duration_hours > 4: 3 g/hr
    else:                  0 g/hr
```

**Justification:** Blog does not specify during-exercise protein. Research consensus is protein unnecessary except ultra-endurance (>4 hours).

**Examples:**

| Persona | Workout A | Workout B | Workout C |
|---------|-----------|-----------|-----------|
| All | **0 g/hr** | **0 g/hr** | **0 g/hr** |

*Note: Workout C is exactly 4 hours, so 0 g/hr. For workouts >4hr, use 3 g/hr.*

---

### Fat (g/hr)

**Formula:**
```
during_fat_rate:
    if duration_hours > 4: 2 g/hr
    else:                  0 g/hr
```

**Justification:** Blog does not specify during-exercise fat. Research consensus is fat unnecessary except ultra-endurance.

**Examples:**

| Persona | Workout A | Workout B | Workout C |
|---------|-----------|-----------|-----------|
| All | **0 g/hr** | **0 g/hr** | **0 g/hr** |

---

### Fiber (g/hr)

**Formula:**
```
during_fiber_rate = 0
```

**Justification:** Fiber during exercise causes GI distress.

**Examples:** All personas, all workouts: **0 g/hr**

---

### Sodium (mg/hr)

**Formula:**
```
during_sodium_rate = actual_sweat_rate × sodium_concentration × 0.6
```

**Chain:**
```
sodium_loss_rate = actual_sweat_rate × sodium_concentration

during_sodium_target = sodium_loss_rate × 0.6
during_sodium_low = max(300, sodium_loss_rate × 0.5)
during_sodium_high = min(1200, sodium_loss_rate × 0.8)

during_sodium_total = during_sodium_target × duration_hours
```

**Justification:** Blog formula: "Sodium Loss (mg/hr) = Sweat Rate (L/hr) × Sodium Concentration (mg/L)". Blog states "Target 50-80% replacement during exercise."

**Examples (mg/hr rate, then total for workout):**

| Persona | Workout A (22°C) | Workout B (18°C) | Workout C (28°C) |
|---------|-----------------|-----------------|-----------------|
| Elena (medium Na) | **749 mg/hr** (1498mg) | **638 mg/hr** (478mg) | **916 mg/hr** (3663mg) |
| Marcus (medium Na) | **749 mg/hr** (1498mg) | **638 mg/hr** (478mg) | **916 mg/hr** (3663mg) |
| Sarah (low Na) | **267 mg/hr** (534mg) | **228 mg/hr** (171mg) | **327 mg/hr** (1307mg) |

---

### Hydration (mL/hr)

**Formula:**
```
during_hydration_rate = actual_sweat_rate × 1000 × 0.75
```

**Chain:**
```
during_hydration_target = actual_sweat_rate × 1000 × 0.75
during_hydration_low = max(300, during_hydration_target × 0.8)
during_hydration_high = min(1200, during_hydration_target × 1.2)

during_hydration_total = during_hydration_target × duration_hours
```

**Justification:** Blog mentions matching 70-90% of sweat losses during exercise. We use 75% as the target.

**Examples (mL/hr rate, then total for workout):**

| Persona | Workout A (22°C) | Workout B (18°C) | Workout C (28°C) |
|---------|-----------------|-----------------|-----------------|
| Elena | **1013 mL/hr** (2025mL) | **863 mL/hr** (647mL) | **1238 mL/hr** (4950mL) |
| Marcus | **1013 mL/hr** (2025mL) | **863 mL/hr** (647mL) | **1238 mL/hr** (4950mL) |
| Sarah | **608 mL/hr** (1215mL) | **518 mL/hr** (388mL) | **743 mL/hr** (2970mL) |

---

### During Exercise Summary Tables

**Total During-Exercise Carbs:**

| Persona | Workout A (2hr) | Workout B (45min) | Workout C (4hr) |
|---------|----------------|-------------------|-----------------|
| Elena | **104g** | **1g** | **350g** |
| Marcus | **104g** | **1g** | **240g** |
| Sarah | **80g** | **1g** | **160g** |

**Total During-Exercise Sodium:**

| Persona | Workout A (2hr) | Workout B (45min) | Workout C (4hr) |
|---------|----------------|-------------------|-----------------|
| Elena | **1498mg** | **478mg** | **3663mg** |
| Marcus | **1498mg** | **478mg** | **3663mg** |
| Sarah | **534mg** | **171mg** | **1307mg** |

**Total During-Exercise Hydration:**

| Persona | Workout A (2hr) | Workout B (45min) | Workout C (4hr) |
|---------|----------------|-------------------|-----------------|
| Elena | **2025mL** | **647mL** | **4950mL** |
| Marcus | **2025mL** | **647mL** | **4950mL** |
| Sarah | **1215mL** | **388mL** | **2970mL** |

---

## Phase 3: Post-Workout

### Carbs (g)

**Formula:**
```
post_carb_grams = weight × post_carb_per_kg × fasted_multiplier
```

**Chain:**
```
post_carb_per_kg:
    if duration_hours > 2: 1.2
    else:                  1.0

fasted_multiplier:
    if is_fasted: 1.2   # Extra glycogen replenishment priority
    else:         1.0

post_carb_target = weight × post_carb_per_kg × fasted_multiplier
post_carb_low = post_carb_target × 0.85
post_carb_high = post_carb_target × 1.15
```

**Justification:** Blog table "Post-Workout Recovery" specifies "Glycogen resynthesis: 1.0-1.2 g/kg/hr." **Fasted multiplier (MEALVANA):** After fasted training, glycogen replenishment is more critical; research recommends prioritizing immediate carb intake.

**Examples (9 combinations):**

| Persona | Workout A (2hr) | Workout B (45min) | Workout C (4hr) |
|---------|----------------|-------------------|-----------------|
| Elena (52 kg) | **52g** (1.0 g/kg) | **52g** (1.0 g/kg) | **62g** (1.2 g/kg) |
| Marcus (75 kg) | **75g** (1.0 g/kg) | **75g** (1.0 g/kg) | **90g** (1.2 g/kg) |
| Sarah (82 kg) | **82g** (1.0 g/kg) | **82g** (1.0 g/kg) | **98g** (1.2 g/kg) |

*Workouts A & B use 1.0 g/kg (≤2hr). Workout C uses 1.2 g/kg (>2hr).*
*If fasted: multiply by 1.2 (e.g., Elena fasted Workout B = 62g instead of 52g)*

---

### Protein (g)

**Formula:**
```
post_protein_grams = weight × post_protein_per_kg
```

**Chain:**
```
post_protein_per_kg:
    if is_fasted: 0.35   # Higher priority after fasted training
    else:         0.30

post_protein_target = weight × post_protein_per_kg
post_protein_low = max(20, post_protein_target × 0.85)
post_protein_high = min(40, post_protein_target × 1.15)
```

**Justification:** Blog table "Post-Workout Recovery" specifies "Muscle protein synthesis: 0.25-0.4 g/kg (20-40g)." **Fasted adjustment (MEALVANA):** Impey et al. (2018) recommends higher protein after low-carb training states.

**Examples:**

| Persona | All Workouts (normal) | After Fasted Training |
|---------|----------------------|----------------------|
| Elena (52 kg) | **16g** | **18g** |
| Marcus (75 kg) | **23g** | **26g** |
| Sarah (82 kg) | **25g** | **29g** |

*Protein does not vary by workout duration/intensity.*

---

### Fat (g)

**Formula:**
```
post_fat_grams = weight × 0.2
```

**Justification:** Blog does not specify post-workout fat. Research shows fat does not impair recovery.

**Examples:**

| Persona | All Workouts |
|---------|--------------|
| Elena (52 kg) | **10g** |
| Marcus (75 kg) | **15g** |
| Sarah (82 kg) | **16g** |

---

### Fiber (g)

**Formula:**
```
post_fiber_grams = 2
```

**Justification:** Blog does not specify post-workout fiber. Light fiber acceptable in recovery meals.

**Examples:** All personas, all workouts: **2g** (range: 0-5g)

---

### Sodium (mg)

**Formula:**
```
post_sodium_mg = max(300, sodium_deficit × 0.5)
```

**Chain:**
```
total_sodium_lost = actual_sweat_rate × sodium_concentration × duration_hours
sodium_deficit = total_sodium_lost - during_sodium_total

post_sodium_target = max(300, sodium_deficit × 0.5)
post_sodium_low = post_sodium_target × 0.75
post_sodium_high = min(700, post_sodium_target × 1.25)
```

**Justification:** Blog table "Post-Workout Recovery" specifies rehydration "with 500-700 mg/L sodium."

**Examples (9 combinations):**

| Persona | Workout A (22°C) | Workout B (18°C) | Workout C (28°C) |
|---------|-----------------|-----------------|-----------------|
| Elena | **500mg** | **300mg*** | **700mg** |
| Marcus | **500mg** | **300mg*** | **700mg** |
| Sarah | **300mg*** | **300mg*** | **435mg** |

*Floored at 300mg minimum. Capped at 700mg.*

---

### Hydration (mL)

**Formula:**
```
post_hydration_ml = max(500, hydration_deficit × 1.5)
```

**Chain:**
```
total_fluid_lost = actual_sweat_rate × duration_hours × 1000
hydration_deficit = total_fluid_lost - during_hydration_total

post_hydration_target = max(500, hydration_deficit × 1.5)
post_hydration_low = max(500, hydration_deficit × 1.25)
post_hydration_high = hydration_deficit × 1.75
```

**Justification:** Blog table "Post-Workout Recovery" specifies "Rehydration: 150% of fluid losses."

**Examples (9 combinations):**

| Persona | Workout A (22°C) | Workout B (18°C) | Workout C (28°C) |
|---------|-----------------|-----------------|-----------------|
| Elena | **1013mL** | **500mL*** | **2475mL** |
| Marcus | **1013mL** | **500mL*** | **2475mL** |
| Sarah | **608mL** | **500mL*** | **1485mL** |

*Floored at 500mL minimum.*

---

### Post-Workout Summary Tables

**Total Post-Workout Carbs:**

| Persona | Workout A (2hr) | Workout B (45min) | Workout C (4hr) |
|---------|----------------|-------------------|-----------------|
| Elena | **52g** | **52g** | **62g** |
| Marcus | **75g** | **75g** | **90g** |
| Sarah | **82g** | **82g** | **98g** |

**Total Post-Workout Protein:**

| Persona | All Workouts |
|---------|--------------|
| Elena | **16g** |
| Marcus | **23g** |
| Sarah | **25g** |

---

## Phase 4: Transitions (Brick Workouts Only)

Transitions apply only to multi-sport brick workouts (e.g., triathlon). These are brief nutrition windows between segments.

### T1 (After swim or first segment)

**Formula:**
```
t1_carbs = weight × 0.3
t1_sodium = 150 + (100 if temperature > 25 else 0)
t1_hydration = 200 + (100 if temperature > 25 else 0)
t1_protein = 0
t1_fat = 0
t1_fiber = 0
```

**Justification (MEALVANA):** Blog does not provide specific transition nutrition values. Based on need for rapid absorption in short window.

**Examples by temperature:**

| Persona | Cool (18°C) | Moderate (22°C) | Hot (28°C) |
|---------|-------------|-----------------|------------|
| Elena (52 kg) | 16g / 150mg / 200mL | 16g / 150mg / 200mL | 16g / 250mg / 300mL |
| Marcus (75 kg) | 23g / 150mg / 200mL | 23g / 150mg / 200mL | 23g / 250mg / 300mL |
| Sarah (82 kg) | 25g / 150mg / 200mL | 25g / 150mg / 200mL | 25g / 250mg / 300mL |

*Format: carbs / sodium / hydration*

---

### T2 (After bike, before run)

**Formula:**
```
t2_carbs = weight × 0.35
t2_sodium = 100 + (75 if temperature > 25 else 0)
t2_hydration = 150 + (75 if temperature > 25 else 0)
t2_protein = 0
t2_fat = 0
t2_fiber = 0
```

**Justification (MEALVANA):** Blog does not provide specific transition values. T2 is slightly higher carbs—last opportunity before run.

**Examples by temperature:**

| Persona | Cool (18°C) | Moderate (22°C) | Hot (28°C) |
|---------|-------------|-----------------|------------|
| Elena (52 kg) | 18g / 100mg / 150mL | 18g / 100mg / 150mL | 18g / 175mg / 225mL |
| Marcus (75 kg) | 26g / 100mg / 150mL | 26g / 100mg / 150mL | 26g / 175mg / 225mL |
| Sarah (82 kg) | 29g / 100mg / 150mL | 29g / 100mg / 150mL | 29g / 175mg / 225mL |

*Format: carbs / sodium / hydration*

---

### Post-Bike Run Penalty

**Formula:**
```
if current segment is run AND previous segment was bike:
    run_carb_ceiling = 70 × 0.75 = 52.5 g/hr
```

**Justification:** Blog states "20-30% reduction in run carb targets after bike leg." We use 25% midpoint.

---

## Appendix: Complete Workout Summaries

### Workout A: 2-Hour Moderate Run (22°C)

| Phase | Elena (52kg, high gut) | Marcus (75kg, mod gut) | Sarah (82kg, low gut) |
|-------|----------------------|----------------------|---------------------|
| **Pre-Meal** | 66g carb, 13g pro, 21g fat | 96g carb, 19g pro, 30g fat | 105g carb, 21g pro, 33g fat |
| **Pre-Snack** | 57g carb, 8g pro, 5g fat | 82g carb, 11g pro, 5g fat | 90g carb, 12g pro, 5g fat |
| **Pre-TopUp** | 38g carb, 0g pro, 0g fat | 55g carb, 0g pro, 0g fat | 60g carb, 0g pro, 0g fat |
| **During** | 52g/hr (104g total) | 52g/hr (104g total) | 40g/hr (80g total) |
| **During Na** | 749mg/hr (1498mg) | 749mg/hr (1498mg) | 267mg/hr (534mg) |
| **During H2O** | 1013mL/hr (2025mL) | 1013mL/hr (2025mL) | 608mL/hr (1215mL) |
| **Post** | 52g carb, 16g pro, 10g fat | 75g carb, 23g pro, 15g fat | 82g carb, 25g pro, 16g fat |

### Workout B: 45-Min Easy Run (18°C)

| Phase | Elena (52kg) | Marcus (75kg) | Sarah (82kg) |
|-------|-------------|--------------|--------------|
| **Pre-Meal** | 41g carb, 13g pro, 21g fat | 59g carb, 19g pro, 30g fat | 64g carb, 21g pro, 33g fat |
| **Pre-Snack** | 41g carb, 8g pro, 5g fat | 59g carb, 11g pro, 5g fat | 64g carb, 12g pro, 5g fat |
| **Pre-TopUp** | 27g carb, 0g pro, 0g fat | 39g carb, 0g pro, 0g fat | 43g carb, 0g pro, 0g fat |
| **During** | ~0g (mouth rinse OK) | ~0g (mouth rinse OK) | ~0g (mouth rinse OK) |
| **During Na** | 478mg total | 478mg total | 171mg total |
| **During H2O** | 647mL total | 647mL total | 388mL total |
| **Post** | 52g carb, 16g pro, 10g fat | 75g carb, 23g pro, 15g fat | 82g carb, 25g pro, 16g fat |

**Note:** Workout B is eligible for fasted training (easy intensity, <60 min). If fasted, skip pre-workout phases and prioritize post-workout nutrition.

### Workout C: 4-Hour Bike Ride (28°C, Hot)

| Phase | Elena (52kg, high gut) | Marcus (75kg, mod gut) | Sarah (82kg, low gut) |
|-------|----------------------|----------------------|---------------------|
| **Pre-Meal** | 61g carb, 13g pro, 21g fat | 88g carb, 19g pro, 30g fat | 96g carb, 21g pro, 33g fat |
| **Pre-Snack** | 53g carb, 8g pro, 5g fat | 77g carb, 11g pro, 5g fat | 84g carb, 12g pro, 5g fat |
| **Pre-TopUp** | 35g carb, 0g pro, 0g fat | 51g carb, 0g pro, 0g fat | 56g carb, 0g pro, 0g fat |
| **During** | 88g/hr (350g total) | 60g/hr (240g total) | 40g/hr (160g total) |
| **During Na** | 916mg/hr (3663mg) | 916mg/hr (3663mg) | 327mg/hr (1307mg) |
| **During H2O** | 1238mL/hr (4950mL) | 1238mL/hr (4950mL) | 743mL/hr (2970mL) |
| **Post** | 62g carb, 16g pro, 10g fat | 90g carb, 23g pro, 15g fat | 98g carb, 25g pro, 16g fat |

**Note:** Workout C demonstrates how gut training affects during-exercise targets. Elena (high) can absorb 88g/hr, Marcus (moderate) is capped at 60g/hr, Sarah (low) at 40g/hr.

---

## Brick Workout Adjustments

Brick workouts (multi-sport sessions like triathlon) require special handling because:
1. Swimming segment has 0 carbs during (cannot eat)
2. Post-bike running has reduced GI tolerance
3. Transitions are opportunities for rapid fueling

### Brick Calculation Principles

**Use CUMULATIVE duration** for the carb band lookup (TABLE 1).

Example: A brick with 30min swim + 90min bike + 30min run = 2.5 hours total duration → use the "2.5-4 hr" band (60-90 g/hr).

**Justification:** Blog mentions brick workouts use total duration. Current edge function confirms: "Uses same bands as running but based on cumulative duration."

### Segment-Specific Adjustments

| Segment | Carb Ceiling | Special Rules | Source |
|---------|--------------|---------------|--------|
| **Swim** | 0 g/hr | Cannot eat while swimming | Blog: "pre/post only" |
| **Bike** | 120 g/hr | Front-load nutrition here | Current edge function |
| **Bike (before run)** | 120 g/hr + **20% bonus** | Extra loading before run | Current edge function: "+20% if followed by run" |
| **Run (after bike)** | **52.5 g/hr** (reduced) | 25% reduction from normal 70 g/hr | Blog: "20-30% reduction in run carb targets after bike leg" |

### Brick Carb Allocation Formula

```
# Step 1: Get cumulative duration carb band
total_duration = swim_duration + bike_duration + run_duration
carb_band = lookup TABLE 1 using total_duration

# Step 2: Calculate carbs per segment
swim_carbs = 0  # Cannot eat

bike_carb_rate = min(carb_in_band, 120, absorption_cap)
if has_run_after_bike:
    bike_carb_rate = bike_carb_rate × 1.2  # Front-load 20% extra
bike_carbs = bike_carb_rate × bike_duration_hours

run_carb_ceiling = 70 × 0.75  # 52.5 g/hr post-bike penalty
run_carb_rate = min(carb_in_band, run_carb_ceiling, absorption_cap)
run_carbs = run_carb_rate × run_duration_hours

# Step 3: Add transition carbs
total_carbs = swim_carbs + t1_carbs + bike_carbs + t2_carbs + run_carbs
```

### Brick Example: Olympic Triathlon

**Workout:** 30min swim + T1 + 60min bike + T2 + 30min run = 2 hours total
**Athlete:** Marcus (75kg, moderate gut training, 60 g/hr absorption cap)
**Conditions:** 25°C

| Segment | Duration | Carb Rate | Carbs | Notes |
|---------|----------|-----------|-------|-------|
| Pre-Workout | - | - | 96g | 3-4h before meal |
| Swim | 30 min | 0 g/hr | 0g | Cannot eat |
| **T1** | 2 min | - | **23g** | 0.3 g/kg quick carbs |
| Bike | 60 min | 60 g/hr × 1.2 = 72 g/hr | 72g | Capped by gut, +20% for run |
| **T2** | 2 min | - | **26g** | 0.35 g/kg last chance |
| Run | 30 min | 52.5 g/hr | 26g | Post-bike penalty applied |
| Post-Workout | - | - | 75g | Recovery |
| **TOTAL DURING** | 2 hr | - | **147g** | Swim + T1 + Bike + T2 + Run |

### Hydration and Sodium During Brick

Swimming has lower hydration and sodium needs:

```
if segment = swim:
    hydration_rate = 0.45 L/hr (base for swim)
    sodium_rate = 500 mg/hr (medium sweater)
else:
    # Use standard run/bike calculations
```

**Justification:** Current edge function specifies swimming hydration at 0.35-0.55 L/hr (lower than running's 0.4-0.8 L/hr) due to water immersion and horizontal position.

---

## Claude's Comments: Reality Check on Carb Recommendations

*This section contains my analysis of whether the algorithm's carbohydrate recommendations are realistic and whether athletes might find them too high, too low, or appropriate.*

### Pre-Workout Carbs: Potentially HIGH for Beginners

**Concern:** The cumulative pre-workout totals may seem overwhelming to recreational athletes.

| Persona | Total Pre-Workout Carbs (Workout A) | g/kg | Real-World Equivalent |
|---------|-------------------------------------|------|----------------------|
| Elena (52 kg) | 161g | 3.1 g/kg | ~6 slices bread + 2 bananas + bowl oatmeal |
| Marcus (75 kg) | 233g | 3.1 g/kg | ~9 slices bread + 3 bananas + large oatmeal |
| Sarah (82 kg) | 255g | 3.1 g/kg | ~10 slices bread + 3 bananas + XL oatmeal |

**My Assessment:**
- **Good news:** These totals (3.1 g/kg) fall within the research-supported 2-4 g/kg range discussed in the "Cumulative Pre-Workout Carbohydrate Considerations" section.
- **For elite/experienced athletes:** These numbers align with what competitive endurance athletes actually eat before long efforts. Marathoners and Ironman athletes routinely consume 2-3 g/kg in the hours before racing.
- **For beginners like Sarah:** 255g of pre-workout carbs may still feel intimidating and could cause GI distress if she hasn't practiced this volume. Recommendations:
  - Build up to these targets gradually over training cycles
  - Start with 2 g/kg total and increase based on tolerance
  - Not all three windows are mandatory—many athletes use only breakfast + small top-up

### During-Exercise Carbs: Appropriate but Gut-Training Dependent

**The numbers look reasonable for the respective gut training levels:**

| Gut Training | Our Cap | Research Range | Assessment |
|--------------|---------|----------------|------------|
| Low (Sarah) | 40 g/hr | 30-40 g/hr | ✅ Appropriate - conservative for untrained |
| Moderate (Marcus) | 60 g/hr | 60 g/hr | ✅ Appropriate - SGLT1 ceiling |
| High (Elena) | 88-100 g/hr | 90-120 g/hr | ✅ Appropriate for trained gut with dual carbs |

**My Assessment:**
- These align well with Jeukendrup's research (60 g/hr single transporter, 90-120 g/hr with glucose:fructose)
- Athletes with low gut training may still struggle with 40 g/hr and should start at 30 g/hr
- The intensity-based "slider" within the band is a reasonable MEALVANA decision, though not explicitly from research

**Potential Athlete Pushback:**
- **Workout C (4hr bike, Elena at 88g/hr = 350g total):** This is achievable for trained cyclists but requires multiple gels/bars per hour. Some athletes may find this volume hard to consume.
- **Workout B (45min easy, 2g/hr = 1g total):** Athletes may question why they need ANY carbs for a short easy run. Consider dropping to 0g recommendation for <60min easy efforts.

### Post-Workout Carbs: Slightly LOW for Aggressive Recovery

**Our recommendations:**

| Workout | Post-Workout Carbs | Research Recommendation |
|---------|-------------------|------------------------|
| A (2hr) | 1.0 g/kg | 1.0-1.2 g/kg/hr for 4 hours |
| C (4hr) | 1.2 g/kg | 1.0-1.2 g/kg/hr for 4 hours |

**My Assessment:**
- These are for the FIRST recovery meal/hour only, which is appropriate
- Research shows glycogen resynthesis is maximized with 1.0-1.2 g/kg/hr for the first 4 hours
- Athletes doing multiple sessions per day should continue eating 1.0-1.2 g/kg each hour
- Our single-meal targets are reasonable for typical training

### Sodium: May Seem HIGH to Casual Athletes

**During-exercise sodium for 2hr run:**

| Persona | Our Target | Common Sports Drink |
|---------|------------|---------------------|
| Elena/Marcus (medium sweater) | 749 mg/hr | ~200-300 mg/hr (Gatorade) |
| Sarah (low sweater) | 267 mg/hr | ~200-300 mg/hr |

**My Assessment:**
- Our sodium targets are HIGHER than what most sports drinks provide
- This is intentional—the blog cites research showing wide variation (200-2000 mg/L sweat concentration)
- Athletes accustomed to standard Gatorade may be surprised by 750 mg/hr recommendations
- **Recommendation:** Include guidance that athletes may need salt tabs or high-sodium drinks to hit these targets

### Hydration: Reasonable but Weather-Dependent

**During-exercise hydration for 2hr run at 22°C:**

| Persona | Our Target | Common Advice |
|---------|------------|---------------|
| Elena/Marcus | 1013 mL/hr | 400-800 mL/hr |
| Sarah | 608 mL/hr | 400-800 mL/hr |

**My Assessment:**
- Our targets (75% of sweat rate) are at the HIGHER end of typical advice
- 1 liter/hour is achievable but aggressive—requires drinking every 6 minutes
- Some athletes may find this uncomfortable or impractical during races
- The calculation is evidence-based (75% sweat replacement) but practical limitations exist

### Overall Verdict

| Category | Assessment | Confidence |
|----------|------------|------------|
| Pre-workout carbs | Potentially high for beginners | Medium - need user testing |
| During carbs | Well-calibrated to gut training | High |
| Post-workout carbs | Appropriate | High |
| Sodium | Higher than expected | High - but may surprise users |
| Hydration | Aggressive but evidence-based | Medium |

**Key Recommendations:**
1. ✅ Cumulative pre-workout guidance added (recommend 2-4 g/kg total; see "Cumulative Pre-Workout Carbohydrate Considerations")
2. Consider 0g during-carb target for easy workouts <60 min
3. Include guidance about needing salt tabs to hit sodium targets
4. Add "beginner modifier" (0.8×) for athletes with low gut training in future versions
5. Include warnings when targets exceed practical consumption limits

### Will Athletes Balk?

**Yes, some will—particularly:**
- Beginners seeing 200+ gram pre-workout totals
- Athletes expecting standard Gatorade to meet sodium needs
- Anyone unfamiliar with aggressive hydration (1L/hr)

**Mitigation strategies:**
- Frame targets as "goals to build toward" not immediate requirements
- Provide "beginner mode" with reduced targets
- Explain the research basis so athletes understand WHY targets are high
- Include food equivalents so numbers feel tangible
