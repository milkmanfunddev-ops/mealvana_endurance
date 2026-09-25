# Ticket 110 — expected records (written 2026-09-25T21:05Z, before touching the app)

Account: test@test.com (607f9dd5). Confirmed plan for week 2026-09-20: 666be167 (conversation 9db7c080),
its list c667902d "Week of Sep 20" (3 rows: Wholewheat pasta, Avocado, Mixed vegetables; none checked).
Ticket 111 writes the Kroger connection rows on the same account (expected, not checked here).
No RevenueCat record is read or written by this ticket.

## Before (db-00-before.txt)
- meal_plans: 666be167 confirmed; every other week-2026-09-20 plan archived.
- shopping_lists: c667902d (666be167) is the default list; archived drafts have no list (ticket 101),
  except once-confirmed be6abf2f (2a4cbd64, 17 rows incl. Farro x2 meals, Spelt, Mixed vegetables).
  Hand-made list 90c2fefc "List 2026-09-19".

## Per check
- 16-007: Farro/Spelt in Bakery & Grains, Mixed vegetables in Produce (or Frozen); plan list named "Week of Sep 20".
- 18-006: a list with Sweet rice cake with jam has a dry rice amount or a "Cooked ..." row, never "Short-grain rice 1.6 kg".
- 19-005: Previous lists marks the confirmed plan's list ("This week's plan").
- 19-001: deleting a hand-made list made by this run leaves the tab on c667902d; c667902d untouched.
- 19-006: a new hand-made list does not become the tab's default; after relaunch the tab opens c667902d.
- 20-001: ticks made offline stay ticked after an offline restart and reach shopping_items.checked when the network returns.
- 20-002: offline shows an offline notice; Shop with Kroger hidden/disabled; a failed write shows a MealvanaSnackbar.
- 18-002: Browse + in a planning conversation builds/updates a draft's list, but the Shopping tab keeps c667902d.

## After
- c667902d still exists with its 3 plan rows; ticks this run makes are undone at the end (checked=false),
  unless noted in notes.md.
- Every hand-made list this run creates is deleted by the run (19-001 deletes one; the rest at the end), noted with ids.
- 666be167 stays confirmed; no other plan confirmed.
