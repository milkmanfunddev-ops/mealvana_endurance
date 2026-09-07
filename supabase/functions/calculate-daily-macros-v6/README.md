# calculate-daily-macros Edge Function

## Overview

Daily macronutrient calculator for endurance athletes. Implements a 4-iteration algorithm that calculates personalized carbohydrate, protein, and fat targets based on:

- Athlete profile (age, sex, weight, body composition)
- Today's training sessions (sport, duration, intensity zones)
- Multi-day context (recovery needs, pre-race loading, weekly training volume)
- Lifestyle factors (daily activity level, training volume tier)
- Safety guardrails (energy availability checks, carb cycling opt-in)

## Algorithm Versions

**Current: v4.0.0** (All 4 iterations implemented)

### Iteration 1: Baseline RMR, TDEE, and macros
- RMR calculation (Cunningham for athletes with BF%, Mifflin-St Jeor otherwise)
- Baseline macros: 4.0g carb/kg, 1.8g protein/kg LBM (1.4g/kg if LBM unknown)
- Session-specific adjustments: intensity factor (zone-weighted RMS), calorie cost, carb demand
- Protein bumps: +0.3g/kg for strength, +0.2g/kg for endurance >1hr
- Fat calculated as residual from TDEE with 0.8g/kg floor
- Clamped ranges: 3-12 g/kg carb, 1.2-2.5 g/kg protein

### Iteration 2: Multi-day context
- **Recovery debt**: After hard sessions (TSS ≥150), adds recovery carbs/protein that decay linearly from 18h to 36h
- **Pre-load override**: Race day or high TSS → 9.0 g/kg carb; moderate → +1.5 g/kg
- **Weekly load adjustment**: ±1.0 g/kg carb based on this week vs typical training volume
- **Training phase modifiers**: BASE/BUILD/PEAK/TAPER/RACE_WEEK/OFF_SEASON scaling

### Iteration 3: Dynamic NEAT + iterative TEF
- **Volume tier inference**: Maps weekly hours to athlete tier (Recreational → Professional)
- **Day type modifier**: Double session/training/rest-after-hard/rest
- **Lifestyle modifier**: Desk/Mixed/Active/Very Active
- **Iterative TEF**: Solves circular dependency between TDEE, fat, and thermic effect via convergent iteration

### Iteration 4: Safety + edge cases
- **Energy Availability gate**: Calculates EA = (intake - exercise) / FFM. Blocks plans <20, overrides 20-30, warns 30-45
- **Multi-session carb compounding**: Each subsequent endurance session gets 1.1^n multiplier
- **Carb cycling opt-in**: "Train low" on qualifying easy days (IF ≤0.80, duration ≤75min, not PEAK/RACE_WEEK)
- **Masters adjustment**: Protein ×1.15 for athletes 45+

## API

### Endpoint
```
POST /calculate-daily-macros
```

### Request Body

```typescript
{
  // Required athlete profile
  sex: 'male' | 'female',
  age: number,
  weight_kg: number,
  height_cm: number,

  // Optional profile
  body_fat_pct?: number,           // If provided, uses Cunningham RMR + accurate FFM
  lifestyle?: 'desk' | 'mixed' | 'active' | 'very_active',
  typical_weekly_hours?: number,   // Average training hours/week
  carb_cycle_opt_in?: boolean,     // Enable train-low carb cycling
  training_phase?: 'base' | 'build' | 'peak' | 'taper' | 'race_week' | 'off_season',

  // Sessions (zero or more)
  sessions: [
    {
      sport: 'running' | 'cycling' | 'swimming' | 'strength',
      duration_hr: number,
      pct_conversational: number,  // 0-1, Z1-Z2
      pct_tempo: number,            // 0-1, Z3-Z4
      pct_allout: number,           // 0-1, Z5+
      tss?: number                  // Optional TSS value
    }
  ],

  // Multi-day context (optional)
  yesterday_tss?: number,
  yesterday_hours_since?: number,
  tomorrow_tss?: number,
  tomorrow_duration_hr?: number,
  tomorrow_is_race?: boolean,
  weekly_hours_ratio?: number,     // This week / typical week

  // System
  mode?: 'prospective' | 'retrospective'  // Default: prospective
}
```

**Validation rules:**
- Zone percentages must sum to 1.0 (±0.001 tolerance)
- All numeric fields must be positive and within reasonable bounds
- At least one of `body_fat_pct`, `lifestyle`, or `typical_weekly_hours` recommended for accurate results

### Response

```typescript
{
  carb_g: number,
  prot_g: number,
  fat_g: number,
  tdee: number,
  rmr: number,
  session_kcal: number,
  neat_kcal: number,
  tef_kcal: number,
  mode: string,
  ea: number | null,              // Energy Availability (kcal/kg FFM)
  ea_status: string | null,       // 'OK' | 'SOFT_WARNING' | 'HARD_WARNING' | 'BLOCK'
  algorithm_version: string
}
```

### Error Responses

```typescript
// Validation error (400)
{
  success: false,
  error: "Validation error message",
  details?: string
}

// Energy Availability block (500)
{
  success: false,
  error: "Energy Availability too low (14.1 kcal/kg FFM). Cannot generate plan..."
}
```

## Example Usage

### Rest Day
```bash
curl -X POST https://your-project.supabase.co/functions/v1/calculate-daily-macros \
  -H "Content-Type: application/json" \
  -d '{
    "sex": "male",
    "age": 34,
    "weight_kg": 75,
    "height_cm": 178,
    "body_fat_pct": 14.7,
    "lifestyle": "desk",
    "typical_weekly_hours": 10,
    "training_phase": "base",
    "sessions": []
  }'
```

Response:
```json
{
  "carb_g": 300,
  "prot_g": 115,
  "fat_g": 93,
  "tdee": 2501,
  "rmr": 1908,
  "session_kcal": 0,
  "neat_kcal": 343,
  "tef_kcal": 250,
  "mode": "prospective",
  "ea": 39.1,
  "ea_status": "SOFT_WARNING",
  "algorithm_version": "v4.0.0"
}
```

### Hard Training Day
```bash
curl -X POST https://your-project.supabase.co/functions/v1/calculate-daily-macros \
  -H "Content-Type: application/json" \
  -d '{
    "sex": "male",
    "age": 34,
    "weight_kg": 75,
    "height_cm": 178,
    "body_fat_pct": 14.7,
    "lifestyle": "desk",
    "typical_weekly_hours": 10,
    "training_phase": "base",
    "sessions": [
      {
        "sport": "running",
        "duration_hr": 1.5,
        "pct_conversational": 0.70,
        "pct_tempo": 0.20,
        "pct_allout": 0.10,
        "tss": 95
      }
    ]
  }'
```

Response:
```json
{
  "carb_g": 369,
  "prot_g": 130,
  "fat_g": 209,
  "tdee": 3879,
  "rmr": 1908,
  "session_kcal": 1205,
  "neat_kcal": 378,
  "tef_kcal": 388,
  "mode": "prospective",
  "ea": 41.8,
  "ea_status": "SOFT_WARNING",
  "algorithm_version": "v4.0.0"
}
```

### Pre-Race Carb Loading
```bash
curl -X POST https://your-project.supabase.co/functions/v1/calculate-daily-macros \
  -H "Content-Type: application/json" \
  -d '{
    "sex": "male",
    "age": 34,
    "weight_kg": 75,
    "height_cm": 178,
    "body_fat_pct": 14.7,
    "lifestyle": "desk",
    "typical_weekly_hours": 10,
    "training_phase": "peak",
    "sessions": [
      {
        "sport": "running",
        "duration_hr": 1.0,
        "pct_conversational": 0.80,
        "pct_tempo": 0.20,
        "pct_allout": 0,
        "tss": 75
      }
    ],
    "yesterday_tss": 220,
    "yesterday_hours_since": 20,
    "tomorrow_is_race": true,
    "weekly_hours_ratio": 1.25
  }'
```

Response:
```json
{
  "carb_g": 798,
  "prot_g": 159,
  "fat_g": 60,
  "tdee": 3773,
  "rmr": 1908,
  "session_kcal": 1050,
  "neat_kcal": 378,
  "tef_kcal": 437,
  "mode": "prospective",
  "ea": 42.6,
  "ea_status": "SOFT_WARNING",
  "algorithm_version": "v4.0.0"
}
```

## File Structure

```
calculate-daily-macros/
├── index.ts                    # Main handler + pipeline orchestration
├── index.test.ts              # Comprehensive test suite (all iterations)
├── types.ts                   # TypeScript interfaces
├── README.md                  # This file
└── formulas/
    ├── rmr.ts                 # RMR calculation (Cunningham/Mifflin-St Jeor)
    ├── session.ts             # Session processing (IF, calorie cost, carb demand)
    ├── baseline.ts            # Baseline macros + protein bumps + clamping
    ├── multi-day.ts           # Recovery debt, pre-load, weekly load, phase modifiers
    ├── neat-tef.ts            # Dynamic NEAT + iterative TEF (Iteration 3)
    └── safety.ts              # EA checks, multi-session compounding, carb cycling
```

## Testing

Run the test suite with Deno:

```bash
cd supabase/functions/calculate-daily-macros
deno test --allow-all index.test.ts
```

Test coverage:
- **Iteration 1**: RMR, zone-to-IF, session cost, carb demand, baseline macros (17 tests)
- **Iteration 2**: Recovery debt, pre-load, weekly load, phase modifiers (16 tests)
- **Iteration 3**: Volume tiers, day types, NEAT, TDEE convergence (12 tests)
- **Iteration 4**: FFM, EA checks, EA override, carb cycling (13 tests)

Total: **58 unit tests**

Tolerances:
- Carb/protein: ±5%
- Fat: ±15% (due to TDEE residual calculation)
- TDEE: ±5%
- EA: ±1.0 kcal/kg FFM

## References

### Specifications
- `/docs/features/macro_calculations/iteration1_spec.txt` + `iteration1_tests.txt`
- `/docs/features/macro_calculations/iteration2_tests.txt` (spec corrupted, formulas in v1_readme.txt)
- `/docs/features/macro_calculations/iteration3_spec.txt` + `iteration3_tests.txt`
- `/docs/features/macro_calculations/iteration4_spec.txt` + `iteration4_tests.txt`
- `/docs/features/macro_calculations/v1_readme.txt` (iterations 1-2)
- `/docs/features/macro_calculations/v2_readme.txt` (iterations 3-4)

### Scientific References
- Cunningham RMR: `500 + 22 × LBM_kg`
- Mifflin-St Jeor: `10×weight + 6.25×height - 5×age + sex_offset`
- Energy Availability thresholds: Mountjoy et al. (2014) RED-S consensus
- Zone-weighted IF: Power-based training principles (Coggan/Allen)
- TEF = 10% of total intake: Standard thermic effect of food

## Deployment

Deploy with Supabase CLI:

```bash
supabase functions deploy calculate-daily-macros
```

The function uses shared CORS and response helpers from `../_shared/`.

## Version History

- **v4.0.0** (2026-03-25): Initial implementation with all 4 iterations
  - Iteration 1: Baseline RMR, TDEE, macros
  - Iteration 2: Multi-day context
  - Iteration 3: Dynamic NEAT + iterative TEF
  - Iteration 4: Safety (EA, compounding, carb cycling)
