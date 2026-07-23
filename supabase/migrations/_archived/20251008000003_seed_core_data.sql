-- Migration: Seed Core Data from Production
-- Description: Seeds essential data (app_content, categories, edge_functions, foods, product_types, food_categories)
-- Date: 2025-10-08
-- Schema Version: v1
-- Source: Extracted from production database

SET session_replication_role = replica;

-- Clear existing data (except categories which is part of base schema)
DELETE FROM food_categories;
DELETE FROM foods;
DELETE FROM product_types;
-- NOTE: edge_functions skipped - contains large multi-line code that's difficult to migrate
-- DELETE FROM edge_functions;
DELETE FROM app_content;

-- ============================================================================
-- 1. Categories (update existing)
-- ============================================================================

INSERT INTO categories (id, name) VALUES
  (1, 'before_run'),
  (2, 'during_run'),
  (3, 'after_run')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- ============================================================================
-- 2. App Content (UI text and algorithm parameters)
-- ============================================================================

INSERT INTO "public"."app_content" ("id", "version", "environment", "locale", "content", "is_active", "created_at", "updated_at", "created_by", "updated_by") VALUES
	('cc1d0af4-9f7c-4c49-b25d-9ab16f65ced7', 1, 'production', 'en', '{"error": {"generic": "Something went wrong. Please try again.", "network": "Network error. Please check your connection.", "plan_generation": "Failed to generate plan", "feedback_submission": "Failed to submit feedback. Please try again."}, "units": {"feet": "ft", "miles": "mi", "inches": "in", "pounds": "lbs", "kilometers": "km", "min_per_km": "min/km", "min_per_mile": "min/mi"}, "gender": {"male": "Male", "other": "Other", "female": "Female"}, "success": {"profile_saved": "Profile saved successfully!", "feedback_submitted": "✅ Thank you for your feedback!"}, "feedback": {"type_suggestions": "Type your suggestions"}, "validation": {"required": "Required", "height_feet": "Enter valid feet (3-8)", "pace_format": "Format: 8:30 or 8.5", "weight_range": "Enter valid weight (80-500 lbs)", "height_inches": "Enter valid inches (0-11)", "distance_range": "Distance must be between 0 and 200", "invalid_number": "Please enter a valid number", "fill_all_fields": "Please fill in all fields"}, "main_screen": {"title": "Mealvana Endurance", "tips_text": "We''ll create a personalized nutrition plan\\nbased on your run details", "pace_label": "Average pace", "pre_run_label": "Time before run", "distance_label": "Distance", "generate_button": "Generate Plan", "gut_training_label": "Gut training level"}, "plan_screen": {"title": "Plan", "after_run": "After Your Run", "before_run": "Before Run", "during_run": "During Run", "save_button": "Save", "saved_button": "Saved", "macro_targets": "Macro targets"}, "gut_training": {"low": "Low", "high": "High", "moderate": "Moderate", "low_description": "New to fueling during runs - start conservative", "high_description": "Experienced endurance athlete with high carb tolerance", "moderate_description": "Some experience with sports nutrition"}, "user_profile": {"title": "Your Profile", "subtitle": "Tell us about yourself", "description": "This helps us calculate accurate nutrition plans for your runs.", "gender_label": "Gender", "height_label": "Height", "weight_label": "Weight", "birthday_hint": "Select your birthday", "birthday_label": "Birthday", "continue_button": "Continue", "water_bottle_label": "Do you run with a water bottle?", "running_habits_label": "Running Habits", "water_bottle_subtitle": "This helps us estimate your hydration needs"}, "pre_run_timing": {"1_hour": "1 hour before", "2_hours": "2 hours before", "3_hours": "3 hours before"}, "food_preferences": {"title": "Food Preferences"}}', true, '2025-08-19 13:17:03.639611+00', '2025-08-21 14:58:05.860303+00', NULL, NULL);

-- ============================================================================
-- 3. Product Types
-- ============================================================================

INSERT INTO "public"."product_types" ("id", "code", "name", "name_plural", "sort_order", "created_at") VALUES
	('8a847f4f-8c26-41ef-a1e2-132b404be95e', 'gel', 'Gel', 'Gels', 10, '2025-09-19 16:24:50.00628+00'),
	('fc915f1b-d541-45fa-ae5c-695ee41073db', 'chew', 'Chew', 'Chews', 20, '2025-09-19 16:24:50.00628+00'),
	('d3908cb2-a21d-4ef1-8d33-c999d29eefcc', 'drink_mix', 'Drink mix', 'Drink mixes', 30, '2025-09-19 16:24:50.00628+00'),
	('09930546-1942-485e-9728-bced1cf933a2', 'electrolyte_only', 'Electrolyte-only', 'Electrolyte-only', 40, '2025-09-19 16:24:50.00628+00'),
	('b27bc986-1402-4e20-b022-a65b5ffbd4d2', 'sports_drink', 'Sports drink', 'Sports drinks', 50, '2025-09-19 16:24:50.00628+00'),
	('6102eea1-2dfe-44cf-8863-b258c27262ef', 'bar', 'Bar', 'Bars', 60, '2025-09-19 16:24:50.00628+00'),
	('666408c5-6d5b-4fc6-bda3-d6428e8362b9', 'waffle', 'Waffle', 'Waffles', 70, '2025-09-19 16:24:50.00628+00'),
	('52a0ff7c-a0f5-4e26-b409-2a7ce3298f4d', 'capsule', 'Capsule', 'Capsules', 80, '2025-09-19 16:24:50.00628+00'),
	('76c16c67-1746-47d7-adea-e5fc9dcd1f4d', 'real_food', 'Real food', 'Real foods', 90, '2025-09-19 16:24:50.00628+00'),
	('cbcfd036-127c-43fb-88d5-34a9d9ba5db4', 'recovery_shake', 'Recovery shake', 'Recovery shakes', 100, '2025-09-19 16:24:50.00628+00'),
	('3b5d6f2e-3d3a-4b6a-9e3b-5c7a1f0d7a10', 'quick_carbs', 'Quick carb', 'Quick carbs', 10, '2025-09-19 21:37:47.189896+00'),
	('8f4f2c73-9a65-4d5a-b3be-9d5f9e2a1c2d', 'solid_carb_snacks', 'Solid carb snack', 'Solid carb snacks', 20, '2025-09-19 21:37:47.189896+00'),
	('f2a8c4e1-7d82-4d9b-8b79-9a03e7b4a6c1', 'real_food_carbs', 'Real-food carb', 'Real-food carbs', 30, '2025-09-19 21:37:47.189896+00'),
	('c7e2a1d4-5b6c-4f9d-8e2a-1a7c9b3e5d2f', 'hydration_with_carbs', 'Hydration with carbs', 'Hydration with carbs', 40, '2025-09-19 21:37:47.189896+00'),
	('a1e2c3d4-b5a6-4c7d-8e9f-0a1b2c3d4e5f', 'electrolytes_fluids', 'Electrolytes & fluids', 'Electrolytes & fluids', 50, '2025-09-19 21:37:47.189896+00'),
	('d4c3b2a1-6e5d-4c3b-8a9f-1e2d3c4b5a6f', 'protein_recovery', 'Protein & recovery', 'Protein & recovery', 60, '2025-09-19 21:37:47.189896+00'),
	('cdd6a8f1-750c-4c78-93f7-ab706285ac7b', 'import', 'Imported', 'Imported', NULL, '2025-09-24 19:55:37.172213+00');

-- ============================================================================
-- 4. Edge Functions
-- ============================================================================

-- NOTE: edge_functions skipped - contains large multi-line code
-- Edge functions should be deployed separately via supabase functions deploy

-- ============================================================================
-- 5. Foods (Reference Data)
-- ============================================================================

INSERT INTO "public"."foods" ("id", "name", "image_address", "created_at", "serving_amount", "max_servings_before", "max_servings_during", "sodium_mg", "caffeine_mg", "potassium_mg", "fat_per_serving", "carbs_per_serving", "protein_per_serving", "calories_per_serving", "fluid_ml_per_serving", "show_in_preferences", "display_name", "max_servings_after", "is_electrolyte", "display_name_plural", "to_exclude_from_solver", "product_type_id", "description", "serving_description", "serving_size", "is_essential", "is_other_food") VALUES
	('87345851-086f-4e1f-9148-52771ea230d4', 'Protein shake (ready-to-drink)', 'protein_shake_ready_to_drink.png', '2025-09-24 19:35:46.868228+00', 1, NULL, NULL, 200, 0, 0, 3.00, 5.00, 25.00, 150, 325.0, false, 'bottle protein shake', NULL, false, 'bottles protein shake', false, 'cbcfd036-127c-43fb-88d5-34a9d9ba5db4', 'Ready to drink, prefect for after workout.', 'bottle', '1 bottle = 11 fl oz (325 ml)', false, false),
	('e7d229dd-adb0-4862-b913-c23ddd345e91', 'Orange juice', 'orange_juice.png', '2025-08-19 17:17:02.105068+00', 1, 2, 10, 0, 0, 0, 0.00, 26.00, 2.00, 112, 240.0, false, 'cup orange juice', 15, false, 'cups orange juice', false, 'f2a8c4e1-7d82-4d9b-8b79-9a03e7b4a6c1', 'Fruit juice carbs post- or pre-workout.', 'cup', NULL, false, false),
	('058cdc7c-d41f-4276-a9fd-b725d7ab8137', 'Peanut butter', 'peanut_butter.png', '2025-09-24 19:58:15.117129+00', 1, NULL, NULL, 75, 0, 0, 8.00, 3.50, 4.00, 95, 0.0, false, 'tablespoon of peanut butter ', NULL, false, 'tablespoons of peanut butter ', false, '76c16c67-1746-47d7-adea-e5fc9dcd1f4d', NULL, 'tablespoon', NULL, false, false),
	('2d0a8b80-4c4e-45fb-83fa-85f074c98055', 'Pretzels (salted minis)', 'pretzels.png', '2025-09-02 21:32:03.578154+00', 1, 2, 3, 350, 0, 50, 1.00, 23.00, 2.00, 110, 0.0, false, 'serving pretzels (salted minis)', 8, false, 'servings pretzels (salted minis)', false, 'f2a8c4e1-7d82-4d9b-8b79-9a03e7b4a6c1', 'Crunchy, salty carbs for quick energy.', 'serving', '1 serving = 1 oz (28 g)', false, false),
	('9fd63557-c41b-4fc6-a7f5-884582c282ed', 'Electrolyte tablet (electrolyte-only)', 'electrolyte_tablet.png', '2025-09-02 21:32:03.578154+00', 1, 2, 3, 300, 0, 150, 0.00, 0.00, 0.00, 0, 0.0, false, 'electrolyte tablet', 2, true, 'electrolyte tablets', false, 'a1e2c3d4-b5a6-4c7d-8e9f-0a1b2c3d4e5f', 'Dissolving tablet for electrolytes only.', 'tablet', NULL, false, false),
	('92a116e8-61f4-4a4f-b8b6-5954757a3f18', 'Fig bar', 'fig_bar.png', '2025-09-24 20:00:32.874837+00', 1, NULL, NULL, 120, 0, 0, 6.00, 38.00, 3.00, 200, 0.0, false, 'twin-pack fig bar', NULL, false, 'twin-packs fig bar', false, '8f4f2c73-9a65-4d5a-b3be-9d5f9e2a1c2d', NULL, 'twin-pack', NULL, false, false),
	('c02c4b94-ef83-4fb5-998f-ab46299e3b12', 'Protein bar', 'protein_bar.png', '2025-08-19 17:17:02.105068+00', 1, 1, 3, 0, 0, 0, 8.00, 25.00, 20.00, 252, NULL, true, 'protein bar', 3, false, 'protein bars', false, 'd4c3b2a1-6e5d-4c3b-8a9f-1e2d3c4b5a6f', 'High-protein snack bar.', 'bar', NULL, false, true),
	('c5e0fb33-50e8-426c-98aa-1a2fc24ae388', 'Toast', 'toast.png', '2025-09-24 19:40:39.891167+00', 1, NULL, NULL, 150, NULL, NULL, 1.00, 17.00, 3.00, 90, 0.0, true, 'slice of toast', NULL, false, 'slices of toast', false, 'f2a8c4e1-7d82-4d9b-8b79-9a03e7b4a6c1', NULL, 'slice', '', false, true),
	('d18f3c8a-1dfd-494b-a3bd-6a817fe6cace', 'Coconut water', 'coconut_water.png', '2025-08-19 17:17:02.105068+00', 1, 2, 10, 0, 0, 600, 0.00, 9.00, 2.00, 44, 236.6, false, 'cup coconut water', 15, true, 'cups coconut water', false, 'a1e2c3d4-b5a6-4c7d-8e9f-0a1b2c3d4e5f', 'Naturally sweet hydration with potassium.', 'cup', NULL, false, false),
	('e5a24d1a-51f0-4e66-8786-51e2a127d01a', 'Energy chews', 'energy_chews.png', '2025-08-19 17:17:02.105068+00', 1, NULL, 6, 108, 0, 0, 0.00, 24.00, 0.00, 108, NULL, true, 'package energy chews', NULL, false, 'packages energy chews', false, '3b5d6f2e-3d3a-4b6a-9e3b-5c7a1f0d7a10', 'Generic chewable carbs.', 'package', NULL, false, true),
	('43f39d86-8a2c-4139-887e-b2af95ddca78', 'Energy bar', 'energy.png', '2025-09-11 15:12:02.486503+00', 1, 2, 3, 120, 0, 200, 6.00, 28.00, 8.00, 180, 0.0, true, 'energy bar', 3, false, 'energy bars', false, '8f4f2c73-9a65-4d5a-b3be-9d5f9e2a1c2d', 'Generic energy bar.', 'bar', NULL, false, true),
	('be5256da-7cd3-40c5-802b-8e2ac6ead338', 'Energy waffle (stroopwafel-style)', 'energy_waffle.png', '2025-09-24 19:44:56.443166+00', 1, NULL, NULL, 80, 0, 0, 7.00, 21.00, 1.00, 150, 0.0, false, 'energy waffle (stroopwafel-style)', NULL, false, 'energy waffles (stroopwafel-style)', false, '666408c5-6d5b-4fc6-bda3-d6428e8362b9', NULL, 'waffle', '1 waffle = 30 g', false, false),
	('408c9d6e-83aa-4875-8100-e6bc09ebe324', 'Water', 'water.png', '2025-09-15 21:20:15.546245+00', 1.0, NULL, NULL, 0, NULL, NULL, 0.00, 0.00, 0.00, 0, 240.0, false, 'cup of water', NULL, false, 'cups of water', false, 'a1e2c3d4-b5a6-4c7d-8e9f-0a1b2c3d4e5f', 'Plain water.', 'cup', NULL, true, false),
	('8421a851-3d81-48c8-8334-0fb99b6aa447', 'Sports drink (carb + electrolytes)', 'sports_drink.png', '2025-08-19 17:17:02.105068+00', 1, 2, 8, 110, 0, 0, 0.00, 14.00, 0.00, 56, 236.6, true, 'cup sports drink (carb + electrolytes)', 15, true, 'cups sports drink (carb + electrolytes)', false, 'c7e2a1d4-5b6c-4f9d-8e2a-1a7c9b3e5d2f', 'General-purpose carb + electrolyte drink.', 'cup', NULL, false, true),
	('3221593d-cac7-4571-937f-3b2329ee3e0b', 'Coffee', 'coffee.png', '2025-09-24 20:02:15.785256+00', 1, NULL, NULL, 5, 95, 120, 0.00, 0.00, 0.00, 0, 240.0, false, 'cup of coffee', NULL, false, 'cups of coffee', false, '76c16c67-1746-47d7-adea-e5fc9dcd1f4d', NULL, 'cup', NULL, false, false),
	('f916b29f-cfe3-4cf5-9362-6b1967e3bdca', 'Chocolate milk', 'chocolate_milk.png', '2025-08-19 17:17:02.105068+00', 1, 10, 10, 0, 0, 0, 8.00, 26.00, 8.00, 208, 236.6, false, 'cup chocolate milk', 15, false, 'cups chocolate milk', false, 'd4c3b2a1-6e5d-4c3b-8a9f-1e2d3c4b5a6f', 'Carb + protein dairy drink.', 'cup', NULL, false, false),
	('429418b7-6580-4a7a-a542-c27fd8130a5c', 'Apple', 'apple.png', '2025-09-24 20:03:48.092164+00', 1, NULL, NULL, 0, 0, 0, 0.30, 25.00, 0.50, 95, 0.0, false, 'apple', NULL, false, 'apples', false, 'f2a8c4e1-7d82-4d9b-8b79-9a03e7b4a6c1', NULL, 'apple', NULL, false, false),
	('1046a183-9f3a-40e9-add6-4baf092826cc', 'Electrolyte drink mix (electrolyte-only)', 'electrolyte_drink_mix.png', '2025-09-24 19:49:51.274656+00', 1, NULL, NULL, 300, 0, 200, 0.00, 0.00, 0.00, 0, 0.0, false, 'serving electrolyte drink mix (electrolyte-only)', NULL, false, 'servings electrolyte drink mix (electrolyte-only)', false, '09930546-1942-485e-9728-bced1cf933a2', 'mixed in 16–20 fl oz', 'serving', '1 serving = 1 stick/scoop', false, false),
	('ae2611c5-63d8-434c-9a11-274ec8439c1e', 'Dates', 'dates.png', '2025-08-19 17:17:02.105068+00', 1, 3, 4, 0, 0, 0, 0.00, 18.00, 0.00, 72, NULL, false, 'pair of dates', NULL, false, 'pairs of dates', false, 'f2a8c4e1-7d82-4d9b-8b79-9a03e7b4a6c1', 'Portable fruit sugars for quick energy.', 'pair', NULL, false, false),
	('2ed43f0f-98dc-4534-81b1-a54265b30a3d', 'Oatmeal', 'oatmeal.png', '2025-08-19 17:17:02.105068+00', 1, 2, 10, 0, 0, 0, 3.00, 30.00, 5.00, 166, NULL, true, 'cup oatmeal', 15, false, 'cups oatmeal', false, 'f2a8c4e1-7d82-4d9b-8b79-9a03e7b4a6c1', 'Warm cereal; steady, slower-digesting carbs.', 'cup', NULL, false, true);

-- ============================================================================
-- 6. Food Categories (Mappings)
-- ============================================================================

INSERT INTO "public"."food_categories" ("food_id", "category_id") VALUES
	('2ed43f0f-98dc-4534-81b1-a54265b30a3d', 1),
	('e7d229dd-adb0-4862-b913-c23ddd345e91', 1),
	('8421a851-3d81-48c8-8334-0fb99b6aa447', 1),
	('ae2611c5-63d8-434c-9a11-274ec8439c1e', 1),
	('6b18db01-4073-466a-87fd-89018f02e9f4', 1),
	('d18f3c8a-1dfd-494b-a3bd-6a817fe6cace', 1),
	('17459c26-52b9-424a-aba2-da761aa12eee', 1),
	('17459c26-52b9-424a-aba2-da761aa12eee', 2),
	('8421a851-3d81-48c8-8334-0fb99b6aa447', 2),
	('ae2611c5-63d8-434c-9a11-274ec8439c1e', 2),
	('e5a24d1a-51f0-4e66-8786-51e2a127d01a', 2),
	('c02c4b94-ef83-4fb5-998f-ab46299e3b12', 3),
	('d18f3c8a-1dfd-494b-a3bd-6a817fe6cace', 3),
	('f916b29f-cfe3-4cf5-9362-6b1967e3bdca', 3),
	('6b18db01-4073-466a-87fd-89018f02e9f4', 3),
	('8421a851-3d81-48c8-8334-0fb99b6aa447', 3),
	('9fd63557-c41b-4fc6-a7f5-884582c282ed', 2),
	('9fd63557-c41b-4fc6-a7f5-884582c282ed', 1),
	('9fd63557-c41b-4fc6-a7f5-884582c282ed', 3),
	('41109851-ea1b-40a3-bca0-41534b6c4181', 2),
	('b1d860f0-0afb-45d5-bcec-9eb8b02827bc', 2),
	('2d0a8b80-4c4e-45fb-83fa-85f074c98055', 1),
	('2d0a8b80-4c4e-45fb-83fa-85f074c98055', 2),
	('f7f21b39-c153-4c44-b6e5-a7497178d9fb', 1),
	('f7f21b39-c153-4c44-b6e5-a7497178d9fb', 3),
	('312f4fca-ca55-47a2-aa2f-afa24cd64ef4', 1),
	('312f4fca-ca55-47a2-aa2f-afa24cd64ef4', 2),
	('71b7a463-382d-41b3-8dea-1d7f9c563856', 3),
	('43f39d86-8a2c-4139-887e-b2af95ddca78', 1),
	('43f39d86-8a2c-4139-887e-b2af95ddca78', 3),
	('c5eabfaf-0e2b-42a5-8351-f12a9b36edef', 1),
	('c5eabfaf-0e2b-42a5-8351-f12a9b36edef', 3),
	('e7d229dd-adb0-4862-b913-c23ddd345e91', 3),
	('ae2611c5-63d8-434c-9a11-274ec8439c1e', 3),
	('408c9d6e-83aa-4875-8100-e6bc09ebe324', 1),
	('408c9d6e-83aa-4875-8100-e6bc09ebe324', 2),
	('408c9d6e-83aa-4875-8100-e6bc09ebe324', 3);

