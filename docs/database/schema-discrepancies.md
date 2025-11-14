# Database Schema Discrepancies: Dev vs Production

**Last Updated**: 2025-11-06
**Status**: Active Issue - Production Missing Multi-Sport Columns

## Executive Summary

Development and Production Supabase databases have **different column structures** despite both having 27 tables. Production is missing multi-sport support columns in the `users` and `activities` tables that were added to development in October 2025.

## Impact

- **Development**: Full multi-sport functionality (running, cycling, swimming)
- **Production**: Running-only functionality
- **Risk**: Schema drift between environments could cause sync issues

## Detailed Discrepancies

### 1. `users` Table

**Missing in Production (4 columns):**
```sql
cycling_ftp_watts             integer,
prefers_cycling_power         boolean   default false,
swimming_css_seconds_per_100m integer,
prefers_swimming_pace         boolean   default false
```

**Impact**: Production cannot store user cycling or swimming preferences.

---

### 2. `activities` Table

**Major Structural Differences:**

#### Activity Type Constraint
- **Dev**: `CHECK (activity_type IN ('running', 'cycling', 'swimming'))`
- **Prod**: `CHECK (activity_type IN ('running', 'event'))`

#### Missing in Production (16 columns + constraints):
```sql
-- Core multi-sport column
sport_type                     text      default 'running'::text
    CHECK (sport_type IN ('running', 'cycling', 'swimming')),

-- Cycling-specific columns (8)
cycling_power_watts            integer,
cycling_ftp_watts              integer,
cycling_speed_mph              real,
cycling_terrain                text CHECK (cycling_terrain IN ('flat', 'rolling', 'hilly')),
cycling_indoor_outdoor         text CHECK (cycling_indoor_outdoor IN ('indoor', 'outdoor')),
cycling_elevation_gain_ft      integer,
cycling_session_goal           text CHECK (cycling_session_goal IN ('endurance', 'tempo', 'intervals')),

-- Swimming-specific columns (5)
swimming_speed_per_100m        integer,
swimming_css_seconds_per_100m  integer,
swimming_pace_per_100m_seconds integer,
swimming_pool_or_open_water    text CHECK (swimming_pool_or_open_water IN ('pool', 'open_water')),
swimming_water_temp_c          real,

-- Cross-sport columns (2)
intensity_target               text,
time_before_minutes            integer,

-- Validation constraints
CONSTRAINT activities_cycling_columns_check
    CHECK (((sport_type = 'cycling') AND (cycling_power_watts IS NOT NULL)) OR
           ((sport_type <> 'cycling') AND (cycling_power_watts IS NULL) AND (cycling_ftp_watts IS NULL))),

CONSTRAINT activities_swimming_columns_check
    CHECK (((sport_type = 'swimming') AND (swimming_speed_per_100m IS NOT NULL)) OR
           ((sport_type <> 'swimming') AND (swimming_speed_per_100m IS NULL) AND
            (swimming_css_seconds_per_100m IS NULL)))
```

**Impact**: Production cannot store cycling or swimming workout data.

---

### 3. `foods` Table

**✅ No Discrepancy** - Both dev and prod have:
```sql
cycling_suitable   boolean default true,
swimming_suitable  boolean default true
```

**Status**: Foods table successfully migrated in both environments.

---

### 4. `user_foods` Table

**Dev Has**:
```sql
suitable_for_activities jsonb  -- JSONB map of sport types
```

**Prod Has**:
```sql
suitable_for_activities jsonb  -- Same column exists
```

**Status**: Both have the JSONB column, no discrepancy.

---

## Table Count Comparison

| Environment | Table Count | Multi-Sport Status |
|-------------|-------------|-------------------|
| **Development** | 27 | ✅ Full (users, activities, foods) |
| **Production** | 27 | ⚠️ Partial (foods only) |
| **Drift Local** | 27 | ✅ Full (matches dev) |

---

## Migration History

### What Happened
1. **October 15, 2025**: Multi-sport migration created and applied to **development** environment
2. Migration added 4 columns to `users` and 16+ columns to `activities`
3. Migration successfully applied to dev Supabase
4. **Migration NOT applied to production** - reason unclear

### Migration Files
Location: `/supabase/migrations/`
- `20251030000001_add_missing_activities_columns.sql`
- Various other incremental migration files in October-November 2025

---

## Resolution Path

### Option 1: Apply Multi-Sport Migration to Production (Recommended)
**Pros:**
- Achieves schema parity
- Enables multi-sport features in production
- Follows intended architecture

**Cons:**
- Requires production deployment
- Need to verify no breaking changes for existing data

**Steps:**
1. Review all October 2025 migration files
2. Test migrations on production snapshot
3. Schedule maintenance window
4. Apply migrations to production
5. Verify schema parity with `supabase db dump`
6. Update `/docs/prod_schema.txt`

### Option 2: Document and Accept Divergence
**Pros:**
- No production changes needed
- Current running-only functionality unaffected

**Cons:**
- Permanent schema drift
- Cannot deploy multi-sport features to production
- Increased maintenance complexity

---

## Verification Commands

### Check Table Count
```bash
# Development
supabase db execute --db-url $DEV_URL "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'"

# Production
supabase db execute --db-url $PROD_URL "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'"
```

### Check Column Differences
```bash
# Users table
supabase db execute --db-url $DEV_URL "SELECT column_name FROM information_schema.columns WHERE table_name='users' ORDER BY ordinal_position"

supabase db execute --db-url $PROD_URL "SELECT column_name FROM information_schema.columns WHERE table_name='users' ORDER BY ordinal_position"
```

---

## Documentation Updates Made

- [x] CLAUDE.md updated - table count corrected (26→27), schema parity claims removed
- [x] `/database_schemas/v1/README.md` updated - noted prod discrepancy
- [x] `/database_schemas/v1/schema.sql` regenerated from dev schema
- [x] `/docs/database/README.md` updated - added schema parity status section
- [x] This discrepancy document created

---

## Related Files

- **Dev Schema**: `/docs/dev_schema.txt` (1803 lines)
- **Prod Schema**: `/docs/prod_schema.txt` (1538 lines)
- **V1 Baseline**: `/database_schemas/v1/schema.sql` (dev-based)
- **Migration Files**: `/supabase/migrations/2025*.sql`

---

## Recommendation

**Apply the multi-sport migration to production** to achieve schema parity and enable full feature set. The current divergence creates technical debt and limits product capabilities.
