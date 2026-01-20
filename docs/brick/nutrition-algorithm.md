# Brick Workout Nutrition Algorithm

## Overview

This document details the nutrition calculation logic for brick workouts, including how macro targets are computed, how phases are structured, and how the edge functions should be modified.

## Key Principles

Based on sports nutrition research (ACSM, ISSN):

1. **Cumulative Calculation**: Use TOTAL duration to determine carbohydrate needs, not per-segment calculations
2. **Gastric Tolerance Varies**: Cycling allows more intake than running; swimming allows none
3. **Transition Windows Matter**: T1 and T2 are critical fueling opportunities
4. **Sport Order Doesn't Affect Totals**: Calculate same macros regardless of order (e.g., swim/run vs run/swim)

## Nutrition Phases for Brick Workouts

### Phase Structure

| Phase | Description | Duration | Foods |
|-------|-------------|----------|-------|
| Before | Pre-workout nutrition | ~2-3 hours before | Standard before foods |
| During Segment 1 | First sport's during phase | Segment 1 duration | Sport-specific foods |
| T1 Transition | Between segment 1 and 2 | ~2-5 minutes | Quick carbs, gels |
| During Segment 2 | Second sport's during phase | Segment 2 duration | Sport-specific foods |
| T2 Transition | Between segment 2 and 3 (if 3 sports) | ~2-5 minutes | Quick carbs, gels |
| During Segment 3 | Third sport's during phase (if 3 sports) | Segment 3 duration | Sport-specific foods |
| After | Recovery nutrition | Post-workout | Standard recovery foods |

### Example: Swim/Run Brick (2000m swim + 10K run)

```
Timeline:
├── Before (45min prior)
├── Swim Start (t=0)
│   └── During Swim (40 min) - No food intake
├── T1 Transition (t=40)
│   └── Quick fueling (2-5 min)
├── Run Start (t=42-45)
│   └── During Run (55 min) - Run-suitable foods
└── After (t=97-100)
    └── Recovery foods
```

## Macro Calculation Formula

### Step 1: Calculate Total Duration

```typescript
function calculateTotalDuration(segments: BrickSegment[]): number {
  return segments.reduce((sum, s) => sum + s.durationMinutes, 0);
}
```

### Step 2: Calculate Base Carbohydrate Rate

Based on ACSM/ISSN guidelines for continuous exercise:

```typescript
function getBaseCarbRate(totalDurationMinutes: number): number {
  // Carbs per hour based on total duration
  if (totalDurationMinutes < 60) {
    return 0; // Mouth rinse only for <1 hour
  } else if (totalDurationMinutes < 90) {
    return 30; // 30g/hr for 1-1.5 hours
  } else if (totalDurationMinutes < 150) {
    return 45; // 45g/hr for 1.5-2.5 hours
  } else if (totalDurationMinutes < 180) {
    return 60; // 60g/hr for 2.5-3 hours
  } else {
    return 75; // 75-90g/hr for 3+ hours (use 75 as default)
  }
}
```

### Step 3: Adjust for Intensity

```typescript
function adjustForIntensity(
  baseCarbRate: number,
  segments: BrickSegment[]
): number {
  // Calculate weighted average intensity
  const totalDuration = calculateTotalDuration(segments);
  let weightedIntensity = 0;

  for (const segment of segments) {
    const intensityMultiplier = {
      easy: 0.7,
      moderate: 1.0,
      hard: 1.2,
      race: 1.3,
    }[segment.intensity];

    weightedIntensity += (segment.durationMinutes / totalDuration) * intensityMultiplier;
  }

  return Math.round(baseCarbRate * weightedIntensity);
}
```

### Step 4: Calculate Total Macros

```typescript
interface BrickMacroTargets {
  totalCarbs: number;
  totalProtein: number;
  totalFat: number;
  totalSodium: number;
  totalWater: number;
  phases: PhaseTargets[];
}

function calculateBrickMacros(
  segments: BrickSegment[],
  userWeightKg: number,
  gutTrainingLevel: 'untrained' | 'moderate' | 'trained'
): BrickMacroTargets {
  const totalDuration = calculateTotalDuration(segments);
  const baseCarbRate = getBaseCarbRate(totalDuration);
  const adjustedCarbRate = adjustForIntensity(baseCarbRate, segments);

  // Gut training multiplier
  const gutMultiplier = {
    untrained: 0.6,
    moderate: 0.85,
    trained: 1.0,
  }[gutTrainingLevel];

  const finalCarbRate = Math.min(adjustedCarbRate * gutMultiplier, 90); // Max 90g/hr

  // Total during carbs
  const duringCarbs = finalCarbRate * (totalDuration / 60);

  // Before carbs: 1-2g/kg body weight, 2-3 hours before
  const beforeCarbs = Math.round(userWeightKg * 1.5);

  // After carbs: 1-1.2g/kg for recovery
  const afterCarbs = Math.round(userWeightKg * 1.0);

  // Protein
  const beforeProtein = 10; // Light protein before
  const afterProtein = Math.round(userWeightKg * 0.3); // 0.3g/kg post

  // Sodium: 300-800mg/hour depending on sweat rate
  const sodiumPerHour = 500; // Default mid-range
  const totalSodium = Math.round(sodiumPerHour * (totalDuration / 60));

  // Hydration: 500-750ml/hour
  const waterPerHour = 600; // Default mid-range
  const totalWater = Math.round(waterPerHour * (totalDuration / 60));

  return {
    totalCarbs: Math.round(beforeCarbs + duringCarbs + afterCarbs),
    totalProtein: beforeProtein + afterProtein,
    totalFat: 15, // Minimal fat for exercise
    totalSodium: totalSodium + 400, // +400 for before/after
    totalWater: totalWater + 500, // +500 for before/after
    phases: calculatePhaseBreakdown(segments, {
      beforeCarbs,
      duringCarbs,
      afterCarbs,
      beforeProtein,
      afterProtein,
      totalSodium,
      totalWater,
    }),
  };
}
```

## Phase-by-Phase Breakdown

### Before Phase

```typescript
const beforePhase = {
  carbs: userWeightKg * 1.5,  // 1-2g/kg, use 1.5
  protein: 10,                 // Light protein
  fat: 5,                      // Minimal
  sodium: 200,                 // Pre-hydration
  water: 300,                  // Pre-hydration
};
```

### During Phases (Sport-Specific)

#### During Swim
```typescript
// Swimming: Cannot eat while swimming
const duringSwimPhase = {
  carbs: 0,
  protein: 0,
  fat: 0,
  sodium: 0,
  water: 0,
  note: "No food intake during swim - mouth rinse acceptable",
};
```

#### During Bike
```typescript
// Cycling: Highest gastric tolerance - maximize intake here
function calculateDuringBikePhase(
  durationMinutes: number,
  totalDuration: number,
  totalDuringCarbs: number
): PhaseTargets {
  // Bike gets higher proportion since tolerance is higher
  const bikeProportion = durationMinutes / totalDuration;
  // Boost bike intake by 20% if followed by run (pre-load strategy)
  const preLoadBoost = 1.2;

  return {
    carbs: Math.round(totalDuringCarbs * bikeProportion * preLoadBoost),
    protein: 0,
    fat: 0,
    sodium: Math.round(500 * (durationMinutes / 60)),
    water: Math.round(600 * (durationMinutes / 60)),
  };
}
```

#### During Run
```typescript
// Running: Reduced gastric tolerance - conservative intake
function calculateDuringRunPhase(
  durationMinutes: number,
  totalDuration: number,
  totalDuringCarbs: number,
  remainingCarbs: number // After bike/swim allocation
): PhaseTargets {
  // Run gets remaining carbs, but capped at 30-40g/hr
  const maxRunCarbsPerHour = 35;
  const maxRunCarbs = maxRunCarbsPerHour * (durationMinutes / 60);

  return {
    carbs: Math.min(remainingCarbs, maxRunCarbs),
    protein: 0,
    fat: 0,
    sodium: Math.round(400 * (durationMinutes / 60)),
    water: Math.round(500 * (durationMinutes / 60)),
  };
}
```

### Transition Phases

#### T1 (After Swim or First Segment)
```typescript
const t1Phase = {
  carbs: 20,     // Quick carbs (gel + drink)
  protein: 0,
  fat: 0,
  sodium: 150,   // Sodium replacement
  water: 200,    // Quick hydration
  timing: "Within first 5-10 minutes after swim",
  recommended_foods: ["energy_gel", "sports_drink"],
};
```

#### T2 (Before Run, After Bike)
```typescript
const t2Phase = {
  carbs: 25,     // Pre-load before reduced tolerance
  protein: 0,
  fat: 0,
  sodium: 100,
  water: 150,
  timing: "Final 5-10 minutes of bike leg",
  recommended_foods: ["energy_gel", "sports_drink", "chews"],
};
```

### After Phase

```typescript
function calculateAfterPhase(
  userWeightKg: number,
  totalDuration: number
): PhaseTargets {
  return {
    carbs: Math.round(userWeightKg * 1.0),  // 1g/kg
    protein: Math.round(userWeightKg * 0.3), // 0.3g/kg
    fat: 10,
    sodium: 300,
    water: 500,
  };
}
```

## Edge Function API Changes

### generate-macros Endpoint

**New Request Schema for Brick:**

```typescript
interface GenerateMacrosBrickRequest {
  device_id: string;
  activity_type: 'brick';
  user_weight_kg: number;
  gut_training_level: 'untrained' | 'moderate' | 'trained';

  // Brick-specific fields
  brick_segments: BrickSegment[];

  // Optional
  environment?: {
    temperature_c?: number;
    humidity_percent?: number;
  };
}

interface BrickSegment {
  sport: 'swimming' | 'cycling' | 'running';
  order: number;
  duration_minutes: number;
  intensity: 'easy' | 'moderate' | 'hard' | 'race';

  // Sport-specific (only relevant ones needed)
  distance_meters?: number;      // Swimming
  pace_per_100m_seconds?: number;// Swimming
  pool_or_open_water?: string;   // Swimming
  distance_miles?: number;       // Cycling, Running
  speed_mph?: number;            // Cycling
  terrain?: string;              // Cycling
  pace_minutes_per_mile?: number;// Running
}
```

**Response Schema:**

```typescript
interface GenerateMacrosBrickResponse {
  success: boolean;
  activity_type: 'brick';
  brick_type: string; // e.g., "swim_run", "bike_run", "swim_bike_run"

  // Total targets
  total_carbs_g: number;
  total_protein_g: number;
  total_fat_g: number;
  total_sodium_mg: number;
  total_water_ml: number;

  // Phase breakdown
  phases: {
    before: PhaseTargets;
    during_segments: DuringSegmentTargets[];
    transitions: TransitionTargets[];
    after: PhaseTargets;
  };

  // Metadata
  total_duration_minutes: number;
  energy_expenditure_kcal: number;
  carb_rate_g_per_hour: number;
}

interface DuringSegmentTargets {
  segment_order: number;
  sport: string;
  duration_minutes: number;
  carbs_g: number;
  sodium_mg: number;
  water_ml: number;
  food_categories: string[]; // e.g., ["during_swim"] or ["during_run"]
}

interface TransitionTargets {
  transition_name: string; // "T1" or "T2"
  after_sport: string;
  before_sport: string;
  carbs_g: number;
  sodium_mg: number;
  water_ml: number;
  timing_note: string;
  food_categories: string[]; // ["transition"]
}
```

### generate-nutrition-plan Endpoint

**Changes for Brick Support:**

```typescript
interface GeneratePlanBrickRequest {
  device_id: string;
  activity_type: 'brick';
  brick_type: string;

  macro_targets: {
    before: PhaseTargets;
    during_segments: DuringSegmentTargets[];
    transitions: TransitionTargets[];
    after: PhaseTargets;
  };

  liked_foods?: string[];
  willing_to_try_foods?: string[];
  disliked_foods?: string[];
}
```

**Response with Phase-Based Foods:**

```typescript
interface GeneratePlanBrickResponse {
  success: boolean;
  plan_id: string;

  plan: {
    before: FoodResult[];
    during_segments: {
      [segmentOrder: number]: FoodResult[];
    };
    transitions: {
      T1?: FoodResult[];
      T2?: FoodResult[];
    };
    after: FoodResult[];
  };

  actual_macros: {
    // Same structure as targets but with achieved values
  };
}
```

## Food Categories for Brick Phases

### Existing Categories to Use

| Phase | Categories |
|-------|------------|
| Before | `before`, `before_run` |
| During Swim | (none - no eating) |
| During Bike | `during_bike`, `during_run` |
| During Run | `during_run` |
| After | `after`, `after_run` |

### New Category: Transition

Add a new `transition` category for quick-access foods:

```sql
-- Add to Supabase
ALTER TYPE category_enum ADD VALUE 'transition';

-- Tag appropriate foods
UPDATE foods
SET categories = array_append(categories, 'transition')
WHERE name IN (
  'GU Energy Gel',
  'Maurten Gel 100',
  'Gatorade Endurance',
  'SIS GO Isotonic Gel',
  'Clif Bloks'
);
```

**Transition Food Criteria:**
- Fast digesting (simple carbs)
- Easy to consume quickly
- Portable (gels, drinks, chews)
- Low fiber, low fat
- Carbs: 15-30g per serving
- Can be consumed in <60 seconds

## Energy Expenditure Calculation

For brick workouts, sum the energy expenditure of each segment:

```typescript
function calculateBrickEnergyExpenditure(
  segments: BrickSegment[],
  userWeightKg: number
): number {
  let totalKcal = 0;

  for (const segment of segments) {
    const met = getMETForSegment(segment);
    const kcal = calculateSegmentKcal(met, userWeightKg, segment.durationMinutes);
    totalKcal += kcal;
  }

  return Math.round(totalKcal);
}

function getMETForSegment(segment: BrickSegment): number {
  switch (segment.sport) {
    case 'swimming':
      return getSwimmingMET(segment.pacePer100mSeconds, segment.poolOrOpenWater);
    case 'cycling':
      return getCyclingMET(segment.speedMph, segment.terrain);
    case 'running':
      return getRunningMET(segment.paceMinutesPerMile);
  }
}

function calculateSegmentKcal(
  met: number,
  weightKg: number,
  durationMinutes: number
): number {
  // ACSM formula: kcal = MET × 3.5 × weightKg / 200 × durationMinutes
  return met * 3.5 * weightKg / 200 * durationMinutes;
}
```

## Example Calculation: Swim/Run Brick

**Input:**
- User: 70kg, moderate gut training
- Swim: 2000m, 40 min, moderate intensity
- Run: 10K (6.2mi), 55 min, moderate intensity

**Calculation:**

```
Total duration: 40 + 55 = 95 minutes

Base carb rate (95 min): 45g/hr
Intensity adjustment: 1.0 (moderate)
Gut training multiplier: 0.85
Final carb rate: 45 × 1.0 × 0.85 = 38g/hr

During carbs: 38 × (95/60) = 60g

Before carbs: 70 × 1.5 = 105g
After carbs: 70 × 1.0 = 70g

Phase Distribution:
├── Before: 105g carbs, 10g protein, 200mg sodium, 300ml water
├── During Swim: 0g (can't eat)
├── T1: 20g carbs, 150mg sodium, 200ml water
├── During Run: 40g carbs, 400mg sodium, 500ml water
├── After: 70g carbs, 21g protein, 300mg sodium, 500ml water

TOTALS:
├── Carbs: 105 + 0 + 20 + 40 + 70 = 235g
├── Protein: 10 + 0 + 0 + 0 + 21 = 31g
├── Sodium: 200 + 0 + 150 + 400 + 300 = 1050mg
├── Water: 300 + 0 + 200 + 500 + 500 = 1500ml
```

## Implementation Notes

### Handling Sport Order

Since order doesn't affect total calculations:

```typescript
// Order affects phase DISPLAY, not total macros
function generatePhaseBreakdown(segments: BrickSegment[]): Phase[] {
  const phases: Phase[] = [{ type: 'before', ...beforeTargets }];

  for (let i = 0; i < segments.length; i++) {
    const segment = segments[i];

    // Add during phase for this segment
    phases.push({
      type: `during_${segment.sport}`,
      ...calculateDuringPhase(segment),
    });

    // Add transition if not last segment
    if (i < segments.length - 1) {
      phases.push({
        type: i === 0 ? 'T1' : 'T2',
        ...calculateTransitionPhase(),
      });
    }
  }

  phases.push({ type: 'after', ...afterTargets });
  return phases;
}
```

### Swim-First Special Case

When swimming is first:

```typescript
if (segments[0].sport === 'swimming') {
  // No pre-swim fueling during swim
  // Emphasize T1 transition as first carb opportunity
  phases.find(p => p.type === 'T1').carbs *= 1.2; // Boost T1 by 20%
}
```

### Run-Last Special Case

When running is last:

```typescript
if (segments[segments.length - 1].sport === 'running') {
  // Pre-load during previous segment
  const prevSegment = segments[segments.length - 2];
  if (prevSegment.sport === 'cycling') {
    // Increase bike during carbs, reduce run during carbs
    phases.find(p => p.type === 'during_cycling').carbs *= 1.15;
    phases.find(p => p.type === 'during_running').carbs *= 0.85;
  }
}
```

## Testing Scenarios

### Test Case 1: Swim/Run Brick
```
Input: 1500m swim (30min) + 5K run (25min)
Expected: ~45min total, 30g/hr carb rate
Verify: Before, During Swim (0), T1, During Run, After
```

### Test Case 2: Bike/Run Brick
```
Input: 20mi bike (60min) + 10K run (50min)
Expected: ~110min total, 60g/hr carb rate
Verify: Before, During Bike (higher carbs), T2, During Run (lower carbs), After
```

### Test Case 3: Swim/Bike/Run Brick
```
Input: 1500m swim (25min) + 40K bike (75min) + 10K run (50min)
Expected: ~150min total, 60g/hr carb rate
Verify: All phases including T1 and T2
```

### Test Case 4: User-Defined Order (Run/Swim)
```
Input: 5K run (25min) first, then 1500m swim (30min)
Expected: Same total macros as Swim/Run
Verify: Phase order reflects user selection
```
