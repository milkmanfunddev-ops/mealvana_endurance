# Ticket 89 expected records (run w29-20260925T1950Z)

RevenueCat: nothing expected to change (no purchase in this ticket).

Dev DB, test@test.com (607f9dd5), before (db-00-baseline.txt, matches the wave lead's prompt):
- be6abf2f week 2026-09-20 CONFIRMED, 4 meals, `shopping` mirror empty, no shopping list.
- 173cebb2 draft (conversation 0401b3d8) with list 813df86f (11 items). Not touched by this run.
- Lists: 90c2fefc "List 2026-09-19" (9), 23a6ab6c/f7eb5cc7 "List 2026-09-16" (0), debb5576/77fd387c/d907ba91/7ed03528 (week of 09-13).

After, by retest / follow-up:
- 17-001 / 17-003: Previous plans lists every plan that `list_plans` should list (confirmed, or `confirmed_at` set, with meals, minus the Plan tab's plan); opens within a second or two; `list_plans` edge time well under 8 s.
- 17-002: no never-confirmed draft (fc9687ff, 968c5a59) is listed.
- 73-001: two Use this plan again in a row leave ONE live conversation-less draft for week 2026-09-20; the first copy is `archived`.
- 18-004: Browse search "salmon" returns only meals with salmon in name/ingredients (none, for a vegetarian account, or a clear empty state); subtitles are not research notes.
- 19-003: Previous lists scrolls to the last list with no overflow stripe.
- 19-009 (mp-244): the first edit of be6abf2f makes ONE `shopping_lists` row with plan_id=be6abf2f holding the plan's rows, and fills `meal_plans.shopping`; the Shopping tab then opens that list.
- 19-007: rename/delete rows in `shopping_lists` match what the sheet shows; one delete call per delete; Keep it writes nothing.
- 17-005 / 17-006 on a throwaway account: deleted plan shows a clear message; empty sheet shows its empty text; offline shows its failed text.
- 18-010: detail controls from Browse do not add to any draft (plan_meals unchanged except by Add to plan).
