// Golden conformance — workout-card number states.
// Manifest: docs/ssot/conformance/design/workout-card-states.goldens.yaml
// (RATIFIED; Q-DID1 RULED 2026-09-11: one row, measured-only when
// verified). Rendering:
// docs/ssot/spec/design/renderings/workout-card-states@v1.html.
//
// Producer→consumer discipline: every card's data goes through the REAL
// MacroDashboardAssembler (state via resolveWorkoutCardState, meta via the
// D-1 pair rule) from seeded domain Activities — the goldens pin the same
// derivation the app ships, not hand-built card data. The brick goldens
// render the REAL TimelineBrickTile (one row per leg, order badges, and the
// D-1b dashed-at-creation outline this bundle fixed).
//
// Invariants pinned:
//   * one row of duration+distance per card, always
//   * never a mixed pair: verified shows the MEASURED family only; planned/
//     skipped/self-reported show the PLANNED family only (DI-DEV-1 guard)
//
// Regenerate with --update-goldens ONLY after a design-spec change.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_metadata.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/widgets/timeline_brick_tile.dart';
import 'package:mealvana_endurance/features/macro_dashboard/application/dashboard_assembler.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/macro_dashboard/domain/dashboard_models.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/widgets/workout_card.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

import '../home_shell/home_shell_test_fonts.dart';

final _day = DateTime(2026, 9, 10);
final _now = DateTime(2026, 9, 10, 20);

Activity _run({
  required String id,
  ActivityStatus status = ActivityStatus.planned,
  DateTime? actualTime,
  String? garminSummaryId,
  int? actualDurationMinutes,
  double? actualDistanceMiles,
}) =>
    Activity(
      id: id,
      userId: 'u1',
      activityType: ActivityType.running,
      title: 'Morning Run',
      scheduledDateTime: DateTime(2026, 9, 10, 7),
      plannedTime: DateTime(2026, 9, 10, 7),
      status: status,
      durationMinutes: 60,
      distanceMiles: 8.0,
      actualTime: actualTime,
      garminSummaryId: garminSummaryId,
      actualDurationMinutes: actualDurationMinutes,
      actualDistanceMiles: actualDistanceMiles,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 10),
    );

WorkoutCardData _cardData(Activity a) {
  const assembler = MacroDashboardAssembler();
  final data = assembler.assemble(
    selectedDate: _day,
    now: _now,
    activities: [a],
    meals: const [],
    targets: null,
    consumed: const ConsumedTotals(),
    profileWeightKg: 75,
    trackingOn: false,
  );
  final workoutNode = data.nodes.singleWhere((n) => n.isWorkout);
  return workoutNode.workout!;
}

Widget _frame(Widget child) => ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF2D1535),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );

BrickMetadata _brickMeta({bool stamped = false}) => BrickMetadata.fromJson({
      'segment_order': ['cycling', 'running'],
      'created_from_existing': false,
      'total_duration_minutes': 90,
      'segments': [
        {
          'sport': 'cycling',
          'order': 1,
          'duration_minutes': 60,
          'intensity': 'moderate',
          if (stamped)
            'garmin': {
              'summary_id': 'gb1',
              'start': '2026-09-10T07:00:00',
              'duration_minutes': 58,
            },
        },
        {
          'sport': 'running',
          'order': 2,
          'duration_minutes': 30,
          'intensity': 'moderate',
          if (stamped)
            'garmin': {
              'summary_id': 'gb2',
              'start': '2026-09-10T08:10:00',
              'duration_minutes': 29,
            },
        },
      ],
    });

Activity _brick({required bool verified}) => Activity(
      id: 'br1',
      userId: 'u1',
      activityType: ActivityType.brick,
      title: 'Brick',
      scheduledDateTime: DateTime(2026, 9, 10, 7),
      status:
          verified ? ActivityStatus.completed : ActivityStatus.planned,
      actualTime: verified ? DateTime(2026, 9, 10, 7) : null,
      garminSummaryId: verified ? 'gb1' : null,
      brickMetadata: _brickMeta(stamped: verified),
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 10),
    );

Widget _brickFrame(Activity brick) => ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF2D1535),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TimelineBrickTile(
                brick: brick,
                timelineOpen: false,
                onOpenBrick: () {},
                onOpenLeg: (_) {},
                onUngroup: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(loadHomeShellFonts);

  Future<void> golden(
    WidgetTester tester,
    Widget frame,
    Finder finder,
    String file,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(frame);
    await tester.pumpAndSettle();
    await expectLater(finder, matchesGoldenFile(file));
  }

  group('goldens', () {
    testWidgets('card-planned', (tester) async {
      final card = _cardData(_run(id: 'a1'));
      expect(card.state, WorkoutCardState.planned);
      expect(card.metaLabel, '8 mi · 60 min'); // planned pair
      await golden(
        tester,
        _frame(WorkoutCard(data: card)),
        find.byType(WorkoutCard),
        'goldens/workout_card_planned.png',
      );
    });

    testWidgets('card-skipped', (tester) async {
      final card = _cardData(_run(id: 'a2', status: ActivityStatus.skipped));
      expect(card.state, WorkoutCardState.skipped);
      expect(card.metaLabel, '8 mi · 60 min'); // planned values, no source
      await golden(
        tester,
        _frame(WorkoutCard(data: card)),
        find.byType(WorkoutCard),
        'goldens/workout_card_skipped.png',
      );
    });

    testWidgets('card-self-reported', (tester) async {
      // Mark-done measures nothing: PLANNED values on the card.
      final card = _cardData(_run(
        id: 'a3',
        status: ActivityStatus.completed,
        actualTime: DateTime(2026, 9, 10, 7),
      ));
      expect(card.state, WorkoutCardState.doneConfirmed);
      expect(card.metaLabel, '8 mi · 60 min');
      await golden(
        tester,
        _frame(WorkoutCard(data: card)),
        find.byType(WorkoutCard),
        'goldens/workout_card_self_reported.png',
      );
    });

    testWidgets('card-verified', (tester) async {
      // MEASURED values ONLY — never the planned 8 mi / 60 min anywhere
      // (the DI-DEV-1 mixed-pair specimen is dead).
      final card = _cardData(_run(
        id: 'a4',
        status: ActivityStatus.completed,
        actualTime: DateTime(2026, 9, 10, 6, 3),
        garminSummaryId: 'g1',
        actualDurationMinutes: 44,
        actualDistanceMiles: 5.1,
      ));
      expect(card.state, WorkoutCardState.doneVerified);
      expect(card.metaLabel, '5.1 mi · 44 min');
      expect(card.metaLabel, isNot(contains('8')));
      expect(card.metaLabel, isNot(contains('60')));
      await golden(
        tester,
        _frame(WorkoutCard(data: card)),
        find.byType(WorkoutCard),
        'goldens/workout_card_verified.png',
      );
    });

    testWidgets('brick-planned — D-1b dashed at creation', (tester) async {
      await golden(
        tester,
        _brickFrame(_brick(verified: false)),
        find.byType(TimelineBrickTile),
        'goldens/workout_card_brick_planned.png',
      );
    });

    testWidgets('brick-verified', (tester) async {
      await golden(
        tester,
        _brickFrame(_brick(verified: true)),
        find.byType(TimelineBrickTile),
        'goldens/workout_card_brick_verified.png',
      );
    });
  });
}
