// Seeded CONTENT tests — meal-log edit and weather.
//
// Each test pumps a screen with fake seeded state and asserts rendered VALUES.
// Screens that read GoRouterState.extra use a two-route GoRouter helper.
//
// Screens covered:
//  3. EditMealLogScreen        — Fields pre-fill from a seeded MealLog extra.
//  4. WeatherDetailScreen      — Temp/humidity/conditions values render.

// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/src/internals.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/edit_meal_log_screen.dart';
import 'package:mealvana_endurance/features/weather/domain/location.dart'
    as domain;
import 'package:mealvana_endurance/features/weather/domain/weather_forecast.dart';
import 'package:mealvana_endurance/features/weather/presentation/screens/weather_detail_screen.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart'
    show UnitSystem;
import 'package:mealvana_endurance/shared/providers/unit_system_provider.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

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
// Domain builders
// =============================================================================

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

void main() {
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
}
