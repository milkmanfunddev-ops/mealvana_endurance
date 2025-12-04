# Current Architecture Analysis

> **Last Updated**: December 2024
> **Status**: Production (release/v1)

## Table of Contents

1. [App Startup Flow Overview](#app-startup-flow-overview)
2. [Main Entry Point](#main-entry-point)
3. [Root App Widget](#root-app-widget)
4. [App Startup Widget](#app-startup-widget)
5. [App Startup Provider](#app-startup-provider)
6. [App Startup Service](#app-startup-service)
7. [Navigation Logic](#navigation-logic)
8. [Database Initialization](#database-initialization)
9. [Post-Auth Flow](#post-auth-flow)
10. [Performance Metrics](#performance-metrics)

---

## App Startup Flow Overview

The app follows **Andrea Bizzotto's robust initialization pattern** with a sophisticated startup flow that handles database initialization, authentication, content loading, and intelligent navigation based on user state.

### Visual Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          APP LAUNCH                             │
│                     (main.dart runApp)                          │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│                   NON-RECOVERABLE INIT                          │
│  • SentryFlutter.init() - Error tracking                        │
│  • Supabase.initialize() - Backend connection                   │
│  • AppConfig.fromEnv() - Load configuration                     │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│                     WIDGET TREE BUILD                           │
│  SentryWidget → ProviderScope → RootAppWidget                   │
│  MaterialApp.router(builder: AppStartupWidget)                  │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│              APP STARTUP PROVIDER (PARALLEL)                    │
│  ┌────────────────┬─────────────────┬─────────────────┐        │
│  │ initDatabase   │ initSupaAuth    │ initAnalytics   │        │
│  │ (~200ms)       │ (~150ms)        │ (~100ms)        │        │
│  └────────────────┴─────────────────┴─────────────────┘        │
│                       (~500ms total)                            │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│                   CHECK USER SESSION                            │
│  • getCurrentUserProfile() from Drift DB                        │
│  • hasCompletedOnboarding flag                                  │
│  • checkForPendingFeedback()                                    │
│                                                                 │
│  Background (Fire-and-forget):                                  │
│  • syncAllAppData() - Reference data sync                       │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│                   NAVIGATION DECISION                           │
│                                                                 │
│  user == null?                                                  │
│    → /welcome (Onboarding start)                                │
│                                                                 │
│  !hasCompletedOnboarding?                                       │
│    → /onboarding/food-preferences (Resume onboarding)           │
│                                                                 │
│  activityIdNeedingFeedback?                                     │
│    → /plan-how-well/:id (Rate completed activity)               │
│                                                                 │
│  else:                                                          │
│    → /main (Main app interface)                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Main Entry Point

**File**: `lib/main.dart`

### Initialization Order

```dart
1. SentryWidgetsFlutterBinding.ensureInitialized()
2. AppConfig.loadDevModeOverride() - Load environment preference
3. dotenv.load() - Load .env.dev.local or .env.prod.local
4. AppConfig.fromEnv() - Parse configuration
5. SentryFlutter.init() - Initialize error tracking
6. Supabase.initialize() - Initialize backend (NON-RECOVERABLE)
7. runApp() - Launch Flutter app
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Sentry initialization BEFORE app | Captures all errors including startup failures |
| Supabase initialization in main() | Non-recoverable - if this fails, app cannot proceed |
| Drift database initialization DEFERRED | Happens later in `appStartupProvider` (recoverable) |
| Global navigator key | Required for Sentry feedback widget screenshot capture |

### Widget Hierarchy

```
SentryWidget
  └─ ProviderScope (Riverpod)
       └─ RootAppWidget (MaterialApp.router)
```

### Code Structure

```dart
void main() async {
  // Binding initialization
  SentryWidgetsFlutterBinding.ensureInitialized();

  // Environment configuration
  await AppConfig.loadDevModeOverride();
  await dotenv.load(fileName: AppConfig.envFileName);
  final config = AppConfig.fromEnv();

  // Error tracking (captures everything after this point)
  await SentryFlutter.init(
    (options) {
      options.dsn = config.sentryDsn;
      options.environment = config.environment;
      // ... other options
    },
  );

  // Backend initialization (NON-RECOVERABLE)
  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
  );

  // Launch app
  runApp(
    SentryWidget(
      child: ProviderScope(
        child: RootAppWidget(),
      ),
    ),
  );
}
```

---

## Root App Widget

**File**: `lib/shared/widgets/root_app_widget.dart`

### Purpose

Creates the MaterialApp.router with **deep link support during initialization**.

### Architecture Pattern (Andrea Bizzotto)

```dart
MaterialApp.router(
  routerConfig: GoRouter,
  builder: (context, child) => AppStartupWidget(
    onLoaded: (_) => child!, // Pass router child back when ready
  )
)
```

### Key Innovation

- **GoRouter is initialized IMMEDIATELY** - deep links work during startup
- **AppStartupWidget wraps the router child** - shows loading/error states
- **Critical for OAuth redirects** - Handles `com.milkman.mealvanaendurance://auth-callback`

### Additional Features

| Feature | Implementation |
|---------|---------------|
| Kyle's Design System | Dual theme support (light/dark mode) |
| ScreenUtil | Responsive sizing based on iPhone 14 Pro (393x852) |
| Wiredash | Integrated feedback widget with theme matching |

### Code Structure

```dart
class RootAppWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(goRouterProvider);

    return ScreenUtilInit(
      designSize: const Size(393, 852), // iPhone 14 Pro
      builder: (context, child) {
        return MaterialApp.router(
          routerConfig: goRouter,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          builder: (context, child) {
            // AppStartupWidget wraps the router child
            return AppStartupWidget(
              onLoaded: (context) => child!,
            );
          },
        );
      },
    );
  }
}
```

---

## App Startup Widget

**File**: `lib/features/app_startup/presentation/widgets/app_startup_widget.dart`

### Purpose

Manages the **visual state** of app initialization.

### State Machine

```dart
appStartupState.when(
  loading: () => AppStartupLoadingWidget(),     // Orange spinner on blackberry background
  error: (e, st) => AppStartupErrorWidget(),    // Error screen with retry button
  data: (_) => onLoaded(context),               // Pass router child to display main UI
)
```

### Visual States

| State | Widget | User Experience |
|-------|--------|-----------------|
| Loading | `AppStartupLoadingWidget` | Orange spinner on blackberry background |
| Error | `AppStartupErrorWidget` | Error message with retry button |
| Success | `onLoaded(context)` | Main app UI displayed |

### Error Recovery

- **Retry mechanism**: `ref.invalidate(appStartupProvider)` re-runs initialization
- **User-friendly errors**: Encourages checking internet connection
- **Non-blocking**: App continues with cached data if possible

### Code Structure

```dart
class AppStartupWidget extends ConsumerWidget {
  final WidgetBuilder onLoaded;

  const AppStartupWidget({required this.onLoaded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStartupState = ref.watch(appStartupProvider);

    return appStartupState.when(
      loading: () => const AppStartupLoadingWidget(),
      error: (e, st) => AppStartupErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(appStartupProvider),
      ),
      data: (_) => onLoaded(context),
    );
  }
}
```

---

## App Startup Provider

**File**: `lib/features/app_startup/application/app_startup_provider.dart`

### Purpose

**Coordinates** the startup sequence and provides navigation data.

### Startup Sequence

```dart
1. Run PARALLEL initializations (fastest path):
   - initializeDatabase()
   - initializeSupabaseAuth()
   - initializeAnalytics()
   - setSentryUserContext()

2. Check user session (requires DB + Auth):
   - checkUserSession()

3. Fire-and-forget background sync:
   - syncAllAppData() (unawaited)

4. Get navigation data (local DB query):
   - getCurrentUserProfile()
   - hasCompletedOnboarding
   - checkForPendingFeedback()

5. Track completion in Sentry
```

### Return Value

```dart
class AppStartupData {
  final UserProfile? user;
  final bool hasCompletedOnboarding;
  final int? activityIdNeedingFeedback;
}
```

### Performance Optimization

| Technique | Benefit |
|-----------|---------|
| Parallel execution | Steps 1-4 run simultaneously (~500ms total) |
| Background sync | Data loading doesn't block app launch |
| Local-first | Navigation decisions use cached data |

### Code Structure

```dart
@Riverpod(keepAlive: true)
Future<AppStartupData> appStartup(AppStartupRef ref) async {
  final startupService = ref.read(appStartupServiceProvider);

  // PARALLEL initialization
  await Future.wait([
    startupService.initializeDatabase(),
    startupService.initializeSupabaseAuth(),
    startupService.initializeAnalytics(),
    startupService.setSentryUserContext(),
  ]);

  // Check user session
  await startupService.checkUserSession();

  // Fire-and-forget background sync
  unawaited(startupService.syncAllAppData());

  // Get navigation data
  final user = await startupService.getCurrentUserProfile();
  final hasCompletedOnboarding = user?.onboardingCompleted ?? false;
  final activityId = await startupService.checkForPendingFeedback();

  return AppStartupData(
    user: user,
    hasCompletedOnboarding: hasCompletedOnboarding,
    activityIdNeedingFeedback: activityId,
  );
}
```

---

## App Startup Service

**File**: `lib/features/app_startup/application/app_startup_service.dart`

### Purpose

**Executes** individual startup operations.

### Key Operations

#### A. Database Initialization (`initializeDatabase`)

```dart
// Touch the database provider - triggers Drift LazyDatabase initialization
final db = ref.read(appDatabaseProvider);
await db.select(db.userProfilesTable).get(); // Verify schema is ready
```

- **Drift migrations run automatically** (onCreate, onUpgrade, beforeOpen)
- **Non-blocking**: App continues if this fails (shows retry screen)

#### B. Supabase Anonymous Auth (`initializeSupabaseAuth`)

```dart
// Check for existing session (SDK auto-restores from secure storage)
final existingSession = _supabase.auth.currentSession;

if (existingSession == null) {
  // Create anonymous user
  await _supabase.auth.signInAnonymously();
}

// Setup auth state listener (ONCE)
setupAuthStateListener();
```

**Auth State Listener Handles**:
- Token refresh events
- Sign-out events (creates new anonymous session)
- Sign-in events (syncs remote profile, invalidates providers)

#### C. Analytics Initialization (`initializeAnalytics`)

```dart
// Get or create device ID (iOS: identifierForVendor, Android: androidId)
final deviceId = await getOrCreateDeviceId();

// Initialize RudderStack → Mixpanel pipeline
await _analytics.initialize();
await _analytics.identifyUser(deviceId);

// Track app opened with session ID
await _analytics.trackAppOpened(deviceId, sessionId);
```

#### D. Check User Session (`checkUserSession`)

```dart
// Get user from local database
final user = await database.getCurrentUserProfile();

if (user != null) {
  // Identify user in analytics with full profile
  await _analytics.identifyUser(
    user.id,
    gender: user.gender.name,
    age: user.age,
    weightPounds: user.weightPounds,
    runsWithWaterBottle: user.runsWithWaterBottle,
    gutTrainingLevel: user.gutTraining.name,
  );
}
```

#### E. Sync All Data (`syncAllAppData`)

```dart
// Fire-and-forget: Single network call to sync-all-data edge function
// Syncs: calendar, foods, carb loading foods, meal types, app content
unawaited(startupService.syncAllAppData());
```

#### F. Check Pending Feedback (`checkForPendingFeedback`)

```dart
// Check for activities that need feedback after run time has passed
// Returns activityId if found, null otherwise
final activityId = await startupService.checkForPendingFeedback();
```

---

## Navigation Logic

**File**: `lib/shared/core/app_router.dart`

### Router Configuration

```dart
GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    // Only redirect root path - allow direct navigation to specific routes
    if (state.uri.path != '/') return null;

    final appStartupData = ref.read(appStartupProvider);

    return appStartupData.maybeWhen(
      data: (data) {
        // Decision tree for initial route
        if (data.user == null) return '/welcome';
        if (!data.hasCompletedOnboarding) return '/onboarding/food-preferences';
        if (data.activityIdNeedingFeedback != null)
          return '/plan-how-well/${data.activityIdNeedingFeedback}';
        return '/main';
      },
      orElse: () => null, // Stay on root during loading/error
    );
  }
)
```

### Navigation Decision Tree

```
                    App Launch
                        |
                   [Read user data]
                        |
         ┌──────────────┼──────────────┐
         │              │              │
    No User      User Exists    User Exists
                 (incomplete)   (complete)
         │              │              │
         ↓              ↓              ↓
    /welcome    /onboarding/    /plan-how-well/:id
                food-preferences (if feedback pending)
                        |              |
                        ↓              ↓
                /auth/post-onboarding  /main
                        |
                  ┌─────┴─────┐
                  │           │
                 Skip      Sign In
                  │           │
                  └─────┬─────┘
                        ↓
                      /main
```

### User States

| State | Route | Description |
|-------|-------|-------------|
| No User | `/welcome` | Create account flow |
| User Incomplete | `/onboarding/food-preferences` | Resume onboarding |
| User Complete + Pending Feedback | `/plan-how-well/:id` | Rate completed activity |
| User Complete | `/main` | Main app interface |

---

## Database Initialization

**File**: `lib/shared/database/database_provider.dart`

### Pattern (Andrea Bizzotto)

```dart
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase(); // Immediately ready - Drift handles async internally
});
```

### Drift LazyDatabase Architecture

| Callback | When | Purpose |
|----------|------|---------|
| `onCreate` | First app install | Creates all tables |
| `onUpgrade` | Schema version increases | Runs migrations |
| `beforeOpen` | Every connection | Ensures columns exist |

### Database Schema (v1)

**27 tables** including:

| Table | Purpose |
|-------|---------|
| `user_profiles` | User biometric and preference data |
| `food_preferences` | User's liked/disliked foods |
| `activities` | Training activities with nutrition plans |
| `foods` | Reference food database |
| `user_foods` | User-created custom foods |
| `app_content` | Dynamic UI text and algorithm parameters |
| `events` | Races and competitions |
| `carb_loading_plans` | Multi-day carb loading plans |
| `carb_loading_days` | Individual days in carb loading plans |
| `feedback` | User satisfaction surveys |
| `feature_survey_responses` | Feature voting responses |
| ... | Plus 16 more tables |

---

## Post-Auth Flow

### When User Authenticates

#### During Onboarding

```
1. Welcome Screen → Create User Profile
2. User Profile Screen → Enter biometrics
3. Sport Preferences Screen → Enter sport-specific settings
4. Food Preferences Screen → Select food preferences
   ↓
   onboardingCompleted = TRUE (via Edge Function)
   ↓
5. Post-Onboarding Auth Screen
   - Apple Sign In / Google Sign In / Email / Skip
   ↓
6. Main App (/main)
```

#### Auth State Listener (Background)

```dart
if (event == AuthChangeEvent.signedIn) {
  // Invalidate identity provider immediately (allows navigation)
  ref.invalidate(userIdProvider);

  // Defer heavy operations to background (prevents race conditions)
  unawaited(_performPostAuthSync(userId));
}
```

#### Post-Auth Sync (Background)

```dart
// Run ALL network calls in PARALLEL (~500ms vs 1.5s sequential)
await Future.wait([
  userRepo.fetchAndSaveRemoteProfile(userId),
  userRepo.fetchAndCacheRemoteFoodPreferences(userId),
  userRepo.syncUserFoodsFromSupabase(userId),
]);

// Invalidate providers AFTER data loaded (clean rebuilds)
ref.invalidate(activitiesControllerProvider);
ref.invalidate(allEventsProvider);
ref.invalidate(nextUpcomingEventProvider);
ref.invalidate(settingsControllerProvider);
```

### Key Files

| File | Purpose |
|------|---------|
| `lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart` | Auth options UI |
| `lib/features/onboarding/application/onboarding_service.dart` | Onboarding flow logic |
| `lib/features/auth/application/auth_service.dart` | Auth state management |

---

## Performance Metrics

### Timing (from logs)

| Phase | Duration |
|-------|----------|
| Parallel initialization (Step 1) | ~500ms |
| - Database initialization | ~200ms |
| - Supabase Auth | ~150ms |
| - Analytics | ~100ms |
| - Sentry context | ~50ms |
| User session check (Step 2) | ~50ms |
| Navigation data query (Step 4) | ~20ms |
| **TOTAL CRITICAL PATH** | **~570ms** |

### Background Operations (non-blocking)

| Operation | Duration |
|-----------|----------|
| Data sync | ~1-2 seconds (all reference data) |
| Post-auth sync | ~500ms (parallel network calls) |

---

## Main App UI

**File**: `lib/shared/widgets/tabs_screen.dart`

### Tab Structure

```
TabsScreen (Bottom Navigation)
├─ Tab 0: ActivitiesListScreen (Primary)
│    - Activities-first interface with calendar picker
│    - Shows nutrition plans for scheduled activities
│
├─ Tab 1: FeatureSurveyScreen
│    - Feature feedback and surveys
│
└─ Tab 2: SettingsScreen
     - User profile, preferences, help, account management
```

### Floating Action Button Bar

| Button | Action |
|--------|--------|
| Calendar Icon | Toggle calendar view (if on Activities tab) OR navigate to Activities tab |
| Plus Icon | Navigate to New Activity Screen (create new nutrition plan) |
| Survey Icon | Navigate to Survey tab |
| Menu Icon | Navigate to Settings tab |

---

## Critical Design Patterns

### Andrea Bizzotto's App Initialization Pattern

#### DO ✅

| Practice | Reason |
|----------|--------|
| Initialize **non-recoverable** dependencies in `main()` | Supabase, Sentry - app can't function without these |
| Initialize **recoverable** dependencies in `appStartupProvider` | Database, Analytics - can retry if failed |
| Use `MaterialApp.builder` to wrap router with `AppStartupWidget` | Supports deep links during initialization |
| Use `AsyncNotifier` for all controllers with `@riverpod` annotation | Modern pattern with error handling |
| Access services via `ref.read()` in controllers | Proper dependency injection |

#### DON'T ❌

| Anti-Pattern | Reason |
|--------------|--------|
| Don't initialize Drift database in `main()` | Must be recoverable |
| Don't block app launch on network calls | Use background sync |
| Don't use `StateNotifier` | Deprecated - use `AsyncNotifier` |
| Don't create manual providers | Use `@riverpod` code generation |

### Offline-First Architecture

| Layer | Implementation |
|-------|----------------|
| Local Storage (Drift SQLite) | Primary source of truth for app state |
| Cloud Storage (Supabase PostgreSQL) | Backend for user authentication |
| Sync Strategy | Background sync keeps data fresh |

### Error Handling Strategy

#### Non-Recoverable Errors (main.dart)

| Error Type | Behavior |
|------------|----------|
| Supabase initialization failure | App won't launch |
| Sentry initialization failure | Log but continue |

#### Recoverable Errors (appStartupProvider)

| Error Type | Behavior |
|------------|----------|
| Database initialization failure | Show retry screen |
| Network sync failure | Continue with cached data |
| Auth session failure | Continue as anonymous user |

---

## File Reference

### Core Startup Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | Entry point, non-recoverable init |
| `lib/shared/widgets/root_app_widget.dart` | MaterialApp setup |
| `lib/features/app_startup/presentation/widgets/app_startup_widget.dart` | Startup UI states |
| `lib/features/app_startup/application/app_startup_provider.dart` | Startup orchestration |
| `lib/features/app_startup/application/app_startup_service.dart` | Startup operations |

### Navigation & Routing

| File | Purpose |
|------|---------|
| `lib/shared/core/app_router.dart` | GoRouter configuration |
| `lib/shared/widgets/tabs_screen.dart` | Main tab navigation |

### Database

| File | Purpose |
|------|---------|
| `lib/shared/database/database_provider.dart` | Drift provider |
| `lib/shared/database/app_database.dart` | Database definition |

### Onboarding

| File | Purpose |
|------|---------|
| `lib/features/onboarding/presentation/screens/food_preferences_screen.dart` | Food preferences UI |
| `lib/features/onboarding/application/onboarding_service.dart` | Onboarding logic |
| `lib/features/onboarding/presentation/providers/onboarding_controller.dart` | Onboarding state |

### Authentication

| File | Purpose |
|------|---------|
| `lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart` | Auth options UI |
| `lib/features/auth/application/auth_service.dart` | Auth state management |

### Configuration

| File | Purpose |
|------|---------|
| `lib/shared/services/app_config.dart` | Environment configuration |
