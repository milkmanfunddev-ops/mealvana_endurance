# Phase 2 Implementation Status

**Last Updated:** 2025-11-18
**Overall Progress:** 9/15 tasks complete (60%)

---

## ✅ What's Complete (9 tasks)

### Backend Services (3/3) ✅
1. ✅ **OAuthService** - Web-based Apple/Google OAuth
   - File: `/lib/features/auth/application/oauth_service.dart`
   - Opens browser for authentication
   - Handles OAuth callbacks
   - Updates local profile after linking

2. ✅ **EmailAuthService** - Email/password signup
   - File: `/lib/features/auth/application/email_auth_service.dart`
   - Email format validation
   - Password strength validation (8+ chars)
   - Links to existing anonymous account

3. ✅ **UserRepository** - Profile updates
   - File: `/lib/features/auth/data/user_repository.dart`
   - Added `updateAuthProvider()` method
   - Updates Drift and Supabase
   - Proper error handling

### Frontend UI (6/6) ✅
4. ✅ **PostOnboardingAuthScreen**
   - File: `/lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart`
   - Hero text with benefits card
   - Apple/Google/Email buttons
   - Skip option with reminder

5. ✅ **EmailSignupScreen**
   - File: `/lib/features/auth/presentation/screens/email_signup_screen.dart`
   - Email/password/confirm fields
   - Password visibility toggles
   - Validation with error messages

6. ✅ **PostOnboardingAuthController**
   - File: `/lib/features/auth/presentation/providers/post_onboarding_auth_controller.dart`
   - Handles all auth actions
   - Analytics tracking
   - Error handling

7. ✅ **Content Management System**
   - File: `/assets/config/content_defaults.json`
   - All auth UI text
   - Benefits messaging
   - Error messages

8. ✅ **Router Configuration**
   - File: `/lib/shared/core/app_router.dart`
   - `/auth/post-onboarding` route
   - `/auth/email-signup` route

9. ✅ **Onboarding Flow**
   - File: `/lib/features/onboarding/presentation/screens/food_preferences_screen.dart`
   - Now navigates to auth screen after food preferences

---

## ⏳ What's Remaining (6 tasks)

### Critical Path (Required for Testing) 🔴

#### 0. Refactor App Initialization (Andrea's Pattern) (BLOCKER)
**Status:** ⏳ Not started
**Priority:** 🔴 CRITICAL - Must be done before auth listener
**Files:**
- `/lib/shared/widgets/root_app_widget.dart`
- `/lib/features/app_startup/presentation/widgets/app_startup_widget.dart`
- `/lib/shared/core/app_router.dart`

**Why Critical:** Current architecture doesn't support OAuth deep links. Andrea Bizzotto's pattern is REQUIRED for MaterialApp.builder + deep linking.

**Current Problem:**
- AppStartupWidget is a GoRouter route at `/`
- RootAppWidget uses MaterialApp.router without builder parameter
- This pattern doesn't work with OAuth redirects (can't intercept deep links)

**Target Architecture (Andrea's Pattern):**
```dart
// RootAppWidget (root_app_widget.dart)
class RootAppWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(goRouterProvider);

    return MaterialApp.router(
      routerConfig: goRouter,
      builder: (context, child) {
        // AppStartupWidget wraps the router child
        return AppStartupWidget(
          onLoaded: (_) => child!, // Pass router child through
        );
      },
    );
  }
}

// AppStartupWidget (app_startup_widget.dart)
class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({required this.onLoaded});
  final WidgetBuilder onLoaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStartupState = ref.watch(appStartupProvider);

    return appStartupState.when(
      loading: () => AppStartupLoadingWidget(),
      error: (e, st) => AppStartupErrorWidget(...),
      data: (_) => onLoaded(context), // Return router child
    );
  }
}
```

**Key Changes:**
1. **Remove AppStartupWidget from GoRouter routes** - It should NOT be a route anymore
2. **Add MaterialApp.builder to RootAppWidget** - Wrap router child with AppStartupWidget
3. **Use onLoaded callback pattern** - AppStartupWidget returns router's child on success
4. **Navigation happens via GoRouter** - AppStartupWidget no longer calls context.go()

**Benefits:**
- ✅ Deep links work immediately (GoRouter processes them)
- ✅ AppStartupWidget manages loading/error states
- ✅ OAuth redirects can be intercepted by router
- ✅ Follows Andrea's production-tested pattern

**References:**
- Andrea's docs: `/docs/technical/andrea/andrea_initialization.txt` (lines 395-465)
- Key quote: "MaterialApp.builder allows us to wrap the router's child widget with the AppStartupWidget without interfering with the routing logic"

**Implementation Steps:**
1. Update `AppStartupWidget` to use `onLoaded` callback
2. Remove `_handleNavigation()` method from `AppStartupWidget`
3. Update `RootAppWidget` to use `MaterialApp.builder`
4. Remove `/` route from `app_router.dart` (AppStartupWidget no longer a route)
5. Test that deep links still work during app initialization

---

#### 1. Auth State Change Listener (BLOCKER)
**Status:** ⏳ Not started
**Priority:** 🔴 CRITICAL
**File:** `/lib/features/app_startup/application/app_startup_service.dart`

**Why Critical:** OAuth redirects won't update app state or navigate users without this.

**What to Add:**
- Listen to `supabase.auth.onAuthStateChange`
- Detect when OAuth provider signs in
- Call `OAuthService.handleOAuthCallback()`
- Navigate to main app after successful linking

**Code Needed:**
```dart
void _setupAuthStateListener() {
  _supabase.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    final session = data.session;

    if (event == AuthChangeEvent.signedIn && session != null) {
      final user = session.user;

      // Check if OAuth sign-in (not anonymous)
      if (user.appMetadata['provider'] != 'anonymous') {
        final provider = user.appMetadata['provider'] as String?;

        // Update local profile
        ref.read(oAuthServiceProvider.notifier).handleOAuthCallback(
          userId: user.id,
          provider: provider ?? 'unknown',
        );

        // Navigate to main
        ref.read(goRouterProvider).go('/main');
      }
    }
  });
}
```

#### 2. iOS Deep Linking Configuration
**Status:** ⏳ Not started
**Priority:** 🔴 CRITICAL
**File:** `ios/Runner/Info.plist`

**Why Critical:** Required for OAuth redirects to return to app after web authentication.

**Details:** When user completes OAuth in browser (Apple/Google Sign-In), Supabase redirects to `com.milkman.mealvanaendurance://auth-callback`. iOS needs to know this URL scheme belongs to our app.

**What to Add:**
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

#### 3. Android Deep Linking Configuration
**Status:** ⏳ Not started
**Priority:** 🔴 CRITICAL
**File:** `android/app/src/main/AndroidManifest.xml`

**Why Critical:** Required for OAuth redirects to return to app after web authentication.

**Details:** Android needs to register the URL scheme via intent filters so the OS knows to open our app when receiving `com.milkman.mealvanaendurance://auth-callback` from browser.

**What to Add:** (inside `<activity>` tag for MainActivity)
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="com.milkman.mealvanaendurance" />
</intent-filter>
```

### Nice-to-Have (Can Defer) 🟡

#### 4. Settings Screen Updates
**Status:** ⏳ Not started
**Priority:** 🟡 MEDIUM
**File:** `/lib/features/settings/presentation/screens/settings_screen.dart`

**Why Not Critical:** Users can test OAuth without this. Just adds convenience.

**What to Add:**
- Account section showing auth status
- "Create Account" button for anonymous users
- "Sign Out" button for authenticated users

### Testing (After Configuration) 🔵

5. ⏳ Test Apple Sign-In flow (browser-based)
6. ⏳ Test Google Sign-In flow (browser-based)
7. ⏳ Test Email signup flow
8. ⏳ Verify data preservation after linking

---

## 📋 Recommended Next Steps

### Step 0: Refactor App Initialization Pattern (1 hour) ⚠️ DO THIS FIRST
**Priority:** BLOCKING - Required before auth listener will work

**Why First:** The current architecture (AppStartupWidget as a route) doesn't support OAuth deep links. Andrea's pattern (MaterialApp.builder) is required.

**Files to Update:**
1. `/lib/shared/widgets/root_app_widget.dart` - Add MaterialApp.builder
2. `/lib/features/app_startup/presentation/widgets/app_startup_widget.dart` - Add onLoaded callback
3. `/lib/shared/core/app_router.dart` - Remove `/` route

**Detailed Steps:**

**1. Update AppStartupWidget to use onLoaded callback:**
```dart
// app_startup_widget.dart
class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({super.key, required this.onLoaded});
  final WidgetBuilder onLoaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStartupState = ref.watch(appStartupProvider);

    return appStartupState.when(
      loading: () => const AppStartupLoadingWidget(),
      error: (e, st) => AppStartupErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(appStartupProvider),
      ),
      data: (_) => onLoaded(context), // Return router child
    );
  }
}
```

**2. Update RootAppWidget to use MaterialApp.builder:**
```dart
// root_app_widget.dart
class RootAppWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeAsync = ref.watch(kyleThemeModeProvider);

    return ScreenUtilInit(
      builder: (context, child) {
        return themeModeAsync.when(
          data: (themeMode) {
            return MaterialApp.router(
              routerConfig: AppRouter.router,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              // CRITICAL: Wrap router child with AppStartupWidget
              builder: (context, child) {
                return AppStartupWidget(
                  onLoaded: (_) => child!,
                );
              },
            );
          },
          // ... loading/error states
        );
      },
    );
  }
}
```

**3. Update app_router.dart - Remove AppStartupWidget route:**
```dart
// Remove this route:
// GoRoute(
//   path: '/',
//   builder: (context, state) => const AppStartupWidget(),
// ),

// Update initialLocation:
static final router = GoRouter(
  initialLocation: '/welcome', // or determine from AppStartupData
  routes: [...],
);
```

**4. Update AppStartupProvider to return navigation target:**
```dart
// app_startup_service.dart
class AppStartupData {
  final UserProfile? user;
  final bool hasCompletedOnboarding;
  final String? activityIdNeedingFeedback;

  // Add method to determine initial route
  String get initialRoute {
    if (user == null) return '/welcome';
    if (!hasCompletedOnboarding) return '/onboarding/food-preferences';
    if (activityIdNeedingFeedback != null) {
      return '/plan-how-well/$activityIdNeedingFeedback';
    }
    return '/main';
  }
}
```

**5. Update GoRouter to use redirect for initial navigation:**
```dart
static final router = GoRouter(
  redirect: (context, state) {
    // Check if this is initial load
    if (state.matchedLocation == '/') {
      final container = ProviderScope.containerOf(context);
      final startupData = container.read(appStartupProvider).valueOrNull;
      return startupData?.initialRoute ?? '/welcome';
    }
    return null; // No redirect needed
  },
  routes: [...],
);
```

**Why This Matters for OAuth:**
- OAuth redirects come as deep links: `com.milkman.mealvanaendurance://auth-callback`
- GoRouter MUST be initialized BEFORE the app can handle deep links
- AppStartupWidget as a route blocks GoRouter initialization
- Andrea's pattern (MaterialApp.builder) solves this by:
  1. Initializing GoRouter immediately when runApp() is called
  2. Wrapping the router's child with AppStartupWidget
  3. Allowing deep links to work during app initialization

---

### Step 1: Implement Auth State Change Listener (30 min)
**File:** `/lib/features/app_startup/application/app_startup_service.dart`

1. Find where `AppStartupService` initializes
2. Add `_setupAuthStateListener()` method
3. Call it during initialization
4. Test that listener fires when auth state changes

### Step 2: Configure Deep Linking (15 min)
**iOS:**
1. Open `ios/Runner/Info.plist`
2. Add URL scheme configuration
3. Save and rebuild iOS app

**Android:**
1. Open `android/app/src/main/AndroidManifest.xml`
2. Find MainActivity `<activity>` tag
3. Add intent filter
4. Save and rebuild Android app

### Step 3: Configure Supabase Dashboard (20 min)
**Required before OAuth testing:**

1. **Google OAuth:**
   - Go to Supabase Dashboard → Authentication → Providers
   - Enable Google
   - Create Web Application OAuth client in Google Cloud
   - Add redirect URI: `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`
   - Copy Client ID/Secret to Supabase

2. **Apple OAuth:**
   - Enable Apple in Supabase Dashboard
   - Create Service ID in Apple Developer
   - Configure return URL: `https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/callback`
   - Create .p8 private key
   - Add key, Key ID, Team ID to Supabase

3. **Redirect URLs:**
   - Go to Authentication → URL Configuration
   - Add: `com.milkman.mealvanaendurance://auth-callback`

### Step 4: Test OAuth Flows (1 hour)
1. Test Apple Sign-In on iOS device/simulator
2. Test Google Sign-In on iOS/Android
3. Test Email signup flow
4. Verify data persists after each linking

### Step 5: Update Settings Screen (Optional - 1 hour)
Can be done later - not blocking OAuth functionality.

---

## 🎯 Critical Blocker Summary

**Cannot test OAuth until these 4 are done:**
0. **Refactor app initialization to Andrea's pattern** (MUST BE FIRST) - 1 hour
1. Auth state change listener in AppStartupService - 30 min
2. iOS deep linking in Info.plist - 10 min
3. Android deep linking in AndroidManifest.xml - 10 min

**Estimated Time:** 2 hours total
**Then:** OAuth testing can begin

**Critical Order:**
1. FIRST: Refactor to Andrea's pattern (deep links won't work without this)
2. THEN: Add auth state listener (OAuth callback handler)
3. THEN: Configure platform deep linking (iOS/Android)
4. FINALLY: Test OAuth flows

---

## 📊 Overall Assessment

**Backend:** ✅ 100% complete (3/3)
**Frontend UI:** ✅ 100% complete (6/6)
**Architecture:** ⏳ 0% complete (0/1) - Refactor to Andrea's pattern
**Platform Config:** ⏳ 0% complete (0/3)
**Testing:** ⏳ 0% complete (0/4)

**Next Milestone:** Refactor app initialization to Andrea's pattern, then complete platform configuration.

**Recommendation:**
1. **FIRST**: Refactor to Andrea's MaterialApp.builder pattern (1 hour) - BLOCKING
2. **THEN**: Implement auth state listener + deep linking config (1 hour)
3. **TOTAL**: ~2 hours to unblock OAuth testing

**Why Architecture Refactor is Critical:**
The current approach (AppStartupWidget as a GoRouter route) fundamentally doesn't support OAuth deep links because:
- GoRouter can't process deep links until after AppStartupWidget completes
- OAuth redirects arrive as deep links during app initialization
- Andrea's pattern (MaterialApp.builder) solves this by initializing GoRouter BEFORE AppStartupWidget runs
