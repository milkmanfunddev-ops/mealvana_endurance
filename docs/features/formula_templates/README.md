# Pre-Workout Nutrition Template System

## Overview

Template-based system for pre-workout nutrition. Templates are curated food combinations (e.g., "Toast + PB + Banana") that scale to hit macro targets based on user weight and timing window.

## Data Sources

### template_foods.json (44 foods)
- Nutrition data sourced from USDA FoodData Central and manufacturer labels
- Each food includes: name, display_name, serving_size, serving_weight_g, calories, carbs_g, protein_g, fat_g, fiber_g, sodium_mg, fluid_ml, allergens, digestion_speed

### templates_v2.json (41 templates)
- Exported from Notion "Pre-workout formula by Claude (v2)" database
- Collection ID: `303e3fdb-754c-81dd-bc60-000b9642fbfd`
- Each template includes: name, timing window, base servings, macros, allergens, scaling notes, validation status, food references
- 41 fully-populated templates (3 partially-populated and 10 stubs excluded)

## Timing Windows

| Window | Minutes | Meal Type | Template Count |
|--------|---------|-----------|---------------|
| < 30 min | 0-30 | top_up | 6 |
| 30-60 min | 30-60 | top_up | 10 |
| 1-2 hours | 60-120 | snack | 9 |
| 3-4 hours | 180-240 | full_meal | 16 |

## Schema

Two Supabase tables:
- `template_foods` - 44 food ingredient catalog with USDA nutrition per serving
- `templates` - 41 denormalized templates with embedded JSONB foods arrays

See migration files:
- `supabase/migrations/20260212000001_create_template_tables.sql` (schema)
- `supabase/migrations/20260212000002_seed_template_data.sql` (seed data)

## Scaling Algorithm

```
Given: template.foods[] (each with nutrition per serving + min/max servings), target_carbs_g
1. Sum base carbs at default_servings
2. Compute ratio = target_carbs_g / base_carbs
3. Scale all items proportionally, round to nearest 0.5, clamp to [min, max]
4. If deficit > 2g, redistribute to unclamped items proportionally
5. Return: scaled items with servings + computed nutrition
```

## Macro Targets (v3 Algorithm)

Pre-workout carbs: `1 g/kg per hour` (capped at 4 g/kg for 4h window)

| Weight | 30 min | 1h | 1.5h | 2h | 3h | 4h |
|--------|--------|-----|------|-----|-----|-----|
| 54 kg | 27g | 54g | 81g | 108g | 162g | 216g |
| 64 kg | 32g | 64g | 96g | 128g | 192g | 256g |
| 73 kg | 37g | 73g | 110g | 146g | 219g | 292g |
| 91 kg | 46g | 91g | 137g | 182g | 273g | 364g |
