# Ticket 111 expected records (run w30-20260925T2103Z)

Account: test@test.com (user 607f9dd5-6fa7-48ee-a628-720d4a0506a1). Dev `kroger` function runs certification.
Confirmed plan 666be167 (week 09-20), its list c667902d. Read only.

## Before (read 2026-09-25T21:04Z, db-kroger-before.txt)
- `kroger_connections`: one row, environment `production`, expires 2026-09-24 23:09:27Z (the 22-005 leftover).
- `kroger_oauth_sessions`: none expected.
- `kroger_drafts`: none for plan 666be167.

## During / after, per check
- 20-008: opening Food > Shopping leaves no `POST /functions/v1/kroger` 400 in the dev edge log for the run's minutes.
- 22-005: `status` returns `other_environment: production`; the screen shows the kroger.other_environment line and Disconnect;
  confirmed Disconnect deletes the production row (no `kroger_connections` row after).
- 22-004: `location` + `search` run on the application token with no connection; the draft for plan 666be167 gets a store and matched lines
  (`kroger_drafts` row for 666be167 with store set). Add to Kroger cart asks to connect first.
- 21-005: Cancel / X leave no `kroger_connections` row; ticket expects no leftover `kroger_oauth_sessions` row.
- 21-007: offline connect makes no session and shows a plain message; double tap gives one `kroger_oauth_sessions` row.
- 21-006, 21-008, full 21-003 connect: need a certification shopper login (none exists apart from Lee's, which this run never uses).
- 21-010: Disconnect asks first; Cancel keeps the row, Confirm deletes it.

## End state
- test@test.com: no `kroger_connections` row (production row removed by 22-005, no connect completes).
- No account created by this run.
