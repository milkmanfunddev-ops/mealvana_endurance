# 115 expected records (run w32-20260925T2219Z)

Retest of 26-001 19-004 20-003 10-001 04-001 16-003 on app build e3367d2c.

## Before (dev DB, read 22:2xZ, db-before.txt)
- test@test.com week 2026-09-20: confirmed 666be167 (conv 9db7c080, confirmed 20:28:08Z), draft 9be88811
  (conv 7cc15497, created 21:24:11Z). Also still confirmed: 8ebeb6da (confirmed 20:21:43Z), noted below.
- Shopping lists: c667902d for 666be167 (3 items, 0 checked); 8719653f for draft 9be88811 (5 items, confirmed_at null).
- meal_logs: none on 2026-09-25; nine live rows on 2026-09-24 (W15-27 edited, W14-25 Built bowl, ...).
- saved_meals: "Egg & Veggie Scramble", "Quinoa, mixed veg & walnuts".
- RevenueCat: test@test.com is the admin; no RC change expected.

## After
- 26-001: Recent lists earlier meals on first open, before Food ever opened.
- 19-004: Plan sub-tab shows a loading card (not "No plan yet") until the plan is read.
- 20-003: after a cold restart the Shopping rows do not jump; c667902d back to 0 checked after untick.
- 04-001: console tracks `paywall_delete_account_tapped` (AccountDeletionEntry.paywall), not
  `settings_delete_account_tapped`; account gone from auth.users; RC customer deleted.
- 10-001: lapsed account's meal_logs row shows on today's timeline after resubscribe on a cleared app,
  without opening Food; account deleted after.
- 16-003: plan 9be88811 status confirmed with confirmed_at set; 666be167 (and 8ebeb6da) archived
  (mp-241); list 8719653f (or a new list) for 9be88811 with confirmed_at set; Shopping tab shows
  loading or the list, never "No shopping list".
