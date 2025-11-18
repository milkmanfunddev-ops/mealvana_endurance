# App Startup, Identity & Authentication Roadmap

_Last updated: 2025-11-18_

## Implementation Status

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 0: Hotfix & Schema Prep | ✅ Complete | Auth fields added, migration ready |
| Phase 1: Canonical UUID Adoption | ✅ Complete | Anonymous auth implemented |
| Phase 2: Authentication UX + Social Login | 🚧 In Progress (9/14) | UI complete, Platform config pending |
| Phase 3: Environment & Telemetry | ⏸️ Deferred | Low priority |
| Phase 4: Observability | ⏸️ Deferred | Pre-launch only |

**Current Focus:** Phase 2 - Account Linking (Apple Sign-In, Google Sign-In, Email/Password)

## ⚠️ CRITICAL: App Initialization Architecture Required

**Before Phase 2 OAuth can work**, the app initialization pattern must be refactored to support OAuth deep links.

**The Problem:**
- OAuth redirects arrive as deep links: `com.milkman.mealvanaendurance://auth-callback`
- Current architecture: AppStartupWidget is a GoRouter route, blocking deep link processing
- Without refactor: OAuth will fail silently (deep links ignored, auth callbacks never trigger)

**The Solution:**
- Implement Andrea Bizzotto's `MaterialApp.builder` pattern
- AppStartupWidget becomes a wrapper widget (not a route)
- GoRouter initializes immediately and handles deep links during app startup

**📚 Complete Implementation Guide:**
- **Architecture Documentation:** `/docs/technical/app-initialization-deep-linking.md`
- **Phase 2 Status:** `/docs/startup_auth_roadmap/PHASE_2_STATUS.md` (see "Step 0: Refactor App Initialization")
- **Phase 2 Implementation:** `/docs/startup_auth_roadmap/phase_2_implementation.md` (see "Architecture Refactor" section)

**Estimated Time:** 1 hour (BLOCKING for all OAuth features)

---

## 1. Guiding Decisions
1. **Canonical identifier** – Every user is represented by the Supabase Auth UUID. Device IDs are treated purely as metadata (`users.device_id`) and never used as a primary key in Drift or Supabase.
2. **Offline-first workflow** – All onboarding steps write to Drift first and mark records `needsUpload`. A sync worker then upserts the same payload directly through Supabase REST/RPC (edge functions removed).
3. **Supabase Auth for everyone** – We bootstrap sessions with `supabase.auth.signInAnonymously()` and keep that anonymous auth session active until the user links a real identity (email/password or social provider). Linking is done via `linkIdentity()` / `updateUser()` so the Supabase Auth UID never changes.
4. **Environment routing** – Build type decides which `.env` file to load:
   - Debug/Profile → `.env.dev.local` (`options.environment = 'development'`, dev Mixpanel token, dev Supabase project).
   - Release/Beta → `.env.prod.local` (`options.environment = 'production'`, prod services).
   - The existing environment switcher still works as a manual override for QA.
5. **Telemetry discipline** – Debug events/crashes land in dev projects; Release events/crashes land in prod. Mixpanel + Sentry instrumentation must capture onboarding/auth states so we can diagnose issues quickly.

## 2. Current Problems
- Android installs fail because Drift requires a 36-char UUID (`user_profiles.id`) but we store device IDs instead.
- The `create-user` edge function hides errors and makes offline-first behavior harder because user creation is remote-first.
- Debug builds often hit production services because `.env.prod.local` is loaded by default.
- Authentication is postponed indefinitely, yet we need social login + email/password soon, with a “Skip for now” option.

## 3. Target Architecture
```
App launch
  ├─ supabase.auth.getSession()
  └─ if no session → supabase.auth.signInAnonymously()
        ↳ returns auth UID (used everywhere as userId)

Onboarding submit (profile / sport / food prefs)
  ├─ Write to Drift (upsert)
  ├─ Mark rows needsUpload=true
  └─ Sync worker upserts to Supabase:
        supabase.from('users').upsert({...}, onConflict: 'id')

Authentication screen (post-onboarding)
  ├─ Options: email/password, Google, Apple, “Skip”
  ├─ For social/email:
        supabase.auth.linkIdentity({ provider: ... })
        supabase.auth.updateUser({ email/password })
  └─ When linked, update local metadata so `isAnonymous=false`
```

## 4. Detailed Roadmap

### Phase 0 – Hotfix & Schema Prep
1. **Schema & models**
   - Add `supabaseUserId` (text, 36 chars) to `UserProfile` domain model and Drift table.
   - Store the same UUID in `users.id` and `user_profiles.id`; `device_id` remains a plain metadata column (no separate legacy column).
   - Remove/relax the current Drift constraint (length 36) once the Supabase UUID is guaranteed; until then, seed new installs with generated UUIDs so Android stops failing.
2. **Bootstrapping anonymous auth**
   - During `AppStartupService`, call `supabase.auth.getSession()`.
   - If no session, call `supabase.auth.signInAnonymously()` and persist `session.user.id` + `session.access_token`.
   - Save the Supabase UUID in SharedPreferences/Drift so Riverpod providers can read it without waiting for Supabase every time.
3. **Stop using `create-user` edge function**
   - Remove the edge invocation from `AuthService.createUser`.
   - Instead, gather onboarding payload from Drift and call `supabase.from('users').upsert()` directly (`onConflict: 'id'`).
   - Because we already have an auth session, Row-Level Security policies run under the authenticated role; we must ensure policies allow anonymous users (`auth.jwt()->>'is_anonymous' = 'true'`).
4. **Code surfaces touched immediately**
   - `lib/features/auth/domain/user_preferences.dart` – add `supabaseUserId`, `isAnonymous`, and `authProvider`, and update JSON factories so `id` serializes the canonical UUID while `deviceId` remains metadata.
   - `lib/shared/database/tables/user_profiles.dart` – make `id` the Supabase UUID (text length 36) and regenerate Drift companions.
   - `lib/shared/database/app_database.dart` – add migrations that rewrite the `id` column to store the Supabase UUID for all new rows; update `saveUserProfile`/`updateUserProfile` helpers accordingly (no legacy columns needed because we are pre-release).
   - `lib/features/app_startup/application/app_startup_service.dart` – sign in anonymously if no session exists and persist the UUID before other providers request a user.
   - `lib/features/auth/application/auth_service.dart` – stop calling the `create-user` edge function; write to Drift first, then enqueue a Supabase upsert.
   - `lib/shared/services/sync/data_sync_service.dart` – ensure uploads/downloads read `supabaseUserId` (not device ID) for every payload (`user_id`, analytics tags, etc.).

### Phase 1 – Canonical UUID Adoption
1. Update every service/provider to reference `user.supabaseUserId` instead of device IDs. Targets:
   - `lib/shared/services/sync/data_sync_service.dart`
   - `lib/features/activities/...` controllers/services
   - `lib/shared/services/analytics/analytics_tracker.dart` and any other analytics/logging helpers
   - push/notification helpers (if we tag by device id today)
2. When storing relationships (activities, foods, feedback, etc.), insert the Supabase UUID into the `user_id` column (both Drift and Supabase writes).
3. Update edge functions (if still in use) or Supabase RPC queries to expect the UUID in parameters. Remove any `device_id` filters outside of `users`.
4. Ensure new installs always insert the Supabase UUID into `user_profiles.id`; no additional backfill is needed because we are still pre-release (if we later backfill prod, we can run a one-off script).
5. Add automated tests that assert newly created users have `supabaseUserId` populated and that the same value flows through `supabase.from(...).insert`.

**What “canonical UUID” means in practice**
- `auth.users.id` (from `supabase.auth.signInAnonymously()` or real auth) becomes the authoritative `userId` everywhere.
- `public.users.id` = Supabase Auth UUID (app sets this value explicitly when upserting).
- `public.users.device_id` = stable hardware identifier, purely metadata.
- Drift `UserProfileEntry.id` = UUID.
- Any table that references a user must continue referencing `users.id` (already UUID). When inserting, pass the canonical UUID rather than the device id.
- Analytics, notifications, Mixpanel distinct IDs, and Sentry user context should use the same UUID so cross-system correlation works.

### Phase 2 – Authentication UX + Social Login (Web OAuth)
1. **Anonymous session UX**
   - After food preferences, show a "Create your account" screen.
   - Buttons:
     - "Continue with Apple" → `supabase.auth.signInWithOAuth(OAuthProvider.apple)` - opens browser
     - "Continue with Google" → `supabase.auth.signInWithOAuth(OAuthProvider.google)` - opens browser
     - "Sign up with Email" → collect email/password, call `supabase.auth.updateUser({ email, password })`
     - "Skip for now" → dismiss, but show reminders in settings/home.
   - The screen lives at `/onboarding/auth` and blocks navigation to `/main` until the user links or taps Skip. Persist `authSkippedAt` in Drift so settings can show a "Finish sign-in" prompt when the user revisits the app.
   - UI spec: hero copy, benefits list, primary CTA stack, plus a "Continue without signing in" text button; reuse Kyle components (`SectionHeaderText`, `PrimaryButton`, `SecondaryButton`, icon buttons).
2. **Web OAuth flow (Apple/Google)**
   - Uses Supabase's hosted OAuth (NO native packages needed)
   - Opens browser/web view for authentication
   - User signs in on web, Supabase handles OAuth
   - Redirects back to app via deep link: `com.milkman.mealvanaendurance://auth-callback`
   - Auth state change listener detects new session
   - Updates local profile: `isAnonymous = false`, `authProvider = 'apple'/'google'`
   - User ID stays the same (data preserved)
3. **Provider setup (Supabase Dashboard)**
   - In Supabase Dashboard → Authentication → Providers, enable Google & Apple.
   - Supply OAuth credentials:
     - **Google**: create a **Web application** OAuth client in Google Cloud, copy the client ID/secret, and paste them into the Supabase dashboard. Add the Supabase-provided redirect URI: `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`. **No iOS/Android native credentials needed** - web flow only.
     - **Apple**: create a Service ID + private key in Apple Developer, register the Supabase redirect URL: `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`. **Store `.p8` key securely** (GitHub Secrets, NOT in repo); paste its contents, key ID, and team ID into the Supabase dashboard.
   - **No Xcode capabilities needed** - web OAuth doesn't require native Apple Sign-In capability
4. **Flutter configuration**
   - **Deep link scheme** (for OAuth redirect back to app):
     - iOS: add `CFBundleURLTypes` entry to `ios/Runner/Info.plist` with scheme `com.milkman.mealvanaendurance`
     - Android: add `<intent-filter>` to `android/app/src/main/AndroidManifest.xml` with scheme `com.milkman.mealvanaendurance`
   - **Auth state listener** (in AppStartupService):
     - Listen to `supabase.auth.onAuthStateChange`
     - Detect OAuth sign-in events
     - Update local profile automatically
   - **No native dependencies**: Just `supabase_flutter` (already installed)
5. **Email/password**
   - Direct `supabase.auth.updateUser(email, password)` call
   - Links email to existing anonymous account
   - Optional email verification (can be disabled for faster signup)

### Phase 3 – Environment & Telemetry Automation
1. **Automatic `.env` selection**
   - In `main.dart`:
     ```dart
     final envFile = kReleaseMode ? '.env.prod.local' : '.env.dev.local';
     await dotenv.load(fileName: envFile);
     AppConfig.loadFromEnv(envFile);
     options.environment = kReleaseMode ? 'production' : 'development';
     ```
   - After loading, apply the SharedPreferences override (environment switcher) if it exists.
2. **Mixpanel & analytics**
   - `AppConfig` already surfaces `mixpanelProjectToken`; ensure `.env.dev.local` uses the dev token.
   - Add a debug log on startup showing which token/env is active for quick verification. Reuse the existing Mixpanel calls—just extend them with the new auth events when the screen ships.
3. **Sentry**
   - Confirm `.env.dev.local` points to the dev DSN; `.env.prod.local` to the prod DSN.
   - Ensure `options.environment` matches the env so filtering works in Sentry UI.
4. **Verification checklist**
   - Add a small script or checklist entry (e.g., in `README.md`) describing how to confirm the correct env at runtime (`flutter logs` should print “Loading env: .env.dev.local”).

### Phase 4 – Observability Enhancements
1. Instrument onboarding/auth steps with Mixpanel events (`profile_submitted`, `auth_skipped`, `auth_linked_google`, etc.) and Sentry breadcrumbs (a lightweight addition on top of the existing tracker).
2. Capture anonymous vs permanent state in user context (`sentry.setUser(id: uuid, data: { 'is_anonymous': true/false })`).
3. Add health metrics: measure onboarding duration, number of retries, failure reasons (Drift validation, Supabase rejection, auth linking errors).
4. Set up dashboards/alerts (Mixpanel and Sentry) for spikes in anonymous onboarding failures or auth linking errors.

## 5. SQL to run on Supabase (Dev & Prod)
Run this once before shipping the new code so the schema matches the expectations above.

```sql
-- Require the app to set the primary key explicitly (match auth.users.id)
alter table public.users
    alter column id drop default;  -- remove gen_random_uuid() default

-- Make sure device_id stays around for analytics/history
alter table public.users
    alter column device_id set not null;
```

After this migration, inserts must always provide `id` (the Supabase Auth UUID).

## 6. Dependencies & Notes
- **Drift Migration Order**: introduce new columns with defaults, backfill from current data, then switch app code to use the new fields. Ship migrations before removing legacy columns.
- **Anonymous Auth Abuse**: enable CAPTCHA/Turnstile in Supabase Auth settings and monitor the built-in rate limit (30 requests/hr per IP). Consider server-side cleanup tasks.
- **Manual Overrides**: Document the environment switcher (gesture, secret tap, etc.) so QA/on-call engineers can still toggle between dev/prod after the automatic detection lands.
- **Testing Strategy**:
  1. Unit tests for `AuthService` verifying Supabase UUID persistence.
  2. Integration tests for onboarding flows (anonymous session → data sync).
  3. Smoke tests for social login on both iOS & Android simulators/emulators.

## 7. Open Questions
1. Do we want to backfill Supabase UUIDs for existing production users now or wait until authentication rolls out? (Current directive: ignore for now.)
2. What reminders/nudges should we display if the user skips authentication? (E.g., banner on home, gating some features.)
3. Do we need any merge logic if an anonymous user signs into an existing permanent account on another device? (Current plan: keep it simple; treat anonymous accounts as disposable.)

---

For implementation details or updates, coordinate with the App Startup squad and keep this document in sync as milestones ship.
