# Foods Database Diagnostic Queries

## Issue: Edge Function Finding 0 Generic Foods

The `generate-nutrition-plan` edge function is returning 0 generic foods, only finding 2 essential foods (water and salt). This causes the LP solver to fail.

## Root Cause Analysis

The edge function query filters foods by:
```typescript
.filter('categories', 'cs', `{${categoryName}}`)
.or(`activity_types.is.null,activity_types.cs.{${activityType}}`)
```

Where:
- `categoryName` is one of: "before_run", "during_run", "after_run"
- `activityType` is typically "running"
- `cs` is the "contains" operator for PostgreSQL arrays

## Diagnostic Queries

### 1. Check if foods table has any rows
```sql
SELECT COUNT(*) as total_foods FROM foods;
```

### 2. Check if categories column is populated
```sql
SELECT
  COUNT(*) as total_foods,
  COUNT(CASE WHEN categories IS NOT NULL THEN 1 END) as has_categories,
  COUNT(CASE WHEN categories IS NULL THEN 1 END) as null_categories
FROM foods;
```

### 3. Check category values distribution
```sql
SELECT
  categories,
  COUNT(*) as food_count
FROM foods
WHERE categories IS NOT NULL
GROUP BY categories
ORDER BY food_count DESC
LIMIT 20;
```

### 4. Check if foods have the expected categories
```sql
-- Foods suitable for before run
SELECT
  name,
  categories,
  activity_types,
  to_exclude_from_solver
FROM foods
WHERE categories @> ARRAY['before_run']::text[]
LIMIT 10;

-- Foods suitable for during run
SELECT
  name,
  categories,
  activity_types,
  to_exclude_from_solver
FROM foods
WHERE categories @> ARRAY['during_run']::text[]
LIMIT 10;

-- Foods suitable for after run
SELECT
  name,
  categories,
  activity_types,
  to_exclude_from_solver
FROM foods
WHERE categories @> ARRAY['after_run']::text[]
LIMIT 10;
```

### 5. Check if foods are excluded from solver
```sql
SELECT
  COUNT(*) as total_foods,
  COUNT(CASE WHEN to_exclude_from_solver = true THEN 1 END) as excluded_foods,
  COUNT(CASE WHEN to_exclude_from_solver = false OR to_exclude_from_solver IS NULL THEN 1 END) as available_foods
FROM foods;
```

### 6. Check essential foods
```sql
SELECT
  name,
  is_essential,
  categories,
  activity_types
FROM foods
WHERE is_essential = true;
```

### 7. Full diagnostic query (combined)
```sql
SELECT
  id,
  name,
  categories,
  activity_types,
  to_exclude_from_solver,
  is_essential,
  is_electrolyte,
  show_in_preferences,
  CASE
    WHEN categories @> ARRAY['before_run']::text[] THEN 'YES'
    ELSE 'NO'
  END as before_run_suitable,
  CASE
    WHEN categories @> ARRAY['during_run']::text[] THEN 'YES'
    ELSE 'NO'
  END as during_run_suitable,
  CASE
    WHEN categories @> ARRAY['after_run']::text[] THEN 'YES'
    ELSE 'NO'
  END as after_run_suitable
FROM foods
WHERE to_exclude_from_solver = false OR to_exclude_from_solver IS NULL
ORDER BY name
LIMIT 50;
```

## Expected Results

A properly configured foods table should have:
- Multiple foods with `categories` containing "before_run", "during_run", or "after_run"
- `activity_types` either NULL or containing "running"
- `to_exclude_from_solver` set to false or null
- Essential foods (water, salt) with `is_essential = true`

## Possible Solutions

### Solution 1: Re-seed Foods Data
If foods are missing or have null categories, you may need to re-run the food seeding migration:
```bash
# Check if seed migration exists
ls supabase/migrations/*seed_core_data.sql

# Apply it to production
supabase db push --linked
```

### Solution 2: Manual Category Assignment
If specific foods are missing categories, you can manually update them:
```sql
-- Example: Update bananas to be suitable for all phases
UPDATE foods
SET categories = ARRAY['before_run', 'during_run', 'after_run']::text[]
WHERE name = 'Bananas';

-- Example: Update energy gels to be during-run only
UPDATE foods
SET categories = ARRAY['during_run']::text[]
WHERE name LIKE '%Gel%';
```

### Solution 3: Check Production vs Dev Schema Parity
There may be a schema mismatch between development and production:
```bash
# Compare schemas
supabase db diff --linked
```

## Running These Queries

### Via Supabase Dashboard
1. Go to https://supabase.com/dashboard/project/wvmvsodrvbkxfydabqed
2. Navigate to SQL Editor
3. Paste and run queries

### Via CLI
```bash
# Set up connection (if not already linked)
supabase link --project-ref wvmvsodrvbkxfydabqed

# Run query
supabase db execute --linked "SELECT COUNT(*) FROM foods;"
```

## Related Issues

- Missing `is_essential` column in Drift schema (FIXED in this commit)
- Schema mismatch between old `food_categories` table and new `categories` array column
- Production environment may need migration to populate `categories` and `activity_types`
