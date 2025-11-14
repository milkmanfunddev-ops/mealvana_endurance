# Schema Migrations

## Current Schema Version: v1

### PHASE_0_SCHEMA_SIMPLIFICATION.sql

**Status:** Ready to run on Dev/Prod

**What it does:**
- Drops and recreates tables with BIGSERIAL PKs (activities, events, etc.)
- Drops join tables (food_categories, categories, meal_types, edge_functions)
- Adds array-based categories to foods tables
- Removes RLS and triggers (dev posture)

**After running:**
1. Update v1 schema snapshot: `dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v1/`
2. This becomes the **new v1 baseline** (no v2 needed)

**To Run:**
1. Open Supabase SQL Editor (Dev or Prod)
2. Copy/paste entire file
3. Execute
4. Update Drift schema and regenerate
