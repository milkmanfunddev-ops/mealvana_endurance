-- ============================================================================
-- Add is_indivisible column to template_foods
-- ============================================================================
-- Items marked as indivisible must use whole-number servings in the solver
-- and by-hour apportionment. Examples: electrolyte tablets, gel packets.
-- This replaces hardcoded product_type checks in code.

ALTER TABLE template_foods
ADD COLUMN IF NOT EXISTS is_indivisible boolean DEFAULT false;

COMMENT ON COLUMN template_foods.is_indivisible IS
  'Whether this food comes in discrete, sealed units that cannot be fractionally consumed (e.g., tablets, gel packets)';

-- ============================================================================
-- Set is_indivisible = true for discrete/sealed items
-- ============================================================================

-- Electrolyte Tablet — can't split a tablet
UPDATE template_foods SET is_indivisible = true WHERE name = 'electrolyte_tablet';

-- Energy Gel — sealed packet, can't open half
UPDATE template_foods SET is_indivisible = true WHERE name = 'energy_gel';

-- Pickle Juice Shot — sealed bottle
UPDATE template_foods SET is_indivisible = true WHERE name = 'pickle_juice_shot';

-- Salt packet — discrete packet
UPDATE template_foods SET is_indivisible = true WHERE name = 'salt';
