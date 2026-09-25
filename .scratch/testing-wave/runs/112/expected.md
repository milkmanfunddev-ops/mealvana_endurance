# 112 expected records (run w34-20260925T2320Z, app e3367d2c)

Account: test@test.com (dev). No RevenueCat record is checked in this ticket (no purchase path).
All checks read dev `meal_logs` / `saved_meals` with SELECT only.

## Retests
- 26-002 (fix 58): a Recent re-log of a multi-item meal writes one new `meal_logs` row whose `items`
  equal the source's items (same count, names, portions, numbers), totals equal the source's,
  `source` equals the source's `source`, `saved_meal_id` equals the source's (null for a non-saved log).
- 26-003 (fix 58): a Common quick-add tile ("Oatmeal + raisins") saves with `name` = the tile's name,
  items and totals equal the tile.
- 26-004 (fix 41): a quick add whose items carry no sodium saves `sodium_mg` null (unknown), not 0.
  Items do not gain a `"sodium_mg": 0`.
- 26-005 (fix 54): after a Recent re-log (and a recipe log) the meal is first in Recent without
  leaving Log a Meal.

## Follow-up tests
- 26-006: saved meal log -> row source saved, saved_meal_id set, the saved meal's items/totals;
  `saved_meals.last_used_at` bumped. Recent at 2 and 1.5 servings -> totals scale exactly.
  Trash on a throwaway saved meal asks first or offers undo; server row `is_deleted` true.
  Double tap Log it -> one row. Describe-sourced Recent re-log -> no AI call, totals equal source.
- 26-007: Common "Egg" at 1 and 1.5 servings -> totals x1 / x1.5 (sodium 71 -> 106.5); portion keeps its unit.
- 26-008: recipe logs = per-serving figure x servings; chips filter by type; search finds by name.
- 26-009: eaten_at = the time the sheet showed (or the tap time; note which); a changed time lands in
  eaten_at; dismissing writes nothing; offline log shows at once and uploads when back online.
- 09-005: same item twice -> two rows; changed time on the right day; offline log shows at once and
  uploads when back online; timeline totals follow.
