# Database Schema Changes - December 14, 2025

## Overview

Added dietary preference and allergy support to the Mealvana Endurance database schema to enable personalized food filtering based on user dietary restrictions and allergies.

## Migration Details

**Migration File**: `/supabase/migrations/20251214120000_add_dietary_preference_and_allergies.sql`

**Environments**:
- ✅ **Production (Supabase)**: Applied December 14, 2025
- ✅ **Development (Drift)**: Applied December 14, 2025

**Schema Version**: v1 (non-breaking additions)

## Changes Summary

### 1. New Enum Types

#### `dietary_preference_enum`
Single-select enum for user dietary preferences:
- `omnivore` - No dietary restrictions
- `vegetarian` - No meat
- `pescatarian` - Fish allowed, no other meat
- `vegan` - No animal products
- `mediterranean` - Mediterranean diet pattern
- `paleo` - Paleo diet pattern
- `keto` - Ketogenic diet pattern
- `low_carb` - Low carbohydrate diet pattern

**Purpose**: Allows users to specify their dietary preference during onboarding for personalized food filtering.

#### `allergy_enum`
Multi-select enum for common food allergens:
- `dairy` - Milk and dairy products
- `eggs` - Eggs and egg products
- `fish` - Fish and fish products
- `gluten` - Wheat, barley, rye (gluten-containing grains)
- `peanuts` - Peanuts and peanut products
- `sesame` - Sesame seeds and sesame products
- `shellfish` - Shellfish and shellfish products
- `soy` - Soy and soy products
- `tree_nuts` - Tree nuts (almonds, walnuts, cashews, etc.)

**Purpose**: Tracks user allergies for safety-critical food filtering.

### 2. Users Table Changes

#### New Columns

**`dietary_preference`** (dietary_preference_enum, nullable)
- User's dietary preference selection from onboarding
- NULL means no preference set (shows all foods)
- Single-select value

**`allergies`** (allergy_enum[], default '{}')
- Array of user allergies
- Empty array means no allergies
- Multi-select values

#### New Index

**`idx_users_dietary_preference`**
- Partial index on `dietary_preference WHERE dietary_preference IS NOT NULL`
- Optimizes queries filtering users by dietary preference
- Uses B-tree index (standard for enum comparisons)

### 3. Foods Table Changes

#### New Columns

**`allergens`** (allergy_enum[], default '{}')
- Array of allergens contained in this food
- Used to exclude foods when user has matching allergies
- Example: `{dairy, gluten}` for a food containing milk and wheat

**`excluded_diets`** (dietary_preference_enum[], default '{}')
- Array of dietary preferences that should exclude this food
- Used to hide foods incompatible with user's diet
- Example: `{vegan, vegetarian}` for a food containing meat

#### New Indexes

**`idx_foods_allergens_gin`**
- GIN index on `allergens` array column
- Enables efficient array containment queries
- Optimizes filtering foods by user allergies

**`idx_foods_excluded_diets_gin`**
- GIN index on `excluded_diets` array column
- Enables efficient array containment queries
- Optimizes filtering foods by user dietary preference

## Database Implementation

### Supabase (PostgreSQL)

Uses native PostgreSQL features:
- Enum types: `CREATE TYPE dietary_preference_enum AS ENUM (...)`
- Array types: `allergy_enum[]`
- GIN indexes: `CREATE INDEX ... USING gin (allergens)`

### Drift (SQLite)

Uses PostgreSQL-compatible implementations:
- Enums: TEXT columns with CHECK constraints
- Arrays: TEXT columns with PostgreSQL array format (`'{dairy,gluten}'`)
- Indexes: Standard indexes (GIN not supported in SQLite)

## Query Examples

### Filtering Foods by User Allergies

**Supabase (PostgreSQL)**:
```sql
-- Exclude foods containing user's allergens
SELECT * FROM foods
WHERE NOT (allergens && ARRAY['dairy', 'gluten']::allergy_enum[]);
```

**Dart/Supabase Client**:
```dart
final userAllergies = ['dairy', 'gluten'];
final safeFoods = await supabase
  .from('foods')
  .select()
  .not('allergens', 'cs', '{${userAllergies.join(',')}}');
```

### Filtering Foods by Dietary Preference

**Supabase (PostgreSQL)**:
```sql
-- Exclude foods not suitable for vegan diet
SELECT * FROM foods
WHERE NOT ('vegan' = ANY(excluded_diets));
```

**Dart/Supabase Client**:
```dart
final userDiet = 'vegan';
final suitableFoods = await supabase
  .from('foods')
  .select()
  .not('excluded_diets', 'cs', '{$userDiet}');
```

### Combined Filtering

**Dart Example**:
```dart
// Get foods safe for user's diet and allergies
final safeFoods = await supabase
  .from('foods')
  .select()
  .not('allergens', 'cs', '{${userAllergies.join(',')}}')
  .not('excluded_diets', 'cs', '{$userDiet}');
```

## Business Logic Impact

### Onboarding Flow
- Users can now select dietary preference (single-select)
- Users can now select allergies (multi-select)
- Both fields are optional (users can skip)

### Food Filtering
- Foods are automatically filtered based on user's dietary preference
- Foods are automatically excluded if they contain user's allergens
- Filtering is safety-critical for allergies

### Food Database Management
- Admin can mark foods with allergens (e.g., protein bars with peanuts)
- Admin can mark foods as excluded from specific diets (e.g., meat excluded from vegan)
- Both fields are optional (empty arrays by default)

## Performance Considerations

### Index Strategy

**GIN Indexes** (PostgreSQL only):
- Optimized for array containment queries (`&&`, `@>`, `<@` operators)
- Essential for efficient filtering with multiple allergies/diets
- Trade-off: Slower writes, faster reads (acceptable for read-heavy food database)

**Partial Index on dietary_preference**:
- Only indexes non-NULL values
- Reduces index size since many users may not set a preference
- Optimizes common query pattern (filtering users by preference)

### Query Performance

**Expected Performance**:
- Food filtering by allergies: O(log n) with GIN index
- Food filtering by diet: O(log n) with GIN index
- User filtering by preference: O(log n) with partial B-tree index

**Worst Case**:
- No indexes: O(n) table scan
- With indexes: < 10ms for typical queries (< 1000 foods)

## Data Migration

### Existing Data

**Users Table**:
- All existing users have `dietary_preference = NULL` (no preference)
- All existing users have `allergies = '{}'` (no allergies)
- Users will populate these fields during next onboarding interaction

**Foods Table**:
- All existing foods have `allergens = '{}'` (no allergens marked)
- All existing foods have `excluded_diets = '{}'` (suitable for all diets)
- Admin will populate these fields via database seeding/updates

### Backward Compatibility

**Breaking Changes**: None
- All new columns are nullable or have default values
- Existing queries continue to work unchanged
- New filtering is opt-in (only applies when user sets preferences)

## Testing Recommendations

### Unit Tests
- Test enum value validation (valid/invalid values)
- Test array operations (add/remove allergens)
- Test NULL handling (no preference set)

### Integration Tests
- Test food filtering with various allergy combinations
- Test food filtering with various dietary preferences
- Test combined filtering (allergies + diet)
- Test edge cases (empty arrays, NULL values)

### Performance Tests
- Test query performance with 1000+ foods
- Verify GIN index usage in query plans
- Test filtering with multiple allergies (5+ items)

## Documentation Updates

Updated files:
- ✅ `/docs/prod_schema.txt` - Added enum types, columns, indexes, and comments
- ✅ `/docs/database/README.md` - Added enum types section and dietary preferences overview
- ✅ `/docs/database/supabase/README.md` - Added recent schema changes and query examples
- ✅ `/docs/database/SCHEMA_CHANGES_2025-12-14.md` - This document

## Rollback Plan

If issues are discovered:

1. **Remove user data** (safe, no existing data):
   ```sql
   ALTER TABLE users DROP COLUMN dietary_preference;
   ALTER TABLE users DROP COLUMN allergies;
   ```

2. **Remove food data** (safe, no existing data):
   ```sql
   ALTER TABLE foods DROP COLUMN allergens;
   ALTER TABLE foods DROP COLUMN excluded_diets;
   ```

3. **Remove indexes**:
   ```sql
   DROP INDEX idx_users_dietary_preference;
   DROP INDEX idx_foods_allergens_gin;
   DROP INDEX idx_foods_excluded_diets_gin;
   ```

4. **Remove enum types**:
   ```sql
   DROP TYPE dietary_preference_enum;
   DROP TYPE allergy_enum;
   ```

**Note**: Rollback is safe since all new columns have default values and no existing data depends on them.

## Next Steps

### Immediate
1. ✅ Apply migration to production Supabase
2. ✅ Update Drift schema to match
3. ✅ Update documentation
4. 🔲 Seed foods table with allergen data
5. 🔲 Seed foods table with excluded_diets data

### Short Term
1. Update onboarding UI to collect dietary preference
2. Update onboarding UI to collect allergies
3. Implement food filtering logic in nutrition plan service
4. Add allergy warnings in food selection UI

### Long Term
1. Add user education about allergen information accuracy
2. Add admin interface for managing food allergens
3. Consider adding custom allergen types (user-defined)
4. Consider adding severity levels for allergies

---

**Migration Completed**: December 14, 2025
**Schema Version**: v1 (non-breaking additions)
**Status**: ✅ Production Ready
