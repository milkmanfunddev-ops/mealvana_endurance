# Foods Table Simplification Roadmap

## Overview

This roadmap outlines the migration from complex serving unit logic to a simplified display-name approach for the foods table. This change will significantly reduce complexity across the entire codebase while improving user experience with more natural language food descriptions.

## Current Problem

The current foods table uses a complex serving unit system with multiple fields that creates unnecessary complexity:
- `serving_unit` (e.g., "cup")
- `serving_unit_plural` (e.g., "cups")
- `serving_qualifier` (e.g., "cooked")
- `serving_size` (legacy field)
- `display_override` (override mechanism)

This requires complex logic throughout the codebase to format quantities like "2 cups, cooked" and creates multiple failure points.

## Proposed Solution

Simplify to a display-name approach where:
- `serving_amount` is always 1.0 for simplicity
- `display_name` contains the full description (e.g., "cup cooked oatmeal")
- `display_name_plural` contains the plural form (e.g., "cups cooked oatmeal")
- Quantity formatting becomes: `${quantity} ${quantity === 1 ? display_name : display_name_plural}`

## Schema Changes

### Current Schema
```sql
create table public.foods
(
    id                     uuid                     default gen_random_uuid() not null primary key,
    name                   text,
    image_address          text,
    created_at             timestamp with time zone default now(),
    serving_amount         numeric,
    serving_unit           text,                    -- TO REMOVE
    serving_unit_plural    text,                    -- TO REMOVE
    serving_qualifier      text,                    -- TO REMOVE
    max_servings_before    integer,
    max_servings_during    integer,
    serving_size           text,                    -- TO REMOVE
    sodium_mg              integer,
    caffeine_mg            integer,
    potassium_mg           integer,
    fat_per_serving        numeric(10, 2),
    carbs_per_serving      numeric(10, 2),
    protein_per_serving    numeric(10, 2),
    calories_per_serving   integer,
    fluid_ml_per_serving   numeric(10, 1),
    brand_id               uuid references public.brands,
    product_type           text constraint foods_product_type_check
                          check (product_type = ANY (ARRAY ['gel'::text, 'chew'::text, 'drink_mix'::text, 'electrolyte_only'::text, 'sports_drink'::text, 'bar'::text, 'waffle'::text, 'capsule'::text, 'real_food'::text, 'recovery_shake'::text])),
    show_in_preferences    boolean                  default false,
    display_name           varchar(100),
    max_servings_after     integer,
    is_electrolyte         boolean                  default false,
    display_name_plural    varchar(100),
    to_exclude_from_solver boolean                  default false,
    display_override       varchar(100)             -- TO REMOVE
);
```

### Target Schema
```sql
create table public.foods
(
    id                     uuid                     default gen_random_uuid() not null primary key,
    name                   text,
    image_address          text,
    created_at             timestamp with time zone default now(),
    serving_amount         numeric,                 -- Always 1.0 for simplicity
    max_servings_before    integer,
    max_servings_during    integer,
    sodium_mg              integer,
    caffeine_mg            integer,
    potassium_mg           integer,
    fat_per_serving        numeric(10, 2),
    carbs_per_serving      numeric(10, 2),
    protein_per_serving    numeric(10, 2),
    calories_per_serving   integer,
    fluid_ml_per_serving   numeric(10, 1),
    brand_id               uuid references public.brands,
    product_type           text constraint foods_product_type_check
                          check (product_type = ANY (ARRAY ['gel'::text, 'chew'::text, 'drink_mix'::text, 'electrolyte_only'::text, 'sports_drink'::text, 'bar'::text, 'waffle'::text, 'capsule'::text, 'real_food'::text, 'recovery_shake'::text])),
    show_in_preferences    boolean                  default false,
    display_name           varchar(100),            -- "cup cooked oatmeal"
    max_servings_after     integer,
    is_electrolyte         boolean                  default false,
    display_name_plural    varchar(100),            -- "cups cooked oatmeal"
    to_exclude_from_solver boolean                  default false
);
```

### Columns to Remove
- `serving_unit`
- `serving_unit_plural`
- `serving_qualifier`
- `serving_size`
- `display_override`

## Implementation Roadmap

### Phase 1: Data Preparation ⏳
**Objective**: Prepare existing data for migration

#### Tasks:
1. **Audit Current Data**
   - [ ] Export current foods with serving unit combinations
   - [ ] Identify unique serving unit + qualifier combinations
   - [ ] Create mapping of current foods to new display names

2. **Populate Display Names**
   - [ ] Write SQL script to populate `display_name` and `display_name_plural` from existing `serving_unit`, `serving_qualifier` combinations
   - [ ] Manually review and refine generated display names
   - [ ] Ensure all foods have proper display names before proceeding

3. **Backup Strategy**
   - [ ] Create backup of foods table
   - [ ] Document rollback procedure

### Phase 2: Code Updates 🔧
**Objective**: Update all application code to use simplified approach

#### Frontend (Flutter/Dart)
1. **Domain Models**
   - [ ] Update `lib/features/nutrition_plan/domain/food.dart`
     - Remove: `servingUnit`, `servingUnitPlural`, `servingQualifier`, `servingSize`
     - Update `fromJson()` and `toJson()` methods
   - [ ] Update `lib/features/nutrition_plan/domain/food_item.dart`
     - Remove: `servingUnit`, `servingUnitPlural`, `servingQualifier`, `servingSize`, `displayOverride`
     - Simplify `formatQuantity()` method to use display names

2. **Database Layer**
   - [ ] Update `lib/shared/database/tables/foods_table.dart`
     - Remove column definitions for deprecated fields
   - [ ] Update `lib/shared/database/app_database.dart`
     - Remove field mappings for deprecated columns

3. **Repository Layer**
   - [ ] Update `lib/features/nutrition_plan/data/food_repository.dart`
     - Remove deprecated fields from all SQL SELECT statements
     - Update food parsing logic
     - Remove complex serving unit fallback logic

4. **Service Layer**
   - [ ] Update `lib/features/nutrition_plan/application/food_data_transformation_service.dart`
     - Remove `display_override` handling
   - [ ] Update `lib/features/barcode_scanning/application/barcode_scanner_service.dart`
     - Update `_convertFoodToDatabaseFormat()` method

#### Backend (Supabase Edge Functions)
1. **Active Edge Functions**
   - [ ] Update `supabase/functions/create-nutrition-plan/index.ts`
     - Remove serving unit fields from `FoodItem` interface
     - Simplify `createFoodItemData()` quantity formatting logic
   - [ ] Update `supabase/functions/generate-ai-nutrition-plan/index.ts`
     - Remove serving unit fields from `Food` interface
     - Update SQL queries to exclude deprecated fields
   - [ ] Update `supabase/functions/get-foods/index.ts`
     - Remove serving unit fields from response mapping
   - [ ] Update `supabase/functions/run-plan/index.ts`
     - Remove serving unit fields from interface and SQL queries

2. **Legacy/Backup Functions**
   - [ ] Update backup functions for consistency (optional)

### Phase 3: Database Schema Migration 🗄️
**Objective**: Remove deprecated columns from database

#### Database Changes
1. **Column Removal**
   ```sql
   -- Remove deprecated columns
   ALTER TABLE foods DROP COLUMN serving_unit;
   ALTER TABLE foods DROP COLUMN serving_unit_plural;
   ALTER TABLE foods DROP COLUMN serving_qualifier;
   ALTER TABLE foods DROP COLUMN serving_size;
   ALTER TABLE foods DROP COLUMN display_override;
   ```

2. **Data Validation**
   - [ ] Verify all foods have populated `display_name` and `display_name_plural`
   - [ ] Run data quality checks
   - [ ] Validate quantity formatting in test scenarios

### Phase 4: Testing & Deployment 🚀
**Objective**: Validate changes and deploy safely

#### Testing
1. **Unit Tests**
   - [ ] Update all tests referencing deprecated fields
   - [ ] Test quantity formatting logic
   - [ ] Test food parsing and serialization

2. **Integration Tests**
   - [ ] Test edge function responses
   - [ ] Test mobile app food display
   - [ ] Test nutrition plan generation

3. **Manual Testing**
   - [ ] Verify food quantities display correctly in UI
   - [ ] Test barcode scanning functionality
   - [ ] Test nutrition plan generation end-to-end

#### Deployment
1. **Staging Deployment**
   - [ ] Deploy code changes to staging
   - [ ] Run database migration on staging
   - [ ] Validate staging functionality

2. **Production Deployment**
   - [ ] Deploy edge functions
   - [ ] Deploy mobile app updates
   - [ ] Run database migration
   - [ ] Monitor for issues

### Phase 5: Documentation & Cleanup 📚
**Objective**: Update documentation and remove legacy code

#### Documentation Updates
1. **Database Documentation**
   - [ ] Update `/docs/database/supabase/tables.md`
   - [ ] Update `/docs/database/drift/schema.md`
   - [ ] Update `/docs/database/README.md`

2. **API Documentation**
   - [ ] Update edge function documentation
   - [ ] Update food model documentation

3. **Migration Documentation**
   - [ ] Document the migration process
   - [ ] Create troubleshooting guide

#### Cleanup
1. **Code Cleanup**
   - [ ] Remove commented-out legacy code
   - [ ] Remove unused imports
   - [ ] Update code comments

2. **Monitoring**
   - [ ] Monitor error rates post-deployment
   - [ ] Validate performance metrics
   - [ ] Collect user feedback

## Quantity Formatting Logic Changes

### Current Complex Logic (to be removed)
```typescript
// Calculate total amount using structured serving data
const totalAmount = quantity * food.serving_amount

// Format quantity using structured serving data
let quantityText: string
if (totalAmount === 1) {
  quantityText = `1 ${food.serving_unit}`
} else {
  const unit = food.serving_unit_plural || food.serving_unit
  if (totalAmount % 1 === 0) {
    quantityText = `${totalAmount.toFixed(0)} ${unit}`
  } else {
    quantityText = `${totalAmount.toFixed(1)} ${unit}`
  }
}

// Add qualifier if present
if (food.serving_qualifier) {
  quantityText += `, ${food.serving_qualifier}`
}
```

### New Simplified Logic
```typescript
const quantityText = `${quantity} ${quantity === 1 ? food.display_name : food.display_name_plural}`
```

## Example Data Transformation

### Before
```json
{
  "name": "Oatmeal",
  "serving_amount": 1.0,
  "serving_unit": "cup",
  "serving_unit_plural": "cups",
  "serving_qualifier": "cooked",
  "display_name": null,
  "display_name_plural": null
}
```

### After
```json
{
  "name": "Oatmeal",
  "serving_amount": 1.0,
  "display_name": "cup cooked oatmeal",
  "display_name_plural": "cups cooked oatmeal"
}
```

## Benefits

1. **Reduced Complexity**: Eliminates complex serving unit logic across 10+ files
2. **Better UX**: More natural language descriptions
3. **Easier Content Management**: Direct editing of display names
4. **Fewer Bugs**: Fewer conditional logic branches
5. **Simpler Testing**: Less edge cases to test
6. **Better Performance**: Simpler string concatenation

## Risks & Mitigation

### Risks
1. **Data Loss**: Removing columns could lose information
2. **Display Inconsistency**: Manual display name entry could be inconsistent
3. **Migration Complexity**: Multiple systems need coordinated updates

### Mitigation
1. **Backup Strategy**: Full database backup before migration
2. **Data Validation**: Automated checks for display name consistency
3. **Phased Rollout**: Code changes before schema changes
4. **Rollback Plan**: Documented rollback procedure

## Success Criteria

- [ ] All food quantities display correctly in mobile app
- [ ] All edge functions return properly formatted food data
- [ ] No increase in error rates post-deployment
- [ ] Reduced code complexity metrics
- [ ] All documentation updated
- [ ] Zero data loss during migration

## Timeline Estimate

- **Phase 1**: 2-3 days (data preparation)
- **Phase 2**: 3-4 days (code updates)
- **Phase 3**: 1 day (database migration)
- **Phase 4**: 2-3 days (testing & deployment)
- **Phase 5**: 1-2 days (documentation & cleanup)

**Total Estimated Duration**: 9-13 days

## Dependencies

- Coordinate with content team for display name creation
- Schedule maintenance window for database migration
- Plan mobile app release cycle around changes

---

*Last Updated*: January 2025
*Status*: Planning Phase
*Next Action*: Begin Phase 1 - Data Preparation