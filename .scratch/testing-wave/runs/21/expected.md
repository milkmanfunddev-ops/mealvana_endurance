# Ticket 21 expected records (run w17-20260924T2233Z)

Account: test@test.com, user id `607f9dd5-6fa7-48ee-a628-720d4a0506a1` (dev). No RevenueCat record
is named by the ticket; RevenueCat is not written or checked beyond "the account is entitled".

## Before (read by the wave lead at 22:35 UTC 09-24; re-read by this run at 22:34 UTC, same values: `db-kroger-before.txt`)

- `kroger_connections`: 1 row, `environment = 'production'`, `updated_at 2026-09-17 14:14 UTC`,
  `expires_at 2026-09-17 14:44 UTC` (access token expired), refresh token present.
- `kroger_oauth_sessions`: 0 rows.
- `kroger_drafts`: 6 rows, newest `updated_at 2026-09-17 14:12 UTC`, all `environment production`,
  store `540FC242` (Kroger Birmingham Spoke). (`db-kroger-drafts-before.txt`)
- `kroger_exports`: 6 rows, all `sent`, all `production`, newest `2026-09-17 13:56 UTC`.

## After (what the ticket expects)

- `kroger_connections`: exactly 1 row for the user, `updated_at` inside this run's minutes, a fresh
  `expires_at` in the future (about 30 min after connect), refresh token present, and
  `environment = 'certification'` (spec, "Kroger." bullet: "Runs against Kroger's certification
  environment with Lee's shopper login").
- `kroger_oauth_sessions`: the row `connect` writes is consumed by `exchange` (0 rows left for the
  user, or one expired row if exchange keeps it).
- `kroger_drafts`: at most one new or updated row, for the plan whose list the Shopping tab shows
  (draft plan `173cebb2…`, list `813df86f…`), written by opening the Kroger screen.
- `kroger_exports`: unchanged (6 rows, newest 09-17). Nothing is sent to Kroger in this ticket.
- The account is left connected for ticket 22.
