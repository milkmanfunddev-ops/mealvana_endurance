# Ticket 25 expected records (run w14-20260924T2015Z)

Account: test@test.com (user 607f9dd5-6fa7-48ee-a628-720d4a0506a1), entitled dev test account. No new account.
RevenueCat: nothing expected to change (no purchase); not checked beyond that.
AI: no AI call. No `describe-meal` / `meal-ai` / `vana-*` model call from this run; COST not spent.

## Before (dev `meal_logs`, read 2026-09-24 ~20:18 UTC)
Newest rows: 9162543b (09-23), d53078c8 / 915ac609 / a281f826 (Patrol, 09-23), and today's 38c4f0ed "W13-23 Lunch",
00a120e5, f952f981, 46b1d076 (wave 13). No row named "W14-25 ..." exists. Ticket 24 (wave-pool-1, same account)
adds one photo-logged row today; not mine. saved_meals for the account: 1 row.

## After: my rows, each named with "W14-25", log_date 2026-09-24, is_deleted false, created_at inside my save window

1. Manual (Log a Meal → Manual tab, `ManualLogForm` → `logManualMeal`):
   name "W14-25 Manual oats", slot breakfast, calories 437, carbs_g 61.3, protein_g 23.5, fat_g 11.7,
   sodium_mg 287, notes "W14-25 manual note", source 'manual', items [] (code passes no components),
   recipe_id / saved_meal_id null.
2. Build a meal (Log a Meal → Build a meal → + Add food): two foods
   - Common ingredient "Chicken breast" (kCommonIngredients: 4 oz cooked (115 g), 187 kcal, 0 C, 35 P, 4 F, 84 mg Na)
   - Manual component "W14-25 jasmine rice", portion "1.25 cup", 263 kcal, 57.4 C, 5.3 P, 0.6 F, 3 mg Na
   Meal name "W14-25 Built bowl", slot dinner. Expected row: source 'manual', items = those two components
   unchanged, calories 450, carbs_g 57.4, protein_g 40.3, fat_g 4.6, sodium_mg 87. "Also save as a favorite" left
   off, so saved_meals stays at 1 row.
3. (Edge of "saved equals entered") Manual tab: "W14-25 Decimal kcal", 250.5 kcal, 30.2 C, 12.25 P, 8.4 F, no sodium,
   no slot. Code parses calories with int.tryParse, so 250.5 is expected to save calories null (a bug if so);
   12.25 P against numeric column scale is expected to round. What the row holds is the result.
