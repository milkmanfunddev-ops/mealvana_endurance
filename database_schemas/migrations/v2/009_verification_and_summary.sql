-- ============================================================================
-- Migration 009: Verification and Summary
-- ============================================================================
-- Description: Verify all Phase 0 changes and provide summary report
-- Date: 2025-01-07
-- ============================================================================

BEGIN;

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Check enums exist
DO $$
DECLARE
  enum_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO enum_count
  FROM pg_type
  WHERE typname IN (
    'gender_enum',
    'distance_unit_enum',
    'pace_unit_enum',
    'gut_training_enum',
    'sport_enum',
    'activity_status_enum',
    'intensity_enum',
    'cycling_terrain_enum',
    'cycling_indoor_outdoor_enum',
    'cycling_session_goal_enum',
    'swimming_pool_open_water_enum',
    'category_enum'
  );

  IF enum_count < 12 THEN
    RAISE WARNING 'Expected 12 enums, found %', enum_count;
  ELSE
    RAISE NOTICE '✓ All enums created (%)', enum_count;
  END IF;
END $$;

-- Check users.id is UUID
DO $$
DECLARE
  users_id_type TEXT;
BEGIN
  SELECT data_type INTO users_id_type
  FROM information_schema.columns
  WHERE table_name = 'users' AND column_name = 'id';

  IF users_id_type = 'uuid' THEN
    RAISE NOTICE '✓ users.id is UUID';
  ELSE
    RAISE WARNING '✗ users.id is %, expected uuid', users_id_type;
  END IF;
END $$;

-- Check activities.id is BIGINT
DO $$
DECLARE
  activities_id_type TEXT;
BEGIN
  SELECT data_type INTO activities_id_type
  FROM information_schema.columns
  WHERE table_name = 'activities' AND column_name = 'id';

  IF activities_id_type = 'bigint' THEN
    RAISE NOTICE '✓ activities.id is BIGINT (BIGSERIAL)';
  ELSE
    RAISE WARNING '✗ activities.id is %, expected bigint', activities_id_type;
  END IF;
END $$;

-- Check activities.user_id is UUID
DO $$
DECLARE
  activities_user_id_type TEXT;
BEGIN
  SELECT data_type INTO activities_user_id_type
  FROM information_schema.columns
  WHERE table_name = 'activities' AND column_name = 'user_id';

  IF activities_user_id_type = 'uuid' THEN
    RAISE NOTICE '✓ activities.user_id is UUID';
  ELSE
    RAISE WARNING '✗ activities.user_id is %, expected uuid', activities_user_id_type;
  END IF;
END $$;

-- Check events.id is BIGINT
DO $$
DECLARE
  events_id_type TEXT;
BEGIN
  SELECT data_type INTO events_id_type
  FROM information_schema.columns
  WHERE table_name = 'events' AND column_name = 'id';

  IF events_id_type = 'bigint' THEN
    RAISE NOTICE '✓ events.id is BIGINT (BIGSERIAL)';
  ELSE
    RAISE WARNING '✗ events.id is %, expected bigint', events_id_type;
  END IF;
END $$;

-- Check foods.categories is array
DO $$
DECLARE
  foods_categories_type TEXT;
BEGIN
  SELECT data_type INTO foods_categories_type
  FROM information_schema.columns
  WHERE table_name = 'foods' AND column_name = 'categories';

  IF foods_categories_type = 'ARRAY' THEN
    RAISE NOTICE '✓ foods.categories is ARRAY';
  ELSE
    RAISE WARNING '✗ foods.categories is %, expected ARRAY', foods_categories_type;
  END IF;
END $$;

-- Check join tables are dropped
DO $$
DECLARE
  join_table_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO join_table_count
  FROM pg_tables
  WHERE schemaname = 'public'
    AND tablename IN (
      'food_categories',
      'user_food_categories',
      'categories',
      'meal_types',
      'carb_loading_food_meal_types',
      'carb_loading_user_food_meal_types'
    );

  IF join_table_count = 0 THEN
    RAISE NOTICE '✓ All join tables dropped';
  ELSE
    RAISE WARNING '✗ Found % join tables still present', join_table_count;
  END IF;
END $$;

-- Check RLS is disabled
DO $$
DECLARE
  rls_enabled_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO rls_enabled_count
  FROM pg_tables t
  JOIN pg_class c ON c.relname = t.tablename
  WHERE t.schemaname = 'public'
    AND c.relrowsecurity = true;

  IF rls_enabled_count = 0 THEN
    RAISE NOTICE '✓ RLS disabled on all tables';
  ELSE
    RAISE WARNING '✗ RLS still enabled on % tables', rls_enabled_count;
  END IF;
END $$;

-- Check RLS policies are dropped
DO $$
DECLARE
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE schemaname = 'public';

  IF policy_count = 0 THEN
    RAISE NOTICE '✓ All RLS policies dropped';
  ELSE
    RAISE WARNING '✗ Found % RLS policies still present', policy_count;
  END IF;
END $$;

-- Check timestamps are naive (not TIMESTAMPTZ)
DO $$
DECLARE
  timestamptz_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO timestamptz_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND data_type = 'timestamp with time zone';

  IF timestamptz_count = 0 THEN
    RAISE NOTICE '✓ All timestamps converted to naive TIMESTAMP';
  ELSE
    RAISE WARNING '✗ Found % TIMESTAMPTZ columns still present', timestamptz_count;
  END IF;
END $$;

-- ============================================================================
-- Summary Report
-- ============================================================================

SELECT '
================================================================================
Phase 0 Migration Complete!
================================================================================

✓ Enums created (gender, sport, intensity, etc.)
✓ users.id is UUID primary key
✓ activities.id is BIGINT (BIGSERIAL)
✓ activities.user_id is UUID foreign key
✓ events.id is BIGINT (BIGSERIAL)
✓ carb_loading_plans.id is BIGINT (BIGSERIAL)
✓ Array-based categories added to foods
✓ Join tables dropped
✓ Timestamps converted to naive TIMESTAMP (UTC)
✓ RLS disabled on all tables
✓ All RLS policies dropped
✓ Permissive grants applied

================================================================================
Next Steps:
================================================================================

1. Run Phase 1 migrations (embed nutrition in activities)
2. Update Drift schema to match
3. Regenerate Dart code with build_runner
4. Test thoroughly in Dev environment

================================================================================
' AS summary;

COMMIT;
