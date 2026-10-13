# Sign in and accounts (auth)

domain: 9 Account and app · folder: `lib/features/auth/` (25 files)

The account screen after onboarding, log-in, email verification, password reset, and the move of an anonymous
athlete's data into a real account.

## What athletes can do here

- **Save the plan** (`/auth/post-onboarding`, after "Save My Plan"): "Your plan is ready. Don't leave it behind. ·
  Save it in seconds. Free through launch month, no card needed." → "Continue with Apple", "Continue with Google",
  "Sign up with email", or "Continue without an account" ("Your plan stays on this device only — save it to keep
  it if you switch phones."; in fact the anonymous profile is uploaded too). Apple or Google upgrades the
  anonymous session in place, so nothing is lost. If the identity already has an account: "Account Already
  Exists" → "Cancel" / "Use Email Instead" / "Log In"; the existing account's settings win over the answers just
  given.
- **Log in** (`?mode=login`, from Welcome's "I already have an account" or Settings): "Log In · Welcome back" with
  Apple, Google, "Log in with email" ("Forgot Password?" → "Enter Reset Code" → "Set New Password"). A log-in with an
  Apple or Google identity the app has never seen is refused: "No account was found for this {provider} account.
  Try logging in with the provider or email you originally signed up with." (the server still creates a shell
  account, so a retry after a minute gets in). Logging into an existing account moves the anonymous athlete's data
  across.
- **Sign up with email**: "Sign Up with Email" → "Verify your email" (six-digit code, "Use a different email"). A
  sign-up abandoned on that screen reopens there at the next launch.
- **Stay anonymous.** Settings shows "Not signed in" with "Create an account to save your data" and "Log into an
  existing account"; no sign-out, no delete, no credit purchases (`settings.md`, `ai_credits.md`).

## What the data means

Supabase Auth plus the `users` row: `auth_user_id`, `auth_provider` (anonymous | email | google | apple),
`is_anonymous`, `device_id`, `email`. Phone: `pending_signup_v1` (+ the password in the secure store) for an
unfinished email sign-up. Deep link scheme `com.milkman.mealvanaendurance://` (`.dev` in dev) is used only for the
TrainingPeaks and Garmin callbacks; Apple and Google sign-in happen inside the app. Analytics: `auth_flow_started /
completed / failed`, `auth_account_already_exists`, `auth_skipped`, `auth_{apple,google}_native_{started,linked,cancelled,failed}`,
`auth_oauth_no_existing_account`, `email_account_created / linked`, `email_verification_required / completed`,
`email_sign_in_success`, `settings_create_account_tapped / login_tapped`. There are no `sign_in_*` events.

## What already exists to reuse

- `presentation/providers/post_onboarding_auth_controller.dart`, `application/oauth_service.dart` (Apple, Google,
  the refused-login check, post-sign-in full sync), `email_auth_service.dart`, `auth_migration_service.dart` (data
  moves on linking; `handleSignInCompletion` is deprecated and unused), `auth_service.dart` (`createUser`),
  `data/pending_signup_store.dart`; screens `post_onboarding_auth_screen`, `email_login_screen`, `email_signup_screen`,
  the verify and reset screens.

Gardening: stale comments at `post_onboarding_auth_screen.dart:125,180,538,929-935,1010-1018`,
`auth_service.dart:144-145`, `root_app_widget.dart:41`; the on-screen "stays on this device only" line contradicts
the upload policy. Possible gap: a registered athlete who re-enters onboarding and taps "Continue without an
account" is saved as anonymous.

## Links

- **ops open work:** bugs `oauth-second-provider-creates-empty-account`, `new-anonymous-uid-minted-per-open-and-signout`,
  `profile-email-diverges-from-auth-email`, `authed-activities-not-syncing`, `anonymous-activities-not-syncing` ·
  feature-requests `eng-task-oauth-login-backend-followups`, `eng-task-oauth-login-refusal-event`,
  `eng-task-verify-email-screen-coverage`, `last-used-provider-hint-at-login`, `eng-task-signins-without-app-profile`,
  `analytics-anon-auth-id-merge`, `decision-anonymous-user-at-the-paywall`.
- **Related map pages:** `onboarding.md` · `settings.md` · `app_startup.md` · `ai_credits.md`.
