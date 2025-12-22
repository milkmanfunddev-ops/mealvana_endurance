# Supabase Database Documentation

## Overview

Supabase provides the PostgreSQL cloud backend for data synchronization and backup.

## Current Status

- **Tables**: 13 production tables (plus calendar feature tables for local-first functionality)
- **Authentication**: Device-based (no user accounts)
- **Access**: Via Edge Functions and direct client connections

## Recent Schema Changes

### December 14, 2025: Dietary Preferences & Allergies
- **Tables**: `users`, `foods`
- **New Enum Types**:
  - `dietary_preference_enum`: omnivore, vegetarian, pescatarian, vegan, mediterranean, paleo, keto, low_carb
  - `allergy_enum`: dairy, eggs, fish, gluten, peanuts, sesame, shellfish, soy, tree_nuts
- **Users Table Changes**:
  - Added `dietary_preference` (dietary_preference_enum, nullable)
  - Added `allergies` (allergy_enum[], default '{}')
  - Added index on `dietary_preference` (partial index where not null)
- **Foods Table Changes**:
  - Added `allergens` (allergy_enum[], default '{}')
  - Added `excluded_diets` (dietary_preference_enum[], default '{}')
  - Added GIN indexes on both array columns for efficient filtering
- **Purpose**: Supports onboarding revamp with dietary preferences and allergy tracking
- **Benefit**: Enables personalized food filtering based on user diet and allergies
- **Migration**: `/supabase/migrations/20251214120000_add_dietary_preference_and_allergies.sql`
- **Schema Version**: Still v1 (non-breaking field additions)

### October 9, 2025: Events Nutrition Plan Tracking
- **Table**: `events`
- **Change**: Added `has_nutrition_plan` field (BOOLEAN DEFAULT FALSE)
- **Purpose**: Tracks whether an event has an associated nutrition plan
- **Benefit**: Enables UI to show "View Nutrition Plan" vs "Create Nutrition Plan" button
- **Migration**: `/supabase/migrations/20251009153108_add_has_nutrition_plan_to_events.sql`
- **Schema Version**: Still v1 (non-breaking field addition)

### October 8, 2025: Carb Loading Days Enhancement
- **Table**: `carb_loading_days`
- **Change**: Added `carb_protocol_g_per_kg` field (REAL/double)
- **Purpose**: Stores the carbohydrate protocol formula (e.g., 8.0 for 8g/kg bodyweight)
- **Benefit**: Enables UI to display "8g/kg bodyweight" instead of just "610g carbs target"
- **Migration**: `/supabase/migrations/20251008233419_add_carb_protocol_g_per_kg_to_carb_loading_days.sql`
- **Schema Version**: Still v1 (field addition, not a breaking change)

## Schema

The complete PostgreSQL schema is maintained in:
- **Production Dump**: `/supabase/schema_dump.sql`
- **Migrations**: `/supabase/migrations/`

## Key Features

### Row Level Security (RLS)

All tables have RLS policies for data isolation:

```sql
-- Users can only access their own data
CREATE POLICY "Users can read own data" ON users
  FOR SELECT USING (device_id = auth.jwt() ->> 'device_id');
```

### Edge Functions

Serverless functions for complex operations:
- `generate-ai-nutrition-plan` - AI-powered plan generation
- `run-plan` - Algorithmic plan generation (fallback)
- `save-food-preferences` - Batch preference updates

### Data Types

| PostgreSQL | Purpose |
|------------|---------|
| UUID | Unique identifiers |
| JSONB | Structured JSON data |
| TIMESTAMPTZ | Timezone-aware timestamps |
| TEXT[] | Array types |
| CHECK constraints | Data validation |

## Access Patterns

### Via Supabase Client
```dart
final supabase = ref.read(appExternalDepsProvider).supabaseClient;

// Basic food query
final data = await supabase
  .from('foods')
  .select()
  .eq('category', 'before_run');

// Filter foods by user allergies (exclude foods containing allergens)
final userAllergies = ['dairy', 'gluten'];
final safeFood s = await supabase
  .from('foods')
  .select()
  .not('allergens', 'cs', '{${userAllergies.join(',')}}'); // contains (cs) operator

// Filter foods by dietary preference (exclude foods not suitable for diet)
final userDiet = 'vegan';
final suitableFoods = await supabase
  .from('foods')
  .select()
  .not('excluded_diets', 'cs', '{$userDiet}'); // contains (cs) operator
```

### Via Edge Functions
```dart
final response = await supabase.functions.invoke(
  'generate-ai-nutrition-plan',
  body: planRequest,
);
```

## Sync Strategy

- Pull fresh food data on app startup
- Push user data changes immediately
- Handle conflicts with version numbers
- Offline queue for failed syncs

## Local Development

```bash
# Start local Supabase
supabase start

# Pull from production
supabase db pull

# Push schema changes
supabase db push
```
