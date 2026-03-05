-- Populate display_name_plural for template_foods that are missing it.
-- Pattern: countable items get plural name; unit-based items get "unit FoodName".
-- This prevents naive pluralization bugs like "Oatmeals", "Honeys", "Datess".

-- Countable whole items (plural of food name)
UPDATE template_foods SET display_name_plural = 'Dates' WHERE food_key = 'dates' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Rice Cakes' WHERE food_key = 'rice_cake' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Oranges' WHERE food_key = 'orange' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Eggs' WHERE food_key = 'egg' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Apples' WHERE food_key = 'apple' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Potatoes' WHERE food_key = 'baked_potato' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Flour Tortillas' WHERE food_key = 'flour_tortilla' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Bagels' WHERE food_key = 'bagel' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Toaster Waffles' WHERE food_key = 'toaster_waffle' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Pancakes' WHERE food_key = 'pancake' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Sweet Potatoes' WHERE food_key = 'sweet_potato' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Crackers' WHERE food_key = 'crackers' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Fig Bars' WHERE food_key = 'fig_bar' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Granola Bars' WHERE food_key = 'granola_bar' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Pop-Tarts' WHERE food_key = 'pop_tarts' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Pretzels' WHERE food_key = 'pretzels' AND display_name_plural IS NULL;

-- Unit-based items (unit + food name)
UPDATE template_foods SET display_name_plural = 'cups Oatmeal' WHERE food_key = 'oats_dry' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Honey' WHERE food_key = 'honey' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Milk' WHERE food_key = 'milk' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Granola' WHERE food_key = 'granola' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Raisins' WHERE food_key = 'raisins' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Mixed Berries' WHERE food_key = 'mixed_berries' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Cream Cheese' WHERE food_key = 'cream_cheese' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Blueberries' WHERE food_key = 'blueberries' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Almond Butter' WHERE food_key = 'almond_butter' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Cereal' WHERE food_key = 'cereal' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Maple Syrup' WHERE food_key = 'maple_syrup' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'slices Cheese' WHERE food_key = 'cheese_slice' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tsp Butter' WHERE food_key = 'butter' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'sheets Graham Crackers' WHERE food_key = 'graham_crackers' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Brown Sugar' WHERE food_key = 'brown_sugar' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Peaches' WHERE food_key = 'peaches' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'scoops Protein Powder' WHERE food_key = 'protein_powder' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Soy Sauce' WHERE food_key = 'soy_sauce' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'oz Chicken' WHERE food_key = 'chicken' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Teriyaki Sauce' WHERE food_key = 'teriyaki_sauce' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'oz Turkey' WHERE food_key = 'turkey_deli' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tsp Mustard' WHERE food_key = 'mustard' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Dried Mango' WHERE food_key = 'dried_mango' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Watermelon' WHERE food_key = 'watermelon' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'pouches Applesauce' WHERE food_key = 'applesauce_pouch' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'servings Sports Drink Mix' WHERE food_key = 'sports_drink_mix' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Peanut Butter' WHERE food_key = 'peanut_butter' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Jam' WHERE food_key = 'jam' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Yogurt' WHERE food_key = 'yogurt' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Grapes' WHERE food_key = 'grapes' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Nutella' WHERE food_key = 'nutella' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups White Rice' WHERE food_key = 'white_rice' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Mango' WHERE food_key = 'mango_fresh' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Orange Juice' WHERE food_key = 'orange_juice' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Strawberries' WHERE food_key = 'strawberries' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'packets Salt' WHERE food_key = 'salt' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Avocados' WHERE food_key = 'avocado' AND display_name_plural IS NULL;
