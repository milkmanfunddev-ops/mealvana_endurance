# 21: Signup and verify-email fixes

**Status:** in-progress — fixed, awaiting retest (wave 2, 2026-10-07)
**Labels:** fix, round:develop-2026-10, area:auth
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** 29 (the backport ticket runs first, alone, because its Touches cross every area).
**Next:** `/testing-wave develop-2026-10` (fix wave)
**Model:** opus

**What to build:** Lee's rulings of 2026-10-07 (TRIAGE 01-002, 01-003, 01-005, 01-009) for Sign Up with Email
and Verify your email. One agent, working through the list. Read `CLAUDE.md` (FOA layers, content system,
`MealvanaSnackbar`, seam tests) and `docs/test/README.md` § Seam tests first. Line numbers are from code at
`f2e8576e`, before 29 lands. **29 may already have changed these files:** it backports the mealplanning
fixes for the same screens (`2a5cc75f` "a rejected code says wrong or expired", `e2c2a457` "code screens wait
60 s and count down a 429"). Start each item by reading what 29 landed, keep what it brought, and change only
what the ruling below still needs.

**Which signup path exists today (from code, unverified on device).** Welcome → Build My Plan signs in
anonymously (`onboarding_session_controller.dart:95`). So when Create Account runs,
`email_signup_screen.dart:105-116` finds an anonymous session and takes the **anonymous upgrade**:
`PostOnboardingAuthController.linkEmailAccount` → `EmailAuthService.linkEmailAccount` (`updateUser(email)`),
then `VerifyEmailScreen(otpType: OtpType.emailChange, pendingPassword: …)` (`:127-138`). Every pass in the
run took this path. The **plain signup** (`signUpWithEmail` → `supabase.auth.signUp`, then
`VerifyEmailScreen(otpType: OtpType.signup)`) runs only when no session exists at Create Account (the
anonymous sign-in failed, or a non-anonymous session was signed out at `:107-111`). Lee ruled that the
anonymous upgrade is being removed. This ticket does **not** remove it and does **not** fix its resend
(`OtpType.emailChange`). Removing it is not ticketed in this round (unverified: no ticket 21–29 found for it).

1. **A wrong code says it is wrong; expired stays for expired (01-002).** `verifyEmailOtp`
   (`email_auth_service.dart:520-528`) picks the text by `e.message.toLowerCase().contains('expired')`. GoTrue
   answers a mistyped, a superseded and a stale code with the same refusal (403, `otp_expired`, "Token has
   expired or is invalid", as mealplanning's `InvalidVerificationCodeException.fromGoTrue` documents;
   unverified against this run's console line at 06:10:30), so every wrong code reads "expired". The server
   cannot tell them apart, so the client decides by the code's age:
   - `VerifyEmailScreen` records `_codeSentAt` in `initState` (the signup sent the code just before the push)
     and resets it after each successful resend. It passes `codeSentAt` to `verifyEmailOtp`.
   - `InvalidVerificationCodeException` carries a reason, not text: `wrong`, `expired`, `malformed`,
     `tooManyTries`. In `verifyEmailOtp`, the `otp_expired` refusal is `expired` when
     `now - codeSentAt >= signupCodeLifetime`, otherwise `wrong`. Put `signupCodeLifetime = Duration(hours: 1)`
     in `lib/features/auth/domain/` with a comment citing `supabase/config.toml:184` (`otp_expiry = 3600`). The
     hosted dev and prod value (`mailer_otp_exp`) is unverified; the wave lead reads it with the Management
     API before the wave and the agent uses that number. A 429 (`over_request_rate_limit`) is `tooManyTries`.
     The 6-digit format check (`:497-501`) is `malformed`.
   - The screen maps the reason to text through the content system (`content.getValue(key, defaultValue:)`,
     as the screen already does), with defaults added to `assets/config/content_defaults.json` under
     `auth.verify_email`: `error_wrong_code` "That code is not right. Check the email and try again.",
     `error_expired` "That code has expired. Tap Resend code for a new one.", `error_malformed`,
     `error_too_many_tries`. If 29 brought `fromGoTrue` with its combined "wrong or has expired" text, replace
     that text with the two reasons above: the ruling says each case gets its own message.
   - Also move the generic "Could not verify that code. Please try again." (`verify_email_screen.dart:124`,
     `email_auth_service.dart:532-535`) to `auth.verify_email.error_generic`.

2. **Resend on the plain signup sends a new code, and every Resend failure says so (01-003).** For
   `OtpType.signup`, `resendVerificationCode` (`email_auth_service.dart:617-635`) calls
   `supabase.auth.resend(type: OtpType.signup, email:)`, which is the right call. What is wrong around it:
   - **Cooldown shorter than the server's.** The screen allows Resend after 30 s (`verify_email_screen.dart:55`,
     `:73`). GoTrue refuses a second email to the same address inside its own interval (default 60 s; the
     local `config.toml:180` says 1 s; hosted dev unverified, the lead reads `smtp_max_frequency` with the
     Management API), and the screen then says "Too many requests". Use one constant equal to the hosted
     interval. On a 429 whose message names the seconds ("after N seconds"), restart the countdown at N. If 29
     brought `e2c2a457`'s 60 s wait and 429 countdown, keep them and skip this bullet.
   - **Only `AuthApiException` is caught** (`email_auth_service.dart:628`). A network failure or
     `AuthRetryableFetchException` escapes `_resend` (`verify_email_screen.dart:129-149` catches only
     `InvalidVerificationCodeException`), so the tap fails with no message and an unhandled async error.
     Catch every failure in the service and turn it into a typed result.
   - **Resend failures reuse `InvalidVerificationCodeException`.** A failed resend is not a wrong code, and the
     reuse makes `expected_failures.dart:139` file it as `invalidCredentials`. Add
     `VerificationResendException` with reasons `rateLimited(seconds?)` and `failed` in
     `auth_exceptions.dart`. The screen shows `auth.verify_email.error_rate_limited` or
     `auth.verify_email.error_resend_failed`.
   - **Hardcoded words.** "Resend code in ${_resendIn}s" and "Resend code" (`:246-248`) and "New code sent to
     …" (`:137`) move to `auth.verify_email.resend_in` (with a `{seconds}` placeholder, the way other content
     keys take values; check `content_service.dart`), `auth.verify_email.resend` and
     `auth.verify_email.resent`. The success stays `MealvanaSnackbar.showSuccess`.
   - **Write down each resend.** After a successful call, `report.note('Verification code resent', area:
     'auth', data: {'otp_type', 'seconds_since_last_send'})` replaces the bare `report.info` at `:631`, so a
     resend that answered 200 but sent nothing can be lined up against the mailbox.
   - `OtpType.emailChange` resend: leave it alone (ruling). Add a one-line comment at the resend call that it
     goes with the anonymous upgrade's removal.

3. **Expected signup outcomes are breadcrumbs, not Sentry events (01-005).** Two senders, both found in code:
   - **`EmailVerificationRequiredException` (`area: unknown`).** `signUpWithEmail` and `linkEmailAccount` throw it
     inside `AsyncValue.guard` (`email_auth_service.dart:402`, `:206`), and `if (ref.mounted) state = result;`
     (`:439`, and the same line in `linkEmailAccount`) writes it into the notifier's state.
     `SentryProviderObserver.providerDidFail` (`sentry_provider_observer.dart:192-202`) reports that
     `AsyncError` as `Report.fault` with tags but no `area`. Ticket 20's needle at `expected_failures.dart:148`
     only downgrades it to a warning event, and Mixpanel `error_reported` still goes out (`report.dart:391`,
     hence `area: unknown`). `PostOnboardingAuthController` writes the same error into its own state
     (`post_onboarding_auth_controller.dart:252`, `:360`).
   - **`InvalidVerificationCodeException`.** `verifyEmailOtp` reports every failure at
     `email_auth_service.dart:606` (`report.fault(error, area: 'auth', message: 'Email verification failed')`).
     The screen already writes a breadcrumb for it (`verify_email_screen.dart:100-106`, `report.note`, area
     `auth`, not a promoted area).
   - **Change.** Add a marker interface `AuthFlowOutcome` in `auth_exceptions.dart`, implemented by
     `EmailVerificationRequiredException`, `InvalidVerificationCodeException` and `VerificationResendException`.
     In `SentryProviderObserver.providerDidFail`, an `AuthFlowOutcome` (bare or inside a `ProviderException`)
     becomes a breadcrumb (new category `auth.flow`, data: provider, type) and never a fault. In
     `verifyEmailOtp` (`:604-608`), report only errors that are not `AuthFlowOutcome`; the outcome's
     breadcrumb is the screen's note. Remove the two needles (`expected_failures.dart:139-151`) for these types
     only if nothing else reaches `Report` with them (grep first); otherwise leave them.
   - **Real auth failures keep reporting, tagged area auth.** Today the observer captures first (no area),
     because `state = result` runs before the service's own report (`signUpWithEmail` `:439` before
     `_failAccountCreation` `:451`; `verifyEmailOtp` `:603` before `:606`; the same order in
     `linkEmailAccount`). The service's `area: 'auth'` fault then finds the error already captured and becomes
     a breadcrumb (`report.dart:281`). Swap the order at those three sites: report first, then write state,
     so the one event carries `area: auth`. `AccountAlreadyExistsException` handling stays as it is.

4. **`public.users.email` is lowercase at write (01-009).** Every client write of the column goes through two
   places: `UserProfile.toJson` (`user_preferences.dart:529`), which `UserRepository` upserts at
   `user_repository.dart:141`, `:897` and `:930`; and the local Drift row (`user_dao.dart:171`, `:259`), which
   that upload reads back. No edge function writes `users.email` (grep of `supabase/functions`). The address
   reaches the profile from onboarding's personal-info step (`auth_service.dart:129`), Settings
   (`settings_controller.dart:292`, `:444`, `:692`; `preferences_screen.dart:134`) and the session email after
   verification (`auth_migration_service.dart:792`). Add `normaliseEmail(String?)` in
   `lib/features/auth/domain/` (trim, lowercase, empty → null) and apply it at the two write places only. Do
   not touch the onboarding screens or their prefill: that is Xuan's, and the prefill idea is in the review
   queue (ruling).
   - **One-off dev SQL, run by the wave lead, never by the agent** (dev `vlmtsdzpnjnavdgytcmi`, Management API
     `database/query`):
     ```sql
     -- 1. Collisions first: two rows that differ only by case must be settled by hand.
     select lower(btrim(email)) as e, count(*) from public.users
       where email is not null group by 1 having count(*) > 1;
     -- 2. What will change.
     select id, email from public.users where email <> lower(btrim(email));
     -- 3. The change (only when step 1 returned no rows).
     update public.users set email = lower(btrim(email)) where email <> lower(btrim(email));
     ```
     Prod is not touched by this ticket.

**Findings:** 01-002, 01-003, 01-005, 01-009.

**Decisions:** none on the page. Lee ruled in the terminal (TRIAGE 2026-10-07: 01-002, 01-003, 01-005,
01-009). Unverified, for the lead before the wave: hosted `mailer_otp_exp` and `smtp_max_frequency` on dev.

**Touches:** lib/features/auth/domain/auth_exceptions.dart,
lib/features/auth/domain/signup_code.dart (new: `signupCodeLifetime`, `normaliseEmail`),
lib/features/auth/application/email_auth_service.dart,
lib/features/auth/presentation/screens/verify_email_screen.dart,
lib/features/auth/domain/user_preferences.dart, lib/shared/database/daos/user_dao.dart,
lib/shared/services/sentry/sentry_provider_observer.dart,
lib/shared/services/report/expected_failures.dart (only if the needles go),
assets/config/content_defaults.json,
test/features/auth/application/email_auth_service_verify_test.dart (new),
test/features/auth/presentation/verify_email_screen_test.dart (new),
test/shared/services/sentry/sentry_provider_observer_test.dart,
test/features/auth/data/user_email_lowercase_test.dart (new).
No codegen expected: `EmailAuthService.build` keeps its signature, so `email_auth_service.g.dart` stays.

**Overlaps:** 22 (`lib/features/auth/domain/user_preferences.dart`: `UserProfile.toJson`), 29 (backports cross
every area; the auth screens above in particular). Tickets 23, 24, 26, 27 were not written when this was cut:
the lead checks `assets/config/content_defaults.json` and `sentry_provider_observer.dart` against them.

- [x] Seam test through the real `EmailAuthService` notifier (`email_auth_service_verify_test.dart`), with a
      fake Supabase auth that answers like GoTrue (403, code `otp_expired`, message "Token has expired or is
      invalid"; 429 `over_email_send_rate_limit` "For security purposes, you can only request this after 47
      seconds."): a refusal 44 s after the send is `wrong`; the same refusal 61 min after is `expired`; the 429
      is `rateLimited(47)`; a `SocketException` on resend is `failed` and does not escape.
- [x] Same file, `RecordingReport`: a plain signup that needs verification and a wrong code produce no fault
      and no degraded event, and one `auth.flow` breadcrumb each; a GoTrue 500 on verify produces exactly one
      fault, with `area: auth`.
- [x] `sentry_provider_observer_test.dart`: an `AsyncError` holding `EmailVerificationRequiredException`
      (bare, and wrapped in `ProviderException`) is a breadcrumb, not a fault.
- [x] Widget test (`verify_email_screen_test.dart`): wrong-code and expired texts come from the content keys;
      Resend stays disabled for the server interval; a 429 restarts the countdown at N; a successful resend
      shows the `MealvanaSnackbar` and resets the code age.
- [x] `user_email_lowercase_test.dart`: a profile saved with the address as typed on personal info
      (`Lee+E2E-01-20261007T110602Z@Example.com`) is uploaded and stored locally as lowercase, through
      `UserRepository.saveUserProfile` with a fake Supabase that captures the upsert.
- [x] `flutter analyze` clean on touched files.
- [ ] Lead: the dev SQL above, after the merge. Retest in ticket 30 (retest: auth and account): a wrong code
      reads "not right", and Resend on a plain signup delivers a second email.
