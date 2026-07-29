# Phase 2: Account Linking Implementation (Web OAuth)

**Status:** 🚧 **IN PROGRESS** (9/14 tasks complete - UI & Backend done, Platform config & Testing pending)
**Updated:** 2025-11-18
**Estimated Duration:** 2-3 weeks
**Priority:** HIGH
**OAuth Approach:** Web-based (Supabase hosted)

---

## Overview

Phase 2 enables users to **upgrade from anonymous accounts to permanent accounts** by linking identity providers (Apple, Google, or Email/Password). This allows:

- ✅ **Cross-device sync** - Access data on multiple devices
- ✅ **Data recovery** - Restore data if app is uninstalled
- ✅ **User trust** - Professional account management
- ✅ **Retention** - Reduce churn from data loss

## Key Principle

**Account linking preserves the user's `auth.uid()`** - All existing nutrition plans, preferences, and data remain intact. The only change is updating:
- `is_anonymous` from `true` → `false`
- `auth_provider` from `'anonymous'` → `'apple'/'google'/'email'`

---

## ✅ Implementation Complete (Backend)

### 1. OAuth Service (Web-Based)

**File:** `/lib/features/auth/application/oauth_service.dart`

**What It Does:**
- Handles Apple Sign-In via Supabase web OAuth
- Handles Google Sign-In via Supabase web OAuth
- Opens browser for authentication
- Redirects back to app via deep link
- Updates local user profile after successful linking

**Implementation:**
```dart
@riverpod
class OAuthService extends _$OAuthService {
  /// Link Apple account using Supabase web OAuth
  Future<void> linkAppleAccount() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'com.milkman.mealvanaendurance://auth-callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    // Opens browser, user signs in, redirects back to app
  }

  /// Link Google account using Supabase web OAuth
  Future<void> linkGoogleAccount() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.milkman.mealvanaendurance://auth-callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    // Opens browser, user signs in, redirects back to app
  }

  /// Handle OAuth callback after successful sign-in
  Future<void> handleOAuthCallback({
    required String userId,
    required String provider,
  }) async {
    // Update local profile: is_anonymous = false, auth_provider = 'apple'/'google'
  }
}
```

**Dependencies:** **NONE** - Uses built-in `supabase_flutter`

**No Native Packages Needed:**
- ❌ NO `sign_in_with_apple` package
- ❌ NO `google_sign_in` package
- ✅ Just `supabase_flutter` (already installed)

### 2. Email Auth Service

**File:** `/lib/features/auth/application/email_auth_service.dart`

**What It Does:**
- Handles email/password signup
- Links email to existing anonymous account
- Validates email format and password strength
- Updates local user profile

**Implementation:**
```dart
@riverpod
class EmailAuthService extends _$EmailAuthService {
  /// Link email/password to existing anonymous user
  Future<void> linkEmailAccount({
    required String email,
    required String password,
  }) async {
    // Validate inputs
    if (validateEmail(email) != null) throw Exception('Invalid email');
    if (validatePassword(password) != null) throw Exception('Weak password');

    // Update user with email and password
    final response = await _supabase.auth.updateUser(
      UserAttributes(
        email: email,
        password: password,
      ),
    );

    // Verify user ID didn't change (critical for data preservation)
    // Update local profile: is_anonymous = false, auth_provider = 'email'
  }
}
```

**Dependencies:** **NONE** - Uses built-in `supabase_flutter`

### 3. User Repository Enhancement

**File:** `/lib/features/auth/data/user_repository.dart`

**Added Method:**
```dart
/// Update auth provider after account linking
Future<void> updateAuthProvider({
  required String authProvider,
  required bool isAnonymous,
}) async {
  // Get current user profile
  // Update auth fields locally (Drift)
  // Sync to Supabase (PostgreSQL)
  // Track in Sentry
}
```

---

## ✅ UI & Frontend Implementation (Complete)

### 1. ✅ Post-Onboarding Auth Screen

**File:** `/lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart` ✅ **CREATED**

**Features:**
- Hero text with account benefits
- Benefits card with 4 key benefits
- Apple Sign-In button (web OAuth)
- Google Sign-In button (web OAuth)
- Email signup button
- Skip button with reminder text
- Full ContentService integration
- Loading states during OAuth flow

### 2. ✅ Post-Onboarding Auth Controller

**File:** `/lib/features/auth/presentation/providers/post_onboarding_auth_controller.dart` ✅ **CREATED**

**Features:**
- `linkAppleAccount()` - Initiates Apple Sign-In
- `linkGoogleAccount()` - Initiates Google Sign-In
- `linkEmailAccount()` - Creates email/password account
- `skipAuthentication()` - Tracks skip event
- Full analytics tracking
- Error handling with user-friendly messages

### 3. ✅ Email Signup Screen

**File:** `/lib/features/auth/presentation/screens/email_signup_screen.dart` ✅ **CREATED**

**Features:**
- Email and password input fields
- Password confirmation field
- Client-side validation (email format, password strength, password match)
- Password visibility toggles
- Email verification notice
- ContentService integration
- Loading states

### 4. ✅ Router Configuration

**File:** `/lib/shared/core/app_router.dart` ✅ **UPDATED**

**Routes Added:**
- `/auth/post-onboarding` → PostOnboardingAuthScreen
- `/auth/email-signup` → EmailSignupScreen

### 5. ✅ Onboarding Flow Update

**File:** `/lib/features/onboarding/presentation/screens/food_preferences_screen.dart` ✅ **UPDATED**

**Change:**
- Now navigates to `/auth/post-onboarding` after food preferences
- Analytics updated to track new flow

### 6. ✅ Content Management System

**File:** `/assets/config/content_defaults.json` ✅ **UPDATED**

**Content Added:**
- `auth.post_onboarding.*` - All post-onboarding auth screen text
- `auth.email_signup.*` - All email signup screen text
- `auth.settings.*` - Settings screen auth status text
- `auth.errors.*` - Error messages

---

## ✅ Architecture Refactor (Complete)

### App Initialization Pattern Refactor

**Status:** ✅ Completed (Nov 19, 2025)
**Files:** `/lib/shared/widgets/root_app_widget.dart`, `/lib/features/app_startup/presentation/widgets/app_startup_widget.dart`, `/lib/shared/core/app_router.dart`

- `AppStartupWidget` now wraps the router child via an `onLoaded` callback and no longer issues `context.go()` calls.
- `RootAppWidget` uses `MaterialApp.builder` (across data/loading/error states) so GoRouter is ready the moment `runApp()` executes.
- `AppRouter` delegates initial routing through a `redirect` callback that inspects `appStartupProvider`, removing the old `/` route that rendered AppStartupWidget directly.

```dart
return MaterialApp.router(
  routerConfig: goRouter,
  builder: (context, child) {
    return AppStartupWidget(
      onLoaded: (_) => child!,
    );
  },
);
```

**Key Outcomes:**
1. OAuth deep links like `com.milkman.mealvanaendurance://auth-callback` are processed during startup because GoRouter is always active.
2. AppStartupWidget focuses purely on initialization UI/state management, keeping navigation centralized in GoRouter.
3. Deep-link smoke tests (`adb shell am start -a android.intent.action.VIEW -d "com.milkman.mealvanaendurance://test" …`) succeed without navigation conflicts.

---
## Platform Configuration & Testing

### 1. ⏳ Settings Screen Updates

**File:** `/lib/features/settings/presentation/screens/settings_screen.dart` (needs update)

**TODO:**
- Add "Account" section at top of settings
- For anonymous users:
  - Display "Not signed in" status
  - Show "Create Account" button with badge
  - Tappable → Navigate to `/auth/post-onboarding`
- For authenticated users:
  - Display "Signed in with [Apple/Google/Email]"
  - Show email address (if available)
  - Show "Sign Out" button

---

## OAuth Flow (Web-Based)

### Apple/Google Sign-In Flow

```
User taps "Continue with Google"
    ↓
PostOnboardingAuthController.linkGoogleAccount()
    ↓
OAuthService.linkGoogleAccount()
    ↓
supabase.auth.signInWithOAuth(OAuthProvider.google)
    ↓
Opens browser/web view (Supabase hosted OAuth page)
    ↓
User signs in with Google on web
    ↓
Google authenticates and returns to Supabase
    ↓
Supabase creates/links account
    ↓
Redirect to: com.milkman.mealvanaendurance://auth-callback
    ↓
App receives deep link
    ↓
Auth state change listener fires (in AppStartupService)
    ↓
OAuthService.handleOAuthCallback() called
    ↓
Updates local profile: is_anonymous = false, auth_provider = 'google'
    ↓
Navigate to /home
    ↓
User sees home screen with authenticated status
```

### Email/Password Flow

```
User taps "Sign up with Email"
    ↓
Navigate to EmailSignupScreen
    ↓
User enters email and password
    ↓
EmailAuthService.linkEmailAccount(email, password)
    ↓
Validate inputs
    ↓
supabase.auth.updateUser(email, password)
    ↓
Verify user ID didn't change
    ↓
Update local profile: is_anonymous = false, auth_provider = 'email'
    ↓
Navigate to /home
    ↓
User sees home screen with authenticated status
```

---

## Configuration Required

### 1. Supabase Dashboard Setup

**Status:** ⏳ Pending (Supabase dashboard)

**Authentication → Providers:**

#### Enable Google:
1. Go to Supabase Dashboard → Authentication → Providers
2. Enable "Google"
3. Create OAuth 2.0 Client in Google Cloud Console:
   - Application type: **Web application**
   - Authorized redirect URIs: `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`
4. Copy Client ID and Client Secret to Supabase dashboard
5. **No native iOS/Android credentials needed** (web flow only)

#### Enable Apple:
1. Enable "Apple"
2. Create Service ID in Apple Developer:
   - Identifier: `com.milkman.mealvanaendurance.auth`
   - Enable "Sign in with Apple"
   - Configure return URLs: `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`
3. Create private key (.p8) in Apple Developer
4. **Store key securely** (GitHub Secrets, NOT in repo)
5. Paste key contents, Key ID, and Team ID into Supabase dashboard

#### Enable Email:
- Already enabled by default
- Optional: Disable email confirmation for faster signup
  - Settings → Authentication → Email Auth → "Enable email confirmations" OFF

**Authentication → URL Configuration:**

```
Site URL: https://mealvana.com
Redirect URLs:
  - com.milkman.mealvanaendurance://auth-callback
  - https://mealvana.com/auth/callback
```

**Authentication → Settings:**

```
JWT expiry: 43200 seconds (12 hours)
Enable anonymous sign-ins: ON
```

### 2. iOS Configuration (✅ Complete)

**File:** `ios/Runner/Info.plist`
- `CFBundleURLTypes` includes the `com.milkman.mealvanaendurance` scheme so Supabase OAuth redirects reopen the app.
- Comment block documents the deep-link purpose and no longer requires additional native capabilities.
### 3. Android Configuration (✅ Complete)

**File:** `android/app/src/main/AndroidManifest.xml`
- `VIEW/BROWSABLE` intent filter added to `MainActivity` with scheme `com.milkman.mealvanaendurance` and host `auth-callback`.
- `android:autoVerify="true"` ensures redirects bounce back immediately on Android 12+.
### 4. Auth State Change Listener (✅ Complete)

**File:** `/lib/features/app_startup/application/app_startup_service.dart`
- `setupAuthStateListener()` now listens to `supabase.auth.onAuthStateChange`, updates analytics, and calls `OAuthService.handleOAuthCallback()` for non-anonymous providers.
- Token refresh + sign-out events are tracked for observability.

---

## Dependencies

**Current (Correct):**
```yaml
dependencies:
  supabase_flutter: ^2.8.5  # Only dependency needed
```

**Removed (No Longer Needed):**
```yaml
# ❌ These were removed - web OAuth doesn't need them
# sign_in_with_apple: ^6.1.0
# google_sign_in: ^6.2.1
```

---

## Content Management Reference

**File:** `assets/config/content_defaults.json` (✅ implemented — snippet for reference)

**Key Section:**
```json
{
  "ui_text": {
    "auth": {
      "post_onboarding": {
        "title": "Sync Your Data",
        "subtitle": "Create an account to access your nutrition plans on all devices",
        "skip_button": "Skip for now",
        "benefits": {
          "sync": "Access on phone, tablet, and web",
          "backup": "Automatic cloud backup",
          "secure": "Secure and encrypted"
        }
      },
      "buttons": {
        "apple": "Continue with Apple",
        "google": "Continue with Google",
        "email": "Sign up with Email"
      },
      "email_signup": {
        "title": "Create Account",
        "email_label": "Email",
        "password_label": "Password",
        "submit_button": "Create Account",
        "validation": {
          "email_required": "Email is required",
          "email_invalid": "Please enter a valid email address",
          "password_required": "Password is required",
          "password_too_short": "Password must be at least 8 characters"
        }
      }
    }
  }
}
```

---

## Testing Strategy

### Manual Testing Checklist

**Anonymous User Flow:**
- [ ] New user completes onboarding
- [ ] Auth screen shows after food preferences
- [ ] User can skip auth → Home screen displays
- [ ] Settings shows "Anonymous" badge
- [ ] Tapping settings account → Returns to auth screen

**Apple Sign-In (Web OAuth):**
- [ ] Tap "Continue with Apple" button
- [ ] Browser opens with Apple Sign-In page
- [ ] User signs in with Apple ID on web
- [ ] Browser redirects back to app
- [ ] App receives deep link callback
- [ ] Account linked successfully (same user ID)
- [ ] Settings shows "Authenticated with Apple"
- [ ] All previous data still accessible (nutrition plans, preferences)

**Google Sign-In (Web OAuth):**
- [ ] Tap "Continue with Google" button
- [ ] Browser opens with Google Sign-In page
- [ ] User signs in with Google account
- [ ] Browser redirects back to app
- [ ] App receives deep link callback
- [ ] Account linked successfully
- [ ] Settings shows authenticated status
- [ ] All data preserved

**Email/Password:**
- [ ] Tap "Sign up with Email"
- [ ] Enter valid email and password
- [ ] Validation passes
- [ ] Account created and linked
- [ ] Settings shows email address
- [ ] Data preserved

**Cross-Device Sync (Future):**
- [ ] Link account on Device A
- [ ] Install app on Device B
- [ ] Sign in with same account
- [ ] Data syncs from Device A to Device B

---

## Advantages of Web OAuth Approach

### ✅ Pros
1. **No Extra Dependencies** - Just `supabase_flutter`
2. **Less Configuration** - No native OAuth SDKs to set up
3. **Simpler Code** - One code path for all providers
4. **Works Everywhere** - Same flow on iOS/Android/Web
5. **Easier Debugging** - Supabase handles OAuth complexity
6. **No Native Limitations** - Works in simulator, no physical device required
7. **Auto-Updates** - Supabase manages OAuth provider changes

### ⚠️ Cons
1. **Opens Browser** - Slightly worse UX than native (user sees redirect)
2. **Network Required** - Can't complete OAuth offline (same as native)
3. **User Sees URL** - Browser shows Supabase URL briefly

### Decision
**Web OAuth is the right choice** for this project because:
- Simpler implementation (less code, less maintenance)
- Good enough UX (opening browser for 5 seconds is acceptable)
- Matches Supabase best practices
- Easier to test and debug

---

## Success Criteria

Phase 2 is complete when:

- ✅ Post-onboarding auth screen displays correctly (UI + routing complete).
- ✅ Users can skip auth and stay anonymous without blocking progress.
- ✅ Email signup flow links credentials to the anonymous session.
- ✅ OAuthService + AuthState listener preserve Supabase UID across Apple/Google linking.
- ⏳ Apple Sign-In flow validated end-to-end (web redirect → deep link → profile update).
- ⏳ Google Sign-In flow validated end-to-end on iOS + Android.
- ⏳ Email signup tested on device, confirming analytics + Sentry breadcrumbs.
- ⏳ Account linking verified to preserve activities/preferences/nutrition data.
- ⏳ Settings screen shows accurate auth status and CTA.
- ⏳ Anonymous reminder badge appears where needed (settings/account surfaces).

---

## Implementation Status

### ✅ Complete
- Backend services (OAuthService, EmailAuthService, UserRepository.updateAuthProvider) and dependency cleanup.
- Frontend UI stack (PostOnboardingAuthScreen, EmailSignupScreen, controllers, content defaults, router wiring, onboarding hand-off).
- Architecture + platform work (AppStartupWidget refactor, RootAppWidget builder, AppRouter redirect, auth state listener, iOS/Android deep links).

### ⏳ Remaining
1. Settings screen account module (surface anonymous vs linked state, CTA to create account / sign out).
2. Supabase dashboard configuration for Google + Apple OAuth (client credentials + redirect URL + custom scheme).
3. End-to-end testing of Apple, Google, and email/password flows, validating analytics + data preservation.

## Recommended Next Steps

1. **Configure Supabase Providers** – Enter Google + Apple credentials, verify redirect URLs, and add the custom scheme `com.milkman.mealvanaendurance://auth-callback` in Authentication → URL Configuration.
2. **Exercise Every Auth Flow** – On devices/simulators, run Apple, Google, and email/password linking; verify analytics + Sentry breadcrumbs and confirm Supabase UID + local data stay stable.
3. **Ship Settings Account Module** – Surface provider/anonymous state, wire the "Create Account" CTA for anonymous users, and expose a sign-out pathway for QA.

---

**Document Owner:** Development Team  \
**Last Updated:** 2025-11-19  \
**OAuth Approach:** Supabase-hosted (web) Apple + Google + email  \
**Status Snapshot:** Backend ✅ | UI ✅ | Architecture ✅ | Platform config ⏳ | Testing ⏳
