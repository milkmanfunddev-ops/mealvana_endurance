-- Migration: add weight_pounds_updated_at and body_fat_pct_updated_at to users
-- These timestamps support "latest-wins" precedence in the Garmin body-comp resolver.
-- When Garmin sends a newer reading than the user's manual entry, Garmin wins,
-- and vice-versa. If both are null, the existing fallback (user wins) applies.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS weight_pounds_updated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS body_fat_pct_updated_at TIMESTAMPTZ;

-- Backfill with existing updated_at (best-effort; keeps stale-guard logic safe).
-- If updated_at doesn't exist, fall back to now().
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'users' AND column_name = 'updated_at'
  ) THEN
    UPDATE users
    SET
      weight_pounds_updated_at = updated_at,
      body_fat_pct_updated_at  = updated_at
    WHERE
      weight_pounds_updated_at IS NULL
      OR body_fat_pct_updated_at IS NULL;
  ELSE
    UPDATE users
    SET
      weight_pounds_updated_at = now(),
      body_fat_pct_updated_at  = now()
    WHERE
      weight_pounds_updated_at IS NULL
      OR body_fat_pct_updated_at IS NULL;
  END IF;
END
$$;
