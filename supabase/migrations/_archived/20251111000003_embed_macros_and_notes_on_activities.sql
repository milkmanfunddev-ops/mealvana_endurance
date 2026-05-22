-- Migration: Embed macro targets and workout notes on activities
-- Date: 2025-11-11
-- Description: Copies macro target JSON + latest workout notes directly onto activities
--              and drops the legacy macro_targets_table and workout_notes tables.

BEGIN;

-- 1. Embed macro targets JSON inside activities (if legacy table still exists)
DO $$
BEGIN
  IF to_regclass('public.macro_targets_table') IS NOT NULL THEN
    WITH macro_payload AS (
      SELECT
        CASE
          WHEN mt.activity_id IS NULL THEN NULL
          WHEN trim(mt.activity_id::text) ~ '^[0-9]+$'
            THEN mt.activity_id::bigint
          ELSE NULL
        END AS activity_id_bigint,
        jsonb_build_object(
          'preRun', jsonb_build_object(
            'carbsG', mt.pre_run_carbs_g,
            'proteinG', mt.pre_run_protein_g,
            'fatCapG', mt.pre_run_fat_cap_g,
            'fluidsMl', mt.pre_run_fluids_ml,
            'sodiumMg', mt.pre_run_sodium_mg
          ),
          'duringRun', jsonb_build_object(
            'carbRateGPerH', mt.during_carb_rate_g_per_h,
            'carbTotalG', mt.during_carb_total_g,
            'fluidRateMlPerH', mt.during_fluid_rate_ml_per_h,
            'fluidTotalMl', mt.during_fluid_total_ml,
            'sodiumRateMgPerH', mt.during_sodium_rate_mg_per_h,
            'sodiumTotalMg', mt.during_sodium_total_mg,
            'massNormRateGPerH', mt.during_mass_norm_rate_g_per_h
          ),
          'postRun', jsonb_build_object(
            'carbsG', mt.post_run_carbs_g,
            'proteinG', mt.post_run_protein_g,
            'fluidsMl', mt.post_run_fluids_ml,
            'sodiumMg', mt.post_run_sodium_mg
          ),
          'metrics', jsonb_build_object(
            'distanceMi', mt.distance_mi,
            'distanceKm', CASE
              WHEN mt.distance_mi IS NOT NULL THEN mt.distance_mi * 1.60934
              ELSE NULL
            END,
            'durationH', mt.duration_h,
            'durationMin', CASE
              WHEN mt.duration_h IS NOT NULL THEN mt.duration_h * 60
              ELSE NULL
            END,
            'paceMinPerMile', mt.pace_min_per_mile,
            'speedMph', CASE
              WHEN mt.pace_min_per_mile IS NOT NULL AND mt.pace_min_per_mile > 0
                THEN 60.0 / mt.pace_min_per_mile
              ELSE NULL
            END,
            'caloriesGrossKcal', mt.calories_gross_kcal,
            'met', mt.met
          ),
          'calculationRule', mt.calculation_rule,
          'timestamp', COALESCE(mt.updated_at, mt.created_at)
        ) AS macro_data
      FROM public.macro_targets_table mt
    )
    UPDATE public.activities a
       SET nutrition_plan_data = jsonb_set(
             COALESCE(a.nutrition_plan_data, '{}'::jsonb),
             '{macroTargets}',
             mp.macro_data,
             true
           )
      FROM macro_payload mp
     WHERE mp.activity_id_bigint IS NOT NULL
       AND mp.activity_id_bigint = a.id;
  END IF;
END $$;

-- 2. Backfill workout notes (latest per activity) into completion fields if table exists
DO $$
BEGIN
  IF to_regclass('public.workout_notes') IS NOT NULL THEN
    WITH raw_notes AS (
      SELECT
        CASE
          WHEN wn.activity_id IS NULL THEN NULL
          WHEN trim(wn.activity_id::text) ~ '^[0-9]+$'
            THEN wn.activity_id::bigint
          ELSE NULL
        END AS activity_id_bigint,
        wn.note_text,
        wn.rating,
        wn.updated_at
      FROM public.workout_notes wn
    ),
    latest_notes AS (
      SELECT DISTINCT ON (activity_id_bigint)
             activity_id_bigint,
             note_text,
             rating
        FROM raw_notes
       WHERE activity_id_bigint IS NOT NULL
       ORDER BY activity_id_bigint, updated_at DESC
    )
    UPDATE public.activities a
       SET completion_notes = COALESCE(a.completion_notes, ln.note_text),
           completion_rating = COALESCE(a.completion_rating, ln.rating)
      FROM latest_notes ln
     WHERE ln.activity_id_bigint = a.id
       AND (ln.note_text IS NOT NULL OR ln.rating IS NOT NULL);
  END IF;
END $$;

-- 3. Drop legacy tables no longer needed
DROP TABLE IF EXISTS public.macro_targets_table CASCADE;
DROP TABLE IF EXISTS public.workout_notes CASCADE;

COMMIT;
