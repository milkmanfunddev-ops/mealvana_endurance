-- Remove custom_foods — it duplicated the existing user_foods table.
--
-- user_foods already stores user-created foods with per-serving macros, owned
-- per user, soft-deleted, and offline-synced — and it's richer (display_name_
-- plural, image, barcode, categories, activity_types, is_electrolyte,
-- to_exclude_from_solver) and already wired into the Food Preferences UI + the
-- solver. The custom_foods table (added 2026-05-22 from the Formula Kit PR4
-- plan) was an empty duplicate with no consumers. Formula Kit will reuse
-- user_foods instead.
--
-- Apply via DataGrip to dev + prod. Idempotent.

DROP TABLE IF EXISTS custom_foods;

-- personal_templates.custom_food_ids now references user_foods.id (not a
-- separate custom_foods table). Column unchanged; comment corrected.
COMMENT ON COLUMN personal_templates.custom_food_ids IS
  'JSON array of user_foods.id values used as custom components in this formula.';
