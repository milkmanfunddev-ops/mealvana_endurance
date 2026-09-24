# 28 expected records (run w15-20260924T2040Z)

From the ticket's criteria. No RevenueCat records are touched.

**Before.**
- Account: the entitled dev test account `test@test.com` (from the credentials file), no new account.
- Dev database `meal_logs` for test@test.com on 2026-09-23: whatever is there already (recorded in `db-before.txt`); no row with `log_method = 'barcode'` from this run.

**After, if a barcode path works on the simulator.**
- One new `meal_logs` row for test@test.com, `log_method = 'barcode'`, on 2026-09-23 (or 2026-09-24 if the day cannot be picked), whose name, calories and macros match what the confirm screen showed.

**After, if scanning cannot work on a simulator.**
- No new row from this run.
- Exactly one followup-test Finding marks the camera path for a device and says what to check there.

**RevenueCat.** Not read or written by this ticket (entitlement is assumed live; the app must not show the paywall).
