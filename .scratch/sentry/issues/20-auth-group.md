# 20: Auth group

**What to build:** MEALVANA-ENDURANCE-CX, CW (refresh-token connection abort), CF (Google sign_in_failed), CH (invalid API key), CG (account creation failed); OAuthAccountNotFound (CE, CZ, CQ) confirmed as Degraded by the allow-list. Fix the real ones.

**Blocked by:** 10 Contract

**Status:** done except the Sentry resolves (lead, after merge) and the owed items below

- [x] Root cause per issue in the ticket; CH's invalid API key source found
- [x] Fixes landed; the Degraded ones no longer appear as errors (allow-list + filter tests; no build carrying them has shipped yet, so Sentry itself cannot show it until one does)
- [ ] Issues resolved in Sentry (lead resolves after merge, table below)

Events read 2026-10-06 (latest event + event list + tags for every issue below); raw JSON is in the
wave scratchpad `20/`, not in the repo.

## Root cause

**CX** `AuthRetryableFetchException(ClientException: Software caused connection abort)` and **CW**
`ClientException: Software caused connection abort`: one moment, one user (Pixel 9 Pro XL, Android 17,
1.27.1+143, 2026-09-25 15:15:04/05). The supabase auto-refresh tick's `POST /auth/v1/token?grant_type=refresh_token`
lost its socket (Android `ECONNABORTED`: network switch or app backgrounded mid-request). CW is the SDK's
own HTTP-client capture (`mechanism: SentryHttpClient`), CX is the same failure surfaced by gotrue a
millisecond later. gotrue retries the refresh on the next tick; nothing for the app to do. The
allow-list had `Connection reset by peer` (DEV-5's wording) but not Android's "Software caused
connection abort". Degraded.

**DEV-5** (`AuthRetryableFetchException: Connection reset by peer`, 102 events): same failure on iOS.
`Connection reset by peer` has been on the allow-list since 2026-07-11, and every event predates the
2026-10-05 drop→downgrade change, so they arrived as `error` from builds without the downgrade. Covered.

**CF** `PlatformException(sign_in_failed, K3.a: 8: )`: google_sign_in on Android, `ApiException` status
8 = `INTERNAL_ERROR` (R8 renamed the class to `K3.a`). Status 8 is **not** the SHA-1 / OAuth-client
mismatch: that is status 10, `DEVELOPER_ERROR`. Evidence that the config is sound:
- Both CF events are one device (OnePlus 8 Pro, Android 11, prod 1.27.1+143 and 1.28.0+146). On
  2026-09-25 the same device's Google sign-in got through to Supabase at 18:49:00 (CQ), failed with
  status 8 at 19:31:05 (CF), and got through again at 19:31:53 (CE). A misconfigured client fails every
  time.
- `android/app/src/prod/google-services.json` registers two Android OAuth clients for
  `com.milkman.mealvanaendurance`: SHA-1 `AB:86:C5:…:7A:0D` (matches the upload keystore
  `secrets/google/mealvana-upload-keystore.jks`, alias `upload`, verified with keytool) and SHA-1
  `D7:C7:4B:…:01:70` (presumably the Play App Signing key, which re-signs store installs). The web client
  `171527646530-d1hr…` is the `serverClientId` in `oauth_service.dart`.

So status 8 is a transient Google Play services failure on that device (old Play services on Android
11 is the usual suspect). Degraded with its own tag; status 7 (NETWORK_ERROR) is offline; status 10 and
12500 stay Faults.

**CH** `AuthApiException(message: Invalid API key, statusCode: 401)`: **not a store build and not a
stale key baked into a release.** The event's tags: `environment: development`, `release
mealvana_endurance@1.27.0+3`, `dist 3`, `contexts.app.build_type: simulator`, bundle
`com.milkman.mealvanaendurance.dev`, iPhone18,1 simulator, 2026-09-23 14:48–14:52. The breadcrumbs show
every Supabase call from launch on answered 401: `GET vlmtsdzpnjnavdgytcmi…/rest/v1/app_config` at
14:48:03, two `app_content` reads, then the signup `POST` at 14:52:11. So it was a local dev simulator
run whose `.env.dev.local` paired the **dev** URL with a client key the dev project never issued. The
dev project's keys have not rotated (anon JWT and `sb_publishable_O…` both created 2025-10-07, verified
via the Management API), so the key came from another project, most likely prod's (both prod keys
answer 401 on the dev URL; checked). The same file had no `SENTRY_DSN`, so the pre-ticket-02
`AppConfig` fallback sent the event to the **prod** Sentry project. That is why a development event
sits in the prod project. Every `.env.dev.local` on this machine today (11 copies across the main checkout and worktrees,
one distinct content) has the dev URL, dev keys and the dev DSN, and answers 200. The bad file no longer
exists, so which hand-made copy it was cannot be recovered. Ticket 02 already removed the DSN fallback,
so the next mismatch stays out of the prod project. No shipped client was affected.

**CG** `Exception: Account creation failed. Please try again.` (and dev twins **DEV-8Q**, **DEV-8X**):
the wrapper of a real cause, 5 ms later on the same device each time. CG wraps CH (14:52:11.991 →
.996), DEV-8Q wraps DEV-8P (`unexpected_failure: Error sending confirmation email`, 500), DEV-8X wraps
DEV-8W (`Error sending email change email`, 500). `EmailAuthService.signUpWithEmail` /
`linkEmailAccount` caught every failure, reported it, then threw a **new**
`Exception('Account creation failed…')`. The controller and the Riverpod net reported that new object;
`Report`'s identity dedupe could not tie it to the cause, so every failed signup made two issues, one
of them causeless. Nothing read the wrapper's text: the signup screen shows
`auth.post_onboarding.error_email_failed` from the content system for any failure it does not route on.

**DEV-8P / DEV-8W** (GoTrue 500 `unexpected_failure`, "Error sending … email"): dev SMTP was failing on
2026-09-21; the 09-22 Sentry bugfix batch fixed dev and prod email. Real Faults if they come back, so no
needle.

**CE, CQ, CZ** `OAuthAccountNotFoundException`: expected (a login-mode OAuth sign-in found no account;
the screen says "try the provider you signed up with"). The needle `OAuthAccountNotFoundException` →
`account_not_found` is on the allow-list and matches `describeThrowable` of the real exception (test
added). The newest event in any of the three is 2026-10-02 (CE, 1.29.0+148); **no event arrived after
2026-10-05**, in prod or dev. All 19 events came from 1.27.1–1.29.0, which predate the `sentry` branch
(the allow-list downgrade landed there 2026-10-05 and has not shipped), so they were `error`. Nothing
to fix. The controller's own `info` was never the source: the Riverpod net reports the controller's
`AsyncError` itself, which is why the type has to be on the allow-list.

**DEV-8M, 9J, 9S, 9T, 9X** `PlatformException(10, A network error has occurred…)`: not google_sign_in.
These are **RevenueCat** (`readableErrorCode: NETWORK_ERROR`, NSURLErrorDomain -1004, tags
`context: revenuecat` / `subscription`, `rc_operation: getOfferings failed / logOut failed /
subscription record read failed`), all on the dev simulator, 09-21 to 09-26. The existing
`NETWORK_ERROR` needle → `store_network` already matches them; the events predate the downgrade. Test
added with the producer-shaped details map.

**DEV-8R** `EmailVerificationRequiredException`, **DEV-9N** `email_not_confirmed`, **DEV-95**
`InvalidVerificationCodeException`, **DEV-9P** `otp_expired`, **DEV-9Q** `over_email_send_rate_limit`,
**DEV-8D** `AccountAlreadyExistsException`: control-flow signals and user input in the email/verify/reset
flows (the UI routes on each). The controllers log some as `info`, but the Riverpod net reports every
notifier `AsyncError`, so without a needle each one becomes an `error` event. Allow-listed with reasons.

## Fix

- `lib/shared/services/report/expected_failures.dart`
  - needle `Software caused connection abort` → `connection_reset` (CX, CW)
  - new `expectedFailurePatterns` (regex, checked after the needles) for google_sign_in
    `sign_in_failed, <class>: 7|8: `; status 8 → new tag `play_services_transient`, status 7 → `offline` (CF)
  - needles `InvalidVerificationCodeException`, `otp_expired` → `invalid_credentials`;
    `EmailVerificationRequiredException`, `email_not_confirmed` → new `verification_pending`;
    `AccountAlreadyExistsException`, `User already registered` → new `account_exists`;
    `over_email_send_rate_limit` → new `rate_limited`
- `lib/features/auth/application/email_auth_service.dart`: signup and link failures go through
  `_failAccountCreation`, which reports the cause once and **rethrows the cause itself**
  (`Error.throwWithStackTrace`) or `AccountAlreadyExistsException`. The generic wrapper and the dead
  "valid email" / "stronger password" wrappers are gone. `report` / `analytics` are read before the
  first await (the provider is auto-disposed).
- `lib/features/auth/presentation/providers/post_onboarding_auth_controller.dart`: `signUpWithEmail` and
  `linkEmailAccount` share `_emailCreationFailed`. The Fault's error is the underlying exception with its
  stack trace; `EmailVerificationRequiredException` and `AccountAlreadyExistsException` are routing
  signals (info + analytics, no Fault). The user message is unchanged: the screen's content-system string.
- Tests (each red before, green after; the red runs were done against `HEAD`'s files):
  - `test/features/auth/account_creation_failure_report_test.dart`: seam test, real controller → real
    service → mocked GoTrue throwing gotrue 2.16's own exception shapes (CH's `AuthApiException(Invalid
    API key, 401)`, DEV-8W's `AuthRetryableFetchException` 500, `User already registered` 422).
  - `test/shared/services/report/expected_failures_test.dart`: one test per new needle/pattern with
    producer-shaped exceptions, the CW path through `filterSentryEvent`, and negatives (status 10/12500,
    Invalid API key, GoTrue 500 stay Faults).
- Verified: `dart analyze` on all five files clean; both test files green; `flutter test
  test/shared/source_guard` green (20 tests). No full suite run (wave rule).

## Owed

- **Security, outside this ticket's scope, needs Lee: the root `.env` ships inside the app bundle and
  holds the prod `SUPABASE_SECRET_KEY` (`sb_secret_oe8R0…`, bypasses RLS).** `pubspec.yaml` lists `.env`
  as a Flutter asset, nothing in `lib/` loads it any more (bootstrap reads only `.env.dev.local` /
  `.env.prod.local`), and the local device build at
  `build/ios/iphoneos/Runner.app/Frameworks/App.framework/flutter_assets/.env` contains the key.
  Whether store builds carry it depends on what Codemagic's `DOTENV_ROOT` holds (`codemagic.yaml` writes
  it to `.env`), which cannot be read through the API. Recommended: drop `.env` from `pubspec.yaml`
  assets, and rotate the prod secret key if `DOTENV_ROOT` ever held it. The same `.env`'s legacy anon
  JWT is stale (prod answers 401 to it).
- Dev Android has no Google OAuth client: `android/app/src/dev/google-services.json` has an empty
  `oauth_client` list, and the dev flavor signs with each machine's debug keystore. Google sign-in on a
  dev Android build would fail with status 10 (no events seen yet). Registering it needs the Google
  Cloud console (`mealvana-dev`), not the repo.
- Which hand-made `.env.dev.local` produced CH cannot be recovered (the file is gone). A startup check
  that compares the anon JWT's `ref` with the URL's project would catch the JWT case but not a
  publishable key, so it is not added here.
- No device run: none of this changes UI. The downgrades can only show in Sentry once a build carrying
  the `sentry` branch ships.
- Not touched, noted while reading: `EmailAuthService.signUpWithEmail` still calls
  `ref.invalidate(userIdProvider)` after an await inside the guard. The same disposal hazard as ticket
  15's, left alone because it is outside this ticket.

## Sentry resolution

| Issue | Action | Comment for Sentry |
|---|---|---|
| MEALVANA-ENDURANCE-CX | resolve-as-degraded | Android ECONNABORTED during token refresh; 'Software caused connection abort' is on the allow-list (connection_reset), ticket 20 |
| MEALVANA-ENDURANCE-CW | resolve-as-degraded | Same refresh abort captured by the SDK HTTP client; beforeSend downgrades it via the new needle, ticket 20 |
| MEALVANA-ENDURANCE-CF | resolve-as-degraded | google_sign_in ApiException 8 (INTERNAL_ERROR), transient: same device signed in 48 s later; config verified; tagged play_services_transient. Status 10 stays a Fault |
| MEALVANA-ENDURANCE-CH | resolve | Local dev simulator run with a non-dev client key on the dev URL and no DSN (old prod-DSN fallback, removed in ticket 02); no shipped build affected |
| MEALVANA-ENDURANCE-CG | resolve | Generic wrapper removed: signup/link failures now report and rethrow the real cause (ticket 20) |
| MEALVANA-ENDURANCE-CE | resolve-as-degraded | Expected control flow; allow-listed as account_not_found since 2026-10-05; no event after that date |
| MEALVANA-ENDURANCE-CQ | resolve-as-degraded | As CE |
| MEALVANA-ENDURANCE-CZ | resolve-as-degraded | As CE (Apple) |
| MEALVANA-ENDURANCE-DEV-5 | resolve-as-degraded | 'Connection reset by peer' on the allow-list since 2026-07-11; events predate the 10-05 downgrade |
| MEALVANA-ENDURANCE-DEV-8P | resolve | Dev SMTP outage 2026-09-21, fixed 09-22; reopen if it recurs |
| MEALVANA-ENDURANCE-DEV-8W | resolve | As DEV-8P (email change mail) |
| MEALVANA-ENDURANCE-DEV-8Q | resolve | Causeless wrapper of DEV-8P; wrapper removed, ticket 20 |
| MEALVANA-ENDURANCE-DEV-8X | resolve | Causeless wrapper of DEV-8W; wrapper removed, ticket 20 |
| MEALVANA-ENDURANCE-DEV-8R | resolve-as-degraded | EmailVerificationRequiredException is a routing signal; allow-listed verification_pending |
| MEALVANA-ENDURANCE-DEV-8T | resolve-as-degraded | As CE |
| MEALVANA-ENDURANCE-DEV-9N | resolve-as-degraded | email_not_confirmed → verification_pending |
| MEALVANA-ENDURANCE-DEV-9P | resolve-as-degraded | otp_expired (user typed an expired code) → invalid_credentials |
| MEALVANA-ENDURANCE-DEV-9Q | resolve-as-degraded | over_email_send_rate_limit (Resend tapped inside the cooldown) → rate_limited |
| MEALVANA-ENDURANCE-DEV-95 | resolve-as-degraded | InvalidVerificationCodeException (wrong code) → invalid_credentials |
| MEALVANA-ENDURANCE-DEV-8M | resolve-as-degraded | RevenueCat NETWORK_ERROR (not google_sign_in), already matched by the store_network needle |
| MEALVANA-ENDURANCE-DEV-9J | resolve-as-degraded | As DEV-8M (logOut) |
| MEALVANA-ENDURANCE-DEV-9S | resolve-as-degraded | As DEV-8M (getCustomerInfo) |
| MEALVANA-ENDURANCE-DEV-9T | resolve-as-degraded | As DEV-8M (logOut) |
| MEALVANA-ENDURANCE-DEV-9X | resolve-as-degraded | As DEV-8M (logOut) |
