# 50-009 · V.O2 integrations row still holds the English last_sync_error 'Please reconnect your V.O2 account' and requires_reauth after ticket 37 (no backfill for existing rows)

- kind: bug
- status: open
- ticket: 50
- run: w5-20261008T1720Z
- screen: none (dev database, `integrations`)
- decision: 

**Steps.**
1. `select provider, is_active, last_sync_status, last_sync_error, last_sync_at, updated_at from integrations where
   user_id = '607f9dd5-…'` at the start of the run and again after the Connected Apps section.

**Expected.**
`last_sync_error` is null or a code (`network`, `rate_limited`, `http_<n>`, `reauth_required`, `unknown`), never an
English sentence (ticket 37); a disconnected row carries no reauth state.

**Actual.**
vdot: `is_active false`, `last_sync_status requires_reauth`, `last_sync_error "Please reconnect your V.O2 account"`,
updated 2026-10-08 13:26:26 (wave 3's disconnect, before the fix wave). Unchanged at 17:47Z. The app now shows the
card as plain Connect (the fixed `needsReconnect` ignores inactive rows), so the athlete sees nothing wrong, but any
reader of the column (coach views, support, analytics, a later reconnect that keeps `requires_reauth` since `error`
never overwrites it) gets the old sentence and state. Only rows written after the fix are clean (TP's after its
disconnect: status and error null). V.O2 could not be disconnected again in this run to show the new path clears it
(it is already inactive; no test login to reconnect).

**Evidence.**
- runs/50/db-integrations-start.txt vdot row at the start
- runs/50/db-integrations-after-tp-sync.txt vdot row unchanged, TP row clean

**Decision quote.**
> 

**Triage.**

