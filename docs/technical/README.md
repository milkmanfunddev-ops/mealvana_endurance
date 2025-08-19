# Mealvana Endurance Technical Implementation Guide

## Overview
This document contains technical implementation details, patterns, and best practices for developing the Mealvana Endurance nutrition planning app. This guide covers Flutter architecture patterns, Riverpod implementation, launcher setup, and development workflows.

## 🚨 CRITICAL Documentation

**📋 [FOA Architecture Guide](foa-architecture.md)** - MANDATORY reading for all developers. Contains required Andrea Bizzotto AsyncNotifier patterns that ALL controllers must follow.

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

## Data Persistence with Hive

### Setup and Configuration
```dart
// Initialize Hive in main()
await Hive.initFlutter();

// Register adapters
Hive.registerAdapter(UserProfileAdapter());
Hive.registerAdapter(NutritionPlanAdapter());

// Open boxes
final userBox = await Hive.openBox<UserProfile>('users');
final plansBox = await Hive.openBox<NutritionPlan>('nutrition_plans');
```

### Repository Implementation
```dart
class HiveUserRepository implements UserRepository {
  HiveUserRepository(this._box);
  final Box<UserProfile> _box;

  @override
  Future<UserProfile?> getProfile(String userId) async {
    return _box.get(userId);
  }

  @override
  Future<void> updateProfile(String userId, UserProfile profile) async {
    await _box.put(userId, profile);
  }

  @override
  Stream<UserProfile> watchProfile(String userId) {
    return _box.watch(key: userId).map((_) => _box.get(userId)!);
  }
}
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

### Hive Optimization
- Use lazy boxes for large datasets
- Implement periodic compaction for boxes with frequent updates
- Consider using Hive-generated type adapters for better performance

## Security Best Practices

### Data Storage
- Use encrypted Hive boxes for sensitive user data
- Never store authentication tokens in plain text
- Implement proper data validation in repository layer

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

### 💾 [Data Storage with Hive](./data-storage.md)
- Local-only Hive Flutter patterns
- Custom type adapters and repositories
- Performance optimization strategies
- Offline-first data persistence

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

This technical guide provides the foundation for implementing a scalable, maintainable Flutter application following proven architectural patterns and best practices.