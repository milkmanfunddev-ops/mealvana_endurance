# Ticket 14 expected records (run w8-20260924T1418Z)

Account: the entitled dev test account from the credentials file, `test@test.com`
(user id `607f9dd5-6fa7-48ee-a628-720d4a0506a1`, dev). No new account.

Checked against mp-241: "New meal plan" archives the plan it is on and starts a fresh, empty draft;
every conversation with Vana builds its own Draft.

## RevenueCat
Nothing read or written: the ticket names no RevenueCat record. Entitlement is checked in the dev
`user_entitlements` row only (active_until in the future before the run).

## Dev database, before (db-before-*.txt)
- `user_entitlements` row for the account with `active_until` > now.
- The plan the Plan tab shows (the plan "it is on"): one `meal_plans` row, status `draft` or
  `confirmed`, not `archived`, `is_deleted = false`.

## Dev database, after tapping New meal plan (db-after-*.txt)
- That plan row: `status = 'archived'`, `updated_at` after the tap.
- Exactly one new `vana_conversations` row for the account (kind planning), created after the tap,
  holding no athlete message (only Vana's opener, if any).
- Exactly one new `meal_plans` row, `status = 'draft'`, created after the tap, with no
  `plan_meals` rows (fresh, empty draft), `conversation_id` = the new conversation's id.
- No other plan of the account changes status; nothing is deleted.
