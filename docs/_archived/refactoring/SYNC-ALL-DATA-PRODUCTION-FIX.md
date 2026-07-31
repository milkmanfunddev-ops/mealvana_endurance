# Sync-All-Data Production Fix
*Date: 2025-11-16*
*Status: ✅ DEPLOYED*

## Issue

The `sync-all-data` edge function was crashing in production with schema cache errors:

```
✗ nutrition_foods: Could not find a relationship between 'foods' and 'food_categories' in the schema cache
✗ carb_loading_foods: Could not find a relationship between 'carb_loading_foods' and 'carb_loading_food_meal_types' in the schema cache
✗ meal_types: Could not find the table 'public.meal_types' in the schema cache
```

## Root Cause

During the **Phase 0 Schema Simplification** refactoring (documented in `/docs/refactoring/archive/PHASE-1-DATABASE-COMPLETE.md`), the production schema was migrated from using junction tables to using PostgreSQL array columns:

### Tables Removed (Phase 0)
- ❌ `food_categories` (junction table)
- ❌ `categories` (lookup table)
- ❌ `meal_types` (lookup table)
- ❌ `carb_loading_food_meal_types` (junction table)
- ❌ `user_food_categories` (junction table)
- ❌ 3 other junction tables

### New Array Column Architecture
Instead of junction tables, the schema now uses PostgreSQL array columns:

**`foods` table:**
```sql
categories     category_enum[]      default '{}'::category_enum[]
activity_types activity_type_enum[]  -- Nullable array
```

**`carb_loading_foods` table:**
```sql
meal_types text[] default '{}'::text[]
```

**`carb_loading_user_foods` table:**
```sql
meal_types text[] default '{}'::text[]
```

However, the `sync-all-data` edge function was still trying to query the old junction tables and perform transformations.

## Solution

Updated `/supabase/functions/sync-all-data/index.ts` to match the new array-based schema:

### Before (Broken)
```typescript
// Tried to join with deleted tables
supabaseClient
  .from('foods')
  .select(`
    *,
    food_categories(category_id),
    categories(*)
  `),

// Tried to join with deleted junction table
supabaseClient
  .from('carb_loading_foods')
  .select(`
    *,
    carb_loading_food_meal_types!inner(
      meal_type_id,
      meal_types(*)
    )
  `),

// Tried to query deleted table
supabaseClient
  .from('meal_types')
  .select('*'),

// Tried to transform non-existent junction table data
response.data.carb_loading_foods = response.data.carb_loading_foods.map((food: any) => {
  const mealTypeIds = food.carb_loading_food_meal_types?.map((mt: any) => mt.meal_type_id) || [];
  // ...
});
```

### After (Fixed)
```typescript
// Simple select - arrays are already in the columns
supabaseClient
  .from('foods')
  .select('*'),

// Simple select - meal_types is already a text[] column
supabaseClient
  .from('carb_loading_foods')
  .select('*'),

// Removed meal_types query entirely - table doesn't exist

// Removed transformation - array is already in correct format
// Note: carb_loading_foods now has meal_types as a text[] column
// No transformation needed - the array is already in the correct format
```

## Changes Made

### 1. Removed Deleted Table Queries
- ❌ Removed `food_categories` join from foods query
- ❌ Removed `categories` join from foods query
- ❌ Removed `meal_types` standalone query
- ❌ Removed `carb_loading_food_meal_types` join from carb loading foods query

### 2. Simplified Data Extraction
- ✅ Foods query now returns `categories` and `activity_types` as arrays directly
- ✅ Carb loading foods query returns `meal_types` as text array directly
- ✅ Removed junction table data transformation logic
- ✅ Updated array destructuring to match new Promise.allSettled signature

### 3. Updated Comments
Added clarifying comments:
```typescript
// 1. Nutrition Plan Foods (all foods with categories and activity_types as arrays)
// 2. Carb Loading Foods (meal_types is now a text[] column)
// Note: carb_loading_foods now has meal_types as a text[] column
// No transformation needed - the array is already in the correct format
```

## Deployment

```bash
supabase functions deploy sync-all-data --project-ref wvmvsodrvbkxfydabqed
```

**Result**: ✅ Successfully deployed (script size: 73.61kB)

## Impact

### Before Fix
- ❌ `sync-all-data` function crashed on every call
- ❌ Users couldn't sync their data
- ❌ Logs showed 3 schema cache errors on every request
- ❌ Edge function returned partial data with errors

### After Fix
- ✅ Function queries only tables that exist
- ✅ Array columns returned directly without transformation
- ✅ No schema cache errors
- ✅ Full data sync works correctly
- ✅ Performance improved (fewer queries, no joins needed)

## Benefits of Array Columns

1. **Simpler Schema**: No need for junction tables and complex joins
2. **Better Performance**: Single table query instead of joins
3. **Easier Sync**: Arrays serialize directly to JSON
4. **Atomic Updates**: Updating categories is a single column update
5. **PostgreSQL Features**: Can use array operators (`@>`, `&&`, `ANY`)

## Related Documentation

- **Phase 0 Migration**: `/docs/refactoring/archive/PHASE-1-DATABASE-COMPLETE.md`
- **Schema Status**: `/docs/refactoring/phase0/database_status.md`
- **Production Schema**: `/docs/prod_schema.txt` (lines 182-184: foods.categories array, line 590: carb_loading_foods.meal_types array)
- **Roadmaps**: `/docs/refactoring/ROADMAPS.md`

## Testing

To verify the fix works:

```bash
# Call the function with a test user_id
curl -X POST 'https://wvmvsodrvbkxfydabqed.supabase.co/functions/v1/sync-all-data' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"user_id": "YOUR_USER_ID"}'
```

Expected response:
```json
{
  "success": true,
  "timestamp": "2025-11-16T...",
  "data": {
    "nutrition_foods": [...],  // Should have data
    "carb_loading_foods": [...],  // Should have meal_types as text[]
    "activities": [...],
    "events": [...],
    "carb_loading_plans": [...],
    "carb_loading_days": [...]
  },
  "errors": {}  // Should be empty!
}
```

## Notes

- The client code (Flutter Drift) already expects array columns, so no client changes needed
- Dev and prod schemas now aligned on array column approach
- Future edge functions should query arrays directly, not junction tables
- Migration from junction tables to arrays was completed in Phase 0 (2025-11-09)

---

**Status**: ✅ **RESOLVED** - Production sync-all-data function now matches production schema
