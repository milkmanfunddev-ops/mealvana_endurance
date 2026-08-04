// Seeded CONTENT tests — meal pickers, weather, and jade.
//
// Each test pumps a screen with fake seeded state and asserts rendered VALUES.
// Screens that read GoRouterState.extra use a two-route GoRouter helper.
//
// Screens covered:
//  1. RecentSavedPickerScreen  — Saved tab lists meals; Recent tab lists logs.
//  2. RecipePickerScreen       — Recipe list renders with calorie/macro subtitle.
//  3. EditMealLogScreen        — Fields pre-fill from a seeded MealLog extra.
//  4. WeatherDetailScreen      — Temp/humidity/conditions values render.
//  5. JadeChatScreen           — Message history renders user + assistant bubbles.

// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/src/internals.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/jade/data/jade_chat_repository.dart';
import 'package:mealvana_endurance/features/jade/domain/jade_conversation.dart';
import 'package:mealvana_endurance/features/jade/domain/jade_message.dart';
import 'package:mealvana_endurance/features/jade/presentation/providers/jade_chat_controller.dart';
import 'package:mealvana_endurance/features/jade/presentation/screens/jade_chat_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/saved_meal.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/edit_meal_log_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/recent_saved_picker_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/recipe_picker_screen.dart';
import 'package:mealvana_endurance/features/recipes/application/recipe_service.dart';
import 'package:mealvana_endurance/features/recipes/domain/recipe.dart';
import 'package:mealvana_endurance/features/weather/domain/location.dart'
    as domain;
import 'package:mealvana_endurance/features/weather/domain/weather_forecast.dart';
import 'package:mealvana_endurance/features/weather/presentation/screens/weather_detail_screen.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart'
    show UnitSystem;
import 'package:mealvana_endurance/shared/providers/unit_system_provider.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';

import '../helpers/widget_test_harness.dart';

// =============================================================================
// Shared helpers
// =============================================================================

/// Pump a screen inside a two-route GoRouter so [GoRouterState.extra] is
/// populated before [didChangeDependencies] runs on the target screen.
Future<void> _pumpWithExtra(
  WidgetTester tester,
  String screenPath,
  Widget Function() buildScreen, {
  required Object? extra,
  List<Override> overrides = const [],
  bool settle = false,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SizedBox.shrink()),
      GoRoute(path: screenPath, builder: (_, __) => buildScreen()),
    ],
  );

  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mockAppExternalDeps(),
        inMemoryDatabaseOverride(),
        // EditMealLogScreen reads appConfigProvider, which throws unless it is
        // overridden the way main_*.dart does after loading .env. Listed before
        // [overrides] so callers can still substitute their own config.
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        ...overrides,
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();

  router.go(screenPath, extra: extra);

  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

// =============================================================================
// Fakes — MealLogController
// =============================================================================

class _FakeMealLogController extends MealLogController {
  @override
  FutureOr<void> build() => null;
}

// =============================================================================
// Fakes — RecipeService
// =============================================================================

class _FakeRecipeService extends Fake implements RecipeService {
  _FakeRecipeService(this._recipes);
  final List<Recipe> _recipes;

  @override
  Future<void> ensureSynced(String userId, {bool force = false}) async {}

  @override
  Future<List<Recipe>> getAllRecipes() async => _recipes;
}

// =============================================================================
// Fakes — ContentService
// =============================================================================

class _FakeContentService extends Fake implements ContentService {
  @override
  String getValue(String key, {String? defaultValue = ''}) =>
      defaultValue ?? '';
}

// =============================================================================
// Fakes — AppLogger
// =============================================================================

class _FakeLogger extends Fake implements AppLogger {
  @override
  void info(String message, {String? context, Map<String, dynamic>? data}) {}
  @override
  void error(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {}
  @override
  void warning(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {}
}

// =============================================================================
// Fakes — JadeChatRepository (no network; returns immediate done event)
// =============================================================================

class _FakeJadeChatRepository extends Fake implements JadeChatRepository {
  _FakeJadeChatRepository({
    this.conversations = const [],
    this.messagesByConversation = const {},
  });

  final List<JadeConversation> conversations;
  final Map<String, List<JadeMessage>> messagesByConversation;

  @override
  Future<List<JadeConversation>> fetchConversations() async => conversations;

  @override
  Future<List<JadeMessage>> fetchMessages(String conversationId) async =>
      messagesByConversation[conversationId] ?? [];

  @override
  Future<JadeSendResult> requestOpener({
    String? timezone,
    double? latitude,
    double? longitude,
  }) async => JadeSendResult(
    conversationId: '',
    // Use async generator so the JadeDoneEvent is delivered across an
    // event-loop boundary that tester.pump() can advance. Stream.fromIterable
    // emits synchronously and the event never arrives in the pump cycle.
    eventStream: (() async* {
      yield const JadeDoneEvent();
    })(),
  );
}

// =============================================================================
// Domain builders
// =============================================================================

SavedMeal _seedSavedMeal({
  String id = 'sm-1',
  String name = 'Peanut Butter Toast',
  int calories = 420,
  double carbsG = 55,
  double proteinG = 14,
  double fatG = 16,
}) {
  final now = DateTime.now();
  return SavedMeal(
    id: id,
    userId: 'u1',
    name: name,
    components: const [],
    calories: calories,
    carbsG: carbsG,
    proteinG: proteinG,
    fatG: fatG,
    createdAt: now,
    updatedAt: now,
  );
}

MealLog _seedMealLog({
  String id = 'log-1',
  String name = 'Overnight Oats',
  int calories = 380,
  double carbsG = 62,
  double proteinG = 15,
  double fatG = 8,
}) {
  final now = DateTime.now();
  final logDate =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return MealLog(
    id: id,
    userId: 'u1',
    logDate: logDate,
    slot: MealSlot.breakfast,
    name: name,
    source: MealLogSource.manual,
    components: const [],
    calories: calories,
    carbsG: carbsG,
    proteinG: proteinG,
    fatG: fatG,
    createdAt: now,
    updatedAt: now,
  );
}

Recipe _seedRecipe({
  String id = 'r-1',
  String name = 'Pre-Race Pasta',
  RecipeType type = RecipeType.mains,
  double calories = 520,
  double carbs = 88,
  double protein = 18,
  double fat = 9,
}) {
  return Recipe(
    id: id,
    name: name,
    description: 'Classic carb-loading dish.',
    ingredients: const ['pasta', 'tomato sauce'],
    instructions: const ['Boil pasta', 'Add sauce'],
    prepTimeMinutes: 20,
    servings: 1,
    type: type,
    nutrition: RecipeNutrition(
      calories: calories,
      carbohydratesGrams: carbs,
      proteinGrams: protein,
      fatGrams: fat,
      fiberGrams: 4,
      sugarGrams: 6,
      sodiumMilligrams: 300,
    ),
  );
}

WeatherForecast _seedForecast({
  double tempC = 18.0,
  int humidity = 72,
  String? conditions = 'Clear skies',
  bool forecastAvailable = true,
  WeatherSource source = WeatherSource.forecast,
  int? windSpeedKmh = 15,
  double? precipitationMm = 0.5,
}) {
  return WeatherForecast(
    temperatureC: tempC,
    humidityPct: humidity,
    forecastAvailable: forecastAvailable,
    forecastDate: DateTime(2026, 8, 15, 8, 0),
    source: source,
    conditions: conditions,
    windSpeedKmh: windSpeedKmh,
    precipitationMm: precipitationMm,
  );
}

/// Deterministically pins [unitSystemProvider] for [WeatherDetailScreen]
/// content tests, since the screen now derives imperial/metric from the
/// provider directly (see `weather_detail_screen.dart`) rather than a
/// caller-supplied `useImperial` flag.
Override _unitSystemOverride(UnitSystem unitSystem) =>
    unitSystemProvider.overrideWith((ref) async => unitSystem);

// =============================================================================
// 1. RecentSavedPickerScreen — Saved tab
// =============================================================================

void main() {
  group('RecentSavedPickerScreen — Saved tab', () {
    testWidgets('renders saved meal name from seeded provider', (tester) async {
      final meal = _seedSavedMeal(name: 'Peanut Butter Toast');
      await _pumpWithExtra(
        tester,
        '/picker',
        () => const RecentSavedPickerScreen(),
        extra: {'logDate': '2026-08-15'},
        overrides: [
          savedMealsProvider.overrideWith((ref) => Stream.value([meal])),
          recentMealsProvider.overrideWith((ref) async => const []),
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(
        find.text('Peanut Butter Toast'),
        findsOneWidget,
        reason: 'Saved meal name must appear in the Saved tab list',
      );
    });

    testWidgets('renders macro subtitle for saved meal', (tester) async {
      final meal = _seedSavedMeal(
        name: 'Peanut Butter Toast',
        calories: 420,
        carbsG: 55,
        proteinG: 14,
        fatG: 16,
      );
      await _pumpWithExtra(
        tester,
        '/picker',
        () => const RecentSavedPickerScreen(),
        extra: {'logDate': '2026-08-15'},
        overrides: [
          savedMealsProvider.overrideWith((ref) => Stream.value([meal])),
          recentMealsProvider.overrideWith((ref) async => const []),
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      // Subtitle: "420 kcal  ·  C 55g  ·  P 14g  ·  F 16g"
      expect(
        find.textContaining('420 kcal'),
        findsOneWidget,
        reason: 'Calorie count must appear in the saved meal subtitle',
      );
      expect(
        find.textContaining('C 55g'),
        findsOneWidget,
        reason: 'Carbs must appear in saved meal subtitle',
      );
    });

    testWidgets('shows "No saved meals yet." when provider returns empty', (
      tester,
    ) async {
      await _pumpWithExtra(
        tester,
        '/picker',
        () => const RecentSavedPickerScreen(),
        extra: {'logDate': '2026-08-15'},
        overrides: [
          savedMealsProvider.overrideWith((ref) => Stream.value(const [])),
          recentMealsProvider.overrideWith((ref) async => const []),
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(
        find.text('No saved meals yet.'),
        findsOneWidget,
        reason: 'Empty-state text must appear when no saved meals exist',
      );
    });

    testWidgets('renders multiple saved meals in order', (tester) async {
      final meals = [
        _seedSavedMeal(id: 'sm-1', name: 'Banana Oatmeal'),
        _seedSavedMeal(id: 'sm-2', name: 'Egg White Wrap'),
      ];
      await _pumpWithExtra(
        tester,
        '/picker',
        () => const RecentSavedPickerScreen(),
        extra: {'logDate': '2026-08-15'},
        overrides: [
          savedMealsProvider.overrideWith((ref) => Stream.value(meals)),
          recentMealsProvider.overrideWith((ref) async => const []),
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(find.text('Banana Oatmeal'), findsOneWidget);
      expect(find.text('Egg White Wrap'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 1b. RecentSavedPickerScreen — Recent tab
  // ===========================================================================

  group('RecentSavedPickerScreen — Recent tab', () {
    testWidgets('switches to Recent tab and shows recent meal log', (
      tester,
    ) async {
      final log = _seedMealLog(name: 'Overnight Oats');
      await _pumpWithExtra(
        tester,
        '/picker',
        () => const RecentSavedPickerScreen(),
        extra: {'logDate': '2026-08-15'},
        overrides: [
          savedMealsProvider.overrideWith((ref) => Stream.value(const [])),
          recentMealsProvider.overrideWith((ref) async => [log]),
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      // Tap the Recent tab
      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();

      expect(
        find.text('Overnight Oats'),
        findsOneWidget,
        reason: 'Recent meal log name must appear after switching tabs',
      );
    });

    testWidgets('Recent tab shows "No recent meals." when empty', (
      tester,
    ) async {
      await _pumpWithExtra(
        tester,
        '/picker',
        () => const RecentSavedPickerScreen(),
        extra: {'logDate': '2026-08-15'},
        overrides: [
          savedMealsProvider.overrideWith((ref) => Stream.value(const [])),
          recentMealsProvider.overrideWith((ref) async => const []),
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();

      expect(
        find.text('No recent meals.'),
        findsOneWidget,
        reason: 'Empty-state text must appear on the Recent tab when no logs',
      );
    });

    testWidgets('Recent tab shows macro subtitle for a seeded log', (
      tester,
    ) async {
      final log = _seedMealLog(
        name: 'Overnight Oats',
        calories: 380,
        carbsG: 62,
        proteinG: 15,
        fatG: 8,
      );
      await _pumpWithExtra(
        tester,
        '/picker',
        () => const RecentSavedPickerScreen(),
        extra: {'logDate': '2026-08-15'},
        overrides: [
          savedMealsProvider.overrideWith((ref) => Stream.value(const [])),
          recentMealsProvider.overrideWith((ref) async => [log]),
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('380 kcal'),
        findsOneWidget,
        reason: 'Calorie count must appear in the recent meal subtitle',
      );
    });
  });

  // ===========================================================================
  // 2. RecipePickerScreen — list renders
  // ===========================================================================

  group('RecipePickerScreen — seeded content', () {
    testWidgets('renders recipe name from seeded service', (tester) async {
      final recipe = _seedRecipe(name: 'Pre-Race Pasta');
      final fakeService = _FakeRecipeService([recipe]);

      await _pumpWithExtra(
        tester,
        '/recipe',
        () => const RecipePickerScreen(),
        extra: {'logDate': '2026-08-15'},
        overrides: [
          recipeServiceProvider.overrideWithValue(fakeService),
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(
        find.text('Pre-Race Pasta'),
        findsOneWidget,
        reason: 'Recipe name must appear in the recipe list tile',
      );
    });

    testWidgets('renders calorie subtitle for a seeded recipe', (tester) async {
      final recipe = _seedRecipe(
        name: 'Pre-Race Pasta',
        calories: 520,
        carbs: 88,
        protein: 18,
        fat: 9,
      );
      final fakeService = _FakeRecipeService([recipe]);

      await _pumpWithExtra(
        tester,
        '/recipe',
        () => const RecipePickerScreen(),
        extra: {'logDate': '2026-08-15'},
        overrides: [
          recipeServiceProvider.overrideWithValue(fakeService),
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      // Subtitle: "520 kcal/serving  ·  C 88g  P 18g  F 9g"
      expect(
        find.textContaining('520 kcal/serving'),
        findsOneWidget,
        reason: 'Calorie per serving must appear in the recipe subtitle',
      );
    });

    testWidgets('renders carbs/protein/fat in recipe subtitle', (tester) async {
      final recipe = _seedRecipe(
        name: 'Pre-Race Pasta',
        carbs: 88,
        protein: 18,
        fat: 9,
      );
      final fakeService = _FakeRecipeService([recipe]);

      await _pumpWithExtra(
        tester,
        '/recipe',
        () => const RecipePickerScreen(),
        extra: {'logDate': '2026-08-15'},
        overrides: [
          recipeServiceProvider.overrideWithValue(fakeService),
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(
        find.textContaining('C 88g'),
        findsOneWidget,
        reason: 'Carb count must appear in subtitle',
      );
      expect(
        find.textContaining('P 18g'),
        findsOneWidget,
        reason: 'Protein count must appear in subtitle',
      );
      expect(
        find.textContaining('F 9g'),
        findsOneWidget,
        reason: 'Fat count must appear in subtitle',
      );
    });

    testWidgets('shows "No recipes found." when service returns empty list', (
      tester,
    ) async {
      final fakeService = _FakeRecipeService([]);

      await _pumpWithExtra(
        tester,
        '/recipe',
        () => const RecipePickerScreen(),
        extra: {'logDate': '2026-08-15'},
        overrides: [
          recipeServiceProvider.overrideWithValue(fakeService),
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(
        find.text('No recipes found.'),
        findsOneWidget,
        reason: 'Empty-state label must appear when no recipes exist',
      );
    });

    testWidgets('renders multiple recipes', (tester) async {
      final recipes = [
        _seedRecipe(id: 'r-1', name: 'Pre-Race Pasta'),
        _seedRecipe(
          id: 'r-2',
          name: 'Recovery Smoothie',
          type: RecipeType.recovery,
        ),
      ];
      final fakeService = _FakeRecipeService(recipes);

      await _pumpWithExtra(
        tester,
        '/recipe',
        () => const RecipePickerScreen(),
        extra: {'logDate': '2026-08-15'},
        overrides: [
          recipeServiceProvider.overrideWithValue(fakeService),
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(find.text('Pre-Race Pasta'), findsOneWidget);
      expect(find.text('Recovery Smoothie'), findsOneWidget);
    });

    testWidgets('renders type filter chips (All, Breakfast, etc.)', (
      tester,
    ) async {
      final fakeService = _FakeRecipeService([]);

      await _pumpWithExtra(
        tester,
        '/recipe',
        () => const RecipePickerScreen(),
        extra: {'logDate': '2026-08-15'},
        overrides: [
          recipeServiceProvider.overrideWithValue(fakeService),
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(
        find.text('All'),
        findsOneWidget,
        reason: '"All" filter chip must render',
      );
      expect(
        find.text('Breakfast'),
        findsOneWidget,
        reason: '"Breakfast" filter chip must render',
      );
      expect(
        find.text('Workout Fuel'),
        findsOneWidget,
        reason: '"Workout Fuel" filter chip must render',
      );
    });
  });

  // ===========================================================================
  // 3. EditMealLogScreen — field pre-fill + validation
  // ===========================================================================

  group('EditMealLogScreen — seeded content', () {
    testWidgets('pre-fills name field from seeded MealLog', (tester) async {
      final log = _seedMealLog(name: 'Overnight Oats', calories: 380);

      await _pumpWithExtra(
        tester,
        '/edit',
        () => const EditMealLogScreen(),
        extra: {'log': log},
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      final nameField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Meal name'),
      );
      expect(
        nameField.controller?.text,
        equals('Overnight Oats'),
        reason: 'Name field must be pre-filled with MealLog.name',
      );
    });

    testWidgets('pre-fills calories field from seeded MealLog', (tester) async {
      final log = _seedMealLog(calories: 380);

      await _pumpWithExtra(
        tester,
        '/edit',
        () => const EditMealLogScreen(),
        extra: {'log': log},
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      final calField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Calories (kcal)'),
      );
      expect(
        calField.controller?.text,
        equals('380'),
        reason: 'Calories field must be pre-filled with MealLog.calories',
      );
    });

    testWidgets('pre-fills carbs/protein/fat fields from seeded MealLog', (
      tester,
    ) async {
      final log = _seedMealLog(carbsG: 62, proteinG: 15, fatG: 8);

      await _pumpWithExtra(
        tester,
        '/edit',
        () => const EditMealLogScreen(),
        extra: {'log': log},
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      final carbField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Carbs (g)'),
      );
      final protField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Protein (g)'),
      );
      final fatField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Fat (g)'),
      );

      expect(
        carbField.controller?.text,
        equals('62.0'),
        reason: 'Carbs field must be pre-filled',
      );
      expect(
        protField.controller?.text,
        equals('15.0'),
        reason: 'Protein field must be pre-filled',
      );
      expect(
        fatField.controller?.text,
        equals('8.0'),
        reason: 'Fat field must be pre-filled',
      );
    });

    testWidgets('shows "Name is required" when name is cleared and saved', (
      tester,
    ) async {
      final log = _seedMealLog(name: 'Overnight Oats');

      await _pumpWithExtra(
        tester,
        '/edit',
        () => const EditMealLogScreen(),
        extra: {'log': log},
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      // Clear the name field
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Meal name'),
        '',
      );
      await tester.pump();

      // Scroll Save changes into view before tapping — the redesigned edit
      // screen is taller and on the default 800x600 test surface the button
      // sits below the fold, so a direct tap misses the hit-test (only warns),
      // _submit() never runs, and validation never fires.
      await tester.ensureVisible(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text('Name is required'),
        findsOneWidget,
        reason: 'Validation must fire when name is cleared',
      );
    });

    testWidgets('renders "Edit Meal" app bar title', (tester) async {
      final log = _seedMealLog();

      await _pumpWithExtra(
        tester,
        '/edit',
        () => const EditMealLogScreen(),
        extra: {'log': log},
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(
        find.text('Edit Meal'),
        findsOneWidget,
        reason: 'AppBar title must read "Edit Meal"',
      );
    });

    testWidgets('renders "Save changes" button', (tester) async {
      final log = _seedMealLog();

      await _pumpWithExtra(
        tester,
        '/edit',
        () => const EditMealLogScreen(),
        extra: {'log': log},
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(
        find.text('Save changes'),
        findsOneWidget,
        reason: '"Save changes" button must be present',
      );
    });

    testWidgets('renders "Meal type" slot selector section', (tester) async {
      final log = _seedMealLog();

      await _pumpWithExtra(
        tester,
        '/edit',
        () => const EditMealLogScreen(),
        extra: {'log': log},
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(
        find.text('Meal type'),
        findsOneWidget,
        reason: 'Slot selector label must appear',
      );
    });

    testWidgets('null extra — renders "Edit Meal" title without crashing', (
      tester,
    ) async {
      // When extra is null, _originalLog is null and the form is mostly empty.
      // The screen must not crash; the name field should be empty.
      await _pumpWithExtra(
        tester,
        '/edit',
        () => const EditMealLogScreen(),
        extra: null,
        overrides: [
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
        ],
        settle: true,
      );

      expect(
        find.text('Edit Meal'),
        findsOneWidget,
        reason: 'AppBar must still show "Edit Meal" with null extra',
      );
    });
  });

  // ===========================================================================
  // 4. WeatherDetailScreen — seeded values
  // ===========================================================================

  group('WeatherDetailScreen — seeded forecast', () {
    testWidgets('renders temperature in Celsius when unit pref is metric', (
      tester,
    ) async {
      final forecast = _seedForecast(tempC: 18.0);

      await pumpSeeded(
        tester,
        WeatherDetailScreen(forecast: forecast),
        overrides: [_unitSystemOverride(UnitSystem.metric)],
        settle: true,
      );

      // The hero section shows "18°C"
      expect(
        find.text('18°C'),
        findsWidgets,
        reason: 'Temperature in Celsius must appear in the hero section',
      );
    });

    testWidgets('renders temperature in Fahrenheit when unit pref is imperial', (
      tester,
    ) async {
      // 18°C → (18 * 9/5) + 32 = 64.4 → rounds to 64°F
      final forecast = _seedForecast(tempC: 18.0);

      await pumpSeeded(
        tester,
        WeatherDetailScreen(forecast: forecast),
        overrides: [_unitSystemOverride(UnitSystem.imperial)],
        settle: true,
      );

      expect(
        find.text('64°F'),
        findsWidgets,
        reason:
            'Temperature must be shown in Fahrenheit when unit pref is imperial',
      );
    });

    testWidgets('renders humidity percentage from seeded forecast', (
      tester,
    ) async {
      final forecast = _seedForecast(humidity: 72);

      await pumpSeeded(
        tester,
        WeatherDetailScreen(forecast: forecast),
        settle: true,
      );

      expect(
        find.textContaining('72%'),
        findsWidgets,
        reason: 'Humidity percentage must appear in the forecast view',
      );
    });

    testWidgets('renders weather conditions string from seeded forecast', (
      tester,
    ) async {
      final forecast = _seedForecast(conditions: 'Clear skies');

      await pumpSeeded(
        tester,
        WeatherDetailScreen(forecast: forecast),
        settle: true,
      );

      expect(
        find.text('Clear skies'),
        findsWidgets,
        reason: 'Conditions string must appear in the hero section and table',
      );
    });

    testWidgets('renders wind speed in km/h from seeded forecast', (
      tester,
    ) async {
      final forecast = _seedForecast(windSpeedKmh: 15);

      await pumpSeeded(
        tester,
        WeatherDetailScreen(forecast: forecast),
        overrides: [_unitSystemOverride(UnitSystem.metric)],
        settle: true,
      );

      expect(
        find.textContaining('15 km/h'),
        findsOneWidget,
        reason: 'Wind speed must appear in the Weather Details card',
      );
    });

    testWidgets('renders precipitation in mm from seeded forecast', (
      tester,
    ) async {
      // 0.5 mm → toStringAsFixed(1) → "0.5 mm"
      final forecast = _seedForecast(precipitationMm: 0.5);

      await pumpSeeded(
        tester,
        WeatherDetailScreen(forecast: forecast),
        overrides: [_unitSystemOverride(UnitSystem.metric)],
        settle: true,
      );

      expect(
        find.textContaining('0.5 mm'),
        findsOneWidget,
        reason: 'Precipitation must appear in the Weather Details card',
      );
    });

    testWidgets('renders location displayName when location is provided', (
      tester,
    ) async {
      final forecast = _seedForecast();
      const location = domain.Location(
        latitude: 42.36,
        longitude: -71.06,
        city: 'Boston',
        country: 'USA',
      );

      await pumpSeeded(
        tester,
        WeatherDetailScreen(forecast: forecast, location: location),
        settle: true,
      );

      // Location.displayName → "Boston, USA"
      expect(
        find.text('Boston, USA'),
        findsOneWidget,
        reason: 'Location displayName must appear in the Location card',
      );
    });

    testWidgets('renders Forecast source label in Forecast Info card', (
      tester,
    ) async {
      final forecast = _seedForecast(source: WeatherSource.forecast);

      await pumpSeeded(
        tester,
        WeatherDetailScreen(forecast: forecast),
        settle: true,
      );

      // WeatherSource.forecast.displayName == 'Forecast'
      expect(
        find.text('Forecast'),
        findsOneWidget,
        reason: 'Source displayName must appear in the Forecast Info card',
      );
    });

    testWidgets('renders "No (using defaults)" when forecastAvailable is false', (
      tester,
    ) async {
      final forecast = _seedForecast(forecastAvailable: false);

      await pumpSeeded(
        tester,
        WeatherDetailScreen(forecast: forecast),
        settle: true,
      );

      expect(
        find.text('No (using defaults)'),
        findsOneWidget,
        reason:
            'Forecast available row must show "No (using defaults)" when false',
      );
    });

    testWidgets('Fahrenheit conversion is arithmetically correct: 0°C = 32°F', (
      tester,
    ) async {
      // BUG TRAP: if the conversion formula is wrong, this catches it.
      final forecast = _seedForecast(tempC: 0.0);

      await pumpSeeded(
        tester,
        WeatherDetailScreen(forecast: forecast),
        overrides: [_unitSystemOverride(UnitSystem.imperial)],
        settle: true,
      );

      // 0°C → 32°F
      expect(
        find.text('32°F'),
        findsWidgets,
        reason: '0°C must convert to 32°F (basic formula check)',
      );
    });

    testWidgets('Fahrenheit conversion: 100°C = 212°F', (tester) async {
      final forecast = _seedForecast(tempC: 100.0);

      await pumpSeeded(
        tester,
        WeatherDetailScreen(forecast: forecast),
        overrides: [_unitSystemOverride(UnitSystem.imperial)],
        settle: true,
      );

      expect(
        find.text('212°F'),
        findsWidgets,
        reason: '100°C must convert to 212°F',
      );
    });
  });

  // ===========================================================================
  // 5. JadeChatScreen — message history renders
  // ===========================================================================

  group('JadeChatScreen — seeded message history', () {
    /// Wire up the jade dependencies the screen needs:
    ///   - jadeChatRepositoryProvider → _FakeJadeChatRepository
    ///   - contentServiceProvider     → _FakeContentService
    ///   - appLoggerProvider          → _FakeLogger
    List<Override> _jadeOverrides({
      List<JadeConversation> conversations = const [],
      Map<String, List<JadeMessage>> messagesByConversation = const {},
    }) {
      return [
        jadeChatRepositoryProvider.overrideWithValue(
          _FakeJadeChatRepository(
            conversations: conversations,
            messagesByConversation: messagesByConversation,
          ),
        ),
        contentServiceProvider.overrideWithValue(_FakeContentService()),
        appLoggerProvider.overrideWithValue(_FakeLogger()),
      ];
    }

    testWidgets('renders empty state with greeting when no history', (
      tester,
    ) async {
      // NOTE: settle: false — the empty state triggers _maybeRequestOpener()
      // which starts a fake streaming sequence. The _TypingIndicator has a
      // repeating AnimationController so pumpAndSettle never settles. Pump
      // many small frames to flush microtasks + post-frame callbacks without
      // relying on settle.
      await pumpSeeded(
        tester,
        const JadeChatScreen(),
        overrides: _jadeOverrides(),
        settle: false,
      );
      // Flush the async build() + opener stream + post-frame callbacks.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // The FakeContentService returns the defaultValue for every key.
      // jade.empty_greeting default = "Hey, I'm Jade"
      expect(
        find.textContaining("Hey, I'm Jade"),
        findsOneWidget,
        reason: 'Empty greeting must appear when no conversation history',
      );
    });

    testWidgets('renders input hint text', (tester) async {
      // settle: false — repeating AnimationController in empty state prevents
      // pumpAndSettle from completing. See note above.
      await pumpSeeded(
        tester,
        const JadeChatScreen(),
        overrides: _jadeOverrides(),
        settle: false,
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // jade.input_hint default = "Ask Jade anything…"
      expect(
        find.textContaining('Ask Jade anything'),
        findsOneWidget,
        reason: 'Input hint must appear in the text field',
      );
    });

    testWidgets('renders user message bubble from seeded history', (
      tester,
    ) async {
      final now = DateTime.now();
      final conversation = JadeConversation(
        id: 'conv-test',
        title: 'Test chat',
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now,
        isDeleted: false,
      );
      final messages = [
        JadeMessage(
          id: 'msg-u1',
          conversationId: 'conv-test',
          role: JadeMessageRole.user,
          content: 'How many carbs before a long run?',
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        JadeMessage(
          id: 'msg-a1',
          conversationId: 'conv-test',
          role: JadeMessageRole.assistant,
          content: 'For a run over 90 minutes, aim for 1-4g/kg.',
          createdAt: now.subtract(const Duration(minutes: 4)),
        ),
      ];

      await pumpSeeded(
        tester,
        const JadeChatScreen(),
        overrides: _jadeOverrides(
          conversations: [conversation],
          messagesByConversation: {'conv-test': messages},
        ),
        settle: true,
      );

      expect(
        find.text('How many carbs before a long run?'),
        findsOneWidget,
        reason: 'User message content must appear in the chat list',
      );
    });

    testWidgets('renders assistant message bubble from seeded history', (
      tester,
    ) async {
      final now = DateTime.now();
      final conversation = JadeConversation(
        id: 'conv-test',
        title: 'Test chat',
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      );
      final messages = [
        JadeMessage(
          id: 'msg-a1',
          conversationId: 'conv-test',
          role: JadeMessageRole.assistant,
          content: 'For a run over 90 minutes, aim for 1-4g/kg.',
          createdAt: now,
        ),
      ];

      await pumpSeeded(
        tester,
        const JadeChatScreen(),
        overrides: _jadeOverrides(
          conversations: [conversation],
          messagesByConversation: {'conv-test': messages},
        ),
        settle: true,
      );

      expect(
        find.text('For a run over 90 minutes, aim for 1-4g/kg.'),
        findsOneWidget,
        reason: 'Assistant message content must appear in the chat list',
      );
    });

    testWidgets('renders both user and assistant messages in order', (
      tester,
    ) async {
      final now = DateTime.now();
      final conversation = JadeConversation(
        id: 'conv-order',
        title: '',
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      );
      final messages = [
        JadeMessage(
          id: 'msg-u1',
          conversationId: 'conv-order',
          role: JadeMessageRole.user,
          content: 'How many carbs before a long run?',
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        JadeMessage(
          id: 'msg-a1',
          conversationId: 'conv-order',
          role: JadeMessageRole.assistant,
          content: 'For a run over 90 minutes, aim for 1-4g/kg.',
          createdAt: now.subtract(const Duration(minutes: 4)),
        ),
      ];

      await pumpSeeded(
        tester,
        const JadeChatScreen(),
        overrides: _jadeOverrides(
          conversations: [conversation],
          messagesByConversation: {'conv-order': messages},
        ),
        settle: true,
      );

      expect(find.text('How many carbs before a long run?'), findsOneWidget);
      expect(
        find.text('For a run over 90 minutes, aim for 1-4g/kg.'),
        findsOneWidget,
      );
    });

    testWidgets('Jade name appears in app bar from content service', (
      tester,
    ) async {
      // settle: false — repeating AnimationController in empty state prevents
      // pumpAndSettle from completing. See note above.
      // jade.coach_name defaultValue = 'Jade'
      await pumpSeeded(
        tester,
        const JadeChatScreen(),
        overrides: _jadeOverrides(),
        settle: false,
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        find.text('Jade'),
        findsWidgets,
        reason:
            'Coach name from ContentService must appear in the AppBar title',
      );
    });

    testWidgets('suggested prompt chips render on empty state', (tester) async {
      // settle: false — repeating AnimationController in empty state prevents
      // pumpAndSettle from completing. See note above.
      // NOTE: The empty state only renders if _maybeRequestOpener produced no
      // content (opener returns JadeDoneEvent immediately with empty content,
      // so the placeholder is dropped and the static empty state is shown).
      await pumpSeeded(
        tester,
        const JadeChatScreen(),
        overrides: _jadeOverrides(),
        settle: false,
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // jade.suggested_prompt_plan_day default = 'Plan my day'
      expect(
        find.text('Plan my day'),
        findsOneWidget,
        reason: 'Suggested prompt chip must appear in the empty state',
      );
    });
  });
}
