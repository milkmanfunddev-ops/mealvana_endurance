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
-- G18 (RULED Xuan 2026-09-26, option 1): the column also DROPS NOT NULL —
-- null = untagged, which is CL-11-consistent (untagged rows count toward
-- the day, no slot card claims them) and matches what Drift has declared
-- since v14. This closes the audit's items-4/6 seam where an untagged row
-- failed on upload (food-search-scan-audit-2026-07-16.md).
--
-- Apply per supabase/migrations/README.md: by hand (DataGrip / Management
-- API), dev first, prod at the carb-loading release under the standing
-- deploy-approval gate. Both statements are idempotent: DROP NOT NULL on
-- an already-nullable column is a no-op, and the constraint recreate is
-- drop-if-exists.

ALTER TABLE public.meal_logs
  ALTER COLUMN slot DROP NOT NULL;

ALTER TABLE public.meal_logs
  DROP CONSTRAINT IF EXISTS meal_logs_slot_check;

-- The IS NULL arm is explicit (G18): a NULL slot would pass the ANY()
-- check anyway under SQL three-valued logic, but the allowance is a ruled
-- behavior now, not an accident of NULL semantics.
ALTER TABLE public.meal_logs
  ADD CONSTRAINT meal_logs_slot_check CHECK (
    slot IS NULL
    OR slot = ANY (
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
