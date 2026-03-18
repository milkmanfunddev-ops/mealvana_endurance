-- ============================================================================
-- Migration: Add Integration Sync Tracking Columns
--
-- Purpose: Enable detection of schedule changes from external providers
--          (Training Peaks, Final Surge) and flag stale nutrition plans
--
-- Changes:
--   1. Add needs_nutrition_refresh boolean to activities table
--   2. Add provider_deleted_at timestamp to activities table
--   3. Add provider_scheduled_at timestamp to activities table
--   4. Add schedule_changed_at timestamp to activities table
--
-- Integration Sync Workflow:
--   - When sync detects schedule change -> set needs_nutrition_refresh = true
--   - When provider deletes workout -> set provider_deleted_at = now()
--   - provider_scheduled_at stores original schedule for change detection
--   - schedule_changed_at tracks when we last detected a change
-- ============================================================================

-- ============================================================================
-- STEP 1: Add needs_nutrition_refresh column
-- Flags when schedule changed significantly (>30 min or different day)
-- ============================================================================

ALTER TABLE activities
ADD COLUMN IF NOT EXISTS needs_nutrition_refresh BOOLEAN DEFAULT FALSE NOT NULL;

COMMENT ON COLUMN activities.needs_nutrition_refresh IS 'Flag set to true when external provider schedule change detected (>30 min time change, different day, duration change >15 min, or distance change >10%). User sees warning banner with "Regenerate Plan" button.';

-- ============================================================================
-- STEP 2: Add provider_deleted_at column
-- Soft-delete timestamp when provider removes workout
-- ============================================================================

ALTER TABLE activities
ADD COLUMN IF NOT EXISTS provider_deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;

COMMENT ON COLUMN activities.provider_deleted_at IS 'Timestamp when provider removed this workout. Activity remains visible with "Removed from [Provider]" indicator. User can manually delete or convert to manual activity.';

-- ============================================================================
-- STEP 3: Add provider_scheduled_at column
-- Store original provider schedule for change detection
-- ============================================================================

ALTER TABLE activities
ADD COLUMN IF NOT EXISTS provider_scheduled_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;

COMMENT ON COLUMN activities.provider_scheduled_at IS 'Original scheduled date/time from provider. Used for change detection during sync. If scheduled_date_time differs from this by >30 min, triggers needs_nutrition_refresh flag.';

-- ============================================================================
-- STEP 4: Add schedule_changed_at column
-- Track when we last detected a schedule change
-- ============================================================================

ALTER TABLE activities
ADD COLUMN IF NOT EXISTS schedule_changed_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;

COMMENT ON COLUMN activities.schedule_changed_at IS 'Timestamp when schedule change was last detected during sync. Helps track change history and debugging.';

-- ============================================================================
-- STEP 5: Create index for querying activities needing nutrition refresh
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_activities_needs_nutrition_refresh
ON activities(needs_nutrition_refresh)
WHERE needs_nutrition_refresh = TRUE;

COMMENT ON INDEX idx_activities_needs_nutrition_refresh IS 'Partial index for efficient queries of activities with stale nutrition plans. Used in Activity Detail screen to show warning banner.';

-- ============================================================================
-- STEP 6: Create index for provider-deleted activities
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_activities_provider_deleted_at
ON activities(provider_deleted_at)
WHERE provider_deleted_at IS NOT NULL;

COMMENT ON INDEX idx_activities_provider_deleted_at IS 'Partial index for activities removed by external provider. Used to filter out soft-deleted workouts or show special UI indicator.';

-- ============================================================================
-- Migration complete!
--
-- New columns:
--   - needs_nutrition_refresh (BOOLEAN): Flag for stale nutrition plans
--   - provider_deleted_at (TIMESTAMP): Soft-delete from provider
--   - provider_scheduled_at (TIMESTAMP): Original provider schedule
--   - schedule_changed_at (TIMESTAMP): When change was detected
--
-- Indexes created:
--   - idx_activities_needs_nutrition_refresh: Fast lookup of flagged activities
--   - idx_activities_provider_deleted_at: Fast filtering of provider-deleted activities
--
-- Significant Schedule Change Criteria (triggers needs_nutrition_refresh):
--   - Time change > 30 minutes
--   - Date change (different day)
--   - Duration change > 15 minutes
--   - Distance change > 10%
--
-- Example sync flow:
--   1. User opens Activities list -> ensureSynced() checks staleness (>1h)
--   2. Fetch workouts from Final Surge API
--   3. ChangeDetectionService.detectChanges(local, remote)
--   4. If schedule changed significantly:
--      - Update scheduled_date_time
--      - Set needs_nutrition_refresh = TRUE
--      - Set provider_scheduled_at = new schedule
--      - Set schedule_changed_at = NOW()
--   5. User opens activity -> sees warning banner
--   6. User taps "Regenerate Plan" -> new nutrition plan generated
--   7. Clear needs_nutrition_refresh flag
-- ============================================================================
