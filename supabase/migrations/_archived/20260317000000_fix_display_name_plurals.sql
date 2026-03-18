-- Fix display_name_plural for foods with dropped qualifiers and incorrect plurals

-- toast: "slices White Bread" → "slices Toast"
UPDATE template_foods
SET display_name_plural = 'slices Toast', updated_at = now()
WHERE name = 'toast';

-- chicken: "oz Chicken" → "oz Chicken (cooked)"
UPDATE template_foods
SET display_name_plural = 'oz Chicken (cooked)', updated_at = now()
WHERE name = 'chicken';

-- turkey_deli: "oz Turkey" → "oz Turkey (deli)"
UPDATE template_foods
SET display_name_plural = 'oz Turkey (deli)', updated_at = now()
WHERE name = 'turkey_deli';

-- sweet_potato: "Sweet Potatoes" → "Sweet Potatoes (baked)"
UPDATE template_foods
SET display_name_plural = 'Sweet Potatoes (baked)', updated_at = now()
WHERE name = 'sweet_potato';

-- coffee: "cups Coffee" → "cups Coffee (black)"
UPDATE template_foods
SET display_name_plural = 'cups Coffee (black)', updated_at = now()
WHERE name = 'coffee';

-- white_rice: "cups White Rice" → "cups White Rice (cooked)"
UPDATE template_foods
SET display_name_plural = 'cups White Rice (cooked)', updated_at = now()
WHERE name = 'white_rice';

-- mango_fresh: "cups Mango" → "cups Mango (fresh)"
UPDATE template_foods
SET display_name_plural = 'cups Mango (fresh)', updated_at = now()
WHERE name = 'mango_fresh';

-- protein_powder: "scoops Protein Powder" → "scoops Protein Powder (whey)"
UPDATE template_foods
SET display_name_plural = 'scoops Protein Powder (whey)', updated_at = now()
WHERE name = 'protein_powder';

-- trail_mix: "portions Trail Mix" → "servings Trail Mix"
UPDATE template_foods
SET display_name_plural = 'servings Trail Mix', updated_at = now()
WHERE name = 'trail_mix';
