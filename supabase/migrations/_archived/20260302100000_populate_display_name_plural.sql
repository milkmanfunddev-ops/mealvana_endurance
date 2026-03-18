-- Populate display_name_plural for template_foods that are missing it.
-- Pattern: countable items get plural name; unit-based items get "unit FoodName".
-- This prevents naive pluralization bugs like "Oatmeals", "Honeys", "Datess".

-- Countable whole items (plural of food name)
UPDATE template_foods SET display_name_plural = 'Dates' WHERE name = 'dates' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Rice Cakes' WHERE name = 'rice_cake' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Oranges' WHERE name = 'orange' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Eggs' WHERE name = 'egg' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Apples' WHERE name = 'apple' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Potatoes' WHERE name = 'baked_potato' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Flour Tortillas' WHERE name = 'flour_tortilla' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Bagels' WHERE name = 'bagel' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Toaster Waffles' WHERE name = 'toaster_waffle' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Pancakes' WHERE name = 'pancake' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Sweet Potatoes' WHERE name = 'sweet_potato' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Crackers' WHERE name = 'crackers' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Fig Bars' WHERE name = 'fig_bar' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Granola Bars' WHERE name = 'granola_bar' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Pop-Tarts' WHERE name = 'pop_tarts' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Pretzels' WHERE name = 'pretzels' AND display_name_plural IS NULL;

-- Unit-based items (unit + food name)
UPDATE template_foods SET display_name_plural = 'cups Oatmeal' WHERE name = 'oats_dry' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Honey' WHERE name = 'honey' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Milk' WHERE name = 'milk' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Granola' WHERE name = 'granola' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Raisins' WHERE name = 'raisins' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Mixed Berries' WHERE name = 'mixed_berries' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Cream Cheese' WHERE name = 'cream_cheese' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Blueberries' WHERE name = 'blueberries' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Almond Butter' WHERE name = 'almond_butter' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Cereal' WHERE name = 'cereal' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Maple Syrup' WHERE name = 'maple_syrup' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'slices Cheese' WHERE name = 'cheese_slice' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tsp Butter' WHERE name = 'butter' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'sheets Graham Crackers' WHERE name = 'graham_crackers' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Brown Sugar' WHERE name = 'brown_sugar' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Peaches' WHERE name = 'peaches' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'scoops Protein Powder' WHERE name = 'protein_powder' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Soy Sauce' WHERE name = 'soy_sauce' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'oz Chicken' WHERE name = 'chicken' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Teriyaki Sauce' WHERE name = 'teriyaki_sauce' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'oz Turkey' WHERE name = 'turkey_deli' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tsp Mustard' WHERE name = 'mustard' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Dried Mango' WHERE name = 'dried_mango' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Watermelon' WHERE name = 'watermelon' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'pouches Applesauce' WHERE name = 'applesauce_pouch' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'servings Sports Drink Mix' WHERE name = 'sports_drink_mix' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Peanut Butter' WHERE name = 'peanut_butter' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Jam' WHERE name = 'jam' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Yogurt' WHERE name = 'yogurt' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Grapes' WHERE name = 'grapes' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'tbsp Nutella' WHERE name = 'nutella' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups White Rice' WHERE name = 'white_rice' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Mango' WHERE name = 'mango_fresh' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Orange Juice' WHERE name = 'orange_juice' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'cups Strawberries' WHERE name = 'strawberries' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'packets Salt' WHERE name = 'salt' AND display_name_plural IS NULL;
UPDATE template_foods SET display_name_plural = 'Avocados' WHERE name = 'avocado' AND display_name_plural IS NULL;
