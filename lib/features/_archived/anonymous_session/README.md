# Anonymous session (archived 2026-09-21)

Paywall ticket 08, decisions mp-459 and mp-417: the app never starts an
anonymous session. A new install goes through onboarding signed out, the
answers wait on the phone in `OnboardingDraft`, the account is made on the
post-onboarding screen, and `saveAllOnboardingData` writes the draft to it.

This folder holds the code that started or relied on anonymous sessions,
verbatim, one file per removal. Nothing here is compiled
(`analysis_options.yaml` excludes `lib/features/_archived/**`).

| File | Came from | What it did |
| --- | --- | --- |
| `welcome_screen_fresh_session.dart` | `onboarding/presentation/screens/welcome_screen.dart`, `_getStarted` | Signed out and opened an anonymous session on Get Started. |
| `post_onboarding_auth_screen_anonymous_start.dart` | `auth/presentation/screens/post_onboarding_auth_screen.dart`, Apple and Google handlers | Opened an anonymous session to link the new identity onto when none existed. |
| `auth_service_create_user_anonymous_fallback.dart` | `auth/application/auth_service.dart`, `createUser` | Opened an anonymous session when the profile was created with no user signed in; `authProvider`/`isAnonymous` defaulted to anonymous. |
| `settings_screen_anonymous_account_section.dart` | `settings/presentation/screens/settings_screen.dart`, `_buildAccountSection` | The account card for an anonymous profile: Create Account, Log In, sign out without an account. |

## What stays live

The link for old installs (mp-455 §4-5): an install left anonymous from
before the paywall opens the new build with its anonymous user still signed
in. The account screen links the new identity onto that user so the uid,
and everything synced under it, survives. That path is
`OAuthService.linkAppleAccount` / `linkGoogleAccount`,
`EmailAuthService.linkEmailAccount` (+ `verifyEmailOtp` with
`OtpType.emailChange`), the upgrade branch of `EmailSignupScreen`, and
`AuthMigrationService`. Ticket 09 adds the grace claim on top of it.

`onboarding_temp_user_id` is not an anonymous session: it is the local key
the connect step writes under when there is no session at all, re-keyed
onto the account by `OnboardingController._migrateOnboardingDataToNewUser`.
