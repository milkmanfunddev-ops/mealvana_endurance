# Prod Parity Execution Guide

## What was wrong with the original approach

The export scripts (02, 03) use `SELECT ... AS sql_statement` which produces result rows. When you copy results from Supabase SQL Editor, they get wrapped in `INSERT INTO "MY_TABLE"(sql_statement) VALUES ('...');` format with doubled single quotes. This output is **not valid SQL** to paste into prod.

**Fix**: Export scripts now use `string_agg()` to produce a single cell containing all INSERT statements concatenated. Click the cell, copy the text, paste into prod.

## Files

| File | Run On | Purpose |
|------|--------|---------|
| `00_diagnostic.sql` | PROD | Check current state before changes |
| `01a_enum_fix.sql` | PROD | Add `archived_for_brick` enum value (must run alone) |
| `01b_schema_ddl.sql` | PROD | Tables, columns, indexes, triggers, grants, template RLS |
| `02_template_foods_data.sql` | PROD | 70 template_foods INSERT statements (already extracted) |
| `02_export_dev_template_foods.sql` | DEV | Re-export script (if you need to refresh data) |
| `03_export_dev_templates.sql` | DEV | Export templates data from DEV |
| `04_normalize_food_preferences.sql` | PROD | Map legacy food names to snake_case |
| `01c_coach_rls_policies.sql` | PROD | Coach access policies (**optional, see warning**) |

## Execution Order

### Step 0: Diagnostic (PROD)
Run `00_diagnostic.sql` on prod and check the results. Pay special attention to:
- Whether RLS is enabled on activities/events/carb_loading tables
- What policies already exist

### Step 1a: Enum Fix (PROD)
Run `01a_enum_fix.sql` **alone** - ALTER TYPE ADD VALUE cannot be inside a transaction.

### Step 1b: Schema DDL (PROD)
Run `01b_schema_ddl.sql` - creates tables, columns, indexes, RLS for template tables.

### Step 2: Template Foods Data (PROD)
Run `02_template_foods_data.sql` - inserts all 70 template_foods rows.

### Step 3: Templates Data (DEV then PROD)
1. Run `03_export_dev_templates.sql` on DEV
2. Result is ONE cell called `all_sql` - click it, copy the entire text
3. Paste into PROD SQL Editor and run

### Step 4: Normalize Food Preferences (PROD)
Run `04_normalize_food_preferences.sql` on PROD.

### Step 5: Deploy Edge Functions
```bash
supabase functions deploy --all
```

### Step 6: Coach RLS Policies (PROD - OPTIONAL)
**Only if diagnostic shows RLS is DISABLED on activities/events/carb_loading tables.**
Run `01c_coach_rls_policies.sql` - safe if RLS is disabled (policies exist but have no effect).

## Deprecated
- `01_schema_parity.sql` - original combined script (replaced by 01a + 01b + 01c)
