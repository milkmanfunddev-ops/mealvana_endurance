# Ticket 22 expected records

Account: test@test.com (user 607f9dd5-6fa7-48ee-a628-720d4a0506a1), the entitled dev test account. No new account.

## Before (db-kroger-before.txt, 01:27 UTC 2026-09-25)
- `kroger_connections`: one row, environment `production`, updated 2026-09-24 22:39:27 UTC (ticket 21's connection).
- `kroger_drafts`: 7 rows, newest plan 173cebb2 (revision 1, production, no store, 11 lines, 22:40:24 UTC).
- `kroger_exports`: 6 rows, all production, status sent, newest 2026-09-17 13:56 UTC.
- RevenueCat: not touched by this ticket (no purchase, no grant). Nothing to check.

## After
- `kroger_connections`: one row, environment `certification`, updated during this run (disconnect deletes the old row, connect writes the new one). If it says production: stop, no send.
- `kroger_drafts`: the draft for the plan the Shopping tab shows gets a store, matched products and approvals, revision rising with each edit, environment certification.
- `kroger_exports`: one new row for that plan, environment certification, status sent, its lines = the matched lines sent (UPC and quantity per line).
- Criterion 3: every unmatched line and every wrong match is a Finding naming the list row and the product.
- Criterion 4 (hand-off opens Kroger's cart with the matched items): cannot be seen on dev under Lee's certification ruling; `_openKroger` returns false outside production. Expected: after the send the app opens nothing, and a hand-off button raises `unavailable`. Filed as a followup-test, not ticked.
- The shopping list itself is not changed.
