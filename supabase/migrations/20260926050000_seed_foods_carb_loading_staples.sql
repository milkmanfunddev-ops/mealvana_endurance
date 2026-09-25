-- G26 (carb-loading@v1 land deploy, Xuan 2026-09-25): seed the foods table
-- with the carb-loading staples so every curated slot-page recommendation
-- resolves to a real food for the one-tap log (G25). Carbs are anchored to
-- the ratified curation serving (carb_loading_foods.display_name); protein/
-- fat/sodium are USDA-typical compositions for that food (per-row citation
-- below); calories = 4C + 4P + 9F, rounded. Rows are logging staples, NOT
-- fueling-solver foods: to_exclude_from_solver = true, show_in_preferences
-- = false. Idempotent: fixed UUIDs + ON CONFLICT DO NOTHING; the rename is
-- a no-op once applied. Applies BY HAND (DataGrip / Management API) at the
-- carb-loading land, dev first, prod at the release cut — alongside
-- 20260926040000_meal_logs_slot_six_slot_taxonomy.sql. The test fixture
-- (test/features/carb_loading/fixtures/g25_catalog_fixtures.dart) is emitted
-- by the same generator as this file; regenerate both together.

-- The 'Gels' row is renamed so the curated 'Energy gel (1 packet)' row and
-- plain search both hit it by name; no duplicate row is created.
UPDATE foods SET name = 'Energy gel', display_name = 'energy gel',
  display_name_plural = 'Energy gels', updated_at = now()
WHERE name = 'Gels';

-- Baked potato: USDA FDC: potato, baked, flesh and skin, 1 large
INSERT INTO foods (id, name, display_name, display_name_plural, description,
  serving_amount, carbs_per_serving, protein_per_serving, fat_per_serving,
  calories_per_serving, sodium_mg, show_in_preferences, is_electrolyte,
  to_exclude_from_solver)
VALUES ('c467d177-3647-588e-bb4c-71fd5c2b44d5', 'Baked potato', 'large baked potato', 'baked potatoes',
  'Plain baked russet, flesh and skin.', 1.0, 63, 7, 0.5, 285, 30, false, false, true)
ON CONFLICT (id) DO NOTHING;

-- Beet juice: USDA-typical beetroot juice, 1 cup
INSERT INTO foods (id, name, display_name, display_name_plural, description,
  serving_amount, carbs_per_serving, protein_per_serving, fat_per_serving,
  calories_per_serving, sodium_mg, show_in_preferences, is_electrolyte,
  to_exclude_from_solver)
VALUES ('3cc13a58-9307-5b8c-91e3-b9510a23ccd8', 'Beet juice', 'cup beet juice', 'cups beet juice',
  'Nitrate-rich; a race-week favorite.', 1.0, 18, 1.5, 0, 78, 78, false, false, true)
ON CONFLICT (id) DO NOTHING;

-- Beets: USDA FDC: beets, cooked, 1 medium
INSERT INTO foods (id, name, display_name, display_name_plural, description,
  serving_amount, carbs_per_serving, protein_per_serving, fat_per_serving,
  calories_per_serving, sodium_mg, show_in_preferences, is_electrolyte,
  to_exclude_from_solver)
VALUES ('f15c8b6e-f2f4-5fcb-9470-e87e256ff4d5', 'Beets', 'medium beet', 'beets',
  'Cooked beetroot.', 1.0, 8, 1.5, 0.2, 40, 64, false, false, true)
ON CONFLICT (id) DO NOTHING;

-- Cereal: USDA-typical ready-to-eat cereal, 1/2 cup dry
INSERT INTO foods (id, name, display_name, display_name_plural, description,
  serving_amount, carbs_per_serving, protein_per_serving, fat_per_serving,
  calories_per_serving, sodium_mg, show_in_preferences, is_electrolyte,
  to_exclude_from_solver)
VALUES ('584f5d0b-f0a4-5d85-8e52-4db4a4aa1984', 'Cereal', 'half-cup cereal (dry)', 'cereal',
  'Ready-to-eat breakfast cereal.', 1.0, 14, 1.5, 0.5, 67, 95, false, false, true)
ON CONFLICT (id) DO NOTHING;

-- Graham crackers: USDA FDC: graham crackers, 2 full sheets
INSERT INTO foods (id, name, display_name, display_name_plural, description,
  serving_amount, carbs_per_serving, protein_per_serving, fat_per_serving,
  calories_per_serving, sodium_mg, show_in_preferences, is_electrolyte,
  to_exclude_from_solver)
VALUES ('309e7c29-5c83-5791-87a0-6f7de2699ee1', 'Graham crackers', 'two sheets graham crackers', 'graham crackers',
  'Plain graham cracker sheets.', 1.0, 23, 2, 3, 127, 125, false, false, true)
ON CONFLICT (id) DO NOTHING;

-- Pancake: USDA-typical plain pancake, 1 medium
INSERT INTO foods (id, name, display_name, display_name_plural, description,
  serving_amount, carbs_per_serving, protein_per_serving, fat_per_serving,
  calories_per_serving, sodium_mg, show_in_preferences, is_electrolyte,
  to_exclude_from_solver)
VALUES ('0c986857-0b2a-569b-b419-5a40df5e20e1', 'Pancake', 'medium pancake', 'pancakes',
  'Plain pancake, no toppings.', 1.0, 18, 4, 4, 124, 190, false, false, true)
ON CONFLICT (id) DO NOTHING;

-- Pasta with marinara: USDA-typical pasta + marinara, 1 heaping cup
INSERT INTO foods (id, name, display_name, display_name_plural, description,
  serving_amount, carbs_per_serving, protein_per_serving, fat_per_serving,
  calories_per_serving, sodium_mg, show_in_preferences, is_electrolyte,
  to_exclude_from_solver)
VALUES ('c4f35e20-8ae5-5493-9eb0-506f1da9aa0b', 'Pasta with marinara', 'cup pasta with marinara', 'pasta with marinara',
  'Cooked pasta with marinara sauce.', 1.0, 62, 11, 5, 337, 480, false, false, true)
ON CONFLICT (id) DO NOTHING;

-- Pizza: USDA FDC: cheese pizza, 1 slice of 14 inch
INSERT INTO foods (id, name, display_name, display_name_plural, description,
  serving_amount, carbs_per_serving, protein_per_serving, fat_per_serving,
  calories_per_serving, sodium_mg, show_in_preferences, is_electrolyte,
  to_exclude_from_solver)
VALUES ('2f375b04-b82c-5c5b-9099-8b195451e4ac', 'Pizza', 'slice of pizza', 'slices of pizza',
  'Cheese pizza, regular crust.', 1.0, 33, 12, 10, 270, 640, false, false, true)
ON CONFLICT (id) DO NOTHING;

-- Rice: USDA FDC: white rice, cooked, 1 cup
INSERT INTO foods (id, name, display_name, display_name_plural, description,
  serving_amount, carbs_per_serving, protein_per_serving, fat_per_serving,
  calories_per_serving, sodium_mg, show_in_preferences, is_electrolyte,
  to_exclude_from_solver)
VALUES ('bc0b0f3a-6e6d-5303-a368-6aabc238cfde', 'Rice', 'cup cooked rice', 'rice',
  'Cooked white rice.', 1.0, 45, 4, 0.4, 200, 2, false, false, true)
ON CONFLICT (id) DO NOTHING;

-- Rice pudding: USDA-typical rice pudding, 1/2 cup
INSERT INTO foods (id, name, display_name, display_name_plural, description,
  serving_amount, carbs_per_serving, protein_per_serving, fat_per_serving,
  calories_per_serving, sodium_mg, show_in_preferences, is_electrolyte,
  to_exclude_from_solver)
VALUES ('4f76303e-5a3c-5ceb-abe5-adcb8b5b2bea', 'Rice pudding', 'half-cup rice pudding', 'rice pudding',
  'Classic rice pudding cup.', 1.0, 30, 4, 4, 172, 85, false, false, true)
ON CONFLICT (id) DO NOTHING;

-- Saltines: USDA FDC: saltines, 10 crackers
INSERT INTO foods (id, name, display_name, display_name_plural, description,
  serving_amount, carbs_per_serving, protein_per_serving, fat_per_serving,
  calories_per_serving, sodium_mg, show_in_preferences, is_electrolyte,
  to_exclude_from_solver)
VALUES ('9f70e574-c039-5170-ad4d-aa235d4299ef', 'Saltines', '10 saltine crackers', 'saltines',
  'Plain saltine crackers.', 1.0, 22, 2, 2.5, 119, 280, false, false, true)
ON CONFLICT (id) DO NOTHING;

-- Sandwich: USDA-typical deli sandwich, 1 medium
INSERT INTO foods (id, name, display_name, display_name_plural, description,
  serving_amount, carbs_per_serving, protein_per_serving, fat_per_serving,
  calories_per_serving, sodium_mg, show_in_preferences, is_electrolyte,
  to_exclude_from_solver)
VALUES ('3c2974a8-8f25-5a9c-813c-cde33f865ae2', 'Sandwich', 'medium sandwich', 'sandwiches',
  'Simple deli sandwich on bread.', 1.0, 30, 15, 9, 261, 700, false, false, true)
ON CONFLICT (id) DO NOTHING;

-- Smoothie: USDA-typical fruit smoothie, 1 cup
INSERT INTO foods (id, name, display_name, display_name_plural, description,
  serving_amount, carbs_per_serving, protein_per_serving, fat_per_serving,
  calories_per_serving, sodium_mg, show_in_preferences, is_electrolyte,
  to_exclude_from_solver)
VALUES ('8c399138-84cb-54fc-8a56-bf0dddcdf48f', 'Smoothie', 'cup smoothie', 'smoothies',
  'Fruit smoothie.', 1.0, 26, 2, 0.5, 117, 40, false, false, true)
ON CONFLICT (id) DO NOTHING;

-- Sweet potato: USDA FDC: sweet potato, baked, 1 medium
INSERT INTO foods (id, name, display_name, display_name_plural, description,
  serving_amount, carbs_per_serving, protein_per_serving, fat_per_serving,
  calories_per_serving, sodium_mg, show_in_preferences, is_electrolyte,
  to_exclude_from_solver)
VALUES ('ad389356-785a-5f71-997a-47ef29833c90', 'Sweet potato', 'medium sweet potato', 'sweet potatoes',
  'Baked sweet potato.', 1.0, 25, 2, 0.2, 110, 40, false, false, true)
ON CONFLICT (id) DO NOTHING;

