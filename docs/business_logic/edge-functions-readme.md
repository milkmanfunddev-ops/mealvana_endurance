# Mealvana Endurance - Edge Functions

This folder contains the TypeScript source code for Supabase Edge Functions used in the Mealvana Endurance app.

## 📋 Edge Functions

### 1. `create-user-edge-function.ts`
**Supabase Function Name**: `create-user`

**Purpose**: Server-side user creation with validation and food preferences handling.

**Features**:
- Complete user validation (device_id, gender, demographics, etc.)
- Food preferences storage in `food_preferences` table
- Conflict detection for existing users
- Comprehensive error handling
- CORS support for web/mobile clients

**Request Body**:
```json
{
  "device_id": "string",
  "gender": "male" | "female" | "other",
  "birthday": "YYYY-MM-DD",
  "height_feet": 5,
  "height_inches": 8,
  "weight_pounds": 150.0,
  "runs_with_water_bottle": true,
  "gut_training_level": "low" | "moderate" | "high",
  "app_version": "1.0.0",
  "food_preferences": {
    "Oatmeal": "like",
    "Banana sliced": "dislike",
    "Gels": "willing_to_try"
  }
}
```

**Response**:
```json
{
  "success": true,
  "user": { ... },
  "message": "User created successfully"
}
```

### 2. `create-nutrition-plan-edge-function.ts`
**Supabase Function Name**: `create-nutrition-plan`

**Purpose**: Server-side nutrition plan generation with evidence-based calculations.

**Features**:
- Complete nutrition calculations (no more algorithm parameters!)
- Food selection based on user preferences
- Evidence-based formulas for carbs, calories, hydration, sodium
- Plan storage with versioning
- User food preference integration

**Request Body**:
```json
{
  "device_id": "string",
  "distance_miles": 13.1,
  "pace_minutes_per_mile": 8.5,
  "time_before_run_hours": 2.0,
  "gut_training_level": "high"
}
```

**Response**:
```json
{
  "success": true,
  "plan": {
    "id": "plan-...",
    "name": "Personalized Nutrition Plan",
    "sections": [...],
    "macroTargets": {...}
  },
  "calculations": {
    "bodyWeightKg": 68.2,
    "met": 10.5,
    "grossCalories": 1250,
    "preRunCarbsG": 136,
    "duringCarbsPerHour": 45.0
  },
  "message": "Nutrition plan created successfully"
}
```

## 🏗️ Business Logic Algorithms

### Nutrition Calculations (Hardcoded Evidence-Based Values)

#### 1. **Unit Conversions**
- Pounds to kg: `weight_pounds * 0.45359237`
- Miles to km: `distance_miles * 1.60934`

#### 2. **MET Calculation (ACSM Running Equation)**
```typescript
const speedMph = 60.0 / pace_minutes_per_mile
const speedMPerMin = speedMph * 26.8224
const vo2 = 0.2 * speedMPerMin + 3.5
const met = vo2 / 3.5
```

#### 3. **Energy Calculations**
- Net calories: `bodyWeightKg * distanceKm * 1.0` (1 cal/kg/km)
- Gross calories: `met * bodyWeightKg * durationHours`

#### 4. **Pre-Run Carbohydrates**
- ≥1 hour before: `1-4g/kg body weight` (time-dependent)
- 15-60 min before: `0.5g/kg body weight`
- <15 min before: `0.25g/kg body weight`

#### 5. **During-Run Carbohydrates**
- Gut training multipliers: `low: 0.8, moderate: 1.0, high: 1.2`
- Mass-normalized rate: `gutMultiplier * bodyWeightKg`
- Clamped to physiological limits: `30-60g/hour`

#### 6. **Sodium Requirements**
- No supplementation for runs ≤1 hour
- Standard rate: `250mg/hour` for longer runs

#### 7. **Fluid Requirements**
- Short runs (≤1h): `400 mL/h`
- High intensity (≥8.0 MET): `800 mL/h`
- Moderate intensity (≥6.0 MET): `600 mL/h`
- Easy pace: `500 mL/h`

#### 8. **Post-Run Recovery**
- Carbohydrates: `1g/kg body weight`
- Protein: `0.2g/kg body weight`

### Food Selection Logic

#### Priority System:
1. **Liked foods in target category** (from user preferences)
2. **Liked foods from other categories** (fallback)
3. **Other foods in target category**

#### During-Run Special Logic:
- Filters out inappropriate foods (Coffee, Orange juice)
- Prioritizes gels and sports drinks
- Limits to 60% of carb target from any single food

## 📊 Database Tables Required

### Core Tables:
1. `users` - User profiles and demographics
2. `foods` - Food database with nutritional info
3. `nutrition_plans` - Generated nutrition plans
4. `food_preferences` - User food likes/dislikes

### Environment Variables:
- `SUPABASE_URL` (auto-provided)
- `SUPABASE_SERVICE_ROLE_KEY` (auto-provided)

## 🚀 Deployment Instructions

### To Supabase Dashboard:
1. Go to Supabase Dashboard → Edge Functions
2. Create function `create-user`
3. Copy/paste `create-user-edge-function.ts`
4. Create function `create-nutrition-plan`
5. Copy/paste `create-nutrition-plan-edge-function.ts`
6. Deploy both functions

### Testing:
```bash
# Test user creation
curl -X POST https://your-project.supabase.co/functions/v1/create-user \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"device_id": "test123", "gender": "other", ...}'

# Test nutrition plan creation
curl -X POST https://your-project.supabase.co/functions/v1/create-nutrition-plan \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"device_id": "test123", "distance_miles": 13.1, "pace_minutes_per_mile": 8.5}'
```

## 🎯 Benefits Achieved

- **🚀 Simplified Client Code** - No complex calculations in Flutter
- **🏗️ Consistent Business Logic** - Centralized server-side algorithms
- **🔧 No Algorithm Parameters** - Hardcoded evidence-based values
- **📊 Better Performance** - Optimized server-side processing
- **🛡️ Enhanced Security** - Business logic protected server-side
- **📱 Offline-Ready** - Works with cached data fallbacks

This represents a major architectural improvement moving from client-side complexity to clean server-side business logic! 🎉