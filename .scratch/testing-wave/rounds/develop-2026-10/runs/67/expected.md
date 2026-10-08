# Ticket 67 expected records (written before the run)

Run w7-20261008T2308Z, app build ff4e0ffb. Cost: none (no AI calls). No RevenueCat writes; the ticket names none.

## Prefs (container plist `flutter.*`)
- Check 1, after Continue on Your privacy with the switch ON: `analytics_consent_status = granted`, regime `strict`.
- Check 4, after Settings → Privacy switch OFF: `analytics_consent_status = denied`.
- Check 5, after the hint's Log in and the login as A (app terminated, plist read): no `flutter.pending_signup_v1` key.

## Console
- Check 1: `📊 [ANALYTICS]` lines from the ON tap / Continue on (Noop echo format in a debug build without ANALYTICS_DEV_ENABLED).
- Check 3: `expected_failure {area: auth, reason: apple_no_account}` (or a breadcrumb note line); none of `auth_apple_native_failed`,
  `auth_flow_failed`, `error_reported`. No snackbar.
- Check 4 OFF: no further sends over two screens (judged on prefs value + line format, per the code map).

## Dev database / auth (read-only SQL)
- After signup A verified: one auth.users row for A, `email_confirmed_at` set, public.users row present.
- After check 5: B's anonymous auth user exists, B address in `email_change`, never confirmed (leftover for the sweep).
- After check 10 (delete in app): A's auth.users row gone; `sweep-accounts.mjs footprint <A id>` → no rows (as runs/48/footprint-A.txt).

## Dev Sentry (read-only)
- Nothing new in the minute of check 3 (Apple sheet Close).

## RevenueCat
- No writes. Not read unless something on screen suggests a subscription change (none expected).
