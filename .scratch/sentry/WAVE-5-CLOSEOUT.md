# Wave 5 close-out: tickets 16-25 (2026-10-06, lead session)

Branch `sentry`, base `c6ce249d` → HEAD `deb59745` (local, not pushed). Nine Opus agents, one ticket
theme each; lead did ticket 25 and the merges. Full suite after review fixes: all pass except the
known-red `ci_config_contract_test` ("push to develop runs dev tests"). Sentry: 103 issues actioned
(76 `resolvedInNextRelease`, 13 `resolved`, 14 left open with a comment) + 44 from ticket 25.
`resolvedInNextRelease`, never plain `resolved`, because every shipped build predates the fixes and a
plain resolve would regress each group and fire the prod Regression alert on the next old-build launch.

## Code review (Standards + Spec, Opus sub-agents) — fixed in `deb59745`
- Ticket 18 hoists that left their `try`/`guard` (settings `_saveProfile`, activities analytics,
  swap-food `authService`) moved back inside, still before the first await.
- Ticket 16 guard: case-insensitive user-id compare; parent-row skip is a promoted Note; deferred
  upload returns `UploadResult.failed('deferred: …')`, not `nothingToUpload`.
- Ticket 19: 504 downgrade scoped to `/rest/v1` + `/auth/v1`; an edge-function 504 stays a Fault.
- Ticket 22: the three write-back skip Notes use the promoted `sync` area (`provider` in data).
- Merge fix: `appleSignInAvailableProvider` catches only the `appConfigProvider` placeholder
  (`ProviderException` → `UnimplementedError`), rethrows anything else; no allow-list entry.

## Review findings deliberately NOT changed (rulings for Lee)
- Observer backstop (ticket 18): a provider's own disposed-mid-build `UnmountedRefException` is now
  Degraded (`riverpod_lifecycle: disposed_mid_build`), never a Fault. Spec item 3 said "fix the
  pattern"; the backstop also covers the unfixed sites below. Keep or drop?
- `_failAccountCreation` (service) and `_emailCreationFailed` (controller) both classify the same
  failure; Report's identity dedupe keeps it to one event. One layer should own it.
- `swap_food_screen` error view shows `error.toString()` (pre-existing); now scrolls instead of
  overflowing. Content-system copy owed.

## Owed (from the agents' tickets + review)
- **Lee, Apple portal (17):** enable Sign in with Apple on Services ID `com.milkman.mealvanaendurance.auth`
  (primary app `com.milkman.mealvanaendurance`), register return URL
  `https://wvmvsodrvbkxfydabqed.supabase.co/functions/v1/apple-signin-callback` (+ dev). Until then
  Android hides the Apple button when `APPLE_AUTH_SERVICES_ID` is empty. Confirm `DOTENV_PROD_LOCAL`
  carries `APPLE_AUTH_SERVICES_ID`.
- **Prod deploys with the release (not before the app build):** `apple-signin-callback` (new),
  `garmin-backfill` (now answers 409/429; older builds Fault on a 409). Both are on DEV.
- **Security (20):** root `.env` is no longer a Flutter asset (`769d5808`). Rotate the prod
  `SUPABASE_SECRET_KEY` if Codemagic's `DOTENV_ROOT` ever held it; Lee's local iOS builds did ship it.
- **`mealplanning`-only fixes (24a, 18, 24b):** DEV-9R paywall clip → `DisposalSafeVideoPlayerController`;
  DEV-9G/9F pop pageless routes before the expiry redirect; DEV-81 `VanaCompanionHost._onRoute` activation
  guard; DEV-9W `subscription_screen_controller` watches above awaits; `CodeEntryController._invoke` still
  calls the deleted legacy logger; `CodeRedeemFailure(` needle tested against a stand-in type.
- **DEV-4 (307 events) is branch skew, no ticket:** dev DB has `mealplanning`'s five-column
  `user_entitlements`; `develop` builds query `entitlement=eq.pro` (42703). Prod has no table yet. Fix =
  merge `mealplanning` → `develop`.
- **Tests owed (18):** write-path seam tests for post-onboarding auth, vana chat, home, carb loading, coach
  controllers; (17) a test that `OAuthService` passes the options to `getAppleIDCredential`.
- **Device checks not run:** 17 (Android emulator Apple flow; blocked on the portal), 19 (dead Garmin token
  → Degraded, no Fault), 21 (Android Flutter 3.47 OpenGL backgrounded error), 22 (TP sandbox: no creds in
  `secrets/integration_test.env`), 24 (query counts proven in tests only).
- **Follow-ups surfaced:** B5 write storm (7,224 `users` upserts in 2.5 min from one 1.27.0 client; caller of
  `UserRepository.updateUserProfile` unknown); Garmin backfill hits Garmin's 100/min limit at ~3 calls/h
  (ask Garmin about the app key); Flutter `stable` floats on Codemagic (3.47.x has the Impeller GLES crash,
  3.44.6 clean) — pin or not; Play pre-launch emulator crashes (BP, C2) recur on every upload — inbound
  filter or archive; TP reconnect prompt when the refresh token dies; "we'll retry automatically" copy after a
  dead-token 409; dev Android `google-services.json` has no OAuth clients (Google sign-in code 10 on dev
  Android); Patrol runs send teardown errors to both Sentry projects — disable Sentry in Patrol builds; dev
  account `607f9dd5…` needs TrainingPeaks + V.O2 reconnected (DEV-AA/AD/AC).
- **Ticket 25:** after the first launch of a build carrying ticket 11, confirm no new `Slow operation:` /
  `MetricKit metric payload` events and no regression of the 44 groups.

## Next
PR `sentry` → `develop` (one push; `develop` auto-cuts the dev TestFlight build, ~9¢/min). Then
`/release-cut` for the dev build, and the device checks above on it.
