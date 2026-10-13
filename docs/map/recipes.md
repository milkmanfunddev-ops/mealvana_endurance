# Recipes

domain: 4 Log what you ate · folder: `lib/features/recipes/` (3 files, no screen)

The "Recipes" tab on "Log a Meal" (`meal_logging.md`): the Supabase `recipes` table and `recipe-images` bucket,
kept on the phone and refreshed daily; a recipe logs as one line. Reuse: `recipe_service` (its `toggleFavorite` /
`getFavoriteRecipes` are dead), `recipe_repository`.
