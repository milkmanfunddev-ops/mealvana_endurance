// Brick-workout grouping on the Fuel Timeline (Notion bug 3a6e3fdb…522c:
// "Brick workout function is gone"). The old activities-list screen's brick
// features were ported to the fuel timeline; these tests pin the port:
//
// - Two same-day activities of different sports → the Create Brick button
//   appears in the workout area, and tapping it enters selection mode
//   (Cancel / Confirm + selectable activity cards).
// - A brick activity renders as a BrickGroupCard instead of a regular
//   workout timeline tile.
//
// Fixtures use TODAY's date because the screen resolves brick availability
// against calendarSelectedDateProvider, which defaults to today.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_metadata.dart';
import 'package:mealvana_endurance/features/activities/presentation/widgets/activity_card.dart';
import 'package:mealvana_endurance/features/activities/presentation/widgets/brick_group_card.dart';
import 'package:mealvana_endurance/features/activities/presentation/widgets/create_brick_button.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/fuel_timeline/application/day_timeline_assembler.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/providers/fuel_timeline_controller.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/screens/fuel_timeline_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  late PreferencesService prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = PreferencesService(await SharedPreferences.getInstance());
  });

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  Activity activity(
    String id,
    ActivityType type,
    int hour, {
    BrickMetadata? brickMetadata,
  }) {
    return Activity(
      id: id,
      userId: 'u1',
      activityType: type,
      title: '$id workout',
      scheduledDateTime: DateTime(today.year, today.month, today.day, hour),
      durationMinutes: 60,
      brickMetadata: brickMetadata,
      createdAt: today,
      updatedAt: today,
    );
  }

  DailyMacroTargets targets() => DailyMacroTargets(
    id: 't1',
    userId: 'u1',
    targetDate: today,
    carbG: 300,
    protG: 140,
    fatG: 75,
    tdee: 1911,
    rmr: 1091,
    sessionKcal: 502,
    neatKcal: 300,
    mode: 'prospective',
    createdAt: today,
    updatedAt: today,
  );

  DayTimelineResult resultWith(List<Activity> activities) {
    return const DayTimelineAssembler().assemble(
      selectedDate: today,
      now: now,
      meals: const [],
      activities: activities,
      targets: targets(),
      consumed: const ConsumedTotals(),
    );
  }

  List<Override> overridesFor(DayTimelineResult result) => [
    preferencesServiceProvider.overrideWithValue(prefs),
    inMemoryDatabaseOverride(),
    fuelTimelineDayProvider.overrideWith((ref) async => result),
  ];

  testWidgets(
    'two same-day activities of different sports show Create Brick button',
    (tester) async {
      final result = resultWith([
        activity('run1', ActivityType.running, 8),
        activity('ride1', ActivityType.cycling, 16),
      ]);
      await smokeScreen(
        tester,
        const FuelTimelineScreen(),
        overrides: overridesFor(result),
      );

      expect(find.byType(CreateBrickButton), findsOneWidget);
    },
  );

  testWidgets('two same-day activities of the SAME sport show no button', (
    tester,
  ) async {
    final result = resultWith([
      activity('run1', ActivityType.running, 8),
      activity('run2', ActivityType.running, 16),
    ]);
    await smokeScreen(
      tester,
      const FuelTimelineScreen(),
      overrides: overridesFor(result),
    );

    expect(find.byType(CreateBrickButton), findsNothing);
  });

  testWidgets('tapping Create Brick enters selection mode', (tester) async {
    final result = resultWith([
      activity('run1', ActivityType.running, 8),
      activity('ride1', ActivityType.cycling, 16),
    ]);
    await smokeScreen(
      tester,
      const FuelTimelineScreen(),
      overrides: overridesFor(result),
    );

    await tester.tap(find.byType(CreateBrickButton));
    await tester.pumpAndSettle();

    // Selection controls replace the Create Brick button…
    expect(find.byType(CreateBrickButton), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Confirm (0)'), findsOneWidget);
    // …and workouts render as selectable activity cards.
    expect(find.byType(ActivityCard), findsNWidgets(2));

    // Cancel exits selection mode and restores the button.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateBrickButton), findsOneWidget);
    expect(find.byType(ActivityCard), findsNothing);
  });

  testWidgets('brick activity renders BrickGroupCard, not a workout tile', (
    tester,
  ) async {
    const metadata = BrickMetadata(
      segmentOrder: ['cycling', 'running'],
      segments: [
        BrickSegment(
          sport: 'cycling',
          order: 1,
          durationMinutes: 60,
          intensity: 'moderate',
        ),
        BrickSegment(
          sport: 'running',
          order: 2,
          durationMinutes: 30,
          intensity: 'moderate',
        ),
      ],
      originalActivityIds: ['ride1', 'run1'],
      createdFromExisting: true,
      totalDurationMinutes: 90,
    );
    final result = resultWith([
      activity('brick1', ActivityType.brick, 8, brickMetadata: metadata),
    ]);
    await smokeScreen(
      tester,
      const FuelTimelineScreen(),
      overrides: overridesFor(result),
    );

    expect(find.byType(BrickGroupCard), findsOneWidget);
    expect(find.text('BRICK'), findsOneWidget);
    // The regular workout tile would show the uppercased title — it must not.
    expect(find.text('BRICK1 WORKOUT'), findsNothing);
  });
}
