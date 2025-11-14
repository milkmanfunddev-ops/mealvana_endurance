-- Fix events table: swap event_type and event_subtype values and use enums
-- event_type should be sport category (running, cycling, swimming, triathlon, duathlon, multisport)
-- event_subtype should be race distance (marathon, half_marathon, 10k, 5k, etc.)

-- Step 1: Drop existing enums if they exist (to handle re-running migration)
DROP TYPE IF EXISTS public.event_type_enum CASCADE;
DROP TYPE IF EXISTS public.event_subtype_enum CASCADE;

-- Step 2: Create enum types for event_type (sport categories)
CREATE TYPE public.event_type_enum AS ENUM (
  'running',
  'cycling',
  'swimming',
  'triathlon',
  'duathlon',
  'multisport'
);

-- Step 3: Create enum type for event_subtype (all possible race distances across all sports)
CREATE TYPE public.event_subtype_enum AS ENUM (
  -- Running distances
  '5k',
  '10k',
  '15k',
  '10_mile',
  'half_marathon',
  '25k',
  '30k',
  'marathon',
  'ultra_50k',
  'ultra_50m',
  'ultra_100k',
  'ultra_100m',
  'ultra_12h',
  'ultra_24h',
  -- Cycling distances
  '20k',
  '40k_tt',
  '50k',
  'half_century',
  'metric_century',
  'century',
  'gran_fondo',
  '200k',
  -- Swimming distances
  '1k',
  '1.5k',
  '2.5k',
  -- Triathlon distances
  'sprint',
  'olympic',
  'half_ironman',
  'ironman',
  -- Duathlon distances
  'standard',
  'long_course',
  -- Multisport types
  'aquathlon',
  'aquabike',
  -- Generic
  'custom'
);

-- Step 3: Add temporary columns to store the swapped values
ALTER TABLE public.events ADD COLUMN temp_event_type event_type_enum;
ALTER TABLE public.events ADD COLUMN temp_event_subtype event_subtype_enum;

-- Step 4: Swap the values
-- Current event_type (race distance text) -> new event_subtype (enum)
-- Set new event_type to 'running' (since all existing events are running)
UPDATE public.events
SET
  temp_event_subtype = event_type::event_subtype_enum, -- Cast race distance to enum
  temp_event_type = 'running'::event_type_enum -- Default all existing to running
WHERE event_type IS NOT NULL;

-- Step 5: Drop old constraint
ALTER TABLE public.events DROP CONSTRAINT IF EXISTS event_type_check;

-- Step 6: Drop old text columns
ALTER TABLE public.events DROP COLUMN event_type;
ALTER TABLE public.events DROP COLUMN event_subtype;

-- Step 7: Rename temp columns to original names
ALTER TABLE public.events RENAME COLUMN temp_event_type TO event_type;
ALTER TABLE public.events RENAME COLUMN temp_event_subtype TO event_subtype;

-- Step 8: Make event_type NOT NULL (required field)
ALTER TABLE public.events ALTER COLUMN event_type SET NOT NULL;
-- event_subtype remains nullable

-- Step 9: Update comments to reflect correct usage
COMMENT ON COLUMN public.events.event_type IS 'Sport category: running, cycling, swimming, triathlon, duathlon, multisport';
COMMENT ON COLUMN public.events.event_subtype IS 'Race distance/type: marathon, half_marathon, 10k, 5k, sprint, olympic, etc.';
