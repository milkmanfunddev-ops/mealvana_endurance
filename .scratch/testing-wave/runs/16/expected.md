# Ticket 16 expected records (run w9-20260924T1446Z)

Account: the entitled dev test account `test@test.com` (user id `607f9dd5-6fa7-48ee-a628-720d4a0506a1`, dev).
No new account, no new plan generated (no COST spend).

Checked against mp-241 ("Confirming a draft archives every other plan for that week, drafts from other
conversations included"), mp-244 (the server builds the list at confirm; Confirm waits for it) and mp-235
(Confirm lands on Food > Shopping with the tab bar showing).

## RevenueCat
Nothing read or written: the ticket names no RevenueCat record.

## Dev database, before (db-before.txt)
- `user_entitlements`: active_until in the future.
- Week 2026-09-20: `be6abf2f` confirmed (4 meals), Draft `54a02440` (conversation `d8efbdb3`, 1 meal:
  Egg & Veggie Scramble, saved meal `fd993bbb`), `6f365c30`, `15b6b4f4`, `b82409d9` archived.
- Draft's list `9bdc9556` exists (plan_id 54a02440, 6 plan rows, confirmed_at null).

## Dev database, after Confirm (db-after.txt)
- `54a02440`: `status = 'confirmed'`, updated_at after the tap.
- Every other week-2026-09-20 plan of the account: `status = 'archived'` (so `be6abf2f` flips
  confirmed -> archived). Exactly one confirmed, non-deleted plan for the week.
- No other week's plan changes status; nothing deleted; no new `meal_plans` row.
- The Draft's list `9bdc9556` (the plan's one list): `confirmed_at` set at the tap, sorted first.
- Its `source='plan'` rows equal what the server's rules (`grocery.ts buildItems`) build from the
  plan's meals: for Egg & Veggie Scramble x1 (`saved_meals.ingredients_json`), 6 rows: Egg 2, Butter
  10 g, Heavy cream 15 ml, Spinach 50 g, Bell pepper 40 g, Mushroom 30 g; salt and black pepper
  skipped as always-have. Each row's `from_meal_ids` = the plan meal id `97b0f6f4`.
- `meal_plans.shopping` of `54a02440` mirrors the same 6 lines.

## Screen, after Confirm
- The Review sheet's Confirm waits for the server, then the athlete lands on the main screens with
  Food > Shopping open and the tab bar showing (mp-235); the list shows those 6 rows in aisle groups,
  imperial units unless Settings says metric (mp-244).
- The Plan tab's plan bar shows the confirmed plan (1 meal, Egg & Veggie Scramble).
