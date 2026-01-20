# Edge Function Audit for Brick Workouts

**Audit Date:** 2026-01-20
**Purpose:** Document current nutrition edge function architecture and identify where brick support needs to be added
**Status:** Research Only - No Changes Made

---

## Executive Summary

The Mealvana Endurance app uses two primary edge functions for nutrition planning:

1. **`generate-macros`** - Calculates macro targets using ACSM formulas (supports running, cycling, swimming)
2. **`generate-nutrition-plan`** - Generates optimal food selections using Linear Programming (sport-agnostic via sport configs)

**Key Finding:** Both functions already have multi-sport support infrastructure. Adding brick workout support requires extending these existing patterns rather than creating new edge functions.

---

## 1. Edge Function: `generate-macros`

**Location:** `/supabase/functions/generate-macros/index.ts`
**Purpose:** Calculate macro and hydration targets based on activity parameters using ACSM formulas
**Size:** 1,104 lines (including running, cycling, and swimming formulas)

### 1.1 Request Schema

#### Common Fields (All Activity Types)
```typescript
{
  activity_type: 'running' | 'cycling' | 'swimming',  // Required
  weight: number,                                      // Required
  weight_unit: 'kg' | 'lb',                           // Default: 'kg'

  // Shared nutrition parameters
  gut_training: 'low' | 'moderate' | 'high',          // Default: 'high'
  carb_source: 'glucose_only' | 'dual',               // Default: 'dual'
  time_before_min: number,                             // Default: 120

  // Shared hydration parameters
  sweat_sodium: 'low' | 'medium' | 'high',            // Default: 'medium'
  sweat_rate_category: 'light' | 'medium' | 'heavy',  // Default: 'medium'
  optional_sweat_rate_lph: number | null,             // Measured sweat rate (optional)
  drink_sodium_mg_per_l: number,                      // Default: 500

  // Environmental parameters
  temp_c: number | null,                               // Default: null (moderate)
  humidity_pct: number | null,                         // Default: null (moderate)
}
```

#### Running-Specific Fields
```typescript
{
  activity_type: 'running',
  run_distance: number,                                // Required
  run_distance_unit: 'mi' | 'km',                     // Default: 'mi'
  run_pace: string | number,                          // Required (e.g., "8:30" or 8.5)
  run_pace_unit: 'min_per_mile' | 'min_per_km',      // Default: 'min_per_mile'
}
```

#### Cycling-Specific Fields
```typescript
{
  activity_type: 'cycling',
  distance_miles: number,                              // Required
  speed_mph: number,                                   // Required
  terrain: 'flat' | 'rolling' | 'hilly',              // Default: 'flat'
  elevation_gain_ft: number,                           // Default: 0
  indoor_outdoor: 'indoor' | 'outdoor',               // Default: 'outdoor'
}
```

#### Swimming-Specific Fields
```typescript
{
  activity_type: 'swimming',
  distance_meters: number,                             // Required
  pace_per_100m_seconds: number,                      // Required
  pool_or_open_water: 'pool' | 'open_water',         // Default: 'pool'
  water_temp_c: number,                                // Default: 26
  pool_deck_temp_c: number | null,                    // Optional
  pool_deck_humidity_pct: number | null,              // Optional
}
```

### 1.2 Response Schema (Normalized)

**Critical:** All activity types return the same field names for Dart parsing consistency:

```typescript
{
  success: true,
  activity_type: 'running' | 'cycling' | 'swimming',
  macros: {
    // Duration and pace
    duration_min: number,
    duration_h: number,
    pace_min_per_mile: number,                        // 0 for cycling/swimming
    pace_per_100m_seconds?: number,                   // Swimming only
    speed_mph: number,
    distance_mi: number,
    distance_km: number,
    distance_meters?: number,                          // Swimming only

    // Energy expenditure
    calories_net_kcal: number,
    calories_gross_kcal: number,
    MET: number,

    // Pre-activity nutrition (normalized names for all sports)
    pre_run_carbs_g: number,
    pre_run_carbs_rule: string,                       // E.g., "2.0h × 1.2 g/kg"
    pre_run_protein_g_optional: number,
    pre_run_fat_g_cap: number,
    pre_run_water_ml: number,
    pre_run_sodium_mg: number,

    // During-activity nutrition
    during_rate_g_per_h: number,
    during_total_g: number,
    during_mass_norm_rate_g_per_h: number,
    during_abs_clamp_range_g_per_h: [number, number],
    during_mass_norm_total_range_g?: [number, number],  // Running only
    during_water_rate_ml_per_h: number,
    during_water_total_ml: number,
    during_sodium_rate_mg_per_h: number,
    during_sodium_total_mg: number,

    // Post-activity nutrition
    post_run_carbs_g: number,
    post_run_protein_g: number,
    post_run_water_ml: number,
    post_run_sodium_mg: number,
  }
}
```

### 1.3 Activity Type Handling

**Lines 873-1077** - Main request handler routes to sport-specific functions:

```typescript
const activityType = requestData.activity_type || 'running';

if (activityType === 'running') {
  macros = computeRunFueling(requestData);
} else if (activityType === 'cycling') {
  const cyclingInput = { /* transform request */ };
  const cyclingMacros = calculateCyclingMacros(cyclingInput);
  macros = { /* normalize field names */ };
} else if (activityType === 'swimming') {
  const swimmingInput = { /* transform request */ };
  const swimmingMacros = calculateSwimmingMacros(swimmingInput);
  macros = { /* normalize field names */ };
} else {
  return errorResponse('Invalid activity_type');
}
```

### 1.4 Sport-Specific Formulas

#### Running Formulas (Lines 35-398)
- **MET Calculation:** ACSM running equation with walk/run switch at 4.0 mph (line 36-42)
- **Gross Calories:** `MET × 3.5 × weight (kg) / 200 × duration (min)` (line 44-46)
- **Net Calories:** `1.0 × weight (kg) × distance (km)` (line 48-50)
- **Carb Recommendations:** Duration-based bands (line 54-76)
  - ≤1h: 0-30 g/h
  - 1-2h: 30-45 g/h
  - 2-3h: 45-60 g/h
  - 3-4h: 60-75 g/h
  - >4h: 75-90 g/h
- **Absorption Caps:** Gut training dependent (line 77-83)
  - Glucose only: 60-65 g/h
  - Dual source (low gut): 80 g/h
  - Dual source (moderate gut): 90 g/h
  - Dual source (high gut): 100 g/h

#### Cycling Formulas (Lines 400-658)
- **MET Calculation:** Speed-based lookup + terrain multiplier (line 404-433)
  - ≤16 kph: 6.0 MET (leisure)
  - 16-19 kph: 8.0 MET (light)
  - 19-22 kph: 10.0 MET (moderate)
  - 22-25 kph: 12.0 MET (vigorous)
  - 25-30 kph: 14.0 MET (very vigorous)
  - >30 kph: 16.0 MET (racing)
- **Terrain Adjustments:** Rolling +10%, Hilly +25% (line 427-431)
- **Elevation Bonus:** Vertical meters per kilometer adds 1-4 MET (line 435-456)
- **Indoor/Outdoor:** Indoor = 95% of outdoor MET (line 458-464)
- **Carb Recommendations:** Higher than running (line 507-546)
  - ≤1h: 0-30 g/h
  - 1-2h: 30-60 g/h
  - 2-3h: 60-90 g/h
  - 3-4h: 75-100 g/h
  - >4h: 90-120 g/h (elite cyclists)

#### Swimming Formulas (Lines 660-863)
- **MET Calculation:** Pace-based + pool/open water + water temp (line 664-686)
  - ≥180 sec/100m: 6.0 MET
  - 150-180 sec/100m: 8.0 MET
  - 120-150 sec/100m: 10.0 MET
  - 90-120 sec/100m: 11.0 MET
  - <90 sec/100m: 13.0 MET
- **Open Water Bonus:** +15% MET (line 677-679)
- **Water Temp Adjustments:** Cold +10%, Warm -5% (line 680-684)
- **Carb Recommendations:** Lower due to feeding difficulty (line 727-755)
  - ≤1h: 0 g/h (no feeding)
  - 1-1.5h: 0-30 g/h
  - 1.5-2.5h: 30-60 g/h
  - >2.5h: 45-75 g/h
- **Hydration:** Reduced rates (0.35-0.55 L/h) due to immersion (line 770-790)

### 1.5 Brick Workout Gap Analysis

**Missing Support:**
1. No `activity_type: 'brick'` handling
2. Cannot accept multiple activities in single request
3. No transition nutrition calculations
4. No cumulative MET or calorie tracking across activities
5. No sport-specific carb carry-over logic

**Where to Add Brick Support:**
1. **Lines 873-877:** Add `activityType === 'brick'` branch
2. **Request Schema:** Add brick-specific fields:
   ```typescript
   {
     activity_type: 'brick',
     activities: [
       { type: 'cycling', distance_miles: 20, speed_mph: 18, ... },
       { type: 'running', run_distance: 5, run_pace: "8:00", ... }
     ]
   }
   ```
3. **Response Schema:** Add transition phase:
   ```typescript
   {
     macros: {
       // Existing fields...
       transition_carbs_g: number,
       transition_water_ml: number,
       transition_sodium_mg: number,
     }
   }
   ```

---

## 2. Edge Function: `generate-nutrition-plan`

**Location:** `/supabase/functions/generate-nutrition-plan/index.ts`
**Purpose:** Generate optimal food selections using Linear Programming with sport-specific configurations
**Size:** 374 lines (lean, modular design)

### 2.1 Request Schema

```typescript
{
  device_id: string,                                   // Required (user UUID)
  macro_targets: {                                     // Required
    pre_run: {                                         // Note: "pre_run" used for all sports
      carbs_g: number,
      protein_g: number,
      sodium_mg: number,
      water_ml: number,
    },
    during_run: {                                      // Note: "during_run" used for all sports
      carbs_g: number,                                 // Or carbs_total_g
      sodium_mg: number,                               // Or sodium_total_mg
      water_ml: number,                                // Or water_total_ml
    },
    post_run: {                                        // Note: "post_run" used for all sports
      carbs_g: number,
      protein_g: number,
      sodium_mg: number,
      water_ml: number,
    },
  },
  liked_foods?: string[],                              // Food IDs or product types
  willing_to_try_foods?: string[],                    // Food IDs or product types
  disliked_foods?: string[],                          // Food IDs or product types
  activity_type?: 'running' | 'cycling' | 'swimming' | 'triathlon' | 'duathlon' | 'multisport',
}
```

### 2.2 Response Schema

```typescript
{
  success: true,
  plan_id: string,                                     // UUID
  detailed_message: string,
  plan: {
    before: FoodResult[],
    during: FoodResult[],
    after: FoodResult[],
  },
  macro_targets: {
    // Echo of request macro_targets
    activity_type: string,
  }
}

interface FoodResult {
  food_id: string,
  food_name: string,
  quantity: number,                                    // Servings
  carbs_grams: number,
  protein_grams: number,
  fat_grams: number,
  sodium_mg: number,
  fluids_ml: number,
  calories: number,
  display_name?: string,
  display_name_plural?: string,
  description?: string,
  image_address?: string,
}
```

### 2.3 Sport Configuration Architecture

**Location:** `/supabase/functions/_shared/nutrition/sport-configs/`

The edge function is **sport-agnostic** - all sport-specific logic lives in configuration files:

#### Sport Config Interface
```typescript
interface SportConfig {
  name: string,
  activityType: ActivityType,

  phases: {
    before: PhaseConfig,
    during: PhaseConfig,
    after: PhaseConfig,
  },

  foodOverrides: FoodOverride[],                      // Now in database (empty in code)

  optimizationWeights: {
    before: MacroWeights,
    during: MacroWeights,
    after: MacroWeights,
  },
}

interface PhaseConfig {
  maxFoods: number,                                    // Max distinct foods
  defaultMaxServings: number,
  maxServingsCap: number,
  priorities: ('carbs' | 'protein' | 'sodium' | 'hydration')[],
}

interface MacroWeights {
  carbs: number,
  protein?: number,
  sodium: number,
}
```

#### Running Config (`sport-configs/running.ts`)
```typescript
{
  phases: {
    before: { maxFoods: 4, defaultMaxServings: 2, maxServingsCap: 3 },
    during: { maxFoods: 4, defaultMaxServings: 2, maxServingsCap: 4 },
    after: { maxFoods: 4, defaultMaxServings: 2, maxServingsCap: 3 },
  },
  optimizationWeights: {
    before: { carbs: 1.0, protein: 0.6, sodium: 0.2 },
    during: { carbs: 1.0, sodium: 0.8 },
    after: { carbs: 0.9, protein: 0.7, sodium: 0.3 },
  },
}
```

#### Cycling Config (`sport-configs/cycling.ts`)
```typescript
{
  phases: {
    before: { maxFoods: 4, defaultMaxServings: 2, maxServingsCap: 3 },
    during: { maxFoods: 5, defaultMaxServings: 3, maxServingsCap: 6 },  // More variety
    after: { maxFoods: 4, defaultMaxServings: 2, maxServingsCap: 3 },
  },
  optimizationWeights: {
    before: { carbs: 1.0, protein: 0.5, sodium: 0.3 },
    during: { carbs: 1.0, sodium: 0.7 },
    after: { carbs: 0.8, protein: 0.8, sodium: 0.3 },
  },
}
```

#### Swimming Config (`sport-configs/swimming.ts`)
```typescript
{
  phases: {
    before: { maxFoods: 3, defaultMaxServings: 2, maxServingsCap: 2 },  // Lighter
    during: { maxFoods: 2, defaultMaxServings: 1, maxServingsCap: 2 },  // Limited
    after: { maxFoods: 4, defaultMaxServings: 2, maxServingsCap: 3 },
  },
  optimizationWeights: {
    before: { carbs: 0.8, protein: 0.3, sodium: 0.2 },
    during: { carbs: 0.5, sodium: 0.3 },
    after: { carbs: 0.7, protein: 0.9, sodium: 0.4 },
  },
}
```

#### Triathlon Config (`sport-configs/index.ts`)
```typescript
{
  phases: {
    before: { maxFoods: 4, defaultMaxServings: 2, maxServingsCap: 3 },
    during: { maxFoods: 4, defaultMaxServings: 2, maxServingsCap: 4 },
    after: { maxFoods: 4, defaultMaxServings: 2, maxServingsCap: 3 },
  },
  optimizationWeights: {
    before: { carbs: 1.0, protein: 0.5, sodium: 0.3 },
    during: { carbs: 1.0, sodium: 0.8 },                                // Conservative
    after: { carbs: 0.8, protein: 0.8, sodium: 0.4 },
  },
}
```

### 2.4 Food Phase Filtering (Database-Driven)

**Location:** `/supabase/functions/_shared/nutrition/food-queries.ts`

Foods are filtered by `categories` array column (expanded category enum):

#### Category Enum Values
- `before` - Universal pre-activity
- `during_run` - Running during activity (most restrictive)
- `during_bike` - Cycling during activity (allows solid foods)
- `during_swim` - Swimming during activity (liquids/gels only)
- `after` - Universal post-activity
- `transition` - Triathlon transition zone

#### Category Mapping Logic (Lines 166-183)
```typescript
function getCategoryForPhase(phase: Phase, activityType: string): string[] {
  switch (phase) {
    case 'before':
      return ['before', 'before_run'];  // Backward compatibility

    case 'during':
      const sportCategory = SPORT_DURING_CATEGORY[activityType] || 'during_run';

      // CRITICAL: Cycling includes running foods (safe to use)
      if (activityType === 'cycling') {
        return [sportCategory, 'during_run'];
      }
      return [sportCategory];

    case 'after':
      return ['after', 'after_run'];  // Backward compatibility
  }
}
```

**Key Insight:** Foods are tagged with **categories** (e.g., `['during_bike', 'during_run']`), not activity types. This allows:
- Banana = `['during_run', 'during_bike']` (safe for both)
- Energy gel = `['during_run', 'during_bike', 'during_swim']` (universal)
- Trail mix = `['during_bike']` (cycling only - GI stress on run)

### 2.5 Linear Programming Solver

**Location:** `/supabase/functions/_shared/nutrition/lp-solver.ts`

#### Objective Function (Lines 86-105)
```typescript
score = food.preference_score                        // 200 (liked), 80 (willing), 20 (neutral)
      + weights.carbs * food.carbs_g                 // Sport-specific weight
      + weights.protein * food.protein_g             // Before/after only
      + weights.sodium * (200 - |food.sodium_mg - 200|)
```

#### Constraints (Lines 32-78)
- **Carbs:** 90-110% of target (or 0-5g if target is zero)
- **Protein:** 90-110% of target (before/after only)
- **Sodium:** 75-110% of target (relaxed lower bound)
- **Water:** ≤110% of target (upper bound only)
- **Max Foods:** ≤4 distinct foods per phase
- **Max Servings:** Food-specific (from database `max_servings_during` column)

#### Greedy Fallback (Lines 143-149)
If LP solver fails (infeasible constraints), uses greedy algorithm:
1. Sort foods by preference score
2. Select highest-scoring foods
3. Add servings until carb target met
4. Post-process for sodium/water

### 2.6 Post-Processing Logic

**Location:** `generate-nutrition-plan/index.ts` (Lines 51-197)

Adds essential foods (water, electrolytes) if LP solution has deficits:

#### Sodium Addition (Lines 103-145)
```typescript
if (sodiumDeficit > sodiumTarget * 3% && foods.length < 5) {
  // Fetch electrolyte foods (is_electrolyte = true)
  // Sort by sodium-to-water ratio (prefer high sodium, low water)
  // Add servings to close gap (cap at 110% of target)
}
```

#### Water Addition (Lines 148-167)
```typescript
if (waterDeficit > waterTarget * 15% && foods.length < 5) {
  // Fetch water from essential foods (is_essential = true)
  // Add servings to close gap (cap at 110% of target)
}
```

### 2.7 Brick Workout Gap Analysis

**Missing Support:**
1. No transition phase in request schema (`macro_targets.transition`)
2. No transition phase in response schema (`plan.transition`)
3. Sport configs only have `before`, `during`, `after` phases
4. No `transition` category in database enum
5. No sport-specific transition recommendations (e.g., bike→run needs quick carbs)

**Where to Add Brick Support:**
1. **Request Schema (Lines 292-320):** Add `transition` to `macro_targets`
2. **Response Schema (Lines 352-368):** Add `transition` to `plan`
3. **Sport Config (`sport-configs/types.ts`):** Add `transition: PhaseConfig` to `SportConfig.phases`
4. **Category Enum (Database):** Add `transition` to `category_enum` type
5. **Food Queries (`food-queries.ts`):** Add `transition` case to `getCategoryForPhase()`
6. **Optimization (Lines 346-350):** Add `optimizePhase(supabase, 'transition', ...)`

**Brick-Specific Config Example:**
```typescript
{
  phases: {
    before: { /* standard */ },
    during_bike: { /* cycling config */ },
    transition: {
      maxFoods: 2,              // Quick, minimal
      defaultMaxServings: 1,
      maxServingsCap: 2,
      priorities: ['carbs'],    // Fast-acting carbs only
    },
    during_run: { /* running config */ },
    after: { /* standard */ },
  },
  optimizationWeights: {
    transition: { carbs: 1.0, sodium: 0.5 },  // Carbs priority, light sodium
  },
}
```

---

## 3. Shared Nutrition Utilities

**Location:** `/supabase/functions/_shared/nutrition/`

### 3.1 File Structure
```
nutrition/
├── constants.ts           - Constraint ranges, preference scores, category mappings
├── food-queries.ts        - Database queries with sport filtering
├── food-utils.ts          - Food deduplication, preference matching
├── greedy-fallback.ts     - Greedy algorithm when LP fails
├── lp-solver.ts           - Linear programming solver
├── types.ts               - TypeScript interfaces
└── sport-configs/
    ├── types.ts           - Sport config interface
    ├── running.ts         - Running-specific settings
    ├── cycling.ts         - Cycling-specific settings
    ├── swimming.ts        - Swimming-specific settings
    └── index.ts           - Config registry + getSportConfig()
```

### 3.2 Key Constants

#### Macro Constraint Ranges (`constants.ts`, Lines 56-76)
```typescript
MACRO_CONSTRAINT_RANGES = {
  carbs: {
    before: { min: 0.9, max: 1.1 },
    during: { min: 0.9, max: 1.1 },
    after: { min: 0.9, max: 1.1 },
  },
  protein: {
    before: { min: 0.9, max: 1.1 },
    after: { min: 0.9, max: 1.1 },
  },
  sodium: {
    before: { min: 0.85, max: 1.1 },
    during: { min: 0.9, max: 1.1 },
    after: { min: 0.85, max: 1.1 },
  },
  water: {
    before: { min: 0.85, max: 1.1 },
    during: { min: 0.9, max: 1.1 },
    after: { min: 0.85, max: 1.1 },
  },
}
```

#### Preference Scores (`constants.ts`, Lines 93-98)
```typescript
PREFERENCE_SCORE_MAP = {
  liked: 200,          // User explicitly liked
  willing: 80,         // User willing to try
  essential: 50,       // Water, salt (always available)
  neutral: 20,         // Generic foods
}
```

### 3.3 Sport Category Mapping

**Location:** `constants.ts` (Lines 153-161)

```typescript
SPORT_DURING_CATEGORY = {
  running: 'during_run',
  cycling: 'during_bike',
  swimming: 'during_swim',
  triathlon: 'during_run',    // Most restrictive for safety
  duathlon: 'during_run',
  multisport: 'during_run',
}
```

**Design Pattern:** For brick workouts, we'll need:
```typescript
SPORT_DURING_CATEGORY = {
  // ... existing ...
  'brick_bike': 'during_bike',
  'brick_run': 'during_run',
  'brick_transition': 'transition',  // New category
}
```

---

## 4. Brick Workout Implementation Roadmap

### 4.1 Phase 1: Database Schema (Prerequisite)

**Location:** Supabase database

1. **Add `transition` to category enum:**
   ```sql
   ALTER TYPE category_enum ADD VALUE 'transition';
   ```

2. **Tag existing foods with transition suitability:**
   - Energy gels → Add `transition`
   - Bananas → Add `transition`
   - Sports drinks → Add `transition`
   - Rule: If `during_run` AND `during_bike` → Add `transition`

3. **Add brick-specific foods:**
   - Quick carb options (gels, chews)
   - Transition-friendly packaging

### 4.2 Phase 2: `generate-macros` Extension

**Location:** `/supabase/functions/generate-macros/index.ts`

#### 2.1 Add Brick Request Schema (Lines 873-877)
```typescript
interface BrickMacrosRequest {
  activity_type: 'brick',
  activities: [
    {
      type: 'cycling',
      distance_miles: number,
      speed_mph: number,
      terrain?: string,
      elevation_gain_ft?: number,
    },
    {
      type: 'running',
      run_distance: number,
      run_pace: string,
      run_pace_unit?: string,
    }
  ],
  transition_duration_min?: number,  // Default: 2

  // Standard shared fields
  weight: number,
  weight_unit?: string,
  gut_training?: string,
  // ... etc
}
```

#### 2.2 Add Brick Calculation Function (New)
```typescript
function calculateBrickMacros(input: BrickMacrosRequest) {
  // 1. Calculate each activity separately
  const bikeInput = { /* map from input.activities[0] */ };
  const bikeMacros = calculateCyclingMacros(bikeInput);

  const runInput = { /* map from input.activities[1] */ };
  const runMacros = computeRunFueling(runInput);

  // 2. Calculate transition nutrition
  const transitionCarbs = 15;  // Quick 15g carb top-up
  const transitionWater = 150; // 150ml quick sip
  const transitionSodium = 100; // Light sodium

  // 3. Aggregate totals
  const totalDuration = bikeMacros.duration_h + runMacros.duration_h + (input.transition_duration_min / 60);
  const totalCalories = bikeMacros.calories_gross_kcal + runMacros.calories_gross_kcal;

  // 4. Return combined response
  return {
    duration_min: totalDuration * 60,
    duration_h: totalDuration,

    // Pre-brick (use bike pre-ride)
    pre_run_carbs_g: bikeMacros.pre_ride_carbs_g,
    // ... other pre fields

    // During bike leg
    during_bike_rate_g_per_h: bikeMacros.during_ride_carbs_per_h,
    during_bike_total_g: bikeMacros.during_ride_carbs_total,
    during_bike_water_total_ml: bikeMacros.during_ride_water_total_ml,
    during_bike_sodium_total_mg: bikeMacros.during_ride_sodium_total_mg,

    // Transition
    transition_carbs_g: transitionCarbs,
    transition_water_ml: transitionWater,
    transition_sodium_mg: transitionSodium,

    // During run leg
    during_run_rate_g_per_h: runMacros.during_rate_g_per_h,
    during_run_total_g: runMacros.during_total_g,
    during_run_water_total_ml: runMacros.during_water_total_ml,
    during_run_sodium_total_mg: runMacros.during_sodium_total_mg,

    // Post-brick (use run post-run)
    post_run_carbs_g: runMacros.post_run_carbs_g,
    // ... other post fields

    // Aggregates
    total_calories_kcal: totalCalories,
    total_carbs_g: bikeMacros.during_ride_carbs_total + transitionCarbs + runMacros.during_total_g,
  };
}
```

#### 2.3 Update Request Handler (Lines 873-1077)
```typescript
if (activityType === 'brick') {
  // Validate brick-specific fields
  if (!requestData.activities || requestData.activities.length !== 2) {
    return errorResponse('Brick workouts require exactly 2 activities');
  }

  macros = calculateBrickMacros(requestData);
}
```

### 4.3 Phase 3: `generate-nutrition-plan` Extension

**Location:** `/supabase/functions/generate-nutrition-plan/index.ts`

#### 3.1 Add Transition Phase to Request Schema (Lines 299-320)
```typescript
interface NutritionPlanRequest {
  macro_targets: {
    pre_run: MacroTargets,
    during_bike?: MacroTargets,    // NEW
    transition?: MacroTargets,     // NEW
    during_run: MacroTargets,
    post_run: MacroTargets,
  },
  activity_type?: 'running' | 'cycling' | 'swimming' | 'brick',
}
```

#### 3.2 Add Transition Phase to Response (Lines 352-368)
```typescript
{
  plan: {
    before: FoodResult[],
    during_bike?: FoodResult[],   // NEW
    transition?: FoodResult[],    // NEW
    during_run?: FoodResult[],    // Rename from "during"
    after: FoodResult[],
  }
}
```

#### 3.3 Create Brick Sport Config
**New File:** `/supabase/functions/_shared/nutrition/sport-configs/brick.ts`

```typescript
export const brickConfig: SportConfig = {
  name: 'Brick Workout',
  activityType: 'brick',

  phases: {
    before: {
      maxFoods: 4,
      defaultMaxServings: 2,
      maxServingsCap: 3,
      priorities: ['carbs', 'hydration'],
    },
    during: {
      // Use cycling rules for bike leg
      maxFoods: 5,
      defaultMaxServings: 3,
      maxServingsCap: 6,
      priorities: ['carbs', 'sodium'],
    },
    transition: {
      maxFoods: 2,           // Minimal, quick
      defaultMaxServings: 1,
      maxServingsCap: 2,
      priorities: ['carbs'], // Fast-acting carbs only
    },
    after: {
      maxFoods: 4,
      defaultMaxServings: 2,
      maxServingsCap: 3,
      priorities: ['protein', 'carbs', 'hydration'],
    },
  },

  foodOverrides: [],

  optimizationWeights: {
    before: { carbs: 1.0, protein: 0.5, sodium: 0.3 },
    during: { carbs: 1.0, sodium: 0.7 },        // Bike leg
    transition: { carbs: 1.0, sodium: 0.5 },    // Quick carbs
    after: { carbs: 0.9, protein: 0.8, sodium: 0.4 },
  },
};
```

#### 3.4 Update Sport Config Registry
**File:** `/supabase/functions/_shared/nutrition/sport-configs/index.ts`

```typescript
import { brickConfig } from './brick.ts';

const sportConfigs: SportConfigMap = {
  running: runningConfig,
  cycling: cyclingConfig,
  swimming: swimmingConfig,
  triathlon: triathlonConfig,
  duathlon: duathlonConfig,
  multisport: multisportConfig,
  brick: brickConfig,  // NEW
};
```

#### 3.5 Update Category Mapping
**File:** `/supabase/functions/_shared/nutrition/constants.ts`

```typescript
SPORT_DURING_CATEGORY = {
  running: 'during_run',
  cycling: 'during_bike',
  swimming: 'during_swim',
  triathlon: 'during_run',
  duathlon: 'during_run',
  multisport: 'during_run',
  brick: 'during_bike',        // NEW (bike leg for "during" phase)
};

function getCategoryForPhase(phase: Phase, activityType: string): string[] {
  // ... existing before/after cases

  case 'during':
    // SPECIAL CASE: Brick workouts need both bike and run categories
    if (activityType === 'brick') {
      return ['during_bike', 'during_run'];  // Allow foods suitable for either
    }

    const sportCategory = SPORT_DURING_CATEGORY[activityType] || 'during_run';
    // ... existing logic

  case 'transition':  // NEW
    return ['transition'];
}
```

#### 3.6 Update Optimization Call (Lines 346-350)
```typescript
// Handle brick workouts with separate bike/run/transition phases
if (activityType === 'brick') {
  const [before, duringBike, transition, duringRun, after] = await Promise.all([
    optimizePhase(supabase, 'before', userId, preTargets, ...),
    optimizePhase(supabase, 'during', userId, duringBikeTargets, ..., 'cycling'),  // Use cycling config
    optimizePhase(supabase, 'transition', userId, transitionTargets, ..., 'brick'),
    optimizePhase(supabase, 'during', userId, duringRunTargets, ..., 'running'),   // Use running config
    optimizePhase(supabase, 'after', userId, postTargets, ...),
  ]);

  return jsonResponse({
    plan: {
      before: before.items,
      during_bike: duringBike.items,
      transition: transition.items,
      during_run: duringRun.items,
      after: after.items,
    },
  });
}
```

### 4.4 Phase 4: Testing Strategy

#### 4.1 Unit Tests (Edge Function)
**Location:** `/supabase/functions/tests/`

```typescript
Deno.test('Brick macros calculation - bike-to-run', async () => {
  const request = {
    activity_type: 'brick',
    activities: [
      { type: 'cycling', distance_miles: 20, speed_mph: 18 },
      { type: 'running', run_distance: 5, run_pace: '8:00' }
    ],
    weight: 70,
    weight_unit: 'kg',
  };

  const response = await fetch('http://localhost:54321/functions/v1/generate-macros', {
    method: 'POST',
    body: JSON.stringify(request),
  });

  const result = await response.json();

  assert(result.success);
  assert(result.macros.transition_carbs_g > 0);
  assert(result.macros.during_bike_total_g > 0);
  assert(result.macros.during_run_total_g > 0);
});

Deno.test('Brick nutrition plan - transition foods', async () => {
  const request = {
    device_id: 'test-user-123',
    activity_type: 'brick',
    macro_targets: {
      pre_run: { carbs_g: 80, protein_g: 20, sodium_mg: 400, water_ml: 500 },
      during_bike: { carbs_g: 60, sodium_mg: 600, water_ml: 800 },
      transition: { carbs_g: 15, sodium_mg: 100, water_ml: 150 },
      during_run: { carbs_g: 45, sodium_mg: 500, water_ml: 600 },
      post_run: { carbs_g: 50, protein_g: 20, sodium_mg: 400, water_ml: 500 },
    },
  };

  const response = await fetch('http://localhost:54321/functions/v1/generate-nutrition-plan', {
    method: 'POST',
    body: JSON.stringify(request),
  });

  const result = await response.json();

  assert(result.success);
  assert(result.plan.transition.length > 0);
  assert(result.plan.transition.length <= 2);  // Max 2 foods in transition

  // Verify transition foods are quick-acting
  const transitionFoods = result.plan.transition;
  for (const food of transitionFoods) {
    assert(food.carbs_grams > 0);  // Must have carbs
  }
});
```

#### 4.2 Integration Tests (Dart)
**Location:** `/test/features/nutrition_plan/brick_nutrition_plan_test.dart`

```dart
group('Brick workout nutrition planning', () {
  test('Generate brick macros via edge function', () async {
    final request = {
      'activity_type': 'brick',
      'activities': [
        {'type': 'cycling', 'distance_miles': 20, 'speed_mph': 18},
        {'type': 'running', 'run_distance': 5, 'run_pace': '8:00'},
      ],
      'weight': 70,
      'weight_unit': 'kg',
    };

    final response = await supabase.functions.invoke(
      'generate-macros',
      body: request,
    );

    expect(response.data['success'], true);
    expect(response.data['macros']['transition_carbs_g'], greaterThan(0));
  });

  test('Generate brick nutrition plan via edge function', () async {
    final request = {
      'device_id': userId,
      'activity_type': 'brick',
      'macro_targets': {
        'pre_run': {'carbs_g': 80, 'protein_g': 20, 'sodium_mg': 400, 'water_ml': 500},
        'during_bike': {'carbs_g': 60, 'sodium_mg': 600, 'water_ml': 800},
        'transition': {'carbs_g': 15, 'sodium_mg': 100, 'water_ml': 150},
        'during_run': {'carbs_g': 45, 'sodium_mg': 500, 'water_ml': 600},
        'post_run': {'carbs_g': 50, 'protein_g': 20, 'sodium_mg': 400, 'water_ml': 500},
      },
    };

    final response = await supabase.functions.invoke(
      'generate-nutrition-plan',
      body: request,
    );

    expect(response.data['success'], true);
    expect(response.data['plan']['transition'], isNotEmpty);
    expect(response.data['plan']['transition'].length, lessThanOrEqualTo(2));
  });
});
```

---

## 5. Key Design Decisions

### 5.1 Why Not Create New Edge Functions?

**Decision:** Extend existing `generate-macros` and `generate-nutrition-plan`

**Rationale:**
1. **Code Reuse:** Brick workouts use existing running/cycling formulas
2. **Maintainability:** Single source of truth for each sport's calculations
3. **Deployment:** No new function deployments required
4. **Testing:** Existing test infrastructure covers base cases

### 5.2 Transition Phase Design

**Decision:** Treat transition as a distinct phase (not part of bike or run)

**Rationale:**
1. **Nutritional Needs:** Transition has unique requirements (quick carbs, minimal volume)
2. **Database Design:** Existing `category_enum` supports phase-based food filtering
3. **User Experience:** Separate transition guidance in UI is clearer
4. **Sport Config Pattern:** Follows existing `before`, `during`, `after` pattern

**Alternative Considered:** Include transition in bike leg "during" phase
- **Rejected:** Mixes two distinct nutritional contexts (sustained effort vs quick top-up)

### 5.3 Database vs Code Configuration

**Decision:** Store food suitability in database `categories` array, not edge function code

**Rationale:**
1. **Data-Driven:** Foods can be updated without code deployment
2. **Existing Pattern:** Current system uses `during_run`, `during_bike`, `during_swim`
3. **User Foods:** Users can tag custom foods with transition suitability
4. **A/B Testing:** Easy to test different transition food recommendations

---

## 6. Migration Checklist

### Database Schema
- [ ] Add `transition` to `category_enum` type
- [ ] Tag existing foods with `transition` category (gels, bananas, sports drinks)
- [ ] Create brick-specific test foods

### Edge Functions
- [ ] Update `generate-macros` request schema
- [ ] Implement `calculateBrickMacros()` function
- [ ] Update `generate-macros` request handler
- [ ] Create `brick.ts` sport config
- [ ] Update sport config registry
- [ ] Add transition phase to `generate-nutrition-plan`
- [ ] Update category mapping logic

### Testing
- [ ] Write edge function unit tests (Deno)
- [ ] Write Dart integration tests
- [ ] Manual testing via Supabase dashboard
- [ ] Production smoke test after deployment

### Documentation
- [ ] Update edge function API docs
- [ ] Document brick-specific request/response schemas
- [ ] Add brick workout examples
- [ ] Update sport config documentation

---

## 7. Open Questions for Human Review

1. **Transition Duration:** Default to 2 minutes or make configurable?
2. **Transition Macros Formula:** Fixed 15g carbs or scale by workout intensity?
3. **Multi-Activity Support:** Should we support >2 activities (e.g., swim-bike-run)?
4. **Backward Compatibility:** How to handle clients sending old request format?
5. **Database Migration:** Add `transition` category in production immediately or wait for full brick feature?

---

## Appendix A: Request/Response Examples

### A.1 Generate Macros - Brick Workout

**Request:**
```json
{
  "activity_type": "brick",
  "activities": [
    {
      "type": "cycling",
      "distance_miles": 20,
      "speed_mph": 18,
      "terrain": "rolling"
    },
    {
      "type": "running",
      "run_distance": 5,
      "run_pace": "8:00",
      "run_pace_unit": "min_per_mile"
    }
  ],
  "transition_duration_min": 2,
  "weight": 70,
  "weight_unit": "kg",
  "gut_training": "high",
  "temp_c": 25,
  "humidity_pct": 70
}
```

**Response:**
```json
{
  "success": true,
  "activity_type": "brick",
  "macros": {
    "duration_min": 108.67,
    "duration_h": 1.81,

    "pre_run_carbs_g": 140,
    "pre_run_protein_g_optional": 18,
    "pre_run_water_ml": 600,
    "pre_run_sodium_mg": 450,

    "during_bike_rate_g_per_h": 75,
    "during_bike_total_g": 50,
    "during_bike_water_total_ml": 600,
    "during_bike_sodium_total_mg": 500,

    "transition_carbs_g": 15,
    "transition_water_ml": 150,
    "transition_sodium_mg": 100,

    "during_run_rate_g_per_h": 60,
    "during_run_total_g": 40,
    "during_run_water_total_ml": 500,
    "during_run_sodium_total_mg": 400,

    "post_run_carbs_g": 84,
    "post_run_protein_g": 21,
    "post_run_water_ml": 1250,
    "post_run_sodium_mg": 625,

    "total_calories_kcal": 1250,
    "total_carbs_g": 105
  }
}
```

### A.2 Generate Nutrition Plan - Brick Workout

**Request:**
```json
{
  "device_id": "123e4567-e89b-12d3-a456-426614174000",
  "activity_type": "brick",
  "macro_targets": {
    "pre_run": {
      "carbs_g": 140,
      "protein_g": 18,
      "sodium_mg": 450,
      "water_ml": 600
    },
    "during_bike": {
      "carbs_g": 50,
      "sodium_mg": 500,
      "water_ml": 600
    },
    "transition": {
      "carbs_g": 15,
      "sodium_mg": 100,
      "water_ml": 150
    },
    "during_run": {
      "carbs_g": 40,
      "sodium_mg": 400,
      "water_ml": 500
    },
    "post_run": {
      "carbs_g": 84,
      "protein_g": 21,
      "sodium_mg": 625,
      "water_ml": 1250
    }
  },
  "liked_foods": ["banana", "energy_gel"],
  "willing_to_try_foods": ["trail_mix"]
}
```

**Response:**
```json
{
  "success": true,
  "plan_id": "456e7890-f12c-34e5-b678-537725285111",
  "detailed_message": "Optimized brick workout nutrition plan with sport-specific food selection.",
  "plan": {
    "before": [
      {
        "food_id": "oatmeal-uuid",
        "food_name": "Oatmeal",
        "quantity": 2,
        "carbs_grams": 120,
        "protein_grams": 16,
        "sodium_mg": 400,
        "fluids_ml": 500,
        "display_name": "Oatmeal with Berries"
      }
    ],
    "during_bike": [
      {
        "food_id": "trail-mix-uuid",
        "food_name": "Trail Mix",
        "quantity": 1,
        "carbs_grams": 30,
        "sodium_mg": 200,
        "fluids_ml": 0
      },
      {
        "food_id": "sports-drink-uuid",
        "food_name": "Sports Drink",
        "quantity": 2,
        "carbs_grams": 28,
        "sodium_mg": 300,
        "fluids_ml": 600
      }
    ],
    "transition": [
      {
        "food_id": "gel-uuid",
        "food_name": "Energy Gel",
        "quantity": 1,
        "carbs_grams": 22,
        "sodium_mg": 100,
        "fluids_ml": 150
      }
    ],
    "during_run": [
      {
        "food_id": "banana-uuid",
        "food_name": "Banana",
        "quantity": 1,
        "carbs_grams": 27,
        "sodium_mg": 1,
        "fluids_ml": 90
      },
      {
        "food_id": "water-uuid",
        "food_name": "Water",
        "quantity": 2,
        "fluids_ml": 500
      }
    ],
    "after": [
      {
        "food_id": "protein-shake-uuid",
        "food_name": "Protein Shake",
        "quantity": 1,
        "carbs_grams": 45,
        "protein_grams": 25,
        "sodium_mg": 300,
        "fluids_ml": 500
      },
      {
        "food_id": "banana-uuid",
        "food_name": "Banana",
        "quantity": 2,
        "carbs_grams": 54,
        "fluids_ml": 180
      }
    ]
  },
  "macro_targets": {
    "activity_type": "brick"
  }
}
```

---

**End of Audit**
