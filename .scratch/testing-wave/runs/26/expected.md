# Ticket 26 expected records (run w13-20260924T1904Z)

Account: test@test.com (user 607f9dd5-6fa7-48ee-a628-720d4a0506a1), entitled dev test account. No new account.
RevenueCat: nothing expected to change (no purchase in this ticket); not checked beyond that.
AI: no AI call. No `meal-ai` / `vana-*` edge-function request from this run.

## Before (dev `meal_logs`, read 2026-09-24 ~19:10 UTC)
- Newest non-deleted rows for the account: a281f826 / 915ac609 (Patrol Build, 09-23), 9162543b "Rice cake and Almond butter" (09-23, manual, 168 kcal, 2 items), 8a4e9125 "Oatmeal with Blueberries" (09-16, describe).
- No row created by this run exists yet. Ticket 23 (same account, other simulator) may add one describe row today with "W13-23" in its text; that row is not mine.

## After: three new rows, one per source, each equal to its source
Each new row: user_id = test account, log_date = today (2026-09-24, device local), is_deleted = false,
created_at inside my own save window, and after upload present on the server.

1. Recent (source row 9162543b "Rice cake and Almond butter", picked because it is older than
   anything ticket 23 writes today), logged at 1 serving:
   name = "Rice cake and Almond butter", calories 168, carbs_g 18.0, protein_g 4.8, fat_g 9.6, sodium_mg 0.0
   (equal to the source row). Code (log_meal_screen `_onRecentTap`) sets source='saved', saved_meal_id null,
   recipe_id null, and items = one synthetic component (name = meal name, portion '1 serving', totals) instead of
   the source's two items. The totals must equal the source; the item-level difference is written up if it shows.
2. Common (static `kCommonIngredients` entry "Egg": portion '1 large', 72 kcal, 0.4 C, 6.3 P, 5.0 F, 71 mg Na), 1 serving:
   name = "Egg", calories 72, carbs_g 0.4, protein_g 6.3, fat_g 5.0, sodium_mg 71, source='manual',
   recipe_id null, saved_meal_id null, items = [one component "Egg"].
3. Recipes (changed at 19:08Z, see notes: dev `recipes` row a1b2c3d4-e5f6-7890-abcd-000000000017 "Cottage Cheese & Pineapple Bowl": 300 kcal, 38 C, 28 P, 5 F, 450 mg Na, servings 1), 1 serving:
   name = "Cottage Cheese & Pineapple Bowl", calories 300, carbs_g 38, protein_g 28, fat_g 5, sodium_mg 450,
   source='recipe', recipe_id = a1b2c3d4-...-000000000017, saved_meal_id null, items = [one component with the recipe name, portion '1 serving'].

If the tab shows a different item than planned (list order, empty tab), the pick changes and notes.md says so.

## Change at 19:09Z: Common pick
The Common tab opens on "Quick add" combos; the single ingredients (Egg) sit below them. I logged the
visible combo "Oatmeal + raisins" instead (kQuickAssemblies: Rolled oats 1/2 cup dry 150 kcal 27 C 5 P 2.5 F;
Raisins 2 tbsp 54 kcal 14 C 0.6 P 0.1 F; no sodium on either), because a two-item combo tests more of
"saves as the source had it" than one ingredient. Expected row: items = those two components unchanged
(names, portions, macros), calories 204, carbs_g 41.0, protein_g 5.6, fat_g 2.6, source='manual',
recipe_id null, saved_meal_id null. Code names it deriveMealName(components) = "Rolled oats and Raisins",
not the tile's "Oatmeal + raisins"; sodium_mg is summed with null as 0.
