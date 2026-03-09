-- Energy chews should be divisible into half-packet increments (0.5 packets ≈ 3 chews).
-- The original seed data incorrectly set is_indivisible = true.
-- This allows the by-hour UI to assign in 0.5-packet steps instead of whole packets.
UPDATE template_foods
SET is_indivisible = false, updated_at = now()
WHERE name = 'energy_chews';

-- Energy gels should also be divisible into half-packet increments.
-- With is_indivisible = true, the by-hour UI forces whole-packet steps (1.0),
-- so placing "2 packets" across 2 hours shows "1 energy gel" instead of "½ packet".
-- Also lower min_servings_during from 1.0 to 0.5 so the solver can assign half-packets.
UPDATE template_foods
SET is_indivisible = false, min_servings_during = 0.5, updated_at = now()
WHERE name = 'energy_gel';
