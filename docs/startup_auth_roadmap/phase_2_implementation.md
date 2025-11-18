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

## 🚧 Architecture Refactor (CRITICAL - Required First)

### ⚠️ App Initialization Pattern Refactor

**Status:** ⏳ Not started
**Priority:** 🔴 BLOCKING - Must complete before OAuth will work
**Estimated Time:** 1 hour

**The Problem:**
Our current app initialization pattern doesn't support OAuth deep links. Here's why:

**Current (Broken) Flow:**
```
App Launch
    ↓
runApp(MaterialApp.router) → GoRouter initialized
    ↓
User lands on '/' route → AppStartupWidget rendered
    ↓
AppStartupWidget runs initialization
    ↓
On success: context.go('/welcome' or '/main')
    ↓
OAuth redirect arrives: com.milkman.mealvanaendurance://auth-callback
    ↓
❌ PROBLEM: GoRouter can't handle deep link because AppStartupWidget controls navigation
```

**Why This Breaks OAuth:**
1. OAuth redirects arrive as **deep links** during or immediately after app initialization
2. GoRouter needs to be **ready to process deep links** from the moment the app launches
3. But our AppStartupWidget is **a route itself** (`/`), blocking GoRouter's deep link handling
4. When OAuth redirect arrives, AppStartupWidget has already navigated away using `context.go()`
5. Deep link is ignored or causes navigation conflicts

**Andrea Bizzotto's Solution:**
Andrea's initialization pattern solves this by using `MaterialApp.builder` to wrap the router's child widget. This ensures:
- GoRouter initializes **immediately** when `runApp()` is called
- Deep links can be processed **during** app initialization
- AppStartupWidget manages **loading/error states** without interfering with routing

**Target (Working) Flow:**
```
App Launch
    ↓
runApp(MaterialApp.router with builder)
    ↓
GoRouter initialized IMMEDIATELY (ready for deep links)
    ↓
MaterialApp.builder wraps router child with AppStartupWidget
    ↓
AppStartupWidget shows loading → Runs initialization → Returns router child
    ↓
GoRouter determines initial route based on app state
    ↓
OAuth redirect arrives: com.milkman.mealvanaendurance://auth-callback
    ↓
✅ SUCCESS: GoRouter handles deep link, triggers auth callback
```

---

### Implementation Guide

**File 1: `/lib/features/app_startup/presentation/widgets/app_startup_widget.dart`**

**BEFORE (Current - Route-based):**
```dart
class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStartupState = ref.watch(appStartupProvider);

    return appStartupState.when(
      loading: () => const AppStartupLoadingWidget(),
      error: (e, st) => AppStartupErrorWidget(...),
      data: (appStartupData) => _handleNavigation(context, appStartupData),
    );
  }

  Widget _handleNavigation(BuildContext context, AppStartupData data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (data.user == null) {
        context.go('/welcome');
      } else if (!data.hasCompletedOnboarding) {
        context.go('/onboarding/food-preferences');
      } else {
        context.go('/main');
      }
    });
    return Scaffold(...); // Placeholder
  }
}
```

**AFTER (Andrea's Pattern - Wrapper Widget):**
```dart
class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({
    super.key,
    required this.onLoaded, // NEW: Callback pattern
  });

  final WidgetBuilder onLoaded; // NEW: Returns router child

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStartupState = ref.watch(appStartupProvider);

    return appStartupState.when(
      loading: () => const AppStartupLoadingWidget(),
      error: (e, st) => AppStartupErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(appStartupProvider),
      ),
      data: (_) => onLoaded(context), // NEW: Return router child
    );
  }
}
```

**Key Changes:**
- ❌ Remove `_handleNavigation()` method - no longer needed
- ❌ Remove `context.go()` calls - GoRouter handles navigation
- ✅ Add `onLoaded` callback - returns router's child widget
- ✅ AppStartupWidget is now a **wrapper**, not a route

---

**File 2: `/lib/shared/widgets/root_app_widget.dart`**

**BEFORE (Current):**
```dart
class RootAppWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeAsync = ref.watch(kyleThemeModeProvider);

    return ScreenUtilInit(
      builder: (context, child) {
        return themeModeAsync.when(
          data: (themeMode) {
            return MaterialApp.router(
              title: 'Mealvana Endurance',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              routerConfig: AppRouter.router, // AppStartupWidget is a route at '/'
            );
          },
          // ... loading/error states
        );
      },
    );
  }
}
```

**AFTER (Andrea's Pattern with MaterialApp.builder):**
```dart
class RootAppWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeAsync = ref.watch(kyleThemeModeProvider);

    return ScreenUtilInit(
      builder: (context, child) {
        return themeModeAsync.when(
          data: (themeMode) {
            return MaterialApp.router(
              title: 'Mealvana Endurance',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              routerConfig: AppRouter.router,
              // NEW: Wrap router child with AppStartupWidget
              builder: (context, child) {
                return AppStartupWidget(
                  onLoaded: (_) => child!, // Pass through router's child
                );
              },
            );
          },
          // ... loading/error states (also need builder)
          loading: () {
            return MaterialApp.router(
              routerConfig: AppRouter.router,
              builder: (context, child) {
                return AppStartupWidget(
                  onLoaded: (_) => child!,
                );
              },
            );
          },
          error: (error, stack) {
            return MaterialApp.router(
              routerConfig: AppRouter.router,
              builder: (context, child) {
                return AppStartupWidget(
                  onLoaded: (_) => child!,
                );
              },
            );
          },
        );
      },
    );
  }
}
```

**Key Changes:**
- ✅ Add `builder` parameter to `MaterialApp.router`
- ✅ Wrap `child` (router's widget) with `AppStartupWidget`
- ✅ Use `onLoaded: (_) => child!` to return router's child
- ✅ Apply to all theme states (data, loading, error)

---

**File 3: `/lib/shared/core/app_router.dart`**

**BEFORE (Current):**
```dart
class AppRouter {
  static final router = GoRouter(
    initialLocation: '/', // AppStartupWidget route
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AppStartupWidget(), // ❌ Remove this
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      // ... other routes
    ],
  );
}
```

**AFTER (Andrea's Pattern):**
```dart
class AppRouter {
  static final router = GoRouter(
    initialLocation: '/', // Root - will redirect to actual initial screen

    // NEW: Add redirect logic for initial navigation
    redirect: (context, state) {
      // Only redirect on initial load (root path)
      if (state.matchedLocation == '/') {
        // Read startup data from provider
        final container = ProviderScope.containerOf(context);
        final startupData = container.read(appStartupProvider).valueOrNull;

        if (startupData == null) {
          // Still loading - stay at root
          return null;
        }

        // Determine initial route based on app state
        if (startupData.user == null) {
          return '/welcome';
        } else if (!startupData.hasCompletedOnboarding) {
          return '/onboarding/food-preferences';
        } else if (startupData.activityIdNeedingFeedback != null) {
          return '/plan-how-well/${startupData.activityIdNeedingFeedback}';
        } else {
          return '/main';
        }
      }

      // No redirect for other paths
      return null;
    },

    routes: [
      // ❌ REMOVE: AppStartupWidget route
      // GoRoute(path: '/', builder: (context, state) => const AppStartupWidget()),

      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      // ... other routes
    ],
  );
}
```

**Key Changes:**
- ❌ Remove `AppStartupWidget` route at `/`
- ✅ Add `redirect` callback to handle initial navigation
- ✅ Read `appStartupProvider` to determine initial route
- ✅ GoRouter now controls all navigation (including initial)

---

### Why This Matters for OAuth Deep Links

**Before (Broken):**
```
OAuth redirect: com.milkman.mealvanaendurance://auth-callback
    ↓
App receives deep link
    ↓
GoRouter tries to handle it
    ↓
❌ AppStartupWidget is controlling navigation via context.go()
    ↓
❌ Deep link ignored or causes conflict
    ↓
❌ User stuck, auth callback never triggers
```

**After (Working):**
```
OAuth redirect: com.milkman.mealvanaendurance://auth-callback
    ↓
App receives deep link
    ↓
GoRouter processes it immediately (initialized at app launch)
    ↓
✅ AppStartupWidget is just a wrapper (not controlling navigation)
    ✅ Shows loading during initialization
    ✅ Returns router child when ready
    ↓
✅ GoRouter routes to /auth-callback handler
    ↓
✅ Auth state listener detects OAuth sign-in
    ↓
✅ Updates local profile
    ↓
✅ User authenticated successfully
```

---

### Testing the Refactor

**Before implementing OAuth, verify the refactor works:**

1. **App launches correctly:**
   ```bash
   flutter run
   # Verify: App shows loading → navigates to welcome/onboarding/main
   ```

2. **Deep links work during initialization:**
   ```bash
   # Simulate deep link while app is initializing
   adb shell am start -a android.intent.action.VIEW \
     -d "com.milkman.mealvanaendurance://test" \
     com.milkman.mealvanaendurance

   # Verify: Deep link is processed correctly
   ```

3. **No navigation conflicts:**
   ```bash
   # Check logs for navigation errors
   flutter logs | grep -i "navigation\|route\|gorouter"

   # Should see: Clean navigation with no conflicts
   ```

---

### References

**Andrea Bizzotto's Documentation:**
- File: `/docs/technical/andrea/andrea_initialization.txt`
- Section: "Important Note About URL Navigation and Deep Links" (lines 395-465)
- Key quote: "MaterialApp.builder allows us to wrap the router's child widget with the AppStartupWidget without interfering with the routing logic"

**Flutter Documentation:**
- [MaterialApp.builder](https://api.flutter.dev/flutter/material/MaterialApp/builder.html)
- [GoRouter Deep Linking](https://pub.dev/documentation/go_router/latest/topics/Deep%20linking-topic.html)

---

## 🚧 Platform Configuration (Pending)

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

### 2. iOS Configuration

**Add Deep Link Scheme:**

Edit `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.milkman.mealvanaendurance</string>
    </array>
  </dict>
</array>
```

**No Apple Sign-In Capability Needed:**
- Web OAuth doesn't require native Apple Sign-In capability
- No need to enable in Xcode Signing & Capabilities
- Works without physical device (simulator OK)

### 3. Android Configuration

**Add Deep Link Scheme:**

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="com.milkman.mealvanaendurance" />
</intent-filter>
```

### 4. Auth State Change Listener

**File:** `/lib/features/app_startup/application/app_startup_service.dart` (needs update)

**Add Method:**
```dart
/// Setup auth state change listener to handle OAuth callbacks
void setupAuthStateListener() {
  _supabase.auth.onAuthStateChange.listen((data) async {
    final event = data.event;
    final session = data.session;

    if (event == AuthChangeEvent.signedIn && session != null) {
      final user = session.user;

      // Check if this is an OAuth sign-in (not anonymous)
      final provider = user.appMetadata?['provider'] as String?;

      if (provider != null && provider != 'anonymous') {
        // OAuth callback - update local profile
        await ref.read(oAuthServiceProvider.notifier).handleOAuthCallback(
          userId: user.id,
          provider: provider,
        );
      }
    }
  });
}
```

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

## Content Management

**File:** `assets/config/content_defaults.json` (needs update)

**Add Section:**
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

- ✅ OAuthService created (DONE)
- ✅ EmailAuthService created (DONE)
- ✅ UserRepository.updateAuthProvider() added (DONE)
- ✅ No native OAuth dependencies (DONE)
- ⏳ Post-onboarding auth screen displays correctly
- ⏳ User can skip auth and continue to home
- ⏳ Apple Sign-In works via browser
- ⏳ Google Sign-In works via browser
- ⏳ Email signup works with password
- ⏳ Account linking preserves all user data
- ⏳ Settings shows correct auth status
- ⏳ Settings reminder badge works for anonymous users
- ⏳ Analytics events firing correctly
- ⏳ Error handling covers common cases
- ⏳ Auth state change listener handles OAuth callbacks

---

## Implementation Status

### ✅ Backend Complete (4/4 tasks)
1. ✅ OAuthService with web OAuth flow
2. ✅ EmailAuthService with validation
3. ✅ UserRepository.updateAuthProvider()
4. ✅ Dependencies cleaned up (native packages removed)

### 🚧 Frontend TODO (11 tasks remaining)
5. ⏳ Add auth UI text to content_defaults.json
6. ⏳ Create PostOnboardingAuthScreen UI
7. ⏳ Create PostOnboardingAuthController
8. ⏳ Create EmailSignupScreen
9. ⏳ Add auth routes to GoRouter
10. ⏳ Update onboarding flow to show auth screen
11. ⏳ Update Settings screen with auth badge
12. ⏳ Configure iOS deep linking (Info.plist)
13. ⏳ Configure Android deep linking (AndroidManifest.xml)
14. ⏳ Add auth state change listener
15. ⏳ Test all auth flows

---

## Implementation Progress

### ✅ Completed (9/14 tasks)

**Backend Services:**
1. ✅ OAuthService with Apple/Google web OAuth
2. ✅ EmailAuthService with validation
3. ✅ UserRepository.updateAuthProvider()

**Frontend UI:**
4. ✅ PostOnboardingAuthScreen with benefits card
5. ✅ EmailSignupScreen with validation
6. ✅ PostOnboardingAuthController
7. ✅ Content defaults (auth text)
8. ✅ Router configuration (auth routes)
9. ✅ Onboarding flow update

### ⏳ Remaining (5/14 tasks)

**Critical Path (Required for Testing):**
1. ⏳ **Add auth state change listener** in `AppStartupService`
   - Detect OAuth callback events
   - Call `OAuthService.handleOAuthCallback()`
   - Navigate to main app after successful linking
   - **BLOCKER**: OAuth won't work without this

2. ⏳ **Configure iOS deep linking** in `Info.plist`
   - Add URL scheme: `com.milkman.mealvanaendurance`
   - Required for OAuth redirect

3. ⏳ **Configure Android deep linking** in `AndroidManifest.xml`
   - Add intent filter with scheme `com.milkman.mealvanaendurance`
   - Required for OAuth redirect

**Nice-to-Have (Can defer):**
4. ⏳ **Update Settings screen** with auth status
   - Show "Create Account" for anonymous users
   - Show provider for authenticated users
   - Not blocking OAuth testing

**Testing Phase (After config):**
5. ⏳ Test Apple Sign-In flow
6. ⏳ Test Google Sign-In flow
7. ⏳ Test Email signup flow
8. ⏳ Verify data preservation after linking

---

## Recommended Next Steps

### Priority 1: Auth State Change Listener (CRITICAL)

**File:** `/lib/features/app_startup/application/app_startup_service.dart`

**What to Add:**
```dart
// Add in AppStartupService initialization
void _setupAuthStateListener() {
  _supabase.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    final session = data.session;

    if (event == AuthChangeEvent.signedIn && session != null) {
      final user = session.user;

      // Check if this was an OAuth sign-in (not anonymous)
      if (user.appMetadata['provider'] != 'anonymous') {
        final provider = user.appMetadata['provider'] as String?;

        // Call OAuth callback handler
        ref.read(oAuthServiceProvider.notifier).handleOAuthCallback(
          userId: user.id,
          provider: provider ?? 'unknown',
        );

        // Navigate to main app
        ref.read(goRouterProvider).go('/main');
      }
    }
  });
}
```

**Why Critical:** Without this, OAuth redirects will work but won't update the app state or navigate users.

### Priority 2: Deep Linking Configuration

**iOS (`ios/Runner/Info.plist`):**
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.milkman.mealvanaendurance</string>
    </array>
  </dict>
</array>
```

**Android (`android/app/src/main/AndroidManifest.xml`):**
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="com.milkman.mealvanaendurance" />
</intent-filter>
```

### Priority 3: Supabase Dashboard Configuration

**Before testing OAuth:**
1. Configure Google OAuth in Supabase Dashboard
2. Configure Apple OAuth in Supabase Dashboard
3. Add redirect URL: `com.milkman.mealvanaendurance://auth-callback`

**See "Configuration Required" section above for detailed steps.**

### Priority 4: Settings Screen Update (Optional)

Can be deferred - not blocking OAuth testing. Users can still test account linking without the settings screen updates.

---

**Document Owner:** Development Team
**Last Updated:** 2025-11-18 (Phase 2 - UI Complete, Platform Config Pending)
**OAuth Approach:** Web-based (Supabase hosted OAuth)
**Status:** 9/14 tasks complete - Backend ✅ | UI ✅ | Config ⏳ | Testing ⏳
