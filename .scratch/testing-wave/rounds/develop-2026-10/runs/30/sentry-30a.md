# Dev Sentry reads for 30a (read-only, project mealvana-endurance-dev)

Window: 12:55Z-13:03Z. This simulator's Sentry user before signup: 2A6B3725-7C9B-48AE-9E48-E1639C2CE6E3
(event context app_start_time 2026-10-08T12:56:42Z = this run's netcut launch).

- 12:56:59Z warning `OSError: Network is unreachable, errno = 51` (root /), user 2A6B3725. That is the anonymous sign-in
  failing while netcut was on (Build My Plan tapped 12:56:59Z): a warning, recorded in Sentry, so D9 is met.
- 12:58:11Z fatal `FlutterError: A RenderFlex overflowed by 971 pixels on the bottom.` user 2A6B3725,
  issue MEALVANA-ENDURANCE-DEV-B1, event ba3e81d087934a2aa441845a11d44049, view_names [onboarding]. Filed 30-002.
- No event of type EmailVerificationRequiredException, InvalidVerificationCodeException or DashboardTargetsAnomaly for
  user 2A6B3725 or a869be25-c973-46f8-ba86-7a665c079913 in the last 2 h (search_errors on both user ids returned only the two
  events above).
- Other events in the window belong to other users (607f9dd5…, 9472B22D…: TrainingPeaks/V.O2 token refresh, onesignal init
  skipped, integration sync cooldown), other wave runs on the shared dev account; not this run.

# Whole-run sweep (13:27Z, last 1 h, users 2A6B3725 [this simulator signed out], a869be25 [A], 1ffc8851 [anon → B],
# a8e2c6a5 [anonymous pass], 9f270ed1 [C])
- 12:56:59 warning OSError Network is unreachable (2A6B3725): anonymous sign-in offline, 30a step 1 (expected, recorded per D9).
- 12:58:11 fatal FlutterError RenderFlex overflowed by 971 px (2A6B3725): 30-002.
- 13:06:05, 13:06:34, 13:06:58, 13:14:05, 13:23:21 warning TimeoutException after 2 s: the region lookup held by netcut
  (7(i)/(ii)); known noise: the ticket holds app.mealvana.io on purpose; the app records the fallback (D9).
- 13:07:06, 13:14:05, 13:23:34 warning "Notification permission answer not stored: no local profile" (2A6B3725 / 1ffc8851):
  one per launch before any profile exists. Filed 30-011.
- 13:11:18 error OAuthCancelledException google sign-in cancelled (1ffc8851): 30-005.
- 13:11:33 warning SignInWithAppleAuthorizationException error 1000 (1ffc8851): 30-005.
- 13:13:10 warning AuthApiException 429 over_email_send_rate_limit (1ffc8851): 30-008.
- 13:16:49 warning AuthRetryableFetchException + OSError (1ffc8851): verify while offline (01-014 d), a real failure; fine.
- 13:19:36 error AuthApiException 422 email_exists + warning AccountAlreadyExistsException (a8e2c6a5): 30-005.
- 13:21:38 warning OSError (1ffc8851): offline delete-user (01-016 b), a real failure; fine.
- 13:23:02 error WrongCredentialsException + warning AuthApiException invalid_credentials (2A6B3725): login with a deleted
  account (01-016 d): 30-005.
- None of: DashboardTargetsAnomaly, SlowOperation, EmailVerificationRequiredException, InvalidVerificationCodeException.
