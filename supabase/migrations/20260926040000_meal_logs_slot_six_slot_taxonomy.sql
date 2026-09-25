-- Widen meal_logs_slot_check to the six-slot loading-day taxonomy
-- (carb-loading@v1, CL-5 / Path A: slot logs are ordinary meal_logs rows
-- tagged to a slot).
--
-- ADDITIVE ONLY: adds 'morning_snack' / 'afternoon_snack' / 'evening_snack'
-- and KEEPS the legacy 'snack' — existing rows carry it, and loading-day
-- surfaces fold it into Afternoon Snack at display time (no data
-- migration). Idempotent drop-and-recreate because the dev dump
-- (docs/dev_schema.txt:2429) and prod may have drifted.
--
-- NOT IN SCOPE, noted deliberately (pre-existing seam, queued for Xuan —
-- food-search-scan-audit-2026-07-16.md items 4/6): Postgres declares
-- meal_logs.slot NOT NULL while Drift made it NULLABLE at v14, so an
-- untagged (null-slot) row fails on upload. The new slot tags INCREASE
-- traffic through this column; this migration neither fixes nor blesses
-- the nullability mismatch — reconciling it is its own ruling.
--
-- Apply per supabase/migrations/README.md: by hand (DataGrip / Management
-- API), dev first, prod at the carb-loading release under the standing
-- deploy-approval gate.

ALTER TABLE public.meal_logs
  DROP CONSTRAINT IF EXISTS meal_logs_slot_check;

ALTER TABLE public.meal_logs
  ADD CONSTRAINT meal_logs_slot_check CHECK (
    slot = ANY (
      ARRAY[
        'breakfast'::text,
        'lunch'::text,
        'dinner'::text,
        'snack'::text,
        'morning_snack'::text,
        'afternoon_snack'::text,
        'evening_snack'::text
      ]
    )
  );
