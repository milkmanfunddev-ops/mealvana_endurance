// Ticket 99 (Finding 29-002): a workout FinalSurge reports done reads
// DONE_VERIFIED with the measured values (integrations-data-display.md D-1,
// Q-DID1 B: measured only), not "8 mi · Planned". The rows are the transformer
// output for the two real payloads from runs/29 (the producer's shape as
// stored), fed through the real assembler.
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_transformer.dart';
import 'package:mealvana_endurance/features/macro_dashboard/application/dashboard_assembler.dart';
import 'package:mealvana_endurance/features/macro_dashboard/domain/dashboard_models.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';

import '../../../fixtures/final_surge_completed_fixtures.dart';

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

  test('"Easy" (planned 8 mi) shows done and verified with 3.5 mi · 34 min', () {
    final c = card(fromFeed(fsCompletedEasy));
    expect(c.state, WorkoutCardState.doneVerified);
    expect(c.chipLabel, 'verified · Final Surge');
    expect(c.metaLabel, '3.5 mi · 34 min');
  });

  test('"Run" shows done and verified with its measured 3.9 mi · 36 min', () {
    final c = card(fromFeed(fsCompletedRun));
    expect(c.state, WorkoutCardState.doneVerified);
    expect(c.metaLabel, '3.9 mi · 36 min');
  });

  test('the plan-only payload still reads Planned with the planned 8 mi', () {
    final c = card(fromFeed(fsEasyWithoutCompletion()));
    expect(c.state, WorkoutCardState.planned);
    expect(c.metaLabel, '8 mi');
  });

  test('a Garmin stamp on the same row still reads verified · Garmin', () {
    final garmin = fromFeed(fsCompletedEasy).copyWith(garminSummaryId: 'g-1');
    expect(card(garmin).chipLabel, 'verified · Garmin');
  });

  test('an athlete mark-done on an FS row stays self-reported', () {
    final marked = fromFeed(fsEasyWithoutCompletion()).copyWith(
      status: ActivityStatus.completed,
      actualTime: DateTime(2026, 9, 24, 5, 32),
    );
    expect(card(marked).state, WorkoutCardState.doneConfirmed);
  });

  test('a completion reported without measurements keeps the planned pair', () {
    final flagOnly = fromFeed({
      ...fsCompletedEasy,
      'ActualTime': null,
      'ActualDistanceMeters': null,
    });
    final c = card(flagOnly);
    expect(c.state, WorkoutCardState.doneVerified);
    expect(c.metaLabel, '8 mi');
  });
}
