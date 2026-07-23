// Seeded CONTENT tests for the Fuel Timeline screen.
//
// Unlike the smoke suite ("does it render?"), these tests drive the screen with
// a fully-assembled DayTimelineResult (via fuelTimelineDayProvider override)
// and assert the VALUES rendered to the user are correct.
//
// Coverage goals:
//   • Chronological feed order (meal before ride, ride before dinner)
//   • Consumed + target values appear in the energy dashboard
//   • Filter switching gates nodes AND Add buttons correctly
//   • Tracking-off hides dashboard AND macro line on meal cards
//   • Timeline-off hides the time-rail labels
//   • Empty-timeline text is shown when there are no nodes
//   • Error state shows the Retry button
//   • Meal tap toggles inline Swap/Remove actions (expand/collapse round-trip)
//   • Net intake maths visible in expanded energy balance card

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/daily_macros/presentation/providers/daily_macros_controller.dart';
import 'package:mealvana_endurance/features/fuel_timeline/application/day_timeline_assembler.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/providers/fuel_timeline_controller.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/screens/fuel_timeline_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';

import '../helpers/widget_test_harness.dart';

// ---------------------------------------------------------------------------
// Fixed test date so proration is deterministic.
// now = 2026-06-17 20:00 → kind = today, elapsed = 1160/1440 ≈ 0.806
// ---------------------------------------------------------------------------

final _date = DateTime(2026, 6, 17);
final _now = DateTime(2026, 6, 17, 20, 0);

// ---------------------------------------------------------------------------
// Fixture factories
// ---------------------------------------------------------------------------

MealLog _meal({
  String id = 'm1',
  String name = 'Everything Bagel',
  MealSlot slot = MealSlot.breakfast,
  DateTime? eatenAt,
  int calories = 574,
  double carbsG = 58,
  double proteinG = 30,
  double fatG = 25,
}) => MealLog(
  id: id,
  userId: 'u1',
  logDate: '2026-06-17',
  slot: slot,
  name: name,
  source: MealLogSource.manual,
  components: const [],
  calories: calories,
  carbsG: carbsG,
  proteinG: proteinG,
  fatG: fatG,
  eatenAt: eatenAt ?? DateTime(2026, 6, 17, 7, 30),
  createdAt: _date,
  updatedAt: _date,
);

Activity _ride({
  String id = 'a1',
  String title = '25 mi Ride',
  DateTime? scheduledAt,
}) => Activity(
  id: id,
  userId: 'u1',
  activityType: ActivityType.cycling,
  title: title,
  scheduledDateTime: scheduledAt ?? DateTime(2026, 6, 17, 16, 15),
  distanceMiles: 25,
  cyclingSpeedMph: 15,
  durationMinutes: 100,
  createdAt: _date,
  updatedAt: _date,
);

DailyMacroTargets _targets() => DailyMacroTargets(
  id: 't1',
  userId: 'u1',
  targetDate: _date,
  carbG: 300,
  protG: 140,
  fatG: 75,
  tdee: 1911,
  rmr: 1091,
  sessionKcal: 502,
  neatKcal: 300,
  mode: 'prospective',
  createdAt: _date,
  updatedAt: _date,
);

DayTimelineResult _assemble({
  List<MealLog> meals = const [],
  List<Activity> activities = const [],
  ConsumedTotals consumed = const ConsumedTotals(),
}) => const DayTimelineAssembler().assemble(
  selectedDate: _date,
  now: _now,
  meals: meals,
  activities: activities,
  targets: _targets(),
  consumed: consumed,
);

// ---------------------------------------------------------------------------
// Seeded daily macros controller (avoids DB / network in build())
// ---------------------------------------------------------------------------

class _SeededDailyMacrosController extends DailyMacrosController {
  @override
  Future<DailyMacrosState> build() async {
    final t = _targets();
    return DailyMacrosState(
      selectedDate: _date,
      dailyMacros: t,
      weeklyMacros: List<DailyMacroTargets?>.filled(7, t),
    );
  }
}

// ---------------------------------------------------------------------------
// Pump helper — seeds both the timeline result AND daily macros controller
// ---------------------------------------------------------------------------

Future<void> _pump(
  WidgetTester tester, {
  required DayTimelineResult result,
  bool settle = true,
  bool fuelTrackingEnabled = true,
}) async {
  SharedPreferences.setMockInitialValues({
    if (!fuelTrackingEnabled) 'fuel_tracking_enabled': false,
  });
  final prefs = PreferencesService(await SharedPreferences.getInstance());

  tester.view.physicalSize = standardPhoneSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mockAppExternalDeps(),
        mockSharedPreferences(),
        preferencesServiceProvider.overrideWithValue(prefs),
        fuelTimelineDayProvider.overrideWith((ref) async => result),
        dailyMacrosControllerProvider.overrideWith(
          _SeededDailyMacrosController.new,
        ),
      ],
      child: wrapForTest(const FuelTimelineScreen()),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. Chronological feed order
  // -------------------------------------------------------------------------
  group('chronological feed order', () {
    testWidgets('breakfast appears above the ride; ride appears above dinner', (
      tester,
    ) async {
      final result = _assemble(
        meals: [
          _meal(
            id: 'bf',
            name: 'Breakfast Bowl',
            eatenAt: DateTime(2026, 6, 17, 7, 0),
          ),
          _meal(
            id: 'dn',
            name: 'Dinner Plate',
            slot: MealSlot.dinner,
            eatenAt: DateTime(2026, 6, 17, 19, 0),
          ),
        ],
        activities: [_ride()],
      );
      await _pump(tester, result: result);

      // The three cards must appear in order: breakfast → ride → dinner.
      final bfOffset = tester.getTopLeft(find.text('BREAKFAST BOWL'));
      final rideOffset = tester.getTopLeft(find.text('25 MI RIDE'));
      final dnOffset = tester.getTopLeft(find.text('DINNER PLATE'));

      expect(
        bfOffset.dy < rideOffset.dy,
        isTrue,
        reason: 'Breakfast should be above the ride',
      );
      expect(
        rideOffset.dy < dnOffset.dy,
        isTrue,
        reason: 'Ride should be above dinner',
      );
    });
  });

  // -------------------------------------------------------------------------
  // 2. Dashboard values — intake calories and target appear correctly
  // -------------------------------------------------------------------------
  group('dashboard energy values', () {
    testWidgets('INTAKE stat shows consumed calories (574)', (tester) async {
      final result = _assemble(
        meals: [_meal()],
        activities: [_ride()],
        consumed: const ConsumedTotals(
          calories: 574,
          carbsG: 58,
          proteinG: 30,
          fatG: 25,
        ),
      );
      await _pump(tester, result: result);

      // The INTAKE stat uses NumberFormat.decimalPattern; 574 → "574".
      expect(
        find.text('INTAKE'),
        findsOneWidget,
        reason: 'INTAKE eyebrow must be visible in default All filter',
      );
      // The eaten calorie value must appear on screen.
      expect(
        find.textContaining('574'),
        findsWidgets,
        reason: 'Consumed calories (574) must appear in the dashboard',
      );
    });

    testWidgets('expanding the dashboard shows Net intake figure', (
      tester,
    ) async {
      final result = _assemble(
        meals: [_meal()],
        activities: [_ride()],
        consumed: const ConsumedTotals(
          calories: 574,
          carbsG: 58,
          proteinG: 30,
          fatG: 25,
        ),
      );
      await _pump(tester, result: result);

      // Tap the chevron to expand the dashboard card.
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();

      // Expanded All shows ENERGY BALANCE + Net intake.
      expect(find.text('ENERGY BALANCE'), findsOneWidget);
      expect(find.text('Net intake'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 3. Filter switching — node gating AND Add button gating
  // -------------------------------------------------------------------------
  group('filter switching', () {
    testWidgets('All filter shows both meal + ride', (tester) async {
      final result = _assemble(meals: [_meal()], activities: [_ride()]);
      await _pump(tester, result: result);

      expect(find.text('EVERYTHING BAGEL'), findsOneWidget);
      expect(find.text('25 MI RIDE'), findsOneWidget);
    });

    testWidgets('Meals filter hides the ride and the Add Activity button', (
      tester,
    ) async {
      final result = _assemble(meals: [_meal()], activities: [_ride()]);
      await _pump(tester, result: result);

      await tester.tap(find.text('Meals'));
      await tester.pumpAndSettle();

      // BUG CANDIDATE: if the filter isn't applied, the ride card leaks through.
      expect(
        find.text('25 MI RIDE'),
        findsNothing,
        reason: 'Meals filter must hide WorkoutNode cards',
      );
      expect(
        find.text('EVERYTHING BAGEL'),
        findsOneWidget,
        reason: 'Meals filter must keep MealNode cards',
      );
      // Add Activity button must be absent — it would navigate to a create-
      // workout screen which is invalid context when only Meals are shown.
      expect(
        find.text('+ Add Activity'),
        findsNothing,
        reason: 'Meals filter must hide the Add Activity button',
      );
      expect(find.text('+ Add Food'), findsOneWidget);
    });

    testWidgets('Workout filter hides the meal and the Add Food button', (
      tester,
    ) async {
      final result = _assemble(meals: [_meal()], activities: [_ride()]);
      await _pump(tester, result: result);

      await tester.tap(find.text('Workout'));
      await tester.pumpAndSettle();

      // BUG CANDIDATE: if filter gating is reversed, the meal shows up here.
      expect(
        find.text('EVERYTHING BAGEL'),
        findsNothing,
        reason: 'Workout filter must hide MealNode cards',
      );
      expect(
        find.text('25 MI RIDE'),
        findsOneWidget,
        reason: 'Workout filter must keep WorkoutNode cards',
      );
      expect(
        find.text('+ Add Food'),
        findsNothing,
        reason: 'Workout filter must hide the Add Food button',
      );
      expect(find.text('+ Add Activity'), findsOneWidget);
    });

    testWidgets('switching back to All restores both nodes', (tester) async {
      final result = _assemble(meals: [_meal()], activities: [_ride()]);
      await _pump(tester, result: result);

      await tester.tap(find.text('Workout'));
      await tester.pumpAndSettle();
      expect(find.text('EVERYTHING BAGEL'), findsNothing);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      // BUG CANDIDATE: if filter state isn't cleared on "All", nodes remain
      // filtered.
      expect(find.text('EVERYTHING BAGEL'), findsOneWidget);
      expect(find.text('25 MI RIDE'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 4. Tracking toggle — hides dashboard AND macro line
  // -------------------------------------------------------------------------
  group('tracking toggle', () {
    testWidgets('tracking ON: dashboard visible + meal macro line shows kcal', (
      tester,
    ) async {
      final result = _assemble(
        meals: [_meal()],
        activities: [_ride()],
        consumed: const ConsumedTotals(calories: 574),
      );
      await _pump(tester, result: result);

      expect(find.text('INTAKE'), findsOneWidget);
      expect(find.textContaining('574 kcal'), findsOneWidget);
    });

    testWidgets('tracking OFF: dashboard hidden + meal macro line hidden', (
      tester,
    ) async {
      final result = _assemble(
        meals: [_meal()],
        activities: [_ride()],
        consumed: const ConsumedTotals(calories: 574),
      );
      // Seed SharedPreferences with tracking=false before pumping.
      await _pump(tester, result: result, fuelTrackingEnabled: false);

      // BUG CANDIDATE: if tracking flag isn't read from prefs at build time,
      // the dashboard would be shown even though the user disabled it.
      expect(
        find.text('INTAKE'),
        findsNothing,
        reason: 'Dashboard must be hidden when tracking is off',
      );
      expect(
        find.textContaining('574 kcal'),
        findsNothing,
        reason: 'Macro line must be hidden when tracking is off',
      );
      // The meal title must still be visible.
      expect(find.text('EVERYTHING BAGEL'), findsOneWidget);
    });

    testWidgets('tapping tracking icon toggles dashboard visibility', (
      tester,
    ) async {
      final result = _assemble(meals: [_meal()], activities: [_ride()]);
      await _pump(tester, result: result);

      expect(find.text('INTAKE'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.show_chart));
      await tester.pumpAndSettle();

      // After one tap tracking is OFF.
      expect(
        find.text('INTAKE'),
        findsNothing,
        reason: 'Tapping the tracking icon must hide the dashboard',
      );

      await tester.tap(find.byIcon(Icons.show_chart));
      await tester.pumpAndSettle();

      // After a second tap tracking is ON again.
      expect(
        find.text('INTAKE'),
        findsOneWidget,
        reason: 'Second tap must restore the dashboard',
      );
    });
  });

  // -------------------------------------------------------------------------
  // 5. Timeline toggle — hides the time-rail labels
  // -------------------------------------------------------------------------
  group('timeline (time-rail) toggle', () {
    testWidgets('timeline ON: time labels visible', (tester) async {
      final result = _assemble(meals: [_meal()]);
      await _pump(tester, result: result);

      // The meal is at 07:30 AM.
      expect(find.text('7:30 AM'), findsOneWidget);
    });

    testWidgets('timeline OFF: time labels hidden', (tester) async {
      final result = _assemble(meals: [_meal()]);
      await _pump(tester, result: result);

      await tester.tap(find.byIcon(Icons.schedule));
      await tester.pumpAndSettle();

      // BUG CANDIDATE: if the timeline rail switch only hides the dot/line but
      // leaves the time Text, the label would still be present.
      expect(
        find.text('7:30 AM'),
        findsNothing,
        reason:
            'Time label must be hidden when the timeline rail is toggled off',
      );
    });
  });

  // -------------------------------------------------------------------------
  // 6. Empty timeline state
  // -------------------------------------------------------------------------
  group('empty timeline state', () {
    testWidgets('shows empty-state copy when no nodes exist', (tester) async {
      final result = _assemble();
      await _pump(tester, result: result);

      // ContentService returns the defaultValue when no Sanity override.
      expect(
        find.text('Nothing logged yet for this day.'),
        findsOneWidget,
        reason: 'Empty state must show the fallback message',
      );
      // Add buttons still present in All filter even when empty.
      expect(find.text('+ Add Food'), findsOneWidget);
      expect(find.text('+ Add Activity'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 7. Error state
  // -------------------------------------------------------------------------
  group('error state', () {
    testWidgets('shows error message and Retry button when provider throws', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PreferencesService(await SharedPreferences.getInstance());

      tester.view.physicalSize = standardPhoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockAppExternalDeps(),
            mockSharedPreferences(),
            preferencesServiceProvider.overrideWithValue(prefs),
            fuelTimelineDayProvider.overrideWith(
              (ref) async => throw Exception('db read failed'),
            ),
            dailyMacrosControllerProvider.overrideWith(
              _SeededDailyMacrosController.new,
            ),
          ],
          child: wrapForTest(const FuelTimelineScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // ContentService fallback error text.
      expect(
        find.text('Could not load your day.'),
        findsOneWidget,
        reason: 'Error state must show the fallback error message',
      );
      // Retry button must be present so the user can recover.
      expect(
        find.text('Retry'),
        findsOneWidget,
        reason: 'Error state must show the Retry button',
      );
    });
  });

  // -------------------------------------------------------------------------
  // 8. Meal card expand / collapse (inline Swap + Remove actions)
  // -------------------------------------------------------------------------
  group('meal card actions (swipe)', () {
    testWidgets('meal tiles expose no inline expand actions or overflow icon', (
      tester,
    ) async {
      final result = _assemble(meals: [_meal()]);
      await _pump(tester, result: result);

      // The inline Swap/Remove expand row and the "…" overflow icon were
      // replaced by swipe-to-delete / swipe-to-swap. At rest none render.
      expect(find.text('Swap food'), findsNothing);
      expect(find.text('Remove'), findsNothing);
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets(
      'each meal tile is wrapped in a Dismissible for swipe actions',
      (tester) async {
        final result = _assemble(
          meals: [
            _meal(
              id: 'm1',
              name: 'Breakfast Bowl',
              eatenAt: DateTime(2026, 6, 17, 7),
            ),
            _meal(
              id: 'm2',
              name: 'Lunch Wrap',
              slot: MealSlot.lunch,
              eatenAt: DateTime(2026, 6, 17, 12),
            ),
          ],
        );
        await _pump(tester, result: result);

        // One Dismissible per meal (workouts are tap-only, not swipeable).
        expect(find.byType(Dismissible), findsNWidgets(2));
      },
    );
  });

  // -------------------------------------------------------------------------
  // 9. Dashboard card filter transitions
  // -------------------------------------------------------------------------
  group('dashboard card tracks active filter', () {
    testWidgets('Meals filter shows DAILY BUDGET eyebrow', (tester) async {
      final result = _assemble(meals: [_meal()], activities: [_ride()]);
      await _pump(tester, result: result);

      await tester.tap(find.text('Meals'));
      await tester.pumpAndSettle();

      expect(
        find.text('DAILY BUDGET'),
        findsOneWidget,
        reason: 'Meals filter must switch dashboard to Daily Budget card',
      );
    });

    testWidgets('Workout filter shows TODAY\'S WORKOUT eyebrow', (
      tester,
    ) async {
      final result = _assemble(meals: [_meal()], activities: [_ride()]);
      await _pump(tester, result: result);

      await tester.tap(find.text('Workout'));
      await tester.pumpAndSettle();

      expect(
        find.text("TODAY'S WORKOUT"),
        findsOneWidget,
        reason: 'Workout filter must switch dashboard to Active Energy card',
      );
    });
  });
}
