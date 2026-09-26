# Ticket 120 expected records (wave 39, run w39-20260926T1013Z)

Written before the app was launched. Judged against the fix tickets 102-106 and each Finding's Expected.

## Local Drift (read-only copies of the app's database)
- Before launch: leftover rows of 37129f7e (Lee) and 607f9dd5 (test@test.com), none dirty
  (runs/120/local-drift-00-before-launch.txt).
- 86-001 (ticket 102 item 5): after test@test.com signs in, every clean row of 37129f7e is gone
  (it has no dirty rows); test@test.com's own rows are there.
- 86-007 (ticket 102 items 3-4): test@test.com, network cut, Manual meal log -> one meal_logs row with
  needs_upload = 1. Sign out offline: one MealvanaSnackbar line says unsynced changes stay on this
  phone and sync at next sign-in. After the sign-out the account's clean rows are gone; the dirty
  meal log, its parents (the users row) stay. Signing in as another account (new account B) keeps
  test@test.com's dirty row (its unsynced rows stay for its own next sign-in); B sees none of it.
  When test@test.com signs in again the row uploads: dev meal_logs has it, local needs_upload = 0,
  and it is on the Timeline.
- 86-002: once sync settles after login, the local status of each of test@test.com's week 2026-09-20
  plans equals dev's (dev at 10:14Z: 9be88811 confirmed, 50390c90 draft, the rest archived;
  runs/120/db-00-test-plans-before.txt).
- 86-003: the Plan tab, opened within 5-10 s of login, never lists a meal the confirmed plan on dev
  does not hold (dev 9be88811: "Sweet rice cake with jam", 1 meal); the stale local be6abf2f draft
  (5 meals incl. "Brown rice, zucchini & chickpea bowl") never shows.

## Dev database (SELECT only)
- 86-010: after tapping the connected app's name suggestion and Save, public.users first/last name
  change, email stays test@test.com.
- 86-007: the offline meal log is in public.meal_logs for 607f9dd5 after test@test.com's next sign-in.
- New accounts: a public.users row with the signup address after signup; no user_entitlements row
  for an unpaid account; gone after in-app delete.

## RevenueCat
- New unpaid account B: customer, no active entitlement.
- Paid account C: Test Store monthly -> active pro entitlement; after sign-out it lapses about
  5 minutes later (no active entitlement).
- 06-004: C signing in after B lands in the app with no paywall frame; B signing in after C lands
  on the paywall and never sees the app (mp-335).
- 12-007: admin (test@test.com) signs out, Lapsed C signs in -> full-screen paywall, no close
  button (mp-416, mp-457).

## Vana chat (86-005, ticket 104 item 2)
- After Don't Allow on Speech Recognition the Dictate button stays; a tap shows a MealvanaSnackbar
  saying dictation needs Speech Recognition and Microphone access, turned on in iOS Settings -> Mealvana.

## Log In (86-008)
- Wrong password: a clear message, form usable again. Right password with a second tap on Log In
  while busy: one sign-in (one `email_sign_in_success`), no second navigation.

## 86-012 (ticket 103)
- The coordinator tests pass: a failed upload is logged, rows stay dirty, the pull still runs.
