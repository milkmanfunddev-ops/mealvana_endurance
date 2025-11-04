# Cycling & Swimming Implementation Roadmap

## Overview

This roadmap provides a step-by-step implementation plan for adding cycling and swimming support to Mealvana Endurance. Tasks are organized by priority and dependencies to ensure smooth development.

**Total Estimated Timeline:** 7-10 weeks
**Team Size Assumption:** 1 developer
**Current Status:** Documentation Complete ✅

---

## Phase 1: Foundation & Research ✅ COMPLETE

### 1.1 Requirements Gathering ✅
- [x] Research cycling nutrition formulas
- [x] Research swimming nutrition formulas
- [x] Analyze ChatGPT research documents
- [x] Review UI mockups/screenshots
- [x] Identify shared vs sport-specific logic

### 1.2 Architecture Decisions ✅
- [x] Decision: Unified edge functions with `activity_type` parameter
- [x] Decision: Explicit nullable columns for sport-specific fields
- [x] Decision: Sport-agnostic UI with ContentService dynamic text
- [x] Decision: Full formulas (Option A) for cycling/swimming
- [x] Decision: Stay on v1 schema (no migration)
- [x] Decision: Deploy to dev first, then full production release

### 1.3 Documentation Creation ✅
- [x] Create README.md with comprehensive requirements
- [x] Create roadmap.md (this document)
- [ ] Create formulas.md with sport-specific calculations
- [ ] Create edge-functions.md with technical specs
- [ ] Create database-schema.md with v1 updates

**Estimated Duration:** 3-5 days
**Status:** ✅ COMPLETE

---

## Phase 2: Database Schema Updates (v1 Expansion) ✅ COMPLETE

**Priority:** CRITICAL (Blocking)
**Estimated Duration:** 3-5 days
**Status:** ✅ COMPLETE (2025-10-15)

### 2.1 Update Drift Schema ✅
**Files to modify:**
- `lib/shared/database/tables/activities_table.dart`
- `lib/shared/database/tables/user_profiles_table.dart` (or users table)
- `lib/shared/database/app_database.dart`

**Tasks:**
1. Add cycling-specific columns to `ActivitiesTable`:
   ```dart
   // Cycling-specific
   RealColumn get cyclingSpeedMph => real().nullable().named('cycling_speed_mph')();
   TextColumn get cyclingTerrain => text().nullable().named('cycling_terrain')();
   TextColumn get cyclingIndoorOutdoor => text().nullable().named('cycling_indoor_outdoor')();
   IntColumn get cyclingElevationGainFt => integer().nullable().named('cycling_elevation_gain_ft')();
   TextColumn get cyclingSessionGoal => text().nullable().named('cycling_session_goal')();
   ```

2. Add swimming-specific columns to `ActivitiesTable`:
   ```dart
   // Swimming-specific
   IntColumn get swimmingPacePer100mSeconds => integer().nullable().named('swimming_pace_per_100m_seconds')();
   TextColumn get swimmingPoolOrOpenWater => text().nullable().named('swimming_pool_or_open_water')();
   RealColumn get swimmingWaterTempC => real().nullable().named('swimming_water_temp_c')();
   ```

3. Add shared intensity and timing columns:
   ```dart
   TextColumn get intensityTarget => text().nullable().named('intensity_target')();
   IntColumn get timeBeforeMinutes => integer().nullable().named('time_before_minutes')();
   ```

4. Update check constraints:
   ```dart
   @override
   List<String> get customConstraints => [
     "CHECK (activity_type IN ('running', 'cycling', 'swimming'))",
     "CHECK (cycling_terrain IS NULL OR cycling_terrain IN ('flat', 'rolling', 'hilly'))",
     "CHECK (cycling_indoor_outdoor IS NULL OR cycling_indoor_outdoor IN ('indoor', 'outdoor'))",
     "CHECK (cycling_session_goal IS NULL OR cycling_session_goal IN ('endurance', 'tempo', 'intervals'))",
     "CHECK (swimming_pool_or_open_water IS NULL OR swimming_pool_or_open_water IN ('pool', 'open_water'))",
     // ... existing constraints
   ];
   ```

5. Add sport-specific preferences to `UserProfiles` table:
   ```dart
   // Cycling preferences
   IntColumn get ftpWatts => integer().nullable().named('ftp_watts')();
   IntColumn get typicalBikeBottles => integer().nullable().named('typical_bike_bottles')();
   BoolColumn get hasAeroBottle => boolean().nullable().named('has_aero_bottle')();
   BoolColumn get hasBentoBox => boolean().nullable().named('has_bento_box')();

   // Swimming preferences
   IntColumn get cssPacePer100mSeconds => integer().nullable().named('css_pace_per_100m_seconds')();
   BoolColumn get typicalWetsuit => boolean().nullable().named('typical_wetsuit')();
   TextColumn get typicalSwimCapType => text().nullable().named('typical_swim_cap_type')();

   // Shared
   BoolColumn get giSensitivity => boolean().nullable().named('gi_sensitivity')();
   ```

6. Run code generation:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

7. Generate schema snapshot for v1:
   ```bash
   dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v1/
   ```

### 2.2 Update Supabase Schema (Dev Environment)
**Files to create:**
- `supabase/migrations/YYYYMMDDHHMMSS_add_cycling_swimming_support.sql`

**Tasks:**
1. Create migration SQL file with:
   - ALTER TABLE activities ADD COLUMN ... (cycling columns)
   - ALTER TABLE activities ADD COLUMN ... (swimming columns)
   - ALTER TABLE users ADD COLUMN ... (sport-specific preferences)
   - **ALTER TABLE foods ADD COLUMN suitable_for_activities** (NEW - sport-specific food suitability)
   - **ALTER TABLE user_foods ADD COLUMN suitable_for_activities** (NEW)
   - Add check constraints

2. **Seed food suitability data**:
   - Default all existing foods to `'["running", "cycling", "swimming"]'` (backward compatible)
   - Update specific foods for sport restrictions:
     - Energy gels → all sports
     - Solid foods (bananas, bars) → exclude swimming during
     - Heavy solids (sandwiches, rice cakes) → cycling only during
   - Add new cycling-specific foods (rice cakes, stroopwafels, mini sandwiches)

3. Test migration on local Supabase:
   ```bash
   supabase db reset
   ```

4. Deploy to dev Supabase:
   ```bash
   supabase db push --linked --project-ref <dev-project-ref>
   ```

### 2.3 Update Domain Models
**Files to create:**
- `lib/features/nutrition_plan/domain/cycling_parameters.dart`
- `lib/features/nutrition_plan/domain/swimming_parameters.dart`

**Files to update:**
- `lib/features/nutrition_plan/domain/run_parameters.dart` (ensure consistency)

**Example `CyclingParameters` model:**
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cycling_parameters.freezed.dart';
part 'cycling_parameters.g.dart';

@freezed
class CyclingParameters with _$CyclingParameters {
  const factory CyclingParameters({
    required double distanceMiles,
    required double speedMph,
    required int durationMinutes,
    required String intensityTarget,
    required String sessionGoal,
    required String terrain,
    required String indoorOutdoor,
    required int elevationGainFt,
    required int timeBeforeMinutes,
    required double temperatureC,
    required double humidityPct,
    required String windCondition,
    required String sunExposure,
  }) = _CyclingParameters;

  factory CyclingParameters.fromJson(Map<String, dynamic> json) =>
    _$CyclingParametersFromJson(json);
}
```

### 2.4 Seed Food Suitability Data (NEW)
**Files to create:**
- `supabase/migrations/YYYYMMDDHHMMSS_seed_food_suitability.sql`

**Tasks:**
1. **Default all existing foods to universal suitability:**
   ```sql
   -- Ensure all existing foods are backward compatible
   UPDATE foods
   SET suitable_for_activities = '["running", "cycling", "swimming"]'::jsonb
   WHERE suitable_for_activities IS NULL;

   UPDATE user_foods
   SET suitable_for_activities = '["running", "cycling", "swimming"]'::jsonb
   WHERE suitable_for_activities IS NULL;
   ```

2. **Restrict solid foods from swimming during category:**
   ```sql
   -- Bananas: Great for cycling/running, impractical during swimming
   UPDATE foods
   SET suitable_for_activities = '["running", "cycling"]'::jsonb
   WHERE name ILIKE '%banana%'
   AND EXISTS (
     SELECT 1 FROM food_categories fc
     JOIN categories c ON fc.category_id = c.id
     WHERE fc.food_id = foods.id AND c.name = 'during_run'
   );

   -- Energy bars: Cycling/running only during
   UPDATE foods
   SET suitable_for_activities = '["running", "cycling"]'::jsonb
   WHERE product_type_id IN (SELECT id FROM product_types WHERE name ILIKE '%bar%')
   AND EXISTS (
     SELECT 1 FROM food_categories fc
     JOIN categories c ON fc.category_id = c.id
     WHERE fc.food_id = foods.id AND c.name = 'during_run'
   );
   ```

3. **Restrict heavy solids to cycling only:**
   ```sql
   -- Sandwiches, rice cakes: Cycling only
   UPDATE foods
   SET suitable_for_activities = '["cycling"]'::jsonb
   WHERE (name ILIKE '%sandwich%' OR name ILIKE '%rice cake%' OR name ILIKE '%stroopwafel%')
   AND EXISTS (
     SELECT 1 FROM food_categories fc
     JOIN categories c ON fc.category_id = c.id
     WHERE fc.food_id = foods.id AND c.name = 'during_run'
   );
   ```

4. **Keep universal foods (gels, drinks, chews):**
   ```sql
   -- Energy gels, sports drinks, chews remain universal
   UPDATE foods
   SET suitable_for_activities = '["running", "cycling", "swimming"]'::jsonb
   WHERE product_type_id IN (
     SELECT id FROM product_types
     WHERE name IN ('Energy Gel', 'Sports Drink', 'Energy Chew', 'Electrolyte Drink')
   );
   ```

5. **Add new cycling-specific foods (optional enhancement):**
   ```sql
   -- Rice cakes (popular with cyclists)
   INSERT INTO foods (id, name, display_name, ...)
   VALUES (gen_random_uuid(), 'Rice Cake with Honey', 'Rice Cake', ...)
   ON CONFLICT DO NOTHING;

   -- Stroopwafels (Dutch cycling tradition)
   INSERT INTO foods (id, name, display_name, ...)
   VALUES (gen_random_uuid(), 'Stroopwafel', 'Stroopwafel', ...)
   ON CONFLICT DO NOTHING;
   ```

6. **Test food filtering:**
   ```sql
   -- Test query: Get cycling foods for during phase
   SELECT name, suitable_for_activities
   FROM foods
   WHERE suitable_for_activities @> '["cycling"]'::jsonb
   AND id IN (SELECT food_id FROM food_categories WHERE category_id = (SELECT id FROM categories WHERE name = 'during_run'));
   ```

**Deliverables:**
- ✅ Updated Drift schema with new columns (activities_table, user_profiles, foods_table, user_foods_table)
- ✅ Generated Dart code from build_runner
- ✅ Updated v1 schema snapshot in database_schemas/v1/
- ✅ Supabase migration file created (`20251015000000_add_cycling_swimming_support.sql`)
- ✅ Old migrations archived in `_archive/` folder for reference
- ✅ Migration README.md created for local dev setup
- ✅ **Food suitability schema added (suitable_for_activities column)**
- ✅ **Schema version remains v1 (no migration logic for active development)**

**Acceptance Criteria:**
- ✅ Drift tables updated with cycling/swimming columns
- ✅ User profiles table updated with FTP/CSS preferences
- ✅ Foods and user_foods tables support sport-specific suitability
- ✅ Schema snapshot matches actual database structure
- ⏳ Can insert cycling activity with all sport-specific fields (Phase 4)
- ⏳ Can insert swimming activity with all sport-specific fields (Phase 4)
- ⏳ **Food queries correctly filter by activity type** (Phase 3 - Edge Functions)
- ⏳ **Cyclists get solid food options in nutrition plans** (Phase 3)
- ⏳ **Swimmers don't get impractical foods during swim** (Phase 3)

---

## Phase 3: Edge Function Refactoring ✅ COMPLETE

**Priority:** CRITICAL (Blocking for nutrition generation)
**Estimated Duration:** 1.5-2 weeks
**Status:** ✅ COMPLETE (2025-10-15)

### 3.1 Rename Existing Edge Functions ✅
**Tasks:**
1. ✅ Rename `generate-ai-nutrition-plan` folder to `generate-nutrition-plan`
2. ✅ Update all references in code
3. ✅ Update supabase function deploy scripts

### 3.2 Update `generate-macros` Edge Function ✅
**File:** `supabase/functions/generate-macros/index.ts`

**Tasks:**
1. **Add `activity_type` parameter validation:**
   ```typescript
   interface MacroRequest {
     activity_type: 'running' | 'cycling' | 'swimming';
     weight: number;
     weight_unit: 'kg' | 'lb';
     // ... existing fields

     // Cycling-specific (optional)
     cycling_distance_miles?: number;
     cycling_speed_mph?: number;
     cycling_terrain?: 'flat' | 'rolling' | 'hilly';
     cycling_indoor_outdoor?: 'indoor' | 'outdoor';
     cycling_elevation_gain_ft?: number;

     // Swimming-specific (optional)
     swimming_distance_meters?: number;
     swimming_pace_per_100m_seconds?: number;
     swimming_pool_or_open_water?: 'pool' | 'open_water';
     swimming_water_temp_c?: number;
   }
   ```

2. **Extract existing running logic into separate function:**
   ```typescript
   function calculateRunningMacros(params: RunningParams): MacroOutput {
     // Existing computeRunFueling logic stays EXACTLY as-is
     return computeRunFueling(params);
   }
   ```

3. **Create new cycling calculation function:**
   ```typescript
   function calculateCyclingMacros(params: CyclingParams): MacroOutput {
     // Implement cycling formulas (see formulas.md)
     // - Calculate MET from speed
     // - Calculate energy expenditure
     // - Calculate carb needs (30-90 g/h based on duration)
     // - Calculate hydration (0.5-0.75 L/h higher than running due to airflow)
     // - Calculate sodium (same as running for duration)
     return {
       duration_min, duration_h,
       calories_net_kcal, calories_gross_kcal,
       MET,
       pre_run_carbs_g, // Generic naming even for cycling
       during_rate_g_per_h, during_total_g,
       pre_run_water_ml, during_water_rate_ml_per_h,
       pre_run_sodium_mg, during_sodium_rate_mg_per_h,
       post_run_carbs_g, post_run_protein_g,
       // ... etc
     };
   }
   ```

4. **Create new swimming calculation function:**
   ```typescript
   function calculateSwimmingMacros(params: SwimmingParams): MacroOutput {
     // Implement swimming formulas (see formulas.md)
     // - Calculate MET from pace/intensity
     // - Calculate energy expenditure (higher per km than running)
     // - Calculate carb needs (30-60 g/h, harder to consume while swimming)
     // - Calculate hydration (0.4-0.8 L/h, often missed by athletes)
     // - Calculate sodium (swimmers still sweat!)
     return { /* ... */ };
   }
   ```

5. **Update main request handler with sport routing:**
   ```typescript
   serve(async (req) => {
     const requestData = await req.json();
     const { activity_type } = requestData;

     let macros: MacroOutput;

     switch (activity_type) {
       case 'running':
         macros = calculateRunningMacros(requestData);
         break;
       case 'cycling':
         macros = calculateCyclingMacros(requestData);
         break;
       case 'swimming':
         macros = calculateSwimmingMacros(requestData);
         break;
       default:
         return errorResponse('Invalid activity_type');
     }

     return successResponse(macros);
   });
   ```

6. ✅ **Write comprehensive tests:**
   - ✅ `test/local_edge_functions/functions/generate-macros/cycling-macros.test.ts` - 41 cycling tests (all passing)
   - ✅ `test/local_edge_functions/functions/generate-macros/swimming-macros.test.ts` - 42 swimming tests (all passing)
   - ✅ TDD approach: Tests written first, then implementations added

### 3.3 Update `generate-nutrition-plan` Edge Function ✅
**File:** `supabase/functions/generate-nutrition-plan/index.ts`

**Tasks:**
1. **Add `activity_type` parameter to request interface:**
   ```typescript
   interface NutritionPlanRequest {
     activity_type: 'running' | 'cycling' | 'swimming';
     device_id: string;
     macro_targets: {
       pre_run: MacroTargets;  // Keep generic "run" naming for now
       during_run: MacroTargets;
       post_run: MacroTargets;
     };
     liked_foods: string[];
     willing_to_try_foods: string[];
     disliked_foods: string[];
   }
   ```

2. **Update food filtering to include activity suitability (CRITICAL NEW FEATURE):**
   ```typescript
   async function getFoodsForPhase(
     supabase,
     phase: 'before' | 'during' | 'after',
     activityType: 'running' | 'cycling' | 'swimming',
     deviceId: string,
     likedFoods: Set<string>,
     willTryFoods: Set<string>,
     dislikedFoods: Set<string>
   ) {
     // Get generic foods for this phase
     const { data: foods } = await supabase
       .from('foods')
       .select('*')
       .eq('category', getCategoryForPhase(phase))
       .contains('suitable_for_activities', [activityType]); // ← NEW FILTER

     // Get user foods for this phase (also filter by activity)
     const { data: userFoods } = await supabase
       .from('user_foods')
       .select('*')
       .eq('device_id', deviceId)
       .eq('is_deleted', false)
       .contains('suitable_for_activities', [activityType]); // ← NEW FILTER

     // ... rest of logic (preferences, essential foods, etc.)
   }
   ```

3. **Update food timing labels based on activity type:**
   ```typescript
   function getTimingLabel(phase: 'before' | 'during' | 'after', activityType: string): string {
     const labels = {
       before: {
         running: '2-3 hours before',
         cycling: '2-3 hours before',
         swimming: '2-3 hours before',
       },
       during: {
         running: 'Throughout run',
         cycling: 'On the bike',
         swimming: 'At feed stops (if applicable)',
       },
       after: {
         running: 'Within 30 minutes',
         cycling: 'Within 30 minutes',
         swimming: 'Within 30 minutes',
       },
     };
     return labels[phase][activityType];
   }
   ```

4. **Update LP solver constraints for cycling:**
   - Cyclists can tolerate more solid foods during activity
   - Increase max servings for "during" phase from 4 to 5
   - Allow slightly higher sodium concentrations (cycling = less GI distress than running)

5. **Update LP solver constraints for swimming:**
   - Swimmers have very limited during-workout options
   - For pool swims <90min: Focus on pre-swim fueling
   - For open water/long swims: Ensure high-carb liquids only for during phase
   - Post-swim: Prioritize fast-absorbing carbs + protein

5. ✅ **Write comprehensive tests:**
   - ✅ Sport-specific food filtering verified
   - ✅ Business logic tests (food preferences, essential foods)
   - ✅ LP solver tests (linear programming optimization)
   - ⏳ Full integration tests deferred to Phase 9

### 3.4 Deploy Edge Functions to Dev Environment ✅
**Tasks:**
1. ✅ Deploy `generate-macros` to dev:
   ```bash
   supabase functions deploy generate-macros
   ```
   **Deployed to:** vlmtsdzpnjnavdgytcmi.supabase.co

2. ✅ Deploy `generate-nutrition-plan` to dev:
   ```bash
   supabase functions deploy generate-nutrition-plan
   ```
   **Deployed to:** vlmtsdzpnjnavdgytcmi.supabase.co

3. ✅ Test end-to-end in dev:
   - ✅ Running: 80 min, MET 12.5, 57g carbs (backward compatible)
   - ✅ Cycling: 120 min, MET 17.6, 110g carbs
   - ✅ Swimming: 100 min, MET 10, 75g carbs
   - ✅ E2E test file: `test/local_edge_functions/e2e-multi-sport-test.ts`

**Deliverables:**
- ✅ Refactored `generate-macros` with multi-sport support
- ✅ Refactored `generate-nutrition-plan` with multi-sport support
- ✅ Comprehensive test suite (83 tests: 41 cycling + 42 swimming, all passing)
- ✅ Edge functions deployed to dev environment
- ✅ End-to-end testing in dev completed successfully
- ✅ Phase 3 deployment summary: `/docs/features/cycling_swimming/phase3-deployment-summary.md`

**Acceptance Criteria:**
- ✅ Running macros calculation produces identical results to before refactor
- ✅ Cycling macros calculation uses correct MET values
- ✅ Swimming macros calculation accounts for high energy cost
- ✅ All edge function tests pass (83/83)
- ✅ Dev deployment successful with no errors
- ✅ Backward compatibility maintained (defaults to 'running')

---

## Phase 4: Domain Models & Repositories ✅ COMPLETE

**Priority:** HIGH (Required before controllers/UI)
**Estimated Duration:** 3-5 days
**Status:** ✅ COMPLETE (2025-10-15)

### 4.1 Create Domain Models ✅
**Files created:**
- ✅ `lib/features/nutrition_plan/domain/cycling_parameters.dart` - Plain Dart class (NOT freezed)
- ✅ `lib/features/nutrition_plan/domain/swimming_parameters.dart` - Plain Dart class (NOT freezed)

**Tasks:**
1. ✅ Define `CyclingParameters` using plain Dart class pattern (matching `RunParameters`)
2. ✅ Define `SwimmingParameters` using plain Dart class pattern (matching `RunParameters`)
3. ✅ Manual `copyWith()`, `toJson()`, `fromJson()` methods (NO code generation needed)

**Architecture Decision:**
- ❌ **NOT using freezed or json_serializable** - Project uses plain Dart classes
- ✅ Consistent with existing `RunParameters` pattern
- ✅ Manual copyWith/toJson/fromJson for full control

### 4.2 Update Repository Layer ✅
**Files updated:**
- ✅ `lib/features/calendar/application/calendar_service.dart` (acts as repository)
- ✅ `lib/features/auth/data/user_repository.dart`
- ✅ `lib/shared/database/app_database.dart`

**Tasks:**
1. ✅ **Update `CalendarService` (Activity Repository):**
   - ✅ Added method: `createCyclingActivity()`
   - ✅ Added method: `createSwimmingActivity()`
   - ✅ Existing methods already support sport-specific data retrieval

2. ✅ **Update `UserRepository` (User Preferences):**
   - ✅ Added method: `saveCyclingPreferences()`
   - ✅ Added method: `saveSwimmingPreferences()`
   - ✅ Added method: `saveGISensitivity()`
   - ✅ All methods include Sentry error tracking

3. ✅ **Update `AppDatabase` (Data Layer):**
   - ✅ Added method: `updateCyclingPreferences()`
   - ✅ Added method: `updateSwimmingPreferences()`
   - ✅ Added method: `updateGISensitivity()`
   - ✅ Proper Drift companion syntax with nullable values

**Deliverables:**
- ✅ Cycling and swimming domain models created (plain Dart)
- ✅ Repository methods added for multi-sport support
- ✅ No code generation needed (plain Dart classes)
- ⏳ Unit tests for repository methods (deferred to Phase 9)

**Acceptance Criteria:**
- ✅ Can create cycling activity via CalendarService
- ✅ Can create swimming activity via CalendarService
- ✅ Can save cycling preferences via UserRepository
- ✅ Can save swimming preferences via UserRepository
- ✅ Can update GI sensitivity via UserRepository
- ⏳ All repository tests pass (Phase 9)

---

## Phase 5: Application Layer (Services & Controllers) - REVISED APPROACH ✅ COMPLETE

**Priority:** HIGH (Required before UI)
**Estimated Duration:** 1-2 days (REDUCED from 5-7 days)
**Status:** ✅ COMPLETE (2025-10-15)

### 🔄 **ARCHITECTURE DECISION: Unified Service Pattern**

After reviewing the existing implementation, we're using a **unified service approach** instead of creating separate sport-specific services. This follows DRY principles and leverages the multi-sport edge functions from Phase 3.

**Why This Approach:**
- ✅ Edge functions already accept `activity_type` parameter (Phase 3)
- ✅ Existing `NutritionPlanService` and `DistancePageGutEntryController` follow this pattern
- ✅ Avoids code duplication across 3 sports
- ✅ Single source of truth for error handling, analytics, logging
- ✅ Easier maintenance and testing

### 5.1 Extend Existing Service (NOT Create New Services)
**Files to update (NOT create):**
- `lib/features/nutrition_plan/application/nutrition_plan_service.dart`

**Tasks:**
1. ❌ ~~Create separate `CyclingNutritionService`~~ - NOT NEEDED
2. ❌ ~~Create separate `SwimmingNutritionService`~~ - NOT NEEDED
3. ❌ ~~Create `MultiSportCalendarService`~~ - CalendarService already handles this
4. ✅ **Extend `NutritionPlanService` with sport-aware methods:**
   ```dart
   /// Generate macros for any activity type (running, cycling, swimming)
   Future<MacroTargets> generateMacrosForActivity({
     required String activityType, // 'running', 'cycling', 'swimming'
     required Map<String, dynamic> parameters,
   }) async {
     final requestData = {
       'activity_type': activityType,
       ...parameters,
     };

     final response = await supabase.functions.invoke('generate-macros', body: requestData);
     // Parse and return MacroTargets
   }

   /// Generate nutrition plan for any activity type
   Future<NutritionPlan> generateNutritionPlanForActivity({
     required String activityType,
     required MacroTargets macroTargets,
   }) async {
     // Call generate-nutrition-plan with activity_type parameter
   }
   ```

### 5.2 Extend Existing Controller (NOT Create New Controllers)
**Files to update (NOT create):**
- `lib/features/nutrition_plan/presentation/providers/distance_page_gut_entry_controller.dart`

**Tasks:**
1. ❌ ~~Create separate `CyclingInputController`~~ - NOT NEEDED
2. ❌ ~~Create separate `SwimmingInputController`~~ - NOT NEEDED
3. ❌ ~~Create separate `ActivityCreationController`~~ - Already exists in calendar feature
4. ✅ **Extend `DistancePageGutEntryController` with sport-aware methods:**
   ```dart
   /// Generate cycling macros (follows same pattern as existing generateMacros)
   Future<void> generateCyclingMacros({
     required double distanceMiles,
     required double speedMph,
     required String terrain,
     required String indoorOutdoor,
     // ... other params
   }) async {
     // Same structure as generateMacros() but calls with activity_type='cycling'
   }

   /// Generate swimming macros
   Future<void> generateSwimmingMacros({
     required int distanceMeters,
     required int paceSecondsper100m,
     required String poolOrOpenWater,
     // ... other params
   }) async {
     // Same structure as generateMacros() but calls with activity_type='swimming'
   }
   ```

**Architecture Pattern:**
```dart
// UNIFIED APPROACH (What we're doing)
NutritionPlanService
  ├─ generateMacrosForActivity(activityType, params) // Works for all sports
  ├─ generateNutritionPlanForActivity(activityType, macroTargets)
  └─ [existing running methods stay unchanged]

// INSTEAD OF SEPARATE SERVICES (What roadmap originally suggested)
CyclingNutritionService ❌
SwimmingNutritionService ❌
RunningNutritionService ❌
```

**Deliverables:**
- ✅ Extended `NutritionPlanService` with multi-sport support
  - ✅ Added `generateNutritionPlanForActivity()` method accepting `activity_type` parameter
  - ✅ Forwards to existing methods with validation and Sentry tracking
- ✅ Extended `DistancePageGutEntryController` with cycling/swimming methods
  - ✅ Added `generateCyclingMacros()` - Calls generate-macros edge function with activity_type='cycling'
  - ✅ Added `generateSwimmingMacros()` - Calls generate-macros edge function with activity_type='swimming'
  - ✅ Added `_generateCyclingMacroTargets()` - Internal method with full request handling
  - ✅ Added `_generateSwimmingMacroTargets()` - Internal method with full request handling
- ✅ Existing running functionality preserved (backward compatibility)
- ✅ No new files created (extends existing files)
- ✅ No code generation needed (plain Dart methods)

**Acceptance Criteria:**
- ✅ Can generate cycling macros using extended controller method (`generateCyclingMacros()`)
- ✅ Can generate swimming macros using extended controller method (`generateSwimmingMacros()`)
- ✅ Running macro generation still works (backward compatibility maintained)
- ✅ All methods follow AsyncNotifier pattern with AsyncValue.guard()
- ✅ All business logic calls edge functions (NOT in controllers)
- ✅ Controllers only orchestrate and manage UI state
- ✅ Analytics tracking consistent across all sports (plan_generation_started, plan_generated, plan_generation_failed)
- ✅ Error handling with Sentry breadcrumbs for all sports
- ✅ Debug logging for troubleshooting

**Files Modified:**
- `/lib/features/nutrition_plan/application/nutrition_plan_service.dart`
- `/lib/features/nutrition_plan/presentation/providers/distance_page_gut_entry_controller.dart`

**Key Implementation Details:**
- Both cycling and swimming methods follow the exact same pattern as the existing `generateMacros()` method
- Edge function calls include `activity_type` parameter as required by Phase 3 unified edge functions
- PendingActivityData stored for later creation after plan generation
- Full analytics tracking with plan_id threading for North-Star metrics
- Sport-specific debug logging with emojis (🚴 for cycling, 🏊 for swimming)

**What's Ready for Phase 6:**
✅ Backend controller methods ready to be called from UI:
- `DistancePageGutEntryController.generateCyclingMacros(...)`
- `DistancePageGutEntryController.generateSwimmingMacros(...)`

✅ Edge functions deployed and tested (Phase 3):
- `generate-macros` with activity_type='cycling'
- `generate-macros` with activity_type='swimming'
- `generate-nutrition-plan` with activity_type parameter

✅ Domain models created (Phase 4):
- `CyclingParameters` with all required fields
- `SwimmingParameters` with all required fields

✅ Database schema ready (Phase 2):
- Activities table supports cycling/swimming-specific columns
- User preferences table supports FTP, CSS, and sport-specific equipment

**Next Steps → Phase 6:**
1. Create `CyclingInputScreen` that calls `generateCyclingMacros()`
2. Create `SwimmingInputScreen` that calls `generateSwimmingMacros()`
3. Update `ActivityCreationScreen` navigation to route to new screens
4. Update nutrition plan display to be sport-agnostic
5. Build reusable widgets for sport-specific inputs

---

## Phase 6: Presentation Layer (UI Screens) ✅ COMPLETE

**Priority:** MEDIUM-HIGH (User-facing)
**Estimated Duration:** 1.5-2 weeks
**Status:** ✅ COMPLETE (2025-10-15)

**Prerequisites:** ✅ Phase 5 Complete

**Overview:**
With Phase 5 complete, we now have working backend methods for generating cycling and swimming macros. Phase 6 focuses on building the user-facing screens that allow users to input their workout parameters and view sport-specific nutrition plans.

**Key Objectives:**
1. Create cycling input screen with sport-specific fields
2. Create swimming input screen with sport-specific fields
3. Update activity creation navigation to route to new screens
4. Make nutrition plan display screens sport-agnostic
5. Build reusable UI widgets for multi-sport inputs

### 6.1 Create Cycling Input Screen
**File:** `lib/features/nutrition_plan/presentation/screens/cycling_input_screen.dart`

**Tasks:**
1. Create screen layout following existing design patterns
2. Add hero image (cycling-themed)
3. Implement date & time selectors
4. Add distance increment/decrement widget
5. Add speed increment/decrement widget with duration calculation
6. Add intensity target dropdown (Zone 1-5)
7. Add session goal dropdown (Endurance/Tempo/Intervals)
8. Add terrain dropdown (Flat-Indoor, Flat-Outdoor, Rolling, Hilly)
9. Add elevation gain input
10. Add pre-ride timing selector (reuse `PreRunTimingSelector` widget)
11. Add collapsible environment section (temp, humidity, wind, sun)
12. Add "Generate Nutrition Plan" button
13. Wire up to `CyclingInputController`
14. Add form validation
15. Add loading state overlay
16. Add error handling with user-friendly messages

**UI Rules:**
- NO business logic in screen
- NO API calls from screen
- ALL text from ContentService
- Follow AppTheme color scheme
- Use ScreenUtil for responsive sizing

### 6.2 Create Swimming Input Screen
**File:** `lib/features/nutrition_plan/presentation/screens/swimming_input_screen.dart`

**Tasks:**
1. Create screen layout following existing design patterns
2. Add hero image (swimming-themed)
3. Implement date & time selectors
4. Add pool/open water toggle
5. Add distance input (meters or yards)
6. Add pace per 100m input (MM:SS format)
7. Add intensity target dropdown (Zone 1-4)
8. Add session goal dropdown (Technique/Endurance/Sets)
9. Add water temperature input
10. Add pre-swim timing selector
11. Add collapsible environment section (for pool: deck temp, humidity)
12. Add "Generate Nutrition Plan" button
13. Wire up to `SwimmingInputController`
14. Add form validation
15. Add loading state overlay
16. Add error handling with user-friendly messages

### 6.3 Update Activity Creation Screen
**File:** `lib/features/calendar/presentation/screens/activity_creation_screen.dart`

**Tasks:**
1. Replace "Under Construction" placeholders:
   - Biking tab → Navigate to `CyclingInputScreen`
   - Swimming tab → Navigate to `SwimmingInputScreen`
2. Preserve tab state when switching (don't reset inputs)
3. Update app bar to show current activity type
4. Add tab change analytics tracking

### 6.4 Make Nutrition Plan Display Sport-Agnostic
**Files to update:**
- `lib/features/nutrition_plan/presentation/screens/nutrition_plan_screen.dart`
- `lib/features/nutrition_plan/presentation/screens/macro_targets_screen.dart`
- `lib/features/nutrition_plan/presentation/widgets/nutrition_phase_card.dart`

**Tasks:**
1. **Update `NutritionPlanScreen`:**
   - Accept `activityType` parameter
   - Fetch sport-specific text from ContentService
   - Update phase titles dynamically:
     - `contentService.get('nutrition_plan.before_${activityType}_title')`
     - `contentService.get('nutrition_plan.during_${activityType}_title')`
     - `contentService.get('nutrition_plan.after_${activityType}_title')`

2. **Update `MacroTargetsScreen`:**
   - Same dynamic text approach
   - Update explanatory text based on activity type
   - Example: "On the bike" vs "During your run"

3. **Update `NutritionPhaseCard`:**
   - Accept `activityType` parameter
   - Update timing labels dynamically
   - Update icons based on activity type (optional enhancement)

### 6.5 Create Reusable Widgets
**Files to create:**
- `lib/features/nutrition_plan/presentation/widgets/speed_input_widget.dart`
- `lib/features/nutrition_plan/presentation/widgets/pace_per_100m_input_widget.dart`
- `lib/features/nutrition_plan/presentation/widgets/intensity_zone_dropdown.dart`
- `lib/features/nutrition_plan/presentation/widgets/terrain_selector_dropdown.dart`
- `lib/features/nutrition_plan/presentation/widgets/pool_open_water_toggle.dart`

**Tasks:**
1. Extract common UI patterns into reusable widgets
2. Ensure widgets follow FOA principles (UI-only, no business logic)
3. Add documentation comments
4. Use ContentService for all text

**Deliverables:**
- ✅ `CyclingInputScreen` implemented and styled
- ✅ `SwimmingInputScreen` implemented and styled
- ✅ `ActivityCreationScreen` updated with real navigation
- ⏳ Nutrition plan screens updated for sport-agnostic display (Phase 8)
- ⏳ Reusable widgets created and documented (optional - reused existing widgets)

**Acceptance Criteria:**
- ✅ Can navigate to cycling input screen from calendar
- ✅ Can navigate to swimming input screen from calendar
- ✅ Can input all required cycling parameters
- ✅ Can input all required swimming parameters
- ✅ Duration auto-calculates when distance + speed/pace entered
- ✅ Form validation prevents invalid submissions (inherits from existing pattern)
- ✅ Loading overlay shows during API calls
- ✅ Error handling with user-friendly error messages
- ⏳ Nutrition plan displays with correct sport-specific labels (Phase 8 - requires ContentService updates)

---

## Phase 7: Onboarding & Settings Updates ✅ COMPLETE (Settings) / ⏳ ONBOARDING PENDING

**Priority:** MEDIUM (Nice-to-have but important for UX)
**Estimated Duration:** 5-7 days
**Status:** ✅ Settings UI Complete (2025-10-16) / ⏳ Onboarding UI Pending

**Prerequisites:** ✅ Phase 6 Complete

**Progress:**
- ✅ **Phase 7a: Backend (Domain Models & Controllers) - COMPLETE** (2025-10-16)
- ✅ **Phase 7b: Settings Screen UI - COMPLETE** (2025-10-16)
- ⏳ **Phase 7c: Onboarding Flow UI - NOT STARTED** (Optional - can be deferred)

### 7.1 Update Onboarding Flow
**Files to update:**
- `lib/features/auth/presentation/screens/onboarding_screen.dart`
- `lib/features/auth/presentation/providers/onboarding_controller.dart`

**Tasks:**
1. **Add "Sport Preferences" screen:**
   - Title: "Which sports do you do?"
   - Checkboxes: Running, Cycling, Swimming
   - Multi-select allowed
   - Analytics tracking: Selected sports

2. **Add conditional cycling details screen (if cycling selected):**
   - FTP input (watts) with explanation
   - Help text: "Your FTP is the maximum power you can sustain for ~1 hour. If you don't know, enter 0 and we'll estimate."
   - Bike carrying capacity selector: 1 bottle / 2 bottles / 3+ bottles
   - Aero bottle toggle: Yes/No
   - Bento box toggle: Yes/No

3. **Add conditional swimming details screen (if swimming selected):**
   - CSS input (pace per 100m) with explanation
   - Help text: "Your CSS is the fastest pace you can sustain for 30 minutes of continuous swimming. Format: MM:SS per 100m. Example: 2:00 means 2 minutes per 100 meters."
   - Wetsuit toggle: Yes/No
   - Swim cap selector: None / Latex / Silicone / Neoprene

4. **Update existing "Gut Training" screen:**
   - Add GI sensitivity question: "Do you have a sensitive stomach during exercise?"
   - Help text: "This helps us recommend foods that are easier to digest"

5. **Update onboarding controller:**
   - Save sport preferences to database
   - Save cycling preferences (if applicable)
   - Save swimming preferences (if applicable)
   - Update analytics events

### 7.2 Update Settings Screen ✅ COMPLETE (Phase 7b)

**Completed:** 2025-10-16

**Files Updated:**
- ✅ `lib/features/settings/presentation/screens/settings_screen.dart`
- ✅ `lib/features/settings/domain/settings_state.dart`
- ✅ `lib/features/settings/presentation/providers/settings_controller.dart`
- ✅ `assets/config/content_defaults.json`

**Tasks Completed:**
1. ✅ **Added Content Management Keys:**
   - Added `settings.*` keys for sport settings section
   - Added `cycling_preferences.*` keys (FTP, bottles, aero bottle, bento box)
   - Added `swimming_preferences.*` keys (CSS, wetsuit, swim cap types)
   - Added help text and placeholders for technical fields

2. ✅ **Updated SettingsState Domain Model:**
   - Added `sportSettingsSectionTitle` field
   - Added `cyclingSectionTitle` field
   - Added `swimmingSectionTitle` field
   - Added `giSensitivityLabel` field
   - Updated constructor and copyWith() method

3. ✅ **Updated SettingsController:**
   - Updated `build()` to load sport-specific text labels from ContentService
   - Sport preferences already loaded in Phase 7a
   - Controller methods already exist (Phase 7a): `updateCyclingPreferences()`, `updateSwimmingPreferences()`, `updateGISensitivity()`

4. ✅ **Added Settings Screen UI Sections:**
   - **Sport Settings Section** with GI Sensitivity toggle
   - **Cycling Settings Section:**
     - FTP input field (integer with watts suffix + help text)
     - Bike bottles selector (1/2/3+ buttons)
     - Aero bottle toggle with subtitle
     - Bento box toggle with subtitle
   - **Swimming Settings Section:**
     - CSS pace input (MM:SS format with parser + help text)
     - Wetsuit toggle with subtitle
     - Swim cap type selector (None/Latex/Silicone/Neoprene)

5. ✅ **Widget Implementations:**
   - `_buildGISensitivityToggle()` - Shared GI sensitivity preference
   - `_buildCyclingFtpInput()` - FTP watts input with validation
   - `_buildBikeBottlesSelector()` - 1/2/3+ button selector
   - `_buildAeroBottleToggle()` - Aero bottle yes/no
   - `_buildBentoBoxToggle()` - Bento box yes/no
   - `_buildCssPaceInput()` - MM:SS pace parser (converts to seconds)
   - `_buildWetsuitToggle()` - Wetsuit yes/no
   - `_buildSwimCapSelector()` - 4-option selector (vertical list)

6. ✅ **Code Generation:**
   - Ran `dart run build_runner build` successfully
   - All provider code regenerated (14 outputs)

**Design Patterns:**
- ✅ Consistent styling with existing settings widgets
- ✅ Uses AppTheme colors and ScreenUtil sizing
- ✅ All text from ContentService with fallback defaults
- ✅ Real-time updates (auto-save on change via controller methods)
- ✅ Proper Switch styling (matches existing toggles)
- ✅ Helpful subtitles for all preferences
- ✅ Input validation (FTP >= 0, CSS pace MM:SS format)

**What Works:**
- Users can now edit FTP, bike bottles, aero bottle, and bento box preferences
- Users can now edit CSS pace (MM:SS format), wetsuit, and swim cap type
- Users can set GI sensitivity (shared across all sports)
- All changes save immediately to Drift database via existing controller methods
- Settings screen displays sport preferences in organized sections
- Backward compatible with existing user profiles (all sport fields nullable)

**Documentation:**
- ✅ Roadmap updated with Phase 7b completion status

### 7.3 Backend Implementation (Phase 7a) ✅ COMPLETE

**Completed:** 2025-10-16

**Tasks Completed:**
1. ✅ **Updated UserProfile domain model** (`lib/features/auth/domain/user_preferences.dart`):
   - Added 4 cycling preference fields (FTP, bike bottles, aero bottle, bento box)
   - Added 3 swimming preference fields (CSS pace, wetsuit, swim cap type)
   - Added 1 shared GI sensitivity field
   - Updated `fromJson()`, `toJson()`, `copyWith()` methods

2. ✅ **Updated SettingsState domain model** (`lib/features/settings/domain/settings_state.dart`):
   - Added all 8 sport preference fields
   - Updated `copyWith()` method

3. ✅ **Extended SettingsController** (`lib/features/settings/presentation/providers/settings_controller.dart`):
   - Updated `build()` to load sport preferences from user profile
   - Added `updateCyclingPreferences()` method
   - Added `updateSwimmingPreferences()` method
   - Added `updateGISensitivity()` method
   - Updated `_saveProfile()` to persist sport preferences

4. ✅ **Code Generation:**
   - Ran `dart fix --apply` (53 fixes in 26 files)
   - Ran `build_runner build` (265 outputs generated successfully)

**Files Modified:**
- `/lib/features/auth/domain/user_preferences.dart`
- `/lib/features/settings/domain/settings_state.dart`
- `/lib/features/settings/presentation/providers/settings_controller.dart`

**Documentation:**
- ✅ Created `/docs/features/cycling_swimming/phase7-backend-completion-summary.md`

**What's Ready:**
- ✅ Backend can load sport preferences from database
- ✅ Backend can save sport preferences to database
- ✅ Settings controller has methods for updating cycling/swimming preferences
- ✅ Database schema already supports sport preferences (from Phase 2)

**Deliverables:**
- ⏳ Onboarding flow updated with sport preferences (UI pending - Phase 7c)
- ✅ Settings screen updated with cycling/swimming sections (Phase 7b COMPLETE)
- ✅ User preferences can be persisted correctly (backend ready)
- ✅ All text from ContentService (content keys added in Phase 7b)

**Acceptance Criteria:**
- ⏳ Can select multiple sports during onboarding (Phase 7c - UI not implemented yet)
- ⏳ Cycling details screen shows only if cycling selected (Phase 7c - screens not created yet)
- ⏳ Swimming details screen shows only if swimming selected (Phase 7c - screens not created yet)
- ✅ Can enter FTP with helpful explanation (Settings UI implemented in Phase 7b)
- ✅ Can enter CSS with helpful explanation and format guidance (Settings UI implemented in Phase 7b)
- ✅ Preferences can be saved to database correctly (backend ready - Phase 7a)
- ✅ Can update preferences in settings screen (Phase 7b - UI implemented)
- ✅ Changes will persist across app restarts (persistence logic ready)

---

## Phase 8: Content Management System Updates

**Priority:** MEDIUM (Required for sport-agnostic UI)
**Estimated Duration:** 2-3 days

### 8.1 Update Content Defaults JSON
**File:** `assets/config/content_defaults.json`

**Tasks:**
1. Add new content keys for cycling and swimming
2. Add onboarding text
3. Add activity input screen text
4. Add sport-specific nutrition plan labels

**Example additions:**
```json
{
  "onboarding": {
    "sport_preferences_title": "Which sports do you do?",
    "sport_preferences_subtitle": "We'll customize your nutrition plans for each sport",
    "ftp_label": "FTP (Functional Threshold Power)",
    "ftp_help": "Your FTP is the maximum power you can sustain for ~1 hour. If you don't know, enter 0 and we'll estimate.",
    "ftp_placeholder": "e.g., 250",
    "css_label": "CSS (Critical Swim Speed)",
    "css_help": "Your CSS is the fastest pace you can sustain for 30 minutes of continuous swimming.",
    "css_help_format": "Format: MM:SS per 100m. Example: 2:00 means 2 minutes per 100 meters.",
    "css_placeholder": "e.g., 2:00",
    "bike_bottles_label": "How many water bottles can you carry?",
    "aero_bottle_label": "Do you have an aero bottle?",
    "bento_box_label": "Do you have a bento box?",
    "wetsuit_label": "Do you typically wear a wetsuit?",
    "swim_cap_label": "What swim cap do you usually wear?",
    "gi_sensitivity_label": "Do you have a sensitive stomach during exercise?",
    "gi_sensitivity_help": "This helps us recommend foods that are easier to digest"
  },
  "activity_input": {
    "cycling_title": "Plan Your Ride",
    "cycling_hero_alt": "Cyclist riding at sunset",
    "swimming_title": "Plan Your Swim",
    "swimming_hero_alt": "Swimmer in pool",
    "average_speed_label": "Average Speed",
    "average_speed_unit": "mph",
    "pace_per_100m_label": "Pace per 100m",
    "pace_per_100m_unit": "MM:SS",
    "intensity_target_label": "Intensity Target",
    "session_goal_label": "Session Goal",
    "terrain_label": "Terrain & Aero Load",
    "elevation_gain_label": "Elevation Gain",
    "elevation_gain_unit": "ft",
    "pool_open_water_label": "Pool or Open Water",
    "water_temperature_label": "Water Temperature",
    "duration_calculated": "Duration: ~{duration} min"
  },
  "nutrition_plan": {
    "before_running_title": "Before Your Run",
    "before_cycling_title": "Before Your Ride",
    "before_swimming_title": "Before Your Swim",
    "during_running_title": "During Your Run",
    "during_cycling_title": "On The Bike",
    "during_swimming_title": "During Your Swim",
    "after_running_title": "After Your Run",
    "after_cycling_title": "Post-Ride Recovery",
    "after_swimming_title": "Post-Swim Recovery",
    "timing_running_before": "2-3 hours before",
    "timing_cycling_before": "2-3 hours before",
    "timing_swimming_before": "2-3 hours before",
    "timing_running_during": "Throughout run",
    "timing_cycling_during": "On the bike every 15-20 min",
    "timing_swimming_during": "At feed stops (if applicable)",
    "timing_running_after": "Within 30 minutes",
    "timing_cycling_after": "Within 30 minutes",
    "timing_swimming_after": "Within 30 minutes"
  }
}
```

### 8.2 Update ContentService
**File:** `lib/features/content/application/content_service.dart`

**Tasks:**
1. Add helper method for sport-specific keys:
   ```dart
   String getSportSpecificText(String baseKey, String activityType) {
     final key = '${baseKey}_${activityType}';
     return get(key);
   }
   ```

2. Add validation for required sport keys
3. Update content sync logic to include new keys

**Deliverables:**
- ✅ Content defaults JSON updated with all new keys
- ✅ ContentService updated with sport-specific helpers
- ✅ Content synced to Supabase dev environment

**Acceptance Criteria:**
- [ ] All new content keys accessible via ContentService
- [ ] Sport-specific text displays correctly in UI
- [ ] Fallback to default English text works correctly
- [ ] Content updates sync from Supabase

---

## Phase 9: Testing & Quality Assurance

**Priority:** HIGH (Required before production)
**Estimated Duration:** 1-2 weeks

### 9.1 Edge Function Testing
**Tasks:**
1. Run all edge function test suites:
   ```bash
   cd supabase/functions/generate-macros
   deno test --allow-all

   cd ../generate-nutrition-plan
   deno test --allow-all
   ```

2. Manual end-to-end testing:
   - Test cycling macro generation with various inputs
   - Test swimming macro generation with various inputs
   - Test nutrition plan generation for all 3 sports
   - Test edge cases (very short workouts, very long workouts, extreme weather)

3. Performance testing:
   - Measure average response time for each sport
   - Ensure <2 second response for macro generation
   - Ensure <5 second response for nutrition plan generation

### 9.2 Integration Testing
**Files to create:**
- `test/integration/cycling_workflow_test.dart`
- `test/integration/swimming_workflow_test.dart`
- `test/integration/multi_sport_calendar_test.dart`

**Test Scenarios:**
1. **Cycling Workflow:**
   - User selects cycling in onboarding
   - User creates cycling activity
   - User generates nutrition plan
   - User views plan with sport-specific labels
   - User completes activity
   - User marks activity as completed

2. **Swimming Workflow:**
   - Similar to cycling workflow

3. **Multi-Sport Calendar:**
   - User creates running activity
   - User creates cycling activity
   - User creates swimming activity
   - All 3 activities display correctly in calendar
   - Upcoming events show for all sports
   - Can filter by activity type

### 9.3 Manual QA Checklist

#### Onboarding:
- [ ] Can select multiple sports
- [ ] Cycling details show only if cycling selected
- [ ] Swimming details show only if swimming selected
- [ ] FTP explanation is clear
- [ ] CSS explanation is clear with format example
- [ ] Can skip optional fields
- [ ] Preferences save correctly

#### Activity Creation:
- [ ] Can switch between running/cycling/swimming tabs
- [ ] Tab state preserved when switching
- [ ] Cycling input screen has all required fields
- [ ] Swimming input screen has all required fields
- [ ] Duration calculates automatically
- [ ] Form validation works correctly
- [ ] Loading overlay appears during API calls
- [ ] Error messages display correctly

#### Nutrition Plan Generation:
- [ ] Cycling plan generates successfully
- [ ] Swimming plan generates successfully
- [ ] Running plan still works (backward compatibility)
- [ ] Sport-specific labels display correctly
- [ ] Food selections appropriate for each sport
- [ ] Macro totals match targets (±10g tolerance)
- [ ] Can adjust macro targets
- [ ] Can regenerate plan

#### Settings:
- [ ] Cycling settings section displays
- [ ] Swimming settings section displays
- [ ] Can update FTP
- [ ] Can update CSS
- [ ] Changes persist after app restart

#### Calendar:
- [ ] Can view activities by date
- [ ] Can view activities by type
- [ ] Activity cards show sport-specific icons
- [ ] Can complete activities of all types
- [ ] Can delete activities of all types

### 9.4 Performance Testing
**Tasks:**
1. Test on physical devices:
   - iPhone 12 (iOS 16+)
   - iPhone 15 Pro (iOS 17+)
   - Pixel 6 (Android 13+)
   - Pixel 8 (Android 14+)

2. Measure performance metrics:
   - App launch time
   - Screen transition time
   - API response time
   - Database query time
   - Memory usage

3. Test edge cases:
   - Poor network conditions (3G, airplane mode)
   - Large activity lists (100+ activities)
   - Offline mode (cached plans)
   - Background app refresh

**Deliverables:**
- ✅ All edge function tests pass
- ✅ Integration tests written and passing
- ✅ Manual QA checklist completed
- ✅ Performance benchmarks meet targets
- ✅ Bug fixes implemented

**Acceptance Criteria:**
- [ ] 100% of critical path tests pass
- [ ] 0 high-severity bugs
- [ ] <5 medium-severity bugs
- [ ] Average API response time <3 seconds
- [ ] App responsive on all target devices
- [ ] No crashes during 1-hour stress test

---

## Phase 10: Deployment & Launch

**Priority:** CRITICAL (Final step)
**Estimated Duration:** 1 week

### 10.1 Pre-Deployment Checklist
**Tasks:**
1. **Code Review:**
   - [ ] All code reviewed by senior developer
   - [ ] No hardcoded values (all from ContentService)
   - [ ] All analytics events properly named
   - [ ] All error handling in place
   - [ ] All logging statements appropriate

2. **Documentation Review:**
   - [ ] README.md up to date
   - [ ] formulas.md accurate
   - [ ] edge-functions.md complete
   - [ ] database-schema.md matches actual schema
   - [ ] CLAUDE.md updated with new features

3. **Database Review:**
   - [ ] Schema snapshot in database_schemas/v1/ matches production
   - [ ] All migrations tested on copy of production database
   - [ ] No data loss risk identified
   - [ ] Rollback plan documented

4. **Edge Function Review:**
   - [ ] All edge functions tested in dev
   - [ ] Environment variables configured correctly
   - [ ] Rate limiting appropriate
   - [ ] CORS headers correct

### 10.2 Deploy to Production Supabase
**Tasks:**
1. **Deploy schema changes:**
   ```bash
   supabase db push --linked --project-ref <prod-project-ref>
   ```

2. **Deploy edge functions:**
   ```bash
   supabase functions deploy generate-macros --project-ref <prod-project-ref>
   supabase functions deploy generate-nutrition-plan --project-ref <prod-project-ref>
   ```

3. **Verify edge functions:**
   - Test with curl/Postman
   - Check logs for errors
   - Verify response times

4. **Deploy content updates:**
   - Upload updated content_defaults.json to Supabase storage
   - Verify content syncs to app

### 10.3 Build & Submit App
**Tasks:**
1. **Update version numbers:**
   - `pubspec.yaml`: Bump version to `1.8.0+X`
   - Update CHANGELOG.md

2. **Update app store metadata:**
   - **Title**: "Mealvana Endurance - Multi-Sport Nutrition"
   - **Description**: Add cycling and swimming support
   - **Keywords**: Add "triathlon", "cycling nutrition", "swimming nutrition"
   - **Screenshots**: Add cycling and swimming screenshots

3. **Build iOS:**
   ```bash
   flutter build ios --release
   ```

4. **Build Android:**
   ```bash
   flutter build appbundle --release
   ```

5. **Submit to App Store:**
   - Upload to App Store Connect
   - Fill out release notes
   - Submit for review

6. **Submit to Google Play:**
   - Upload to Google Play Console
   - Fill out release notes
   - Submit for review

### 10.4 Post-Launch Monitoring
**Tasks:**
1. **Monitor edge function logs:**
   - Check for error spikes
   - Monitor response times
   - Check for failed requests

2. **Monitor app analytics:**
   - Track adoption of cycling feature
   - Track adoption of swimming feature
   - Monitor completion rates by sport
   - Track user feedback

3. **Monitor crash reports:**
   - Check Sentry for new crashes
   - Investigate and fix high-priority issues

4. **User feedback:**
   - Monitor app store reviews
   - Respond to user questions
   - Collect feature requests

### 10.5 Launch Communications
**Tasks:**
1. **Email existing users:**
   - Announce cycling and swimming support
   - Highlight benefits for triathletes
   - Include tutorial/guide

2. **Social media:**
   - Post on Twitter/X
   - Post on Instagram
   - Post in triathlon/cycling/swimming groups

3. **Press release:**
   - Send to endurance sports blogs
   - Send to triathlon news sites

**Deliverables:**
- ✅ Code reviewed and approved
- ✅ Database changes deployed to production
- ✅ Edge functions deployed to production
- ✅ App built and submitted to app stores
- ✅ Launch communications sent
- ✅ Monitoring in place

**Acceptance Criteria:**
- [ ] Production database schema updated successfully
- [ ] Production edge functions deployed successfully
- [ ] App submitted to App Store (iOS)
- [ ] App submitted to Google Play (Android)
- [ ] No production errors in first 24 hours
- [ ] User feedback positive (>4.5 stars average)

---

## Phase 11: Iteration & Refinement (Post-Launch)

**Priority:** LOW-MEDIUM (Continuous improvement)
**Estimated Duration:** Ongoing

### 11.1 Gather User Feedback
**Tasks:**
1. Monitor in-app feedback for cycling/swimming
2. Analyze completion ratings by sport
3. Review nutrition plan accuracy reports
4. Collect feature requests

### 11.2 Refine Formulas
**Tasks:**
1. Compare predicted vs actual energy expenditure
2. Adjust MET values based on user data
3. Refine hydration recommendations
4. Fine-tune carb recommendations

### 11.3 UI/UX Improvements
**Tasks:**
1. Simplify complex input screens based on user feedback
2. Add preset templates for common workouts
3. Improve error messages
4. Add contextual help/tooltips

### 11.4 Performance Optimizations
**Tasks:**
1. Optimize edge function cold start time
2. Improve database query performance
3. Reduce app bundle size
4. Implement caching strategies

---

## Risk Management

### High-Risk Items
1. **Edge Function Formula Accuracy**: Mitigation = Start conservative, iterate based on data
2. **Database Schema Changes**: Mitigation = Test thoroughly in dev, have rollback plan
3. **Backward Compatibility**: Mitigation = Comprehensive regression testing for running

### Medium-Risk Items
1. **UI Complexity**: Mitigation = User testing before launch
2. **App Store Approval**: Mitigation = Follow all guidelines, provide clear explanations
3. **Performance Degradation**: Mitigation = Load testing before production

### Low-Risk Items
1. **Content Management Updates**: Mitigation = Fallback to local defaults
2. **Analytics Tracking**: Mitigation = Non-blocking, graceful failure

---

## Success Metrics (30 Days Post-Launch)

**Adoption Metrics:**
- ✅ >20% of users create at least one cycling activity
- ✅ >10% of users create at least one swimming activity
- ✅ >5% of users create all 3 activity types (triathletes)

**Quality Metrics:**
- ✅ <2% edge function error rate
- ✅ Average completion rating >4.2/5 for cycling
- ✅ Average completion rating >4.0/5 for swimming
- ✅ <10 critical bug reports

**Performance Metrics:**
- ✅ Average API response time <3 seconds
- ✅ 95th percentile response time <5 seconds
- ✅ App crash rate <0.1%

---

## Appendix: File Checklist

### New Files to Create
- [ ] `docs/features/cycling_swimming/formulas.md`
- [ ] `docs/features/cycling_swimming/edge-functions.md`
- [ ] `docs/features/cycling_swimming/database-schema.md`
- [ ] `lib/features/nutrition_plan/domain/cycling_parameters.dart`
- [ ] `lib/features/nutrition_plan/domain/swimming_parameters.dart`
- [ ] `lib/features/nutrition_plan/application/cycling_nutrition_service.dart`
- [ ] `lib/features/nutrition_plan/application/swimming_nutrition_service.dart`
- [ ] `lib/features/nutrition_plan/presentation/providers/cycling_input_controller.dart`
- [ ] `lib/features/nutrition_plan/presentation/providers/swimming_input_controller.dart`
- [ ] `lib/features/nutrition_plan/presentation/screens/cycling_input_screen.dart`
- [ ] `lib/features/nutrition_plan/presentation/screens/swimming_input_screen.dart`
- [ ] `supabase/migrations/YYYYMMDDHHMMSS_add_cycling_swimming_support.sql`
- [ ] `supabase/functions/generate-macros/test/cycling.test.ts`
- [ ] `supabase/functions/generate-macros/test/swimming.test.ts`

### Files to Modify
- [ ] `lib/shared/database/tables/activities_table.dart`
- [ ] `lib/shared/database/tables/user_profiles_table.dart`
- [ ] `lib/shared/database/app_database.dart`
- [ ] `lib/features/calendar/presentation/screens/activity_creation_screen.dart`
- [ ] `lib/features/nutrition_plan/presentation/screens/nutrition_plan_screen.dart`
- [ ] `lib/features/auth/presentation/screens/onboarding_screen.dart`
- [ ] `lib/features/auth/presentation/screens/settings_screen.dart`
- [ ] `supabase/functions/generate-macros/index.ts`
- [ ] `supabase/functions/generate-nutrition-plan/index.ts`
- [ ] `assets/config/content_defaults.json`
- [ ] `CLAUDE.md`

---

**Roadmap Version:** 1.2
**Last Updated:** 2025-10-16
**Status:** IN PROGRESS - Phase 6 Complete, Phase 7 Backend Complete
**Current Progress:** 6.5/11 phases complete (59%)
**Estimated Completion:** 3-4 weeks remaining
