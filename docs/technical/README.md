# Mealvana Endurance Technical Implementation Guide

## Overview
This document contains technical implementation details, patterns, and best practices for developing the Mealvana Endurance nutrition planning app. This guide covers Flutter architecture patterns, Riverpod implementation, launcher setup, and development workflows.

## 🚨 CRITICAL Documentation

**📋 [CLAUDE.md](../../CLAUDE.md)** - **PRIMARY AI ASSISTANT CONTEXT**. Contains complete project context, architecture patterns, and critical rules. **READ THIS FIRST**.

**📋 [FOA Architecture Guide](foa-architecture.md)** - MANDATORY reading for all developers. Contains required Andrea Bizzotto AsyncNotifier patterns that ALL controllers must follow.

**📋 [Drift Migration Guide](drift-migration-guide.md)** - Complete guide for migrating from Hive to Drift with type-safe schema versioning.

**📋 [Sentry Integration](sentry-integration.md)** - Error tracking and monitoring setup for production debugging.

## App Architecture Patterns

### 🎯 Feature-Oriented Architecture (FOA) - Andrea Bizzotto Patterns

**CRITICAL: ALL controllers must follow Andrea Bizzotto's AsyncNotifier patterns**

📚 **Comprehensive FOA Guide**: [foa-architecture.md](foa-architecture.md)

### Four-Layer Architecture
Based on Andrea Bizzotto's Feature-Oriented Architecture, we implement a clean separation of concerns across four distinct layers:

```
┌─────────────────────────┐
│   Presentation Layer    │  ← Widgets & Controllers
├─────────────────────────┤
│   Application Layer     │  ← Services & Use Cases
├─────────────────────────┤
│    Domain Layer         │  ← Models & Business Logic
├─────────────────────────┤
│     Data Layer          │  ← Repositories & Data Sources
└─────────────────────────┘
```

#### Presentation Layer
- **Widgets**: Pure UI components that display data and handle user interaction
- **Controllers**: `AsyncNotifier` subclasses with `@riverpod` annotation (NEVER StateNotifier)
- **Purpose**: Visual representation of application state, user interaction handling

**🚨 MANDATORY Controller Pattern:**
```dart
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';

part 'screen_controller.g.dart';

@riverpod
class ScreenController extends _$ScreenController {
  ContentService get _contentService => ref.read(contentServiceProvider);
  ServiceClass get _service => ref.read(serviceProvider);

  @override
  FutureOr<ScreenState> build() {
    // Load content from ContentService (MANDATORY)
    final title = _contentService.getValue(ContentKeys.screenTitle, 
        defaultValue: 'Default Title');
    return ScreenState(title: title);
  }

  Future<void> performAction() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // Business logic here
      return updatedState;
    });
  }
  
  Future<void> refresh() async {
    await _contentService.refreshFromBackend();
    ref.invalidateSelf();
  }
}
```

#### Domain Layer
- **Models**: Immutable data classes representing business entities
- **Business Logic**: Domain-specific operations and validations
- **Purpose**: Core business concepts independent of external concerns

```dart
class NutritionPlan {
  const NutritionPlan({
    required this.id,
    required this.userId,
    required this.macros,
    required this.meals,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final MacroTargets macros;
  final List<Meal> meals;
  final DateTime createdAt;
}

extension MutableNutritionPlan on NutritionPlan {
  NutritionPlan addMeal(Meal meal) {
    return copyWith(meals: [...meals, meal]);
  }
}
```

#### Application Layer
- **Services**: Cross-feature business logic coordination
- **Use Cases**: Complex operations involving multiple repositories
- **Purpose**: Orchestrate domain and data layer interactions

```dart
class NutritionService {
  NutritionService(this.ref);
  final Ref ref;

  Future<NutritionPlan> generatePlan({
    required double distance,
    required Duration pace,
    required UserProfile profile,
  }) async {
    // Complex business logic coordinating multiple repositories
    final userRepo = ref.read(userRepositoryProvider);
    final foodRepo = ref.read(foodRepositoryProvider);
    final planRepo = ref.read(planRepositoryProvider);
    
    // Implementation...
  }
}
```

**Shared Services Architecture:**

Our application includes shared services that provide functionality across multiple features:

- **NotificationService**: Local notification scheduling and management
  - Handles notification permissions across iOS and Android
  - Schedules one-time and recurring reminders
  - Persists scheduled notifications across device reboots
  - Integrates with timezone handling for accurate scheduling
  - Provides graceful fallbacks when permissions are denied

```dart
@riverpod
NotificationService notificationService(NotificationServiceRef ref) {
  return NotificationService();
}

class NotificationService {
  late FlutterLocalNotificationsPlugin _plugin;
  
  Future<void> initialize() async {
    // Platform-specific initialization
  }
  
  Future<bool> requestPermissions() async {
    // Handle iOS/Android permission requests
  }
  
  Future<void> scheduleReminder({
    required DateTime scheduledDate,
    required bool recurring,
    required String title,
    required String body,
  }) async {
    // Schedule notification with timezone support
  }
  
  Future<void> cancelAllReminders() async {
    // Cancel existing scheduled notifications
  }
}
```

#### Data Layer
- **Repositories**: Abstraction over data sources, type-safe entity conversion
- **Data Sources**: Third-party APIs, local storage, external services
- **DTOs**: Data transfer objects for serialization/deserialization

```dart
abstract class UserRepository {
  Future<UserProfile> getProfile(String userId);
  Future<void> updateProfile(String userId, UserProfile profile);
  Stream<UserProfile> watchProfile(String userId);
}

class HiveUserRepository implements UserRepository {
  // Implementation using Hive for local storage
}
```

## Riverpod Implementation Patterns

### Auto-Generation with riverpod_generator
We use `riverpod_generator` for automatic provider generation, reducing boilerplate and improving type safety.

```dart
// pubspec.yaml dependencies
dependencies:
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  // Local notifications for reminder scheduling
  flutter_local_notifications: ^19.4.1
  timezone: ^0.9.2

dev_dependencies:
  riverpod_generator: ^2.3.0
  build_runner: ^2.4.0
```

### Provider Patterns

#### Repository Providers
```dart
@riverpod
UserRepository userRepository(UserRepositoryRef ref) {
  return HiveUserRepository();
}

@riverpod
NutritionPlanRepository nutritionPlanRepository(NutritionPlanRepositoryRef ref) {
  final hive = ref.watch(hiveBoxProvider);
  return HiveNutritionPlanRepository(hive);
}
```

#### Service Providers
```dart
@riverpod
NutritionService nutritionService(NutritionServiceRef ref) {
  return NutritionService(ref);
}
```

#### Controller Providers
```dart
@riverpod
class OnboardingController extends _$OnboardingController {
  @override
  FutureOr<void> build() {
    // Initialize if needed
  }

  Future<void> saveProfile(UserProfile profile) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(userRepositoryProvider).updateProfile(profile.id, profile);
    });
  }
}
```

### State Management Best Practices

#### AsyncValue Usage
```dart
// In controllers, always use AsyncValue.guard for error handling
state = await AsyncValue.guard(() => repository.performOperation());

// In widgets, handle loading/error states
Widget build(BuildContext context, WidgetRef ref) {
  final asyncState = ref.watch(controllerProvider);
  
  return asyncState.when(
    data: (data) => DataWidget(data),
    loading: () => const CircularProgressIndicator(),
    error: (error, stack) => ErrorWidget(error),
  );
}
```

#### Listening to State Changes
```dart
// Use ref.listen for side effects like showing snackbars
ref.listen<AsyncValue>(
  controllerProvider,
  (_, state) => state.showSnackbarOnError(context),
);
```

## Platform-Specific Integrations

### Local Notifications with flutter_local_notifications

Our app integrates local notifications for reminder scheduling using `flutter_local_notifications: ^19.4.1`. This provides cross-platform notification support with platform-specific setup requirements.

**Key Features:**
- Schedule one-time and recurring reminders
- Handle notification permissions on iOS and Android
- Persist notifications across device reboots
- Timezone-aware scheduling
- Cross-platform notification display

**Platform Setup Requirements:**

#### iOS Configuration (Developer Required)
```swift
// ios/Runner/AppDelegate.swift
import UIKit
import Flutter
import flutter_local_notifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required for notification handling
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    
    // Required for background notification processing
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

#### Android Configuration
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <!-- Required permissions -->
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
  <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

  <application>
    <!-- Notification receivers for scheduling persistence -->
    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
      <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
      </intent-filter>
    </receiver>
  </application>
</manifest>
```

**NotificationService Integration:**
```dart
// lib/shared/services/notification_service.dart
@riverpod
NotificationService notificationService(NotificationServiceRef ref) {
  return NotificationService();
}

class NotificationService {
  late FlutterLocalNotificationsPlugin _plugin;
  
  Future<void> initialize() async {
    _plugin = FlutterLocalNotificationsPlugin();
    
    const androidSettings = AndroidInitializationSettings('app_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // Will request when needed
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }
  
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      return await _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } else if (Platform.isAndroid) {
      return await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission() ?? false;
    }
    return false;
  }
}
```

**Developer Action Items:**
- **iOS Setup**: Requires Xcode configuration and AppDelegate.swift updates
- **Testing**: Platform-specific testing on physical devices
- **App Store**: May require notification entitlement documentation

## Edge Functions Integration

### Supabase Edge Functions Architecture

Mealvana Endurance uses a **fat backend architecture** with Supabase Edge Functions handling complex business logic. This approach ensures:

- **Server-side Algorithm Control**: Nutrition algorithms can be updated without app releases
- **Data Consistency**: Complex validations and business rules enforced on the server
- **Performance**: Optimized calculations running in Edge runtime
- **Security**: Sensitive operations protected by server-side validation

**🚨 CRITICAL: Edge Function Data Format Requirements**

All Edge Functions expect enum values in **underscore format** (`willing_to_try`, `dislike`, `like`), not camelCase. When calling Edge Functions, always use:

```dart
// ✅ CORRECT - Use .value for Edge Function calls
final preferences = foodPreferences.map(
  (key, value) => MapEntry(key, value.value), // .value gives underscore format
);

// ❌ WRONG - Don't use .name for Edge Functions
final preferences = foodPreferences.map(
  (key, value) => MapEntry(key, value.name), // .name gives camelCase
);
```

**Key Edge Functions:**

- **create-user**: User registration with device-based authentication
- **save-food-preferences**: Food preference persistence with validation
- **run-plan**: Deterministic nutrition plan generation (algorithmic fallback)
- **generate-ai-nutrition-plan**: AI-powered nutrition optimization with linear programming
- **get-foods**: Food data retrieval with category filtering
- **barcode-lookup**: Product identification via multiple API providers

**📚 Complete Edge Functions Guide**: [edge-functions/README.md](edge-functions/README.md)

## Data Persistence with Drift (Schema v2)

### Database Setup and Configuration  
```dart
// lib/shared/database/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  // Core v1 tables
  UsersTable, FoodPreferencesTable, NutritionPlans, MacroTargetsTable, FeedbackTable,
  // New v2 tables
  FoodsTable, CategoriesTable, FoodCategoriesTable, BrandsTable, AppContentTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2; // Current version with v1→v2 migration

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _populateDefaultData();
      },
      onUpgrade: stepByStep(
        from1To2: (m, schema) async {
          // Big Bang migration: Add all v2 tables
          await _migrateV1ToV2(m, schema);
        },
      ),
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'mealvana_db');
  }
}
```

### Table Definitions
```dart
// User profiles table
@DataClassName('UserProfile')
class Users extends Table {
  TextColumn get deviceId => text()();
  IntColumn get gender => intEnum<Gender>()();
  DateTimeColumn get birthday => dateTime()();
  IntColumn get heightFeet => integer()();
  IntColumn get heightInches => integer()();
  RealColumn get weightPounds => real()();
  BooleanColumn get runsWithWaterBottle => boolean()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentTimestamp)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentTimestamp)();
  IntColumn get gutTraining => intEnum<GutTraining>()();
  BooleanColumn get onboardingCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get appVersion => text()();

  @override
  String get tableName => 'user_profiles';

  @override
  Set<Column> get primaryKey => {deviceId};
}
```

### Repository Implementation (Updated for Schema v2)
```dart
class DriftUserRepository implements UserRepository {
  DriftUserRepository(this._database);
  final AppDatabase _database;

  @override
  Future<UserProfile?> getProfile(String deviceId) async {
    return await (_database.select(_database.userProfilesTable)
          ..where((u) => u.deviceId.equals(deviceId)))
        .getSingleOrNull();
  }

  @override
  Future<void> updateProfile(String deviceId, UserProfile profile) async {
    await _database.into(_database.userProfilesTable).insertOnConflictUpdate(profile);
  }

  @override
  Stream<UserProfile?> watchProfile(String deviceId) {
    return (_database.select(_database.userProfilesTable)
          ..where((u) => u.deviceId.equals(deviceId)))
        .watchSingleOrNull();
  }

  // New v2 methods for cached food data
  @override
  Future<List<Food>> getCachedFoods() async {
    return await _database.select(_database.foodsTable).get();
  }

  @override
  Future<void> cacheFoods(List<Food> foods) async {
    await _database.batch((batch) {
      batch.insertAllOnConflictUpdate(_database.foodsTable, foods);
    });
  }
}
```

### Migration Management (Schema v2)
```bash
# Current migration status: v1 → v2 COMPLETED
# - Added 5 new tables: foods, categories, food_categories, brands, app_content  
# - Used "Big Bang" migration approach for all v2 changes

# For future schema changes:
# 1. Update table definitions in lib/shared/database/tables/
# 2. Increment schemaVersion in AppDatabase (currently = 2)
# 3. Generate new migration
dart run drift_dev make-migrations

# Export schema for version control  
dart run drift_dev schema dump lib/shared/database/app_database.dart drift_schemas/

# Generate migration test code
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/

# Test migrations before deployment
dart test test/generated_migrations/
```

## App Icons and Splash Screens

### Flutter Launcher Icons Setup
```yaml
# pubspec.yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.3

flutter_launcher_icons:
  ios: true
  android: true
  image_path_ios: "assets/common/app-icon.png"
  image_path_android: "assets/android/app-icon-android.png"
  adaptive_icon_background: "assets/android/app-icon-background.png"
  adaptive_icon_foreground: "assets/android/app-icon-foreground.png"
  remove_alpha_ios: true
  web:
    generate: true
    image_path: "assets/common/app-icon.png"
```

**Generate icons:**
```bash
dart run flutter_launcher_icons
```

### Flutter Native Splash Screen Setup
```yaml
# pubspec.yaml
dev_dependencies:
  flutter_native_splash: ^2.3.0

flutter_native_splash:
  color: "#ffffff"
  image: "assets/common/splash-logo.png"
  android_12:
    color: "#ffffff"
    icon_background_color: "#FFFFFF"
    image: "assets/common/splash-logo.png"
```

**Generate splash screens:**
```bash
dart run flutter_native_splash:create
```

## Development Workflow

### Code Generation
```bash
# Watch mode for continuous generation during development
flutter pub run build_runner watch --delete-conflicting-outputs

# One-time generation
flutter pub run build_runner build --delete-conflicting-outputs
```

### Project Structure (Feature-First)
```
lib/
├── features/
│   ├── onboarding/
│   │   ├── application/
│   │   │   └── onboarding_service.dart
│   │   ├── data/
│   │   │   ├── onboarding_repository.dart
│   │   │   └── hive_onboarding_repository.dart
│   │   ├── models/
│   │   │   ├── user_profile.dart
│   │   │   └── onboarding_step.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       ├── widgets/
│   │       └── controllers/
│   ├── nutrition_plan/
│   └── feedback/
├── shared/
│   ├── core/
│   ├── services/
│   └── utils/
└── main.dart
```

### Testing Strategy

#### Unit Tests for Domain Logic
```dart
void main() {
  group('NutritionPlan', () {
    test('addMeal should add meal to plan', () {
      final plan = NutritionPlan.empty();
      final meal = Meal.breakfast(['oatmeal', 'banana']);
      
      final updated = plan.addMeal(meal);
      
      expect(updated.meals.length, 1);
      expect(updated.meals.first, meal);
    });
  });
}
```

#### Widget Tests with Riverpod
```dart
testWidgets('OnboardingScreen shows correct UI', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: OnboardingScreen(),
      ),
    ),
  );
  
  expect(find.text('Welcome'), findsOneWidget);
});
```

## Error Handling Patterns

### Repository Error Handling
```dart
class HiveUserRepository implements UserRepository {
  @override
  Future<UserProfile> getProfile(String userId) async {
    try {
      final profile = _box.get(userId);
      if (profile == null) {
        throw UserNotFoundException('User $userId not found');
      }
      return profile;
    } on HiveError catch (e) {
      throw DataAccessException('Failed to load user profile: ${e.message}');
    }
  }
}
```

### Controller Error Handling
```dart
@riverpod
class UserController extends _$UserController {
  Future<void> loadUser(String userId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return await ref.read(userRepositoryProvider).getProfile(userId);
    });
  }
}
```

### UI Error Display
```dart
extension AsyncValueUI on AsyncValue {
  void showSnackbarOnError(BuildContext context) {
    if (!isLoading && hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}
```

## Performance Considerations

### Provider Lifecycle
- Use `autoDispose` by default for memory efficiency
- Use `keepAlive` for data that should persist across widget rebuilds
- Implement proper cleanup in repository classes

### Drift Optimization
- Use compiled queries for frequently executed statements
- Implement proper indexing on commonly queried columns
- Use batched operations for bulk inserts/updates
- Leverage Drift's streaming capabilities for reactive UIs

## Security Best Practices

### Data Storage
- Use SQLite encryption for sensitive user data (via drift_ffi)
- Never store authentication tokens in plain text
- Implement proper data validation in repository layer
- Use Drift's type-safe queries to prevent SQL injection

### API Communication
- Always validate data received from external sources
- Implement proper error handling for network failures
- Use type-safe deserialization with proper validation

---

## Resources and References

### Architecture References
- [Flutter App Architecture with Riverpod](https://codewithandrea.com/articles/flutter-app-architecture-riverpod-introduction/)
- [Repository Pattern Implementation](https://codewithandrea.com/articles/flutter-repository-pattern/)
- [Feature-First Project Structure](https://codewithandrea.com/articles/flutter-project-structure/)

### State Management
- [Riverpod Documentation](https://riverpod.dev/)
- [AsyncNotifier Usage Guide](https://docs-v2.riverpod.dev/docs/providers/notifier_provider)
- [Code Generation with riverpod_generator](https://docs-v2.riverpod.dev/docs/concepts/about_code_generation)

### Development Tools
- [Flutter Launcher Icons](https://pub.dev/packages/flutter_launcher_icons)
- [Flutter Native Splash](https://pub.dev/packages/flutter_native_splash)
- [Hive Documentation](https://docs.hivedb.dev/)

## Specialized Implementation Guides

This technical guide has been expanded into specialized documentation files for better organization and maintainability:

### 💾 [Data Storage with Drift](./drift-implementation.md)
- Local SQLite database with type-safe queries
- Schema migrations and versioning
- Performance optimization strategies  
- Offline-first data persistence with sync

### 🏗️ [Fat Backend Architecture](./fat-backend-architecture.md)
- Content-driven architecture patterns
- Algorithm parameter management
- Local content system implementation
- Business logic externalization

### 📝 [Content Management System](./content-management.md)
- Local content configuration system
- Algorithm parameter management via JSON
- Type-safe content access patterns
- Content validation and fallback strategies

### 🚀 [Shorebird Code Push](./shorebird-code-push.md)
- Over-the-air update implementation
- Code push deployment strategies
- Update management and rollbacks
- Integration with development workflow

Each specialized guide contains comprehensive examples, best practices, and production-ready patterns specific to the current local-first MVP architecture.

## 🔥 Known Issues & Solutions

### Database Schema Evolution

**Current Status**: ✅ **Drift v2 Active** - Dual database architecture implemented

**Schema v2 Benefits Achieved**:
- **Comprehensive Food Caching**: 24-hour refresh cycles for food data
- **Content Management**: Dynamic UI text stored in app_content table  
- **Brand Integration**: Affiliate marketing support with brands table
- **Type-Safe Relationships**: Many-to-many food-category relationships
- **Migration Safety**: Big Bang v1→v2 migration completed successfully

**v1 → v2 Migration Completed**:
1. ✅ **5 New Tables Added**: foods, categories, food_categories, brands, app_content
2. ✅ **schemaVersion Updated**: From 1 to 2 with automated migration
3. ✅ **Big Bang Approach**: All v2 changes deployed simultaneously
4. ✅ **Content Migration**: Moved from SharedPreferences to Drift app_content table
5. ✅ **Food Caching**: Implemented 24-hour sync cycles for reference data

**For Future Schema Changes (v2 → v3)**:
1. Update table definitions in `lib/shared/database/tables/`
2. Increment `schemaVersion` in `AppDatabase` (currently = 2)
3. Run `dart run drift_dev make-migrations`
4. Add migration logic in `from2To3` method
5. Test with generated migration test suite

### Other Common Issues

1. **Database Connection Issues**
   - Solution: Ensure database is properly initialized in app startup service
   - Check that `await database.ensureOpen()` is called before first query

2. **Migration Failures**
   - Solution: Use generated migration tests to validate schema changes
   - Run `dart test test/generated_migrations/` before deploying

3. **Query Performance Issues**
   - Solution: Add proper indexes using Drift's table annotations
   - Use `explain query plan` to analyze slow queries

4. **Content Service Not Initialized**
   - Solution: Ensure ContentService loads before controllers in app startup

5. **Navigation State Issues**
   - Solution: Use `ref.invalidate()` to refresh router state after auth changes

This technical guide provides the foundation for implementing a scalable, maintainable Flutter application following proven architectural patterns and best practices.