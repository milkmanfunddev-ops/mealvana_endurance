-- Add nutrition_target_overrides column to users table
-- Stores user-configured default nutrition target overrides as JSONB.
-- Null means "use algorithm defaults" for all fields.
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS nutrition_target_overrides JSONB DEFAULT NULL;

-- Add a comment for documentation
COMMENT ON COLUMN public.users.nutrition_target_overrides IS 'User-configured nutrition target overrides. JSON with pre/during/post activity macro targets. Null = use algorithm defaults.';
