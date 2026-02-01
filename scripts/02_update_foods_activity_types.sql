-- ============================================================================
-- Script 2 of 2: Update foods activity_types for multi-sport support
-- Run AFTER script 01_add_transition_to_enum.sql
-- Date: 2026-01-23
-- ============================================================================
-- Activity types: running, cycling, swimming, transition
--
-- Guidelines:
-- - RUNNING during: Only easily digestible foods (gels, chews, liquids, soft fruits)
-- - CYCLING during: Can handle more solid foods (bars, waffles, trail mix, pretzels)
-- - SWIMMING during: Liquids/gels only (at aid stations)
-- - TRANSITION: Quick grab-and-go foods for T1/T2 (bananas, gels, bars, drinks)
-- ============================================================================

-- ============================================================================
-- LIQUIDS & GELS - All sports + transition
-- These are easily digestible and work everywhere
-- ============================================================================

-- Water - universal
UPDATE foods SET activity_types = '{running,cycling,swimming,transition}'::activity_type_enum[]
WHERE name = 'Water';

-- Gels - universal quick energy
UPDATE foods SET activity_types = '{running,cycling,swimming,transition}'::activity_type_enum[]
WHERE name = 'Gels';

-- Energy chews - universal quick energy
UPDATE foods SET activity_types = '{running,cycling,swimming,transition}'::activity_type_enum[]
WHERE name = 'Energy chews';

-- Electrolyte drink mix - universal
UPDATE foods SET activity_types = '{running,cycling,swimming,transition}'::activity_type_enum[]
WHERE name = 'Electrolyte drink mix (electrolyte-only)';

-- Electrolyte tablet - universal
UPDATE foods SET activity_types = '{running,cycling,swimming,transition}'::activity_type_enum[]
WHERE name = 'Electrolyte tablet (electrolyte-only)';

-- Salt Packet - universal
UPDATE foods SET activity_types = '{running,cycling,swimming,transition}'::activity_type_enum[]
WHERE name = 'Salt Packet';

-- Sports drink (carb + electrolytes) - universal
UPDATE foods SET activity_types = '{running,cycling,swimming,transition}'::activity_type_enum[]
WHERE name = 'Sports drink (carb + electrolytes)';

-- Sports drink mix - universal
UPDATE foods SET activity_types = '{running,cycling,swimming,transition}'::activity_type_enum[]
WHERE name = 'Sports drink mix (carb + electrolytes)';

-- Pickle juice shot - universal electrolytes
UPDATE foods SET activity_types = '{running,cycling,swimming,transition}'::activity_type_enum[]
WHERE name = 'Pickle juice shot';

-- Coconut water - universal hydration
UPDATE foods SET activity_types = '{running,cycling,swimming,transition}'::activity_type_enum[]
WHERE name = 'Coconut water';

-- Applesauce/fruit puree - soft, easy to digest, works for all + transition
UPDATE foods SET activity_types = '{running,cycling,swimming,transition}'::activity_type_enum[]
WHERE name = 'Applesauce / fruit purée pouch';

-- ============================================================================
-- SOFT FRUITS - All sports + transition (easy to digest)
-- ============================================================================

-- Dates - soft, quick energy, universal + transition classic
UPDATE foods SET activity_types = '{running,cycling,swimming,transition}'::activity_type_enum[]
WHERE name = 'Dates';

-- Bananas - THE classic transition food, soft enough for running
UPDATE foods SET activity_types = '{running,cycling,swimming,transition}'::activity_type_enum[]
WHERE name = 'Bananas';

-- ============================================================================
-- SOLID FOODS FOR DURING - Cycling only (too heavy for running/swimming during)
-- But still good for before/after all sports and transition
-- ============================================================================

-- Energy waffle (stroopwafel) - cycling during, transition grab-and-go
UPDATE foods SET activity_types = '{cycling,transition}'::activity_type_enum[]
WHERE name = 'Energy waffle (stroopwafel-style)';

-- Pretzels - salty carbs, cycling during, transition
UPDATE foods SET activity_types = '{cycling,transition}'::activity_type_enum[]
WHERE name = 'Pretzels (salted minis)';

-- Trail mix - classic cycling food, NOT for running during
UPDATE foods SET activity_types = '{cycling,transition}'::activity_type_enum[]
WHERE name = 'Trail mix';

-- Fig bar - solid but digestible, cycling during, transition
UPDATE foods SET activity_types = '{cycling,transition}'::activity_type_enum[]
WHERE name = 'Fig bar';

-- Peanut butter - too sticky for running during, cycling OK
UPDATE foods SET activity_types = '{cycling,transition}'::activity_type_enum[]
WHERE name = 'Peanut butter';

-- Energy bar - solid, cycling during, transition grab
UPDATE foods SET activity_types = '{cycling,transition}'::activity_type_enum[]
WHERE name = 'Energy bar';

-- Bagel - classic cycling/transition food
UPDATE foods SET activity_types = '{cycling,transition}'::activity_type_enum[]
WHERE name = 'Bagel (plain)';

-- ============================================================================
-- BEFORE/AFTER ONLY FOODS - All sports (not used during activity)
-- ============================================================================

-- Coffee - before only, all sports
UPDATE foods SET activity_types = '{running,cycling,swimming}'::activity_type_enum[]
WHERE name = 'Coffee';

-- Apple - before only, all sports
UPDATE foods SET activity_types = '{running,cycling,swimming}'::activity_type_enum[]
WHERE name = 'Apple';

-- Berries - before only, all sports
UPDATE foods SET activity_types = '{running,cycling,swimming}'::activity_type_enum[]
WHERE name = 'Berries';

-- Orange juice - before/after, all sports
UPDATE foods SET activity_types = '{running,cycling,swimming}'::activity_type_enum[]
WHERE name = 'Orange juice';

-- Oatmeal - before only, all sports
UPDATE foods SET activity_types = '{running,cycling,swimming}'::activity_type_enum[]
WHERE name = 'Oatmeal';

-- Toast - before only, all sports
UPDATE foods SET activity_types = '{running,cycling,swimming}'::activity_type_enum[]
WHERE name = 'Toast';

-- ============================================================================
-- RECOVERY FOODS - After only, all sports
-- ============================================================================

-- Yogurt - after only, all sports
UPDATE foods SET activity_types = '{running,cycling,swimming}'::activity_type_enum[]
WHERE name = 'Yogurt';

-- Chocolate milk - after only, all sports
UPDATE foods SET activity_types = '{running,cycling,swimming}'::activity_type_enum[]
WHERE name = 'Chocolate milk';

-- Protein bar - after only, all sports
UPDATE foods SET activity_types = '{running,cycling,swimming}'::activity_type_enum[]
WHERE name = 'Protein bar';

-- Protein powder - after only, all sports
UPDATE foods SET activity_types = '{running,cycling,swimming}'::activity_type_enum[]
WHERE name = 'Protein powder (whey)';

-- Protein shake - after only, all sports
UPDATE foods SET activity_types = '{running,cycling,swimming}'::activity_type_enum[]
WHERE name = 'Protein shake (ready-to-drink)';

-- ============================================================================
-- VERIFICATION QUERY
-- ============================================================================

SELECT
    name,
    array_to_string(categories, ', ') as categories,
    array_to_string(activity_types, ', ') as activity_types
FROM foods
ORDER BY name;
