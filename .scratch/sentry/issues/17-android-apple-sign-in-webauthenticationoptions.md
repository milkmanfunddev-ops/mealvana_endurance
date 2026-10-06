# 17: Android Apple sign-in webAuthenticationOptions

**What to build:** MEALVANA-ENDURANCE-A6 and BY: Sign in with Apple on Android throws because `webAuthenticationOptions` is not provided. Supply the options for Android and verify on the emulator.

**Blocked by:** 10 Contract

**Status:** done except the Apple portal setup and the emulator/device check (see Owed)

- [x] Android passes `WebAuthenticationOptions` (Services ID + per-project return URL); unit-tested
- [x] Return-URL relay deployed to DEV and answers Apple's form POST with the plugin's intent (curl-verified)
- [ ] Apple sign-in on the Android emulator reaches the Apple web flow (owed, see below)
- [ ] Issues resolved in Sentry (lead, after merge)

## Root cause

**MEALVANA-ENDURANCE-A6** (38 events, 1 user, `sdk_gphone_arm64` emulator, Android 11, last on
1.29.0+148 on 2026-10-02) and **MEALVANA-ENDURANCE-BY** (1 event, OnePlus8Pro, 1.26.0+110,
2026-09-08). Both events come from the same path:
`_PostOnboardingAuthScreenState._handleAppleSignIn` → `PostOnboardingAuthController.signInWithApple`
→ `OAuthService.signInWithApple` → `SignInWithApple.getAppleIDCredential` →
`MethodChannelSignInWithApple.getAppleIDCredential:45`. On Android the plugin runs Apple's *web*
flow in a Custom Tab and throws at once when `webAuthenticationOptions` is null. Both
`getAppleIDCredential` calls in `oauth_service.dart` (sign-in and link) passed no options, so
the button shown on Android could never work.

A fix for this already exists on `mealplanning` (`9f2b025f`, 2026-09-22), but it is not on
`sentry`, `develop`, `main` or any release branch, and it would not have worked:

1. **Its redirect URI was Supabase's `/auth/v1/callback`.** Apple ends the web flow by POSTing
   `code` / `id_token` / `state` to the return URL. The plugin only gets that result back if the
   return URL answers with a redirect to
   `intent://callback?…#Intent;package=<app id>;scheme=signinwithapple;end` (plugin README,
   "Android"). Supabase's callback does not do that. It completes only flows Supabase started
   itself. Probed on DEV:
   `POST /auth/v1/callback` → `303` to the coach web site with
   `error_code=bad_oauth_callback&error_description=OAuth+state+parameter+missing`. The user would
   end up on an error page with the app waiting forever, so the crash would have turned into a hang.
2. **No `SignInWithAppleCallback` activity in the Android manifest.** The plugin's own manifest
   is empty (6.1.4, the locked version), so nothing in the app could receive `signinwithapple://callback`.
3. **With an empty Services ID it still passed `null`**, so a build without one (dev today)
   kept throwing the same Sentry error.

There is a separate blocker on Apple's side (see Owed). The Services ID
`com.milkman.mealvanaendurance.auth` exists (App Store Connect API: bundle id `W48CV669W9`,
platform `SERVICES`) but has **no capabilities**, so Sign in with Apple is not enabled on it.
Apple's authorize endpoint answers `invalid_client` / "Invalid client." for it with any return
URL. Even with correct code, Android Apple sign-in cannot finish until that is configured.

## Fix

- `lib/features/auth/application/apple_web_authentication.dart` (new):
  - `appleWebAuthenticationOptions({isAndroid, servicesId, supabaseUrl})` returns `null` on iOS.
    On Android it returns `WebAuthenticationOptions(clientId: <Services ID>, redirectUri:
    <SUPABASE_URL>/functions/v1/apple-signin-callback)`. Both values come from the flavor's env
    (`APPLE_AUTH_SERVICES_ID`, `SUPABASE_URL`), so dev and prod each get their own project's return
    URL. With an empty Services ID it throws `AppleSignInNotConfiguredException` (a named error
    instead of the plugin crash).
  - `appleSignInAvailableProvider` is false on an Android build with no Services ID.
- `lib/features/auth/application/oauth_service.dart`: both `getAppleIDCredential` calls (sign-in and
  link) pass `webAuthenticationOptions` from the builder. The `signInWithIdToken` /
  `linkIdentityWithIdToken` hand-off is unchanged. On Android the id token's audience is the
  Services ID, so Supabase's Apple client-id list must include it.
- `lib/shared/services/app_config.dart`: `appleAuthServicesId` read from `APPLE_AUTH_SERVICES_ID`
  (dotenv and `--dart-define`). Cherry-picked from `9f2b025f`, plus a `forTesting` parameter.
- `lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart`: the Apple button is
  hidden when `appleSignInAvailableProvider` is false. A dev Android build offers Google and email
  instead of a button that always fails.
- `android/app/src/main/AndroidManifest.xml`: declares the plugin's `SignInWithAppleCallback`
  activity (`signinwithapple` scheme, `callback` path).
- `supabase/functions/apple-signin-callback/` (new edge function, `verify_jwt = false` in
  `supabase/config.toml`): Apple's return URL. It takes Apple's `form_post` (or a GET) and answers
  `303` to `intent://callback?<fields>#Intent;package=<pkg>;scheme=signinwithapple;end`. The
  package comes from the project ref (dev ref → `com.milkman.mealvanaendurance.dev`, prod ref →
  `com.milkman.mealvanaendurance`), and the `ANDROID_APP_PACKAGE` secret overrides it.
  **Deployed to DEV**. Probe:
  `POST https://vlmtsdzpnjnavdgytcmi.supabase.co/functions/v1/apple-signin-callback` with
  `state=s1&code=c.0-1&id_token=eyJ.a.b` → `303 location: intent://callback?state=s1&code=c.0-1&id_token=eyJ.a.b#Intent;package=com.milkman.mealvanaendurance.dev;scheme=signinwithapple;end`.
- `.env.example`: documents `APPLE_AUTH_SERVICES_ID`.

Tests:
- `test/features/auth/apple_web_authentication_test.dart`: 8 tests covering iOS null; the prod and
  dev return URLs, including a trailing slash; never `/auth/v1/callback`; the empty-ID named
  error; button availability on Android and iOS. Red before (the API did not exist, and the
  cherry-picked getter produced `/auth/v1/callback`), green after.
- `supabase/functions/apple-signin-callback/relay.test.ts`: 5 Deno tests covering producer-shaped
  Apple form_post relayed field-for-field (including the `user` JSON), the package per project, the
  env override, Apple's `user_cancelled_authorize` error relayed, and other methods refused (405).
  `deno test --allow-env --allow-sys supabase/functions/apple-signin-callback/relay.test.ts`.
- `dart analyze` on every changed Dart file: clean apart from 2 existing `use_build_context_synchronously`
  infos in `post_onboarding_auth_screen.dart` (lines 455/589, not touched). `flutter test
  test/shared/source_guard`: green.

## Settings that must exist for the flow to work

| Where | Setting | State now |
|---|---|---|
| Apple Developer → Identifiers → Services IDs → `com.milkman.mealvanaendurance.auth` | **Sign in with Apple** enabled and configured: Primary App ID `com.milkman.mealvanaendurance`; Domains `wvmvsodrvbkxfydabqed.supabase.co` (+ `vlmtsdzpnjnavdgytcmi.supabase.co` if dev shares it); Return URLs `https://wvmvsodrvbkxfydabqed.supabase.co/functions/v1/apple-signin-callback` (+ the dev one, `https://vlmtsdzpnjnavdgytcmi.supabase.co/functions/v1/apple-signin-callback`). Keep `…/auth/v1/callback` too if web (coach mode) Apple OAuth is wanted. | **Missing.** ASC API lists the Services ID with zero capabilities; Apple's authorize endpoint answers `invalid_client`. |
| Supabase PROD → Auth → Apple → Client IDs | Must contain the Services ID (the Android id token's `aud`). | Already `com.milkman.mealvanaendurance,com.milkman.mealvanaendurance.auth` (read-only check). |
| Supabase DEV → Auth → Apple → Client IDs | Must contain whichever Services ID dev uses. | `com.milkman.mealvanaendurance.dev` only (read-only check). |
| PROD edge function `apple-signin-callback` | Deployed with `verify_jwt = false`. | Not deployed (prod deploys go through the playbook P-sequence). |
| DEV edge function `apple-signin-callback` | Same. | **Deployed and probed** (above). |
| `.env.prod.local` / Codemagic `DOTENV_PROD_LOCAL` | `APPLE_AUTH_SERVICES_ID=com.milkman.mealvanaendurance.auth` | Present in the local `.env.prod.local`; the Codemagic secret cannot be read, so it is unknown whether CI carries it. If it doesn't, prod Android hides the Apple button, which is safe but means no Apple sign-in. |
| `.env.dev.local` / `DOTENV_DEV_LOCAL` | `APPLE_AUTH_SERVICES_ID=` (empty) | Empty on purpose: dev Android hides the Apple button. To test on dev, set it to the Services ID **and** add the Services ID to dev Supabase's Apple client ids **and** register the dev return URL with Apple. |

Supabase's Apple *secret key* (the `.p8`-signed JWT, `Z875MDK9BR`) is only used by the web OAuth flow
(coach mode), not by this id-token flow. It expires every 6 months.

## Owed

- **Lee, Apple Developer portal:** enable and configure Sign in with Apple on the Services ID
  `com.milkman.mealvanaendurance.auth` as in the table. The App Store Connect API cannot set
  Services ID return URLs, so this is a portal click-through. After that, re-run the authorize
  probe (open
  `https://appleid.apple.com/auth/authorize?client_id=com.milkman.mealvanaendurance.auth&redirect_uri=https%3A%2F%2Fwvmvsodrvbkxfydabqed.supabase.co%2Ffunctions%2Fv1%2Fapple-signin-callback&response_type=code%20id_token&response_mode=form_post&scope=email%20name`).
  It should show Apple's sign-in form instead of "Invalid client."
- **Prod deploy of `apple-signin-callback`** with the release, from trunk (`./scripts/deploy_prod.sh apple-signin-callback`).
  It must be live before an Android build carrying this change reaches users, otherwise the Custom
  Tab lands on a 404.
- **Emulator/device check not run.** Not done because (a) Apple answers `invalid_client` for the
  only Services ID, so the flow cannot get past Apple's first page on any build until the portal
  step is done; (b) dev has no Services ID, so the dev flavor hides the button; (c) an Android
  Gradle build plus emulator alongside the other wave agents risks the memory contention noted for
  this Mac. Once the portal is configured: run the prod flavor (or dev with a dev Services ID set
  up as in the table) on `Small_Phone`, tap "Continue with Apple", confirm the Custom Tab shows
  Apple's form, sign in, and confirm the app returns signed in.
- **Codemagic `DOTENV_PROD_LOCAL`:** confirm it carries `APPLE_AUTH_SERVICES_ID` (Lee).
- `mealplanning`'s `9f2b025f` touches the same lines. When `sentry` and `mealplanning` meet,
  keep this version (relay return URL, not `/auth/v1/callback`).

## Sentry resolution

| Issue | Action | Comment for Sentry |
|---|---|---|
| MEALVANA-ENDURANCE-A6 | resolve | Ticket 17 (<sha>): Android passes WebAuthenticationOptions (Services ID + relay return URL); button hidden when no Services ID. Apple portal Services ID config still owed before Android Apple sign-in works end to end. |
| MEALVANA-ENDURANCE-BY | resolve | Same root cause as A6. Fixed in ticket 17 (<sha>). |
