# Native OAuth Migration Plan

**Status:** 🚧 In Review  
**Decision:** Ship native-only Google/Apple sign-in while keeping the existing Supabase backend, anonymous-auth bootstrapping, and deep-link–ready app shell.  
**Owner:** Auth Task Force (Levi, Kyle, Andrea)  
**Last Updated:** 2025‑11‑19

---

## 1. Background & Goals

The hosted Supabase OAuth flow (browser redirect + deep link) is fully operational, but product direction now calls for a seamless, in-app experience. Rather than maintaining both hosted and native paths, we will migrate entirely to native Google/Apple SDKs and exchange those tokens with Supabase via `signInWithIdToken`. Key guardrails:

- Supabase remains the single source of truth (auth UUID must never change).
- Anonymous → linked upgrade flow, Drift persistence, and session repository stay untouched.
- Andrea’s `MaterialApp.builder`/GoRouter deep-link architecture remains (push notifications, email verification, other inbound links still rely on it).
- Native OAuth replaces the web flow at the service/controller layer, but the rest of the auth surface (screens, analytics, Sentry) stays the same.

**Success Criteria**
- No browser opens during Google/Apple signup.
- Linking preserves the Supabase UID and all local data.
- Analytics + Sentry capture native-specific events/error codes.
- Supabase dashboard recognizes all authorized client IDs and `.p8` credentials.

---

## 2. Current vs Target Flow

| Aspect | Current (Hosted) | Target (Native) |
| --- | --- | --- |
| User UX | Browser redirect, deep-link return | In-app Google picker / Apple sheet |
| SDK entry point | `signInWithOAuth` | `signInWithIdToken` |
| Dependencies | `supabase_flutter` only | `supabase_flutter` + `google_sign_in` + `sign_in_with_apple` + `crypto` |
| Deep-link requirement | Yes (for callback) | Not for OAuth (but still for other features) |
| Error telemetry | Web-specific errors | Native error codes (12500, ASAuthorizationError, etc.) |

---

## 3. Implementation Plan

### Phase A – Console & Dashboard Configuration (est. 3 hrs)

1. **Google Cloud**
   - Create/confirm project and OAuth consent screen.
   - Generate **Web client** (redirect `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`) with client ID/secret.
   - Generate **Android client** (package `com.milkman.mealvanaendurance`, debug+release SHA‑1 fingerprints).
   - Generate **iOS client** (bundle `com.milkman.mealvanaendurance`).
   - Document all IDs and secrets in 1Password.

2. **Apple Developer Portal**
   - Enable “Sign in with Apple” capability on the app ID.
   - Create Services ID `com.milkman.mealvanaendurance.auth`.
   - Configure return URL `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`.
   - Create a `.p8` key (save Key ID + Team ID + secret in vault, schedule 6‑month rotation).

3. **Supabase Dashboard**
   - Authentication → Providers:
     - **Google**: enable, paste Web client ID/secret, populate “Authorized Client IDs” with web + Android + iOS IDs.
     - **Apple**: enable, upload `.p8`, set Services ID, Team ID, Key ID.
   - Authentication → URL configuration: ensure `com.milkman.mealvanaendurance://auth-callback` remains for other flows.

4. **Environment Files**
   - Add `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`, `GOOGLE_ANDROID_CLIENT_ID` (if needed), and `APPLE_SERVICES_ID` to `.env.dev.local` / `.env.prod.local`.

**Exit Criteria:** All credentials verified, stored securely, and Supabase accepts native tokens.

---

### Phase B – Dependencies & Platform Wiring (est. 45 min)

1. **pubspec.yaml**
   ```yaml
   dependencies:
     supabase_flutter: ^2.8.5
     google_sign_in: ^6.2.1
     sign_in_with_apple: ^6.1.0
     crypto: ^3.0.3
   ```
   - Run `flutter pub get`.

2. **Android**
   - Add Google client IDs to `android/app/src/main/res/values/strings.xml`.
   - Update `AndroidManifest.xml` with the default web client ID metadata per Google Sign-In docs.
   - Ensure SHA‑1 fingerprints match credentials in Google Cloud.

3. **iOS**
   - Add Sign in with Apple capability in Xcode (targets Runner).
   - Add reversed client ID to `Info.plist` (if not already present).
   - Confirm keychain sharing / Associated Domains remain unchanged.

---

### Phase C – Code Changes (est. 3 hrs)

1. **OAuthService (`lib/features/auth/application/oauth_service.dart`)**
   - Remove `signInWithOAuth` usages.
   - Add native flows:
     ```dart
     final googleSignIn = GoogleSignIn(
       clientId: iosClientId,
       serverClientId: webClientId,
     );
     final GoogleSignInAccount? account = await googleSignIn.signIn();
     final auth = await account?.authentication;
     await _supabase.auth.signInWithIdToken(
       provider: OAuthProvider.google,
       idToken: auth.idToken!,
       accessToken: auth.accessToken!,
     );
     ```
   - Apple path: generate raw nonce via `_supabase.auth.generateRawNonce()`, hash with `sha256` (crypto), call `SignInWithApple.getAppleIDCredential`, then `signInWithIdToken`.
   - Centralize environment lookup for client IDs.
   - Preserve existing `handleOAuthCallback` invocation, analytics logging, and error surfacing.

2. **PostOnboardingAuthController**
   - Update actions to call the new native methods.
   - Map native error codes (user cancelled vs. fatal) to UI states.

3. **Analytics/Sentry**
   - Emit `auth_google_native_started/linked/cancelled/failed` and Apple equivalents with error payloads (`platform`, `errorCode`).

4. **Clean-Up**
   - Remove unused imports and any hosted OAuth helper functions.
   - Leave deep-link handlers intact (still used elsewhere).

---

### Phase D – QA & Verification (est. 4 hrs)

| Test | Steps | Notes |
| --- | --- | --- |
| Google (Android) | Fresh anon user → create plan → link Google → restart app offline/online | Validate UID unchanged, data intact. |
| Google (iOS) | Repeat on simulator/physical device | iOS requires configured reversed client ID. |
| Apple (iOS physical) | Fresh anon user → link Apple → ensure email/name captured when available | Must be done on real device signed into Apple ID. |
| Regression | Email/password signup, skip flow, sign-out → sign-in again | Ensure session repository persists native sessions. |
| Failure states | Cancel Google/Apple, revoke token, network loss mid-flow | UI recovers without leaving user stuck. |

Record evidence (video or screenshots) and log ticket numbers for QA.

---

### Phase E – Launch & Maintenance

1. **Documentation**
   - Update Phase 2 status board and README to indicate native-only approach.
   - Add runbook entries for rotating Apple keys and updating Google client IDs.

2. **Monitoring**
   - Sentry alert: >5% native auth failure within 1h.
   - Mixpanel dashboard: track `auth_native_started/linked/cancelled`.

3. **Rollout**
   - Internal dogfood build (TestFlight/Internal testing) → 48h soak.
   - Production rollout once metrics stable; keep hosted flow code removed to avoid split-brain UX.

4. **Maintenance Cadence**
   - Apple `.p8` rotation every 6 months (calendar reminder).
   - Re-verify SHA‑1 fingerprints after signing key changes.
   - Upgrade `google_sign_in` / `sign_in_with_apple` alongside Flutter major upgrades.

---

## 4. Open Questions

1. **Fallback strategy?** Currently none (intentional). If native SDK fails, we surface an error and encourage retry rather than silently falling back to browser, to keep UX consistent.
2. **Web support?** Native packages don’t apply to Flutter web. If/when we ship web builds, we’ll keep a minimal hosted OAuth implementation behind platform checks.
3. **Device coverage?** Apple Sign-In requires iOS 13+. Need to confirm our minimum supported OS still meets App Store requirement.

---

## 5. Next Actions

| Owner | Task | Target Date |
| --- | --- | --- |
| Levi | Complete Google Cloud + Supabase provider configuration | Nov 20 |
| Kyle | Configure Apple Services ID, upload `.p8`, set reminder | Nov 21 |
| Andrea | Implement Phase C code changes + analytics | Nov 22 |
| QA | Execute Phase D matrix on both platforms | Nov 24 |
| PM | Update roadmap docs + comms | Nov 25 |

Once QA signs off, merge and tag Phase 2 as “Native OAuth complete”.

---
