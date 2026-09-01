# Nutrition Plan Generation Fixes
*Date: 2025-11-16*
*Status: 🔴 CRITICAL - Blocking nutrition plan generation*

## Executive Summary

The nutrition plan generation system is completely broken in production due to **Phase 0 schema refactoring** not being applied to the edge functions. The edge functions are still trying to query deleted junction tables and use columns that no longer exist.

**Impact**:
- ❌ No nutrition plans can be generated
- ❌ Users see empty food lists (0 foods found)
- ❌ Edge functions return only Water and Salt (essential foods)
- ❌ Client crashes when parsing nutrition plan data

---

## Critical Issues Identified

### 1. Edge Functions Query Deleted Tables 🔴 CRITICAL

**Affected Functions**:
- `generate-nutrition-plan/index.ts` (Lines 156-247)
- `create-nutrition-plan/index.ts` (Lines 74-91)
- `get-foods/index.ts` (Lines 45-67)
- `save-user-food/index.ts` (Lines 56)

**Root Cause**: Functions try to query tables removed in Phase 0:
```typescript
// ❌ BROKEN - These tables don't exist anymore
await supabase.from("categories").select("id")  // Table deleted
await supabase.from("food_categories").select("food_id")  // Table deleted
await supabase.from("user_food_categories").select("user_food_id")  // Table deleted
```

**Logs**:
```
[CATEGORY] Error fetching category "before_run":
  Could not find the table 'public.categories' in the schema cache
[FOODS-BEFORE] CRITICAL: categoryId is null, cannot fetch foods for phase "before"
[FOODS-BEFORE] Combined 0 generic + 0 user foods + 2 essential = 2 total
```

**Result**: Only essential foods (Water, Salt) are returned → LP solver has nothing to work with → empty nutrition plans.

---

### 2. Edge Functions Query Deleted Columns 🔴 CRITICAL

**Affected Functions**:
- `generate-nutrition-plan/index.ts` (Line 227, 244)
- `save-user-food/index.ts` (Line 56)

**Root Cause**: Functions try to query `product_type_id` which doesn't exist (replaced with `product_type` enum):
```typescript
// ❌ BROKEN
SELECT product_type_id FROM user_foods  // Column doesn't exist

// ✅ CORRECT (production schema)
SELECT product_type FROM user_foods  // product_type_enum column
```

**Logs**:
```
[FOODS-BEFORE] Error fetching uncategorized user foods:
  column user_foods.product_type_id does not exist
  hint: Perhaps you meant to reference the column "user_foods.product_type"
```

**Result**: All user food queries fail → only essential foods returned.

---

### 3. Client Food Sync Crashes 🔴 CRITICAL

**Affected Files**:
- `lib/features/nutrition_plan/data/food_repository.dart` (Line 785)

**Root Cause**: Client expects `categories` as `String?` but receives `List<dynamic>` (array):
```dart
// ❌ BROKEN - Client expects string
productType: json['product_type'] as String?,

// ✅ CORRECT - Production has array
categories: (json['categories'] as List<dynamic>?)
  ?.map((e) => e.toString())
  .toList(),
```

**Logs**:
```
⛔ type 'List<dynamic>' is not a subtype of type 'String?' in type cast
⛔ [FoodRepository] Error syncing foods to local database
```

**Result**: Food sync fails → 0 foods in local database → lookups fail → nutrition plan display broken.

---

### 4. Food Lookup Failures 🔴 CRITICAL

**Affected Files**:
- `lib/features/nutrition_plan/application/llm_nutrition_plan_service.dart`

**Root Cause**: No foods in local database after sync crash:
```
🐛 [FOOD_LOOKUP] Searching for food 408c9d6e-83aa-4875-8100-e6bc09ebe324
   (total foods in table: 0)
⚠️ [FOOD_LOOKUP] Food not found in either table (searched 0 foods)
⛔ [FOOD_TRANSFORMATION] Food not found in local database
```

**Result**: Nutrition plans show food IDs with no names, quantities, or nutritional info.

---

### 5. Macro Validation Failures ⚠️ HIGH

**Root Cause**: Edge function returns foods with IDs only, but client can't look them up:
```
⛔ [LLMNutritionPlanService] Food Items vs Macro Targets Comparison
   macro_targets: {total_carbs_g: 309}
   food_items_actual: {total_carbs_g: 0}  // Because lookups failed!
   percentage_match: {carbs_percentage: 0}
```

**Result**: Nutrition plans appear empty despite edge function generating them.

---

## Production Schema Changes (Phase 0)

### Tables Removed
| Deleted Table | Purpose | Replacement |
|---------------|---------|-------------|
| `categories` | Lookup table for food phases | Use PostgreSQL arrays in `foods.categories` |
| `food_categories` | Junction table | Array column `categories category_enum[]` |
| `user_food_categories` | Junction table | Array column `categories category_enum[]` |
| `meal_types` | Carb loading meals | Array column `meal_types text[]` |
| `carb_loading_food_meal_types` | Junction table | Array column `meal_types text[]` |
| `product_types` | Product type lookup | Use enum `product_type product_type_enum` |
| `user_hidden_foods` | Hidden food tracking | Use `user_foods.is_deleted boolean` |

### Columns Changed
| Table | Old Column | New Column | Type Change |
|-------|-----------|------------|-------------|
| `foods` | `(via junction)` | `categories` | `category_enum[]` array |
| `foods` | `(via junction)` | `activity_types` | `activity_type_enum[]` array |
| `user_foods` | `product_type_id` | `product_type` | `product_type_enum` |
| `user_foods` | `(via junction)` | `categories` | `category_enum[]` array |
| `user_foods` | `(via junction)` | `activity_types` | `activity_type_enum[]` array |
| `carb_loading_foods` | `(via junction)` | `meal_types` | `text[]` array |
| `carb_loading_user_foods` | `(via junction)` | `meal_types` | `text[]` array |

---

## Fix Roadmap

### Phase 1: Edge Functions Schema Alignment 🔴 CRITICAL (2-3 hours)

**Goal**: Update all edge functions to use array columns instead of junction tables.

#### Task 1.1: Fix `generate-nutrition-plan/index.ts`
**Priority**: 🔴 CRITICAL
**Complexity**: High
**Est. Time**: 1.5 hours

**Changes Required**:
1. **Remove category lookup** (Lines 155-167):
   ```typescript
   // ❌ DELETE this entire function
   async function getCategoryId(supabase, categoryName) {
     const { data, error } = await supabase
       .from("categories")  // Table doesn't exist!
       .select("id")
       .eq("name", categoryName)
       .maybeSingle();
   }
   ```

2. **Update `getFoodsForPhase()` to use arrays** (Lines 168-283):
   ```typescript
   // ✅ NEW APPROACH - Query foods by category array
   async function getFoodsForPhase(supabase, phase, deviceId, likedFoods, willTryFoods, dislikedFoods, activityType = 'running') {
     // Map phase to category enum value
     const categoryName = phase === "before" ? "before_run"
                        : phase === "after" ? "after_run"
                        : "during_run";

     // STEP 1: Get generic foods where categories array contains this category
     const { data: genericFoods, error: foodsError } = await supabase
       .from("foods")
       .select(`
         id, name, display_name, display_name_plural, image_address, description,
         calories_per_serving, carbs_per_serving, protein_per_serving,
         fat_per_serving, sodium_mg, fluid_ml_per_serving, serving_amount,
         max_servings_before, max_servings_during, max_servings_after,
         is_electrolyte, to_exclude_from_solver, is_essential,
         categories, activity_types
       `)
       .contains('categories', [categoryName])  // Array contains operator
       .or(`activity_types.is.null,activity_types.cs.{${activityType}}`);  // Array overlap operator

     // STEP 2: Get user foods with same array filtering
     const { data: userFoods, error: userFoodsError } = await supabase
       .from("user_foods")
       .select(`
         id, name, display_name, display_name_plural, image_address, description,
         calories_per_serving, carbs_per_serving, protein_per_serving,
         fat_per_serving, sodium_mg, fluid_ml_per_serving, serving_amount,
         is_electrolyte, to_exclude_from_solver, is_deleted,
         categories, activity_types, product_type
       `)
       .eq("device_id", deviceId)
       .eq("is_deleted", false)
       .contains('categories', [categoryName])  // Use array operator
       .or(`activity_types.is.null,activity_types.cs.{${activityType}}`);

     // STEP 3: Get essential foods
     const { data: essentialFoods } = await supabase
       .from("foods")
       .select('*')
       .eq("is_essential", true);

     // Combine and deduplicate
     const allFoods = [...(genericFoods || []), ...(userFoods || []), ...(essentialFoods || [])];
     return allFoods;
   }
   ```

3. **Remove `product_type_id` references** (Lines 227, 244):
   ```typescript
   // ❌ CHANGE FROM:
   serving_amount, product_type_id,

   // ✅ CHANGE TO:
   serving_amount, product_type,
   ```

**Testing**:
```bash
# Deploy and test
supabase functions deploy generate-nutrition-plan --project-ref wvmvsodrvbkxfydabqed

# Test with curl
curl -X POST 'https://wvmvsodrvbkxfydabqed.supabase.co/functions/v1/generate-nutrition-plan' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "device_id": "TEST_DEVICE",
    "distance_miles": 10,
    "pace_minutes_per_mile": 9,
    "time_before_run_hours": 2,
    "activity_type": "running"
  }'
```

**Success Criteria**:
- ✅ Logs show "Found 15+ generic foods" (not just 2 essential)
- ✅ LP solver finds feasible solution
- ✅ Returns nutrition plan with 6+ food items

---

#### Task 1.2: Fix `create-nutrition-plan/index.ts`
**Priority**: 🔴 CRITICAL
**Complexity**: Medium
**Est. Time**: 45 minutes

**Changes Required**:
1. **Update food query** (Lines 70-79):
   ```typescript
   // ❌ CHANGE FROM:
   const { data: foods, error: foodsError } = await supabaseClient
     .from('foods')
     .select(`
       *,
       food_categories (category_id)  // ❌ Junction table query
     `)

   // ✅ CHANGE TO:
   const { data: foods, error: foodsError } = await supabaseClient
     .from('foods')
     .select('*')  // Categories already in the row as array
   ```

2. **Update `selectFoodsForPlan()` to use array** (Lines 258-295):
   ```typescript
   // ✅ NEW - Check if array contains category
   const foodBelongsToCategory = (food, categoryName) => {
     return food.categories?.includes(categoryName);
   };

   // Filter foods by category name (not ID)
   const preRunFoods = foods.filter(f => foodBelongsToCategory(f, 'before_run'));
   const duringRunFoods = foods.filter(f => foodBelongsToCategory(f, 'during_run'));
   const postRunFoods = foods.filter(f => foodBelongsToCategory(f, 'after_run'));
   ```

**Testing**:
```bash
supabase functions deploy create-nutrition-plan --project-ref wvmvsodrvbkxfydabqed
```

---

#### Task 1.3: Fix `get-foods/index.ts`
**Priority**: 🟡 MEDIUM (fallback function)
**Complexity**: Low
**Est. Time**: 30 minutes

**Changes Required**:
1. **Simplify query** (Lines 45-67):
   ```typescript
   // ✅ NEW - No joins needed
   const { data, error } = await supabaseClient
     .from('foods')
     .select('*')
     .contains('categories', [categoryId]);  // If category filter needed
   ```

---

#### Task 1.4: Fix `save-user-food/index.ts`
**Priority**: 🟡 MEDIUM
**Complexity**: Low
**Est. Time**: 15 minutes

**Changes Required**:
1. **Change column name** (Line 56):
   ```typescript
   // ❌ CHANGE FROM:
   product_type_id: requestData.product_type_id,

   // ✅ CHANGE TO:
   product_type: requestData.product_type,
   ```

---

### Phase 2: Client Food Repository Fixes 🔴 CRITICAL (1 hour)

**Goal**: Fix client-side food parsing to handle array columns.

#### Task 2.1: Fix Food Repository Parsing
**File**: `lib/features/nutrition_plan/data/food_repository.dart`
**Priority**: 🔴 CRITICAL
**Complexity**: Medium
**Est. Time**: 45 minutes

**Changes Required**:
1. **Update `_syncFoodsToLocalDatabase()`** (around line 785):
   ```dart
   // ✅ PARSE ARRAYS CORRECTLY
   Future<void> _syncFoodsToLocalDatabase(List<Map<String, dynamic>> foods) async {
     for (final food in foods) {
       try {
         final companion = FoodsTableCompanion(
           id: Value(food['id'] as String),
           name: Value(food['name'] as String),
           // ... other fields ...

           // ✅ NEW - Parse category array
           categories: Value(
             (food['categories'] as List<dynamic>?)
               ?.map((e) => e.toString())
               .join(',') ?? ''
           ),

           // ✅ NEW - Parse activity_types array
           activityTypes: Value(
             (food['activity_types'] as List<dynamic>?)
               ?.map((e) => e.toString())
               .join(',')
           ),

           // ✅ CHANGE product_type_id → product_type
           productType: Value(food['product_type'] as String?),
         );

         await db.into(db.foodsTable).insertOnConflictUpdate(companion);
       } catch (e, stack) {
         _logger.error(
           '[FoodRepository] Error syncing food',
           error: e,
           stackTrace: stack,
           data: {'food_id': food['id'], 'food_name': food['name']},
         );
       }
     }
   }
   ```

2. **Update Food model** if needed:
   ```dart
   // Check if Food domain model needs category array field
   // May need to add: List<String>? categories;
   ```

**Testing**:
```bash
# Run app and check logs
flutter run

# Look for success:
# ✅ [FOOD_REPOSITORY] Syncing nutrition foods: 31 foods
# ✅ [FOOD_REPOSITORY] Nutrition foods sync completed
```

---

### Phase 3: Drift Schema Updates 🟡 MEDIUM (30 minutes)

**Goal**: Align Drift SQLite schema with production array columns.

#### Task 3.1: Update Foods Table
**File**: `lib/shared/database/tables/foods_table.dart`
**Priority**: 🟡 MEDIUM
**Complexity**: Low
**Est. Time**: 15 minutes

**Changes Required**:
```dart
class FoodsTable extends Table {
  // ... existing fields ...

  // ✅ ADD array column support
  TextColumn get categories => text().withDefault(const Constant(''))();
  TextColumn get activityTypes => text().nullable()();

  // ✅ CHANGE product_type
  TextColumn get productType => text().nullable()();  // Stores enum value
}
```

**Note**: Drift doesn't support arrays natively, so store as comma-separated or JSON string.

---

#### Task 3.2: Update User Foods Table
**File**: `lib/shared/database/tables/user_foods_table.dart`
**Priority**: 🟡 MEDIUM
**Complexity**: Low
**Est. Time**: 15 minutes

**Changes Required**:
```dart
class UserFoodsTable extends Table {
  // ... existing fields ...

  // ✅ ADD array columns
  TextColumn get categories => text().withDefault(const Constant(''))();
  TextColumn get activityTypes => text().nullable()();

  // ✅ CHANGE column name
  TextColumn get productType => text().nullable()();
}
```

**After Changes**:
```bash
# Regenerate Drift code
dart run build_runner build --delete-conflicting-outputs

# Generate schema snapshot
dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v1/
```

---

### Phase 4: Testing & Validation 🟢 LOW (1 hour)

#### Task 4.1: Integration Testing
**Priority**: 🟢 LOW
**Est. Time**: 30 minutes

**Test Cases**:
1. **Fresh Install Flow**:
   - Onboard new user
   - Complete food preferences
   - Verify food sync shows 30+ foods
   - Create activity
   - Generate nutrition plan
   - Verify plan has 6+ food items with names

2. **Existing User Flow**:
   - Open app with existing data
   - Verify foods still in database
   - Generate new nutrition plan
   - Verify plan generation works

3. **Edge Cases**:
   - User with custom foods
   - User with all foods disliked
   - Multi-sport activities (cycling, swimming)

---

#### Task 4.2: Monitoring & Rollback Plan
**Priority**: 🟢 LOW
**Est. Time**: 30 minutes

**Monitoring**:
```sql
-- Check food counts in production
SELECT
  COUNT(*) as total_foods,
  COUNT(*) FILTER (WHERE is_essential = true) as essential_foods,
  COUNT(*) FILTER (WHERE 'before_run' = ANY(categories)) as before_run_foods,
  COUNT(*) FILTER (WHERE 'during_run' = ANY(categories)) as during_run_foods,
  COUNT(*) FILTER (WHERE 'after_run' = ANY(categories)) as after_run_foods
FROM foods;

-- Verify array columns have data
SELECT id, name, categories, activity_types
FROM foods
WHERE categories IS NULL OR cardinality(categories) = 0
LIMIT 10;
```

**Rollback Plan**:
1. Keep backup of old edge function code in git
2. If issues arise, redeploy previous version:
   ```bash
   git checkout <previous-commit>
   supabase functions deploy generate-nutrition-plan --project-ref wvmvsodrvbkxfydabqed
   ```

---

## Estimated Timeline

| Phase | Tasks | Est. Time | Priority |
|-------|-------|-----------|----------|
| Phase 1: Edge Functions | 4 tasks | 2-3 hours | 🔴 CRITICAL |
| Phase 2: Client Fixes | 1 task | 1 hour | 🔴 CRITICAL |
| Phase 3: Drift Schema | 2 tasks | 30 minutes | 🟡 MEDIUM |
| Phase 4: Testing | 2 tasks | 1 hour | 🟢 LOW |
| **TOTAL** | **9 tasks** | **4.5-5.5 hours** | |

---

## PostgreSQL Array Operators Reference

For edge function queries, use these PostgreSQL array operators:

| Operator | Syntax | Example | Description |
|----------|--------|---------|-------------|
| `@>` | `contains` | `.contains('categories', ['before_run'])` | Array contains element(s) |
| `&&` | `overlaps` | `.overlaps('categories', ['before_run', 'during_run'])` | Arrays have common elements |
| `<@` | `containedBy` | `.containedBy('categories', ['before_run'])` | Array is subset of |
| `=` | `eq` | `.eq('categories', ['before_run'])` | Exact array match |

**Supabase JS Examples**:
```typescript
// Contains single category
.contains('categories', ['before_run'])

// Contains any of multiple categories
.overlaps('categories', ['before_run', 'during_run'])

// Check if activity_types contains 'running'
.contains('activity_types', ['running'])

// OR condition for null or contains
.or(`activity_types.is.null,activity_types.cs.{running}`)
```

---

## Success Metrics

**Before Fix**:
- ❌ Nutrition plans generated: 0%
- ❌ Foods synced to client: 0/31 (0%)
- ❌ Food lookups successful: 0%
- ❌ User satisfaction: Blocked

**After Fix**:
- ✅ Nutrition plans generated: 100%
- ✅ Foods synced to client: 31/31 (100%)
- ✅ Food lookups successful: 100%
- ✅ Macro targets within ±10% tolerance: 95%+
- ✅ User satisfaction: Unblocked

---

## Related Documentation

- **Phase 0 Migration**: [/docs/refactoring/archive/PHASE-1-DATABASE-COMPLETE.md](/docs/refactoring/archive/PHASE-1-DATABASE-COMPLETE.md)
- **Production Schema**: [/docs/prod_schema.txt](/docs/prod_schema.txt) (lines 182-184, 234-240, 590-591)
- **Sync-All-Data Fix**: [/docs/refactoring/SYNC-ALL-DATA-PRODUCTION-FIX.md](/docs/refactoring/SYNC-ALL-DATA-PRODUCTION-FIX.md)
- **Edge Functions Audit**: [/docs/refactoring/EDGE_FUNCTIONS_AUDIT.md](/docs/refactoring/EDGE_FUNCTIONS_AUDIT.md)

---

## Next Steps

1. **Immediate**: Start with Phase 1, Task 1.1 (`generate-nutrition-plan`)
2. **Quick Win**: Complete Task 1.4 (`save-user-food`) - only 1 line change
3. **Parallel Work**: Tasks 1.2 and 1.3 can be done in parallel with 1.1
4. **Test Early**: Run integration tests after Phase 1 completes
5. **Deploy Incrementally**: Deploy one function at a time, test, then move to next

---

*This roadmap will be updated as tasks are completed. Mark sections with ✅ when done.*
