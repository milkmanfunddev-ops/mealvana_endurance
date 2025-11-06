# Database Migrations - V1 Schema

This directory contains SQL migration files for Supabase (PostgreSQL).

## Current Migrations

### 1. `add_feature_survey_responses_table.sql`
**Date**: 2025-01-05
**Purpose**: Add feature survey responses table for user voting on feature requests

**What it does**:
- Creates `feature_survey_responses` table
- Adds indexes for performance
- Sets up Row Level Security (RLS) policies
- Grants appropriate permissions

**How to apply**:
1. Open DataGrip and connect to your Supabase instance
2. Open the SQL file
3. Execute the entire file
4. Run verification queries (commented in the file)

**Environments to apply**:
- [ ] Dev Supabase
- [ ] Production Supabase

---

## Migration Guidelines

### Before Running
1. **Backup**: Always backup production data before migrations
2. **Test on Dev**: Run on dev environment first
3. **Review**: Read the entire SQL file to understand changes
4. **Permissions**: Ensure you have sufficient database permissions

### After Running
1. **Verify**: Run verification queries to confirm changes
2. **Test**: Test app functionality with new schema
3. **Monitor**: Watch for errors in application logs
4. **Document**: Update this README with completion status

### Rollback Plan
If you need to rollback a migration:
```sql
-- For feature_survey_responses table
DROP TABLE IF EXISTS feature_survey_responses CASCADE;
```

---

## Schema Version Tracking

**Current Drift Schema Version**: 2
**Current Supabase Tables**: 28

**Note**: We're staying on v1 as the living baseline. Future breaking changes will increment to v2.

---

## Questions?
Contact the development team or refer to the main roadmap document:
`/docs/features/feature-survey-implementation-roadmap.md`
