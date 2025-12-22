# Flutter Web Deployment - Technical Blockers

## Overview

This document provides detailed technical analysis of the critical blockers preventing web deployment, with concrete code examples showing current implementation, why it fails on web, and recommended solutions.

**📌 UPDATE (2025-12-15):** Blocker 1 has been **RESOLVED** via architectural decision to proceed with **Option C: Hybrid IndexedDB Cache + Supabase**. See [cache-strategy.md](./cache-strategy.md) for implementation details.

---

## Blocker 1: Drift SQLite Database (✅ RESOLVED)

### Priority: ~~P0 (Must Fix)~~ → P1 (Abstraction Still Beneficial)
### Impact: All Features
### Effort: 4 weeks (via IndexedDB Cache + Supabase)
### Status: ✅ **RESOLVED** - Proceeding with Option C (Hybrid Cache)

**Resolution:** Instead of migrating Drift to drift_web (Option B) or creating Supabase-only repositories (Option A), we're implementing **Option C: Three-Tier Hybrid Caching** which provides 10x better performance than pure Supabase while eliminating 80% of sync complexity compared to drift_web.

### Current Implementation

**File:** `lib/shared/database/app_database.dart`

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';  // ❌ Not web-compatible

part 'app_database.g.dart';

@DriftDatabase(tables: [
  UsersTable,
  FoodPreferencesTable,
  NutritionPlans,
  MacroTargetsTable,
  FeedbackTable,
  FoodsTable,
  CategoriesTable,
  FoodCategoriesTable,
  BrandsTable,
  AppContentTable,
  EdgeFunctions,
  WorkoutNotes,
  UserFoods,
  UserFoodCategories,
  UserHiddenFoods,
  CarbLoadingSimplePlans,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    // ❌ NativeDatabase uses FFI (Foreign Function Interface)
    // ❌ FFI not available on web platform
    return NativeDatabase.memory();
  }
}
```

### Why This Fails on Web

1. **FFI Not Supported:** `NativeDatabase` uses Dart's FFI to call native C code (SQLite library). Web platform has no FFI support.

2. **Platform-Specific Binary:** SQLite is a native C library compiled for specific platforms (iOS/Android). Web has no access to native binaries.

3. **File System Access:** `NativeDatabase` expects file system access for SQLite database files. Web has limited file system access (only IndexedDB, LocalStorage).

4. **Pervasive Usage:** All 16 tables are used extensively across every feature with no abstraction layer.

### Scope of Changes Required

**Repository Files Using Drift (41 files):**

```
lib/features/auth/data/
├── user_profile_repository.dart
├── drift_user_profile_repository.dart

lib/features/nutrition_plan/data/
├── nutrition_plan_repository.dart
├── drift_nutrition_plan_repository.dart
├── macro_targets_repository.dart

lib/features/food_preferences/data/
├── food_preferences_repository.dart
├── drift_food_preferences_repository.dart

lib/features/content/data/
├── content_repository.dart
├── drift_content_repository.dart

lib/features/feedback/data/
├── feedback_repository.dart
├── drift_feedback_repository.dart

lib/features/foods/data/
├── foods_repository.dart
├── categories_repository.dart
├── product_types_repository.dart
├── user_foods_repository.dart
├── user_hidden_foods_repository.dart

lib/features/workout_notes/data/
├── workout_notes_repository.dart

lib/features/carb_loading/data/
├── carb_loading_repository.dart

lib/shared/database/
├── app_database.dart  # Core database class
├── tables/            # 16 table definitions
    ├── users_table.dart
    ├── foods_table.dart
    ├── nutrition_plans_table.dart
    ├── food_preferences_table.dart
    ├── categories_table.dart
    ├── product_types_table.dart
    ├── food_categories_table.dart
    ├── user_foods_table.dart
    ├── user_food_categories_table.dart
    ├── user_hidden_foods_table.dart
    ├── macro_targets_table.dart
    ├── app_content_table.dart
    ├── edge_functions_table.dart
    ├── feedback_table.dart
    ├── workout_notes_table.dart
    └── carb_loading_simple_plans_table.dart
```

**Database Operations Count:**
- Read operations: 600+ locations
- Write operations: 150+ locations
- Stream subscriptions: 80+ locations
- Join queries: 40+ locations

### Solution Options

#### Option A: Supabase-Only (Recommended for MVP)

**Pros:**
- ✅ Simplest to implement
- ✅ No IndexedDB complexity
- ✅ Leverages existing Supabase backend
- ✅ Real-time updates built-in

**Cons:**
- ❌ No offline support
- ❌ Network latency for all queries
- ❌ Loss of offline-first architecture

**Implementation Example:**

```dart
// lib/features/nutrition_plan/data/supabase_nutrition_plan_repository.dart
class SupabaseNutritionPlanRepository implements NutritionPlanRepository {
  SupabaseNutritionPlanRepository(this._supabase);
  final SupabaseClient _supabase;

  @override
  Future<List<NutritionPlan>> getPlans(String deviceId) async {
    try {
      final response = await _supabase
          .from('nutrition_plans')
          .select()
          .eq('device_id', deviceId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => NutritionPlan.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw RepositoryException('Failed to fetch plans: ${e.message}');
    }
  }

  @override
  Future<void> savePlan(NutritionPlan plan) async {
    try {
      await _supabase
          .from('nutrition_plans')
          .upsert(plan.toJson());
    } on PostgrestException catch (e) {
      throw RepositoryException('Failed to save plan: ${e.message}');
    }
  }

  @override
  Stream<List<NutritionPlan>> watchPlans(String deviceId) {
    return _supabase
        .from('nutrition_plans')
        .stream(primaryKey: ['id'])
        .eq('device_id', deviceId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((json) => NutritionPlan.fromJson(json))
            .toList());
  }
}
```

**Platform-Conditional Provider:**

```dart
// lib/shared/providers/repository_providers.dart
import 'package:flutter/foundation.dart' show kIsWeb;

@riverpod
NutritionPlanRepository nutritionPlanRepository(
    NutritionPlanRepositoryRef ref) {
  if (kIsWeb) {
    final supabase = ref.watch(supabaseProvider);
    return SupabaseNutritionPlanRepository(supabase);
  } else {
    final database = ref.watch(appDatabaseProvider);
    return DriftNutritionPlanRepository(database);
  }
}
```

**Estimated Effort:** 3-4 weeks for all 16 repositories

#### Option B: Drift WASM with IndexedDB

**Pros:**
- ✅ Maintains offline-first architecture
- ✅ Minimal code changes
- ✅ Type-safe queries preserved

**Cons:**
- ❌ Complex WASM setup
- ❌ Large bundle size (+3-4 MB)
- ❌ Browser-specific IndexedDB quirks
- ❌ Difficult debugging

**Implementation Example:**

```dart
// lib/shared/database/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

@DriftDatabase(tables: [/* ... */])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    if (kIsWeb) {
      return LazyDatabase(() async {
        final db = await WasmDatabase.open(
          databaseName: 'mealvana_db',
          sqlite3Uri: Uri.parse('sqlite3.wasm'),
          driftWorkerUri: Uri.parse('drift_worker.js'),
        );

        if (db.missingFeatures.isNotEmpty) {
          print('Missing WASM features: ${db.missingFeatures}');
        }

        return db.resolvedExecutor;
      });
    } else {
      return NativeDatabase.memory();
    }
  }
}
```

**Required Web Assets:**

```
web/
├── sqlite3.wasm        # SQLite compiled to WebAssembly (2.5 MB)
├── drift_worker.js     # Web Worker for database operations
└── index.html          # Must reference workers
```

**Web Configuration:**

```html
<!-- web/index.html -->
<script>
  // Configure WASM paths
  window.dartDriftWorkerPath = 'drift_worker.js';
  window.dartSqlite3WasmPath = 'sqlite3.wasm';
</script>
```

**Estimated Effort:** 4-6 weeks (including WASM debugging)

#### Option C: Database Abstraction Layer

**Pros:**
- ✅ Maximum flexibility
- ✅ Platform-optimized implementations
- ✅ Future-proof for other platforms

**Cons:**
- ❌ Most development time
- ❌ Complex to maintain
- ❌ Must duplicate logic

**Implementation Example:**

```dart
// lib/shared/data/database_provider.dart
abstract class DatabaseProvider {
  // CRUD operations
  Future<Map<String, dynamic>?> getById(String table, String id);
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
  });
  Future<void> insert(String table, Map<String, dynamic> data);
  Future<void> update(String table, String id, Map<String, dynamic> data);
  Future<void> delete(String table, String id);

  // Streaming
  Stream<List<Map<String, dynamic>>> watch(String table);
}

// Mobile implementation
class DriftDatabaseProvider implements DatabaseProvider {
  DriftDatabaseProvider(this._database);
  final AppDatabase _database;

  @override
  Future<Map<String, dynamic>?> getById(String table, String id) async {
    // Use Drift queries
    // ...
  }
}

// Web implementation
class SupabaseDatabaseProvider implements DatabaseProvider {
  SupabaseDatabaseProvider(this._supabase);
  final SupabaseClient _supabase;

  @override
  Future<Map<String, dynamic>?> getById(String table, String id) async {
    return await _supabase
        .from(table)
        .select()
        .eq('id', id)
        .maybeSingle();
  }
}
```

**Estimated Effort:** 8-12 weeks

### ✅ SELECTED APPROACH: Option C (Hybrid IndexedDB Cache + Supabase)

**Decision Rationale:**

1. **10x Faster Performance** - Cached reads <10ms vs 500ms+ for pure Supabase
2. **80% Less Complexity** - ~400 lines vs 2,600+ lines of sync code
3. **Web-Appropriate Architecture** - Stale-while-revalidate is standard web pattern
4. **Small Bundle Size** - No SQLite WASM (+1MB saved vs drift_web)
5. **Graceful Degradation** - Read-only offline vs no offline (Option A)

**Implementation Plan:**
- **Week 1:** Core cache layer (WebCacheService, foods, content, user profile)
- **Week 2:** Smart invalidation (stale-while-revalidate, background sync)
- **Week 3:** Optimistic writes (write queue, retry logic)
- **Week 4:** Service worker & PWA (Workbox, offline fallback)

**Why NOT Option B (drift_web):**
- ❌ drift_web is **2-5x slower** than native Drift
- ❌ Adds **+3-4MB** to bundle size (SQLite WASM)
- ❌ Maintains **2,000+ lines** of complex sync logic
- ❌ Overkill for web (90% reads, small dataset, AI requires internet anyway)

**Documentation:**
- 📋 [Complete Implementation Guide](./roadmap.md) - 4-week detailed plan
- 📊 [Caching Strategy](./cache-strategy.md) - Three-tier architecture with Vercel integration
- 🏗️ [Main Overview](./README.md) - Updated with Option C decision

---

## Blocker 2: Platform-Specific Code (CRITICAL)

### Priority: P0 (Must Fix)
### Impact: App Initialization, Device Info
### Effort: 3-5 days

### Current Implementation

**File:** `lib/shared/providers/device_info_provider.dart`

```dart
import 'dart:io';  // ❌ Not available on web
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_info_provider.g.dart';

@riverpod
String deviceInfo(DeviceInfoRef ref) {
  // ❌ Platform class not available on web
  if (Platform.isIOS) {
    return 'iOS';
  } else if (Platform.isAndroid) {
    return 'Android';
  }
  return 'Unknown';
}

@riverpod
String deviceId(DeviceIdRef ref) {
  // ❌ Would use platform-specific device ID APIs
  if (Platform.isIOS) {
    // Get iOS device ID
    return 'ios-device-id';
  } else if (Platform.isAndroid) {
    // Get Android device ID
    return 'android-device-id';
  }
  return 'unknown-device-id';
}
```

### Why This Fails on Web

1. **dart:io Not Available:** Web platform has no `dart:io` library (no file system, no processes, no Platform class).

2. **Platform Checks:** `Platform.isIOS`, `Platform.isAndroid` don't exist on web.

3. **Device IDs:** Web has no equivalent to mobile device IDs (uses browser fingerprinting or generated IDs instead).

### Solution: Platform Abstraction with Conditional Imports

**Step 1: Create Platform Utility**

```dart
// lib/shared/utils/platform_info.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_mobile.dart'
    if (dart.library.html) 'platform_info_web.dart';

class PlatformInfo {
  static bool get isWeb => kIsWeb;
  static bool get isMobile => !kIsWeb;

  // Delegates to platform-specific implementation
  static String get platformName => getPlatformName();
  static Future<String> get deviceId => getDeviceId();
}
```

**Step 2: Stub Implementation (compile-time only)**

```dart
// lib/shared/utils/platform_info_stub.dart
String getPlatformName() => throw UnimplementedError();
Future<String> getDeviceId() => throw UnimplementedError();
```

**Step 3: Mobile Implementation**

```dart
// lib/shared/utils/platform_info_mobile.dart
import 'dart:io';

String getPlatformName() {
  if (Platform.isIOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  return 'unknown';
}

Future<String> getDeviceId() async {
  // Use device_info_plus package
  // Return actual device ID
  return 'mobile-device-id';
}
```

**Step 4: Web Implementation**

```dart
// lib/shared/utils/platform_info_web.dart
import 'dart:html' as html;
import 'package:uuid/uuid.dart';

String getPlatformName() {
  return 'web';
}

Future<String> getDeviceId() async {
  // Check localStorage for existing device ID
  final storage = html.window.localStorage;
  final existingId = storage['device_id'];

  if (existingId != null) {
    return existingId;
  }

  // Generate new UUID for web
  final newId = const Uuid().v4();
  storage['device_id'] = newId;
  return newId;
}
```

**Step 5: Update Provider**

```dart
// lib/shared/providers/device_info_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../utils/platform_info.dart';

part 'device_info_provider.g.dart';

@riverpod
String platformName(PlatformNameRef ref) {
  return PlatformInfo.platformName;
}

@riverpod
Future<String> deviceId(DeviceIdRef ref) async {
  return await PlatformInfo.deviceId;
}
```

### Files Requiring Platform Abstraction

1. ✅ `lib/shared/providers/device_info_provider.dart`
2. ✅ `lib/shared/services/app_startup_service.dart`
3. ✅ `lib/features/auth/application/oauth_service.dart`
4. ✅ `lib/shared/services/notification_service.dart`
5. ✅ Any files using `Platform.isIOS` or `Platform.isAndroid`

**Search for Platform usage:**
```bash
grep -rn "Platform\." lib/ --include="*.dart"
```

**Estimated Effort:** 3-5 days to refactor all platform checks

---

## Blocker 3: OAuth Native SDKs (HIGH PRIORITY)

### Priority: P1 (Must Fix for Auth)
### Impact: Authentication Flow
### Effort: 1 week

### Current Implementation

**File:** `lib/features/auth/application/oauth_service.dart`

```dart
import 'package:sign_in_with_apple/sign_in_with_apple.dart';  // ❌ Native only
import 'package:google_sign_in/google_sign_in.dart';  // ❌ Native only

class OAuthService {
  Future<AuthCredential?> signInWithApple() async {
    // ❌ Uses Apple's native SDK (iOS)
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    return AuthCredential(
      token: credential.identityToken,
      userId: credential.userIdentifier,
    );
  }

  Future<AuthCredential?> signInWithGoogle() async {
    // ❌ Uses Google Play Services (Android)
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
    );

    final account = await googleSignIn.signIn();
    if (account == null) return null;

    final auth = await account.authentication;
    return AuthCredential(
      token: auth.idToken,
      userId: account.id,
    );
  }
}
```

### Why This Fails on Web

1. **Platform-Specific SDKs:** `sign_in_with_apple` and `google_sign_in` use native iOS/Android SDKs not available on web.

2. **Different OAuth Flow:** Web uses OAuth redirect flow (opens in same/new tab), while mobile uses native SDKs with in-app auth.

3. **No Native Popups:** Web can't show native authentication UI (must use browser-based OAuth).

### Solution: Supabase OAuth with Redirect Flow

**Step 1: Configure Supabase OAuth Providers**

In Supabase Dashboard:
1. Go to Authentication → Providers
2. Enable Apple Sign-In
   - Add Apple Client ID
   - Add Apple Team ID
   - Add Authorized Redirect URLs: `https://mealvana.com/auth/callback`
3. Enable Google Sign-In
   - Add Google Client ID
   - Add Google Client Secret
   - Add Authorized Redirect URLs: `https://mealvana.com/auth/callback`

**Step 2: Create Web-Compatible OAuth Service**

```dart
// lib/features/auth/application/oauth_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'oauth_service_mobile.dart' if (dart.library.html) 'oauth_service_web.dart';

class OAuthService {
  OAuthService(this._supabase);
  final SupabaseClient _supabase;

  Future<AuthResponse?> signInWithApple() async {
    if (kIsWeb) {
      return await _signInWithAppleWeb();
    } else {
      return await _signInWithAppleMobile();
    }
  }

  Future<AuthResponse?> signInWithGoogle() async {
    if (kIsWeb) {
      return await _signInWithGoogleWeb();
    } else {
      return await _signInWithGoogleMobile();
    }
  }

  // Web implementations
  Future<AuthResponse?> _signInWithAppleWeb() async {
    return await _supabase.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'https://mealvana.com/auth/callback',
      authScreenLaunchMode: LaunchMode.platformDefault,
    );
  }

  Future<AuthResponse?> _signInWithGoogleWeb() async {
    return await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'https://mealvana.com/auth/callback',
      authScreenLaunchMode: LaunchMode.platformDefault,
    );
  }

  // Mobile implementations (use native SDKs)
  Future<AuthResponse?> _signInWithAppleMobile() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    return await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: credential.identityToken!,
      nonce: 'nonce',  // Generate proper nonce
    );
  }

  Future<AuthResponse?> _signInWithGoogleMobile() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
    final account = await googleSignIn.signIn();
    if (account == null) return null;

    final auth = await account.authentication;
    return await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: auth.idToken!,
    );
  }
}
```

**Step 3: Handle OAuth Callback (Web)**

```dart
// lib/features/auth/presentation/screens/auth_callback_screen.dart
class AuthCallbackScreen extends ConsumerStatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  ConsumerState<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends ConsumerState<AuthCallbackScreen> {
  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      final supabase = ref.read(supabaseProvider);
      final session = supabase.auth.currentSession;

      if (session == null) {
        throw Exception('No session after OAuth callback');
      }

      // Fetch or create user profile
      await ref.read(authServiceProvider).initializeUser(session.user.id);

      // Navigate to home
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication failed: $e')),
        );
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
```

**Step 4: Update Router**

```dart
// lib/shared/routing/app_router.dart
@riverpod
GoRouter goRouter(GoRouterRef ref) {
  return GoRouter(
    routes: [
      // ... existing routes
      GoRoute(
        path: '/auth/callback',
        builder: (context, state) => const AuthCallbackScreen(),
      ),
    ],
  );
}
```

**Step 5: Test OAuth Flow**

```dart
// Test on web
flutter run -d chrome

// Click "Sign in with Apple"
// Should redirect to Apple OAuth page
// After approval, redirects back to /auth/callback
// User should be authenticated
```

**Estimated Effort:** 1 week (including testing)

---

## Blocker 4: Push Notifications (MEDIUM PRIORITY)

### Priority: P2 (Can Defer)
### Impact: Reminder Features
### Effort: 3-5 days

### Current Implementation

**File:** `lib/shared/services/notification_service.dart`

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';  // ❌ Native only
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  late FlutterLocalNotificationsPlugin _plugin;

  Future<void> initialize() async {
    _plugin = FlutterLocalNotificationsPlugin();

    // ❌ Platform-specific initialization
    const androidSettings = AndroidInitializationSettings('app_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
  }

  Future<void> scheduleReminder(DateTime dateTime) async {
    // ❌ Uses native notification scheduling
    await _plugin.zonedSchedule(
      0,
      'Mealvana Reminder',
      'Plan your nutrition for your upcoming workout!',
      tz.TZDateTime.from(dateTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Workout Reminders',
          importance: Importance.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
```

### Why This Fails on Web

1. **No Local Notification Scheduling:** Web browsers don't support scheduling local notifications (must come from server).

2. **Different Permission Model:** Web uses Web Notifications API with different permission flow.

3. **Service Workers Required:** Web push requires service worker registration (different architecture).

### Solution Options

#### Option A: Disable Notifications on Web (Simplest)

```dart
// lib/shared/services/notification_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;

class NotificationService {
  Future<void> initialize() async {
    if (kIsWeb) {
      print('Notifications not supported on web');
      return;
    }

    // Mobile initialization
    _plugin = FlutterLocalNotificationsPlugin();
    // ... rest of mobile initialization
  }

  Future<void> scheduleReminder(DateTime dateTime) async {
    if (kIsWeb) {
      // Show in-app message instead
      print('Web: Reminder set for $dateTime (in-app only)');
      return;
    }

    // Mobile notification scheduling
    await _plugin.zonedSchedule(/* ... */);
  }
}
```

#### Option B: Web Notifications API (Limited)

```dart
// lib/shared/services/web_notification_service.dart
import 'dart:html' as html;

class WebNotificationService {
  Future<void> initialize() async {
    if (!html.Notification.supported) {
      print('Web Notifications not supported in this browser');
      return;
    }

    print('Web Notifications are supported');
  }

  Future<bool> requestPermissions() async {
    if (!html.Notification.supported) return false;

    final permission = await html.Notification.requestPermission();
    return permission == 'granted';
  }

  void showNotification(String title, String body) {
    if (html.Notification.permission == 'granted') {
      html.Notification(title, body: body);
    }
  }

  // ⚠️ Web cannot schedule future notifications
  // Must implement server-side push or in-app reminders
  Future<void> scheduleReminder(DateTime dateTime) async {
    print('Web: Cannot schedule notifications locally');
    print('Consider using Supabase Edge Function to send push at $dateTime');

    // Option: Store reminder in Supabase, Edge Function sends at scheduled time
    await _scheduleViaBackend(dateTime);
  }

  Future<void> _scheduleViaBackend(DateTime dateTime) async {
    // Store reminder in Supabase
    // Backend cron job checks and sends notifications
    // Requires server-side push notification service
  }
}
```

#### Option C: In-App Reminders (Recommended for MVP)

```dart
// lib/features/reminders/presentation/widgets/in_app_reminder_banner.dart
class InAppReminderBanner extends ConsumerWidget {
  const InAppReminderBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingReminders = ref.watch(upcomingRemindersProvider);

    return upcomingReminders.when(
      data: (reminders) {
        if (reminders.isEmpty) return const SizedBox.shrink();

        final nextReminder = reminders.first;
        return Container(
          color: Colors.orange.shade100,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.notifications_active),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reminder: ${nextReminder.message}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => _openReminder(context, nextReminder),
                child: const Text('View'),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _openReminder(BuildContext context, Reminder reminder) {
    // Navigate to relevant screen
  }
}
```

### Recommendation

**For MVP: Use Option C (In-App Reminders)**

1. No web platform limitations
2. Simpler implementation
3. Works offline (if implemented)
4. Can always add push later via backend service

**For Future: Add Server-Side Push**

1. Use Firebase Cloud Messaging (FCM) for web push
2. Requires service worker setup
3. Store push tokens in Supabase
4. Edge Function sends scheduled notifications

**Estimated Effort:** 3-5 days for in-app reminders

---

## Blocker 5: App Startup Initialization (MEDIUM PRIORITY)

### Priority: P2 (Must Fix Early)
### Impact: App Launch
### Effort: 2-3 days

### Current Implementation

**File:** `lib/shared/services/app_startup_service.dart`

```dart
import 'dart:io';  // ❌ Not available on web
import '../database/app_database.dart';

class AppStartupService {
  Future<void> initialize() async {
    // ❌ Platform check fails on web
    if (Platform.isIOS || Platform.isAndroid) {
      await _initializeMobile();
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  Future<void> _initializeMobile() async {
    // Initialize Drift database
    final database = AppDatabase();  // ❌ Uses NativeDatabase
    await database.ensureOpen();

    // Initialize notifications
    final notificationService = NotificationService();  // ❌ Native only
    await notificationService.initialize();

    // Initialize analytics
    await _initializeAnalytics();
  }
}
```

### Solution: Platform-Conditional Initialization

```dart
// lib/shared/services/app_startup_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_startup_service.g.dart';

@riverpod
class AppStartup extends _$AppStartup {
  @override
  Future<void> build() async {
    // Initialize platform-agnostic services first
    await _initializeSupabase();
    await _initializeAnalytics();
    await _initializeSentry();

    // Platform-specific initialization
    if (kIsWeb) {
      await _initializeWeb();
    } else {
      await _initializeMobile();
    }
  }

  Future<void> _initializeSupabase() async {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  }

  Future<void> _initializeAnalytics() async {
    final analyticsService = ref.read(analyticsServiceProvider);
    await analyticsService.initialize();
  }

  Future<void> _initializeSentry() async {
    // Sentry works on web
    await SentryFlutter.init((options) {
      options.dsn = dotenv.env['SENTRY_DSN'];
      options.environment = kIsWeb ? 'web' : 'mobile';
    });
  }

  Future<void> _initializeWeb() async {
    print('Initializing for web platform');

    // No local database initialization needed
    // Will use Supabase directly

    // Initialize web-specific services
    final notificationService = ref.read(notificationServiceProvider);
    await notificationService.initialize();  // Web stub

    print('Web initialization complete');
  }

  Future<void> _initializeMobile() async {
    print('Initializing for mobile platform');

    // Initialize Drift database
    final database = ref.read(appDatabaseProvider);
    await database.ensureOpen();

    // Initialize mobile notifications
    final notificationService = ref.read(notificationServiceProvider);
    await notificationService.initialize();

    print('Mobile initialization complete');
  }
}
```

**Estimated Effort:** 2-3 days

---

## Summary of Critical Blockers

| Blocker | Priority | Effort | Recommended Solution |
|---------|----------|--------|---------------------|
| Drift SQLite | P0 | 3-4 weeks | Supabase-only repositories |
| Platform Checks | P0 | 3-5 days | Conditional imports with kIsWeb |
| OAuth SDKs | P1 | 1 week | Supabase OAuth redirect flow |
| Push Notifications | P2 | 3-5 days | In-app reminders (defer native push) |
| App Startup | P2 | 2-3 days | Platform-conditional initialization |

**Total Estimated Effort:** 5-7 weeks for all critical blockers

---

## Testing Strategy for Blockers

### Unit Tests

```dart
// test/shared/utils/platform_info_test.dart
void main() {
  group('PlatformInfo', () {
    test('returns correct platform name on web', () {
      expect(PlatformInfo.platformName, 'web');
    });

    test('generates device ID on web', () async {
      final deviceId = await PlatformInfo.deviceId;
      expect(deviceId, isNotEmpty);
      expect(deviceId.length, 36);  // UUID length
    });
  });
}
```

### Integration Tests

```dart
// test/integration/web_repository_test.dart
void main() {
  group('Web Repository Integration', () {
    late SupabaseClient supabase;
    late SupabaseNutritionPlanRepository repository;

    setUp(() async {
      supabase = await initializeSupabase();
      repository = SupabaseNutritionPlanRepository(supabase);
    });

    test('fetches nutrition plans from Supabase', () async {
      final plans = await repository.getPlans('test-device-id');
      expect(plans, isNotEmpty);
    });

    test('saves nutrition plan to Supabase', () async {
      final plan = NutritionPlan(/* ... */);
      await repository.savePlan(plan);

      final fetched = await repository.getPlans('test-device-id');
      expect(fetched, contains(plan));
    });
  });
}
```

---

## Next Steps

1. **Review blockers with team** - Prioritize based on business needs
2. **Start with Blocker 2 (Platform Checks)** - Quick win, unblocks compilation
3. **Tackle Blocker 1 (Database)** - Biggest effort, most critical
4. **Implement Blocker 3 (OAuth)** - Required for authentication
5. **Defer Blocker 4 (Notifications)** - Can launch without push notifications

---

**Document Version:** 1.0
**Last Updated:** 2025-12-15
**Status:** Comprehensive Analysis Complete
**Maintainer:** Development Team
