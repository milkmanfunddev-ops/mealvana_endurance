// Ticket 101 (Lee's ruling 2026-09-25): a workout FinalSurge reports
// completed is final for the athlete. Its card offers no Mark undone (and no
// Skip), the same as a Garmin-verified card; an athlete's own mark-done card
// still does. The provider card is the real assembler's output for the
// transformer's row from the real 2026-09-24 payload.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_transformer.dart';
import 'package:mealvana_endurance/features/macro_dashboard/application/dashboard_assembler.dart';
import 'package:mealvana_endurance/features/macro_dashboard/domain/dashboard_models.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/widgets/workout_card.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';

import '../../fixtures/final_surge_completed_fixtures.dart';

void main() {
  const assembler = MacroDashboardAssembler();
  final day = DateTime(2026, 9, 24);

  Activity fromFeed(Map<String, dynamic> payload) =>
      const FinalSurgeTransformer().transform(payload, 'u1')!.activity;

  WorkoutCardData card(Activity a) => assembler
      .assemble(
        selectedDate: day,
        now: DateTime(2026, 9, 24, 16),
        activities: [a],
        meals: const [],
        targets: null,
        consumed: const ConsumedTotals(),
        trackingOn: true,
      )
      .nodes
      .map((n) => n.workout)
      .whereType<WorkoutCardData>()
      .single;

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 640, child: child)),
    ),
  );

  Future<void> drag(WidgetTester tester, double dx) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(WorkoutCard)),
    );
    const steps = 12;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(dx / steps, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  Future<int> swipeForUndo(WidgetTester tester, WorkoutCardData data) async {
    var undone = 0;
    await tester.pumpWidget(
      host(
        WorkoutCard(
          data: data,
          onMarkDone: () => fail('a done card must never emit mark-done'),
          onMarkUndone: () => undone++,
          onSkip: () => fail('no skip in this test'),
        ),
      ),
    );
    // Partial right-swipe: the reveal would show "Mark undone" if offered.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(WorkoutCard)),
    );
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final offered = find.text('Mark undone').evaluate().isNotEmpty;
    await gesture.up();
    await tester.pumpAndSettle();
    await drag(tester, 320);
    expect(
      offered,
      undone > 0,
      reason: 'the reveal shows Mark undone exactly when the swipe undoes',
    );
    return undone;
  }

  testWidgets('a FinalSurge-completed card offers no Mark undone', (
    tester,
  ) async {
    final c = card(fromFeed(fsCompletedEasy));
    expect(c.completionFinal, isTrue);
    expect(await swipeForUndo(tester, c), 0);
  });

  testWidgets(
    'a provider completion that reads self-reported (no verified chip) is '
    'still final: no Mark undone, no Skip',
    (tester) async {
      // e.g. a brick the platform completed without every leg stamp (B-3
      // keeps it DONE_CONFIRMED); the completion is still the platform's.
      final c = WorkoutCardData(
        activityId: 'b1',
        name: 'Brick',
        timeLabel: '5:30 AM',
        metaLabel: '90 min',
        kcal: 900,
        state: WorkoutCardState.doneConfirmed,
        sport: 'running',
        completionFinal: true,
      );
      expect(await swipeForUndo(tester, c), 0);
      await drag(tester, -120);
      expect(find.text('Skip'), findsNothing);
    },
  );

  testWidgets('an athlete mark-done card still offers Mark undone', (
    tester,
  ) async {
    final marked = fromFeed(fsEasyWithoutCompletion()).copyWith(
      status: ActivityStatus.completed,
      actualTime: DateTime(2026, 9, 24, 5, 32),
    );
    final c = card(marked);
    expect(c.state, WorkoutCardState.doneConfirmed);
    expect(c.completionFinal, isFalse);
    expect(await swipeForUndo(tester, c), 1);
  });
}
