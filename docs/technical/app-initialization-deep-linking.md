# App Initialization & Deep Linking Architecture

**Last Updated:** 2025-11-18
**Status:** Implementation Required
**Priority:** CRITICAL for Phase 2 OAuth

---

## Table of Contents
1. [Overview](#overview)
2. [The Problem](#the-problem)
3. [Andrea Bizzotto's Solution](#andrea-bizzottos-solution)
4. [Implementation Guide](#implementation-guide)
5. [Why This Matters for OAuth](#why-this-matters-for-oauth)
6. [Testing Strategy](#testing-strategy)
7. [References](#references)

---

## Overview

This document explains the **critical architectural pattern** required for supporting OAuth deep links in Mealvana Endurance. We follow **Andrea Bizzotto's initialization pattern** using `MaterialApp.builder` to wrap the router's child widget.

**The Core Pattern:**
```dart
MaterialApp.router(
  routerConfig: goRouter,
  builder: (context, child) {
    return AppStartupWidget(
      onLoaded: (_) => child!, // Returns router's child
    );
  },
)
```

**Why It Matters:**
- OAuth redirects arrive as **deep links** during app initialization
- GoRouter **must be initialized immediately** to handle these deep links
- Our current pattern (AppStartupWidget as a route) **blocks deep link processing**
- Andrea's pattern solves this by wrapping the router child instead of being a route

---

## The Problem

### Current Architecture (Broken for OAuth)

**File Structure:**
- `RootAppWidget` → `MaterialApp.router` → `GoRouter`
- `GoRouter` routes `/` → `AppStartupWidget` (as a route)
- `AppStartupWidget` → Calls `context.go('/welcome')` or `context.go('/main')`

**Flow Diagram:**
```
App Launch
    ↓
runApp(RootAppWidget)
    ↓
MaterialApp.router(routerConfig: GoRouter)
    ↓
GoRouter initializes
    ↓
User lands on '/' route → AppStartupWidget rendered as a screen
    ↓
AppStartupWidget.build() runs initialization
    ↓
When complete: context.go('/welcome') or context.go('/main')
    ↓
OAuth redirect arrives: com.milkman.mealvanaendurance://auth-callback
    ↓
❌ PROBLEM: GoRouter can't handle it because AppStartupWidget is controlling navigation
```

**Why This Breaks OAuth:**

1. **AppStartupWidget is a route** at `/`, not a wrapper widget
2. **It controls navigation** using `context.go()` after initialization completes
3. **OAuth deep links arrive** during or immediately after app initialization
4. **GoRouter can't process them** because AppStartupWidget has already navigated away
5. **Result:** Deep link is ignored, user stuck, auth callback never fires

**Code Evidence:**

```dart
// Current: app_startup_widget.dart (BROKEN)
class AppStartupWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return appStartupState.when(
      data: (appStartupData) => _handleNavigation(context, appStartupData),
    );
  }

  Widget _handleNavigation(BuildContext context, AppStartupData data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ❌ This blocks deep link processing
      if (data.user == null) {
        context.go('/welcome');
      } else {
        context.go('/main');
      }
    });
    return Scaffold(...); // Placeholder
  }
}

// Current: app_router.dart (BROKEN)
static final router = GoRouter(
  initialLocation: '/',
  routes: [
    // ❌ AppStartupWidget should NOT be a route
    GoRoute(
      path: '/',
      builder: (context, state) => const AppStartupWidget(),
    ),
  ],
);
```

---

## Andrea Bizzotto's Solution

### The MaterialApp.builder Pattern

Andrea's pattern uses `MaterialApp.builder` to **wrap the router's child widget** instead of making AppStartupWidget a route.

**Key Insight from Andrea:**
> "Apps that rely on URL-based navigation typically use a MaterialApp.router with a GoRouter for routing. Unfortunately, the AppStartupWidget doesn't handle this requirement—it only manages app initialization. The solution is to introduce a top-level RootAppWidget that configures the router while still handling app startup."

### Target Architecture (Working for OAuth)

**File Structure:**
- `RootAppWidget` → `MaterialApp.router` with `builder` parameter
- `MaterialApp.builder` → Wraps router child with `AppStartupWidget`
- `AppStartupWidget` → Returns router's child via `onLoaded` callback
- `GoRouter` → Handles ALL navigation (including initial and deep links)

**Flow Diagram:**
```
App Launch
    ↓
runApp(RootAppWidget)
    ↓
MaterialApp.router(
  routerConfig: GoRouter,  ← GoRouter initializes IMMEDIATELY
  builder: (context, child) {
    return AppStartupWidget(onLoaded: (_) => child!)
  }
)
    ↓
GoRouter is READY to handle deep links
    ↓
MaterialApp.builder wraps router child with AppStartupWidget
    ↓
AppStartupWidget shows loading state
    ↓
When initialization complete: Returns child! (router's widget)
    ↓
GoRouter determines initial route via redirect logic
    ↓
OAuth redirect arrives: com.milkman.mealvanaendurance://auth-callback
    ↓
✅ SUCCESS: GoRouter processes deep link immediately
    ↓
Auth callback handler triggered
    ↓
User authenticated
```

---

## Implementation Guide

### File 1: AppStartupWidget (Wrapper Widget)

**Location:** `/lib/features/app_startup/presentation/widgets/app_startup_widget.dart`

**Changes:**
1. Add `onLoaded` callback parameter
2. Remove `_handleNavigation()` method
3. Return `onLoaded(context)` on success instead of navigating

**Before:**
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
      } else {
        context.go('/main');
      }
    });
    return Scaffold(...);
  }
}
```

**After:**
```dart
class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({
    super.key,
    required this.onLoaded, // NEW: Callback to return router child
  });

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

      // NEW: Return router child instead of navigating
      data: (_) => onLoaded(context),
    );
  }

  // ❌ REMOVED: _handleNavigation() method
}
```

**Key Changes:**
- ✅ Add required `onLoaded` callback parameter
- ✅ Call `onLoaded(context)` in success state
- ❌ Remove `_handleNavigation()` method
- ❌ Remove ALL `context.go()` calls

---

### File 2: RootAppWidget (Router Configuration)

**Location:** `/lib/shared/widgets/root_app_widget.dart`

**Changes:**
1. Add `builder` parameter to `MaterialApp.router`
2. Wrap `child` with `AppStartupWidget`
3. Pass `child` through via `onLoaded` callback

**Before:**
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
              // ❌ MISSING: builder parameter
            );
          },
          loading: () => MaterialApp.router(...),
          error: (error, stack) => MaterialApp.router(...),
        );
      },
    );
  }
}
```

**After:**
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
              // ✅ NEW: Wrap router child with AppStartupWidget
              builder: (context, child) {
                return AppStartupWidget(
                  onLoaded: (_) => child!,
                );
              },
            );
          },

          // Apply to loading state too
          loading: () {
            return MaterialApp.router(
              title: 'Mealvana Endurance',
              theme: AppTheme.darkTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.dark,
              routerConfig: AppRouter.router,
              builder: (context, child) {
                return AppStartupWidget(
                  onLoaded: (_) => child!,
                );
              },
            );
          },

          // Apply to error state too
          error: (error, stack) {
            return MaterialApp.router(
              title: 'Mealvana Endurance',
              theme: AppTheme.darkTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.dark,
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
- ✅ Add `builder` parameter to ALL MaterialApp.router instances
- ✅ Wrap `child` with `AppStartupWidget`
- ✅ Use `onLoaded: (_) => child!` to return router's child
- ✅ Apply pattern to all theme states (data, loading, error)

---

### File 3: AppRouter (Navigation Logic)

**Location:** `/lib/shared/core/app_router.dart`

**Changes:**
1. Remove AppStartupWidget route at `/`
2. Add `redirect` callback for initial navigation
3. Read `appStartupProvider` to determine initial route

**Before:**
```dart
class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      // ❌ AppStartupWidget should NOT be a route
      GoRoute(
        path: '/',
        builder: (context, state) => const AppStartupWidget(),
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

**After:**
```dart
class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',

    // ✅ NEW: Handle initial navigation via redirect
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

      // No redirect for other paths (including deep links)
      return null;
    },

    routes: [
      // ❌ REMOVED: AppStartupWidget route
      // GoRoute(path: '/', builder: (context, state) => const AppStartupWidget()),

      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),

      // ... other routes including OAuth callback
      GoRoute(
        path: '/auth-callback',
        builder: (context, state) => const AuthCallbackScreen(),
      ),
    ],
  );
}
```

**Key Changes:**
- ❌ Remove AppStartupWidget route at `/`
- ✅ Add `redirect` callback for initial navigation
- ✅ Read `appStartupProvider.valueOrNull` to check app state
- ✅ Return appropriate initial route based on user state
- ✅ Return `null` for non-root paths (allows deep links to work)

---

## Why This Matters for OAuth

### OAuth Flow with Deep Links

**Step-by-Step Process:**

1. **User taps "Continue with Google"**
   - App calls `supabase.auth.signInWithOAuth(OAuthProvider.google)`
   - Opens browser with Google Sign-In page

2. **User signs in on web**
   - Google authenticates user
   - Redirects to Supabase: `https://supabase.co/auth/callback`

3. **Supabase processes OAuth**
   - Creates/links user account
   - Redirects to app: `com.milkman.mealvanaendurance://auth-callback`

4. **OS delivers deep link to app**
   - iOS/Android opens app with deep link URI
   - **CRITICAL:** App must be ready to handle this immediately

5. **GoRouter processes deep link**
   - Matches `/auth-callback` route
   - Renders `AuthCallbackScreen` (or triggers auth state listener)

6. **Auth callback completes**
   - Updates local user profile
   - Navigates to main app
   - User is now authenticated

**With Old Pattern (BROKEN):**
```
Deep link arrives → GoRouter tries to process
    ↓
❌ AppStartupWidget is a route controlling navigation
    ↓
❌ Deep link ignored or causes navigation conflict
    ↓
❌ User stuck, auth never completes
```

**With Andrea's Pattern (WORKING):**
```
Deep link arrives → GoRouter processes immediately
    ↓
✅ AppStartupWidget is just a wrapper (not blocking)
    ↓
✅ GoRouter routes to /auth-callback
    ↓
✅ Auth callback triggers
    ↓
✅ User authenticated successfully
```

---

## Testing Strategy

### 1. Verify App Launch Works

```bash
flutter run
```

**Expected:**
- App shows loading screen (AppStartupLoadingWidget)
- Transitions to welcome/onboarding/main based on user state
- No navigation errors in logs

**Check logs:**
```bash
flutter logs | grep -i "navigation\|route"
```

---

### 2. Test Deep Link Processing

**iOS Simulator:**
```bash
xcrun simctl openurl booted "com.milkman.mealvanaendurance://test"
```

**Android Emulator:**
```bash
adb shell am start -a android.intent.action.VIEW \
  -d "com.milkman.mealvanaendurance://test" \
  com.milkman.mealvanaendurance
```

**Expected:**
- Deep link is processed
- No "route not found" errors
- App navigates to correct screen (or shows placeholder for test link)

---

### 3. Test OAuth Deep Link (After Platform Config)

**Simulate OAuth callback:**
```bash
# iOS
xcrun simctl openurl booted "com.milkman.mealvanaendurance://auth-callback"

# Android
adb shell am start -a android.intent.action.VIEW \
  -d "com.milkman.mealvanaendurance://auth-callback" \
  com.milkman.mealvanaendurance
```

**Expected:**
- Auth callback handler is triggered
- Auth state listener detects sign-in
- User profile is updated
- App navigates to main screen

---

### 4. Test Loading State During Deep Link

**Scenario:** Deep link arrives while app is still initializing

**Test:**
1. Cold start the app
2. Immediately send deep link (within 1 second)
3. Verify deep link is queued and processed after initialization completes

**Expected:**
- AppStartupWidget shows loading
- Deep link is queued by GoRouter
- When initialization completes, deep link is processed
- App navigates to deep link destination

---

## References

### Andrea Bizzotto's Documentation

**Primary Source:** `/docs/technical/andrea/andrea_initialization.txt`

**Key Sections:**
- Lines 395-465: "Important Note About URL Navigation and Deep Links"
- Lines 421-429: `MaterialApp.builder` pattern code example
- Lines 431-440: How it works explanation

**Key Quotes:**

> "Unfortunately, the AppStartupWidget doesn't handle this requirement—it only manages app initialization."

> "The MaterialApp.builder is key to this setup. It allows us to wrap the router's child widget with the AppStartupWidget without interfering with the routing logic."

> "This ensures that: The app startup logic runs before the main app UI loads. Deep links and URL-based navigation are processed correctly from the start."

---

### Flutter/GoRouter Documentation

**MaterialApp.builder:**
- https://api.flutter.dev/flutter/material/MaterialApp/builder.html
- Intercepts all routes and wraps the widget
- Perfect for adding global wrappers (loading states, authentication checks)

**GoRouter Deep Linking:**
- https://pub.dev/documentation/go_router/latest/topics/Deep%20linking-topic.html
- Platform-specific configuration (iOS Info.plist, Android AndroidManifest.xml)
- Handling deep links in GoRouter routes

**GoRouter Redirect:**
- https://pub.dev/documentation/go_router/latest/topics/Redirection-topic.html
- Global redirect logic for initial navigation
- Checking auth state and redirecting appropriately

---

## Summary

**The Pattern:**
```dart
// RootAppWidget
MaterialApp.router(
  routerConfig: goRouter,
  builder: (context, child) {
    return AppStartupWidget(
      onLoaded: (_) => child!,
    );
  },
)
```

**Key Principles:**
1. **GoRouter initializes immediately** when `runApp()` is called
2. **MaterialApp.builder wraps** the router's child with AppStartupWidget
3. **AppStartupWidget is a wrapper**, not a route
4. **GoRouter controls ALL navigation**, including initial and deep links
5. **Deep links work during initialization** because GoRouter is ready

**Benefits:**
- ✅ Supports OAuth deep links during app startup
- ✅ Follows Andrea Bizzotto's production-tested pattern
- ✅ Clean separation of concerns (startup vs navigation)
- ✅ Handles all edge cases (loading, errors, retries)
- ✅ Production-ready and maintainable

**Status:** Implementation required before Phase 2 OAuth can be tested

---

**Document Owner:** Development Team
**Last Reviewed:** 2025-11-18
**Next Review:** After implementation (when OAuth testing begins)
