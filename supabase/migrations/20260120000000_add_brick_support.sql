-- ============================================================================
-- Migration: Add Brick Workout Support
--
-- Purpose: Enable brick workout functionality with multi-sport segments
--
-- Changes:
--   1. Add 'brick' to activity_type_enum
--   2. Add 'archived_for_brick' to activity_status_enum
--   3. Add brick_metadata JSONB column to activities table
--   4. Add brick_id UUID column to activities table
--   5. Create indexes for efficient brick queries
--   6. Add 'transition' to category_enum (if not already present)
--
-- Brick Workflow:
--   - Users can create brick activities combining 2-3 sports (swim/bike/run)
--   - Original activities are soft-deleted with status='archived_for_brick'
--   - brick_metadata stores segment details as JSON
--   - brick_id links archived activities to their parent brick
-- ============================================================================

-- ============================================================================
-- STEP 1: Extend activity_type_enum with 'brick'
-- ============================================================================

DO $$ BEGIN
  ALTER TYPE activity_type_enum ADD VALUE IF NOT EXISTS 'brick';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

COMMENT ON TYPE activity_type_enum IS 'Supported activity types: running, cycling, swimming, triathlon, duathlon, multisport, brick. Brick is a multi-sport workout with 2-3 sequential segments.';

-- ============================================================================
-- STEP 2: Extend activity_status_enum with 'archived_for_brick'
-- ============================================================================

DO $$ BEGIN
  ALTER TYPE activity_status_enum ADD VALUE IF NOT EXISTS 'archived_for_brick';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

COMMENT ON TYPE activity_status_enum IS 'Activity workflow states. archived_for_brick indicates an activity was combined into a brick workout and should not appear in normal queries.';

-- ============================================================================
-- STEP 3: Add brick_metadata column to activities table
-- Stores structured segment information as JSONB
-- ============================================================================

ALTER TABLE activities
ADD COLUMN IF NOT EXISTS brick_metadata JSONB DEFAULT NULL;

COMMENT ON COLUMN activities.brick_metadata IS 'For brick activities: stores segment_order, segments array, original_activity_ids, created_from_existing, and total_duration_minutes. See BrickMetadata domain model for structure.';

-- ============================================================================
-- STEP 4: Add brick_id column to activities table
-- Links archived activities to their parent brick
-- Note: Using TEXT type to match activities.id column type
-- ============================================================================

-- Drop existing constraint and column if they exist (cleanup from failed migrations)
ALTER TABLE activities DROP CONSTRAINT IF EXISTS fk_activities_brick_id;
ALTER TABLE activities DROP COLUMN IF EXISTS brick_id;

-- Add brick_id as TEXT to match activities.id type
ALTER TABLE activities ADD COLUMN brick_id TEXT DEFAULT NULL;

-- Add foreign key constraint (ON DELETE SET NULL to preserve archived activities if brick is deleted)
ALTER TABLE activities
ADD CONSTRAINT fk_activities_brick_id
FOREIGN KEY (brick_id)
REFERENCES activities(id)
ON DELETE SET NULL;

COMMENT ON COLUMN activities.brick_id IS 'For archived activities: references the parent brick activity. When brick is ungrouped, this is set to NULL and status is restored to planned.';

-- ============================================================================
-- STEP 5: Create indexes for efficient brick queries
-- ============================================================================

-- Partial index for activities that are part of a brick (archived originals)
-- Used for queries like: "Get all archived activities for brick X"
CREATE INDEX IF NOT EXISTS idx_activities_brick_id
ON activities(brick_id)
WHERE brick_id IS NOT NULL;

-- Partial index for brick activities themselves
-- Used for queries like: "Get all brick workouts for user"
CREATE INDEX IF NOT EXISTS idx_activities_brick_type
ON activities(activity_type)
WHERE activity_type = 'brick';

-- ============================================================================
-- STEP 6: Add 'transition' to category_enum (if not already present)
-- Required for T1 and T2 transition foods in brick workouts
-- ============================================================================

DO $$ BEGIN
  ALTER TYPE category_enum ADD VALUE IF NOT EXISTS 'transition';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

COMMENT ON TYPE category_enum IS 'Food category phases for multi-sport workouts. Includes: before, during_run, during_bike, during_swim, after, transition (for brick T1/T2).';

-- ============================================================================
-- STEP 7: Add helpful comments for documentation
-- ============================================================================

COMMENT ON TABLE activities IS 'User activities including single-sport (run/bike/swim) and multi-sport (brick/triathlon/duathlon). Brick activities store segment details in brick_metadata and link to archived originals via brick_id.';

-- ============================================================================
-- Migration complete!
--
-- New activity types:
--   - brick: Multi-sport workout with 2-3 sequential segments
--
-- New activity status:
--   - archived_for_brick: Activity combined into brick (hidden from normal queries)
--
-- New columns:
--   - brick_metadata (JSONB): Stores segment_order, segments, original_activity_ids
--   - brick_id (UUID): Links archived activities to parent brick
--
-- Indexes created:
--   - idx_activities_brick_id: Fast lookup of archived activities by brick
--   - idx_activities_brick_type: Fast filtering of brick activities
--
-- Example brick_metadata structure:
--   {
--     "segment_order": ["swimming", "running"],
--     "segments": [
--       {
--         "sport": "swimming",
--         "order": 1,
--         "duration_minutes": 40,
--         "intensity": "moderate",
--         "distance_meters": 2000,
--         "pace_per_100m_seconds": 120,
--         "pool_or_open_water": "pool"
--       },
--       {
--         "sport": "running",
--         "order": 2,
--         "duration_minutes": 55,
--         "intensity": "moderate",
--         "distance_miles": 6.2,
--         "pace_minutes_per_mile": 8.5
--       }
--     ],
--     "original_activity_ids": ["uuid-1", "uuid-2"],
--     "created_from_existing": true,
--     "total_duration_minutes": 95
--   }
-- ============================================================================
