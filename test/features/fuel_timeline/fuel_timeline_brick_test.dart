// Brick-workout grouping on the Fuel Timeline.
//
// Rewritten for the brick redesign (Notion 3a7e3fdb, Xuan 2026-07-27). The
// pinned contract is now the redesigned flow, not the ported one:
//
// - The Brick entry is a third pill in the ADD ROW (after a divider, with a
//   chain icon), not a standalone "Create Brick" button above it. It appears
//   only when 2+ adjacent, brick-eligible workouts of different sports exist.
// - Tapping it swaps the add row for "Pick legs to link … Cancel"; rows stay
//   on the timeline rail rather than becoming full-width ActivityCards.
// - A created brick renders as a TimelineBrickTile — one time-dot on the rail
//   with its legs in an indented bracket — so the rail is never severed.
//
// Fixtures use TODAY's date because the screen resolves brick availability
// against calendarSelectedDateProvider, which defaults to today.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_metadata.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/widgets/timeline_brick_tile.dart';
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

  // The pill lives in the add row and is keyed, so find it by key rather than
  // by a label that also appears elsewhere.
  final brickPill = find.byKey(const ValueKey('fuel_timeline.create_brick'));

  testWidgets(
    'two adjacent activities of different sports show the Brick pill',
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

      expect(brickPill, findsOneWidget);
    },
  );

  testWidgets('two same-day activities of the SAME sport show no pill', (
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

    expect(brickPill, findsNothing);
  });

  testWidgets('tapping Brick enters leg-picking mode', (tester) async {
    final result = resultWith([
      activity('run1', ActivityType.running, 8),
      activity('ride1', ActivityType.cycling, 16),
    ]);
    await smokeScreen(
      tester,
      const FuelTimelineScreen(),
      overrides: overridesFor(result),
    );

    await tester.tap(brickPill);
    await tester.pumpAndSettle();

    // The pick bar takes over the add row's slot.
    expect(brickPill, findsNothing);
    expect(find.text('Pick legs to link'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Nothing is picked yet, so the LEG ORDER panel stays hidden — it would
    // otherwise dock an empty panel over the timeline.
    expect(find.text('LEG ORDER'), findsNothing);

    // Cancel returns to the add row.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(brickPill, findsOneWidget);
    expect(find.text('Pick legs to link'), findsNothing);
  });

  testWidgets('a created brick renders as a TimelineBrickTile on the rail', (
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

    expect(find.byType(TimelineBrickTile), findsOneWidget);
    expect(find.text('BRICK'), findsOneWidget);
    // Header summarises the legs rather than repeating the activity title.
    expect(find.text('2 legs · 90 min'), findsOneWidget);
    // The regular workout tile would show the uppercased title — it must not.
    expect(find.text('BRICK1 WORKOUT'), findsNothing);
  });
}
