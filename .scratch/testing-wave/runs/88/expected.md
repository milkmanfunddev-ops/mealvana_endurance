# Ticket 88 expected records (retest, wave 29, RUN w29-20260925T1949Z)

Account: test@test.com (user 607f9dd5-6fa7-48ee-a628-720d4a0506a1), dev. No RevenueCat writes; the
account is entitled (admin/test account) and nothing here touches RevenueCat.

## Before (db-00-before.txt, 19:50:54Z), week 2026-09-20
- be6abf2f confirmed (conv f6a0f7fa), 4 meals, no shopping list, empty `shopping` mirror.
- 173cebb2 draft (conv 0401b3d8), 2 meals, list 813df86f (11 items, not confirmed).
- archived: 6f365c30 (0b7df6f0), 15b6b4f4 (ebac747d), b82409d9 (1f805690, 0 meals), 54a02440 (d8efbdb3).
- meal_library: 0 of 1,922 active meals with a blank kcal/carbs/protein/fat.

## Retests (what the fixes promise)
- 14-001/14-002 (fix 70, mp-234, mp-668 ruling): New meal plan leaves be6abf2f confirmed and
  unchanged; a new meal_planning conversation row; the plan bar reads "Your plan · 0 meals" before
  any pick. (Whether the draft row exists before the first pick is not required by the ruling.)
- 15-001 (fix 71): archived draft's conversation (ebac747d → 15b6b4f4) says another plan was
  confirmed for the week; read-only (no -/+, no ×, no Confirm); "Use this plan instead". No write
  from viewing.
- 15-002/15-003/16-004/16-005 (fix 48): question once; cards of meals in the conversation's plan
  ticked; singular counts; header is the plan's, not "New meal plan". No writes.
- 16-001 (fix 34): Confirm in a Draft's conversation while the week has a confirmed plan confirms
  that Draft; every other plan of the week archived; its list confirmed (confirmed_at set), rows
  equal to its meals' ingredients (mp-244). Run AFTER 89's flag.
- 16-002 (fix 72, mp-235): after Confirm, Food opens on Shopping with the tab bar.
- 18-001/18-003 (fix 34): reopened Browse shows planned meals ticked; a tap on a ticked card or
  the detail's Add to plan never raises servings.
- 29-001/61-001 (fixes 61, 74): no blank-number meal in any plan; Swap list shows none; with no
  blank meal on dev, the check is that every offered/placed meal carries numbers.

## After
- One new plan (COST plan 88) in a new conversation; confirmed only after 89's flag; then it is
  the only confirmed plan for 2026-09-20, be6abf2f and 173cebb2 archived, 813df86f deleted
  (ticket 101's rule), the new plan's list confirmed.
- No account created (test@test.com only), so nothing to delete at step 9.
