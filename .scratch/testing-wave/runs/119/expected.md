# Ticket 119 expected records (wave 36, run w36-20260926T0031Z)

No RevenueCat records are checked or written by this ticket.

## test@test.com (id 607f9dd5-6fa7-48ee-a628-720d4a0506a1), dev public.users
- Before: runs_with_water_bottle = false, first_name NULL, last_name NULL, email test@test.com,
  gender male, birthday 1996-01-14 (read 00:32 UTC, db-start-test-account.txt).
- 31-006 chip taps then leave without saving: no change to first_name, last_name, gender, birthday.
- 31-005 unsaved change then leave: no change to any column.
- 31-008 offline toggle + save: runs_with_water_bottle unchanged on dev while offline; true on dev
  after going back online (uploaded by the retry path); no success message that hides a failed save.
- End: runs_with_water_bottle = false again (put back), names and email untouched.

## Throwaway account (lee+e2e-119-<UTC>@rightpathprogramming.com)
- 31-004: after clearing First name and saving, public.users.first_name is NULL or '' and the
  screen shows it empty after reopening.
- 31-007: after editing Email and saving, either the field is read-only or auth.users.email and
  public.users.email agree (never differ from the login address).
- 31-011: Sign Out > Cancel keeps the session; Delete Account > Cancel leaves the public.users and
  auth.users rows in place.
- End: account deleted through the app; no public.users row, no auth.users row.

## Device
- 31-009: Appearance pick (Light/System) survives a relaunch; carry-over across sign-out recorded;
  Dark restored at the end.
