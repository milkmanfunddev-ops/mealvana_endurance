// Ticket 99 (Finding 29-002): a completed FinalSurge workout is stored as
// completed with the measured values, and the planned fields keep the plan.
// Fed the two real payloads from runs/29 (producer-shaped wire maps), never
// the transformer's own output.
//
// Spec: docs/ssot/spec/integrations/final-surge-completion.PROPOSED.md
// (app-side, awaiting Xuan), citing FS-2.1 and M-1.3.
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_transformer.dart';
import 'package:mealvana_endurance/features/integrations/domain/final_surge_defaults.dart';

import '../../fixtures/final_surge_completed_fixtures.dart';

void main() {
  const transformer = FinalSurgeTransformer();
  const userId = 'u1';

  group('completed payload "Easy" (planned 8 mi, ran 3.5 mi)', () {
    late Activity a;
    late FinalSurgeTransformResult result;

    setUp(() {
      result = transformer.transform(fsCompletedEasy, userId)!;
      a = result.activity;
    });

    test('is stored as completed by the provider', () {
      expect(result.providerReportsCompletion, isTrue);
      expect(a.status, ActivityStatus.completed);
      expect(a.completionType, Activity.providerCompletionType);
    });

    test('carries the measured values in actual_*', () {
      // 2021.254 s -> 33.7 min; 5704.1698 m -> 3.54 mi.
      expect(a.actualDurationMinutes, 34);
      expect(a.actualDistanceMiles, closeTo(3.544, 0.001));
    });

    test('actual_time is the recorded start on the naive local day', () {
      expect(a.actualTime, DateTime(2026, 9, 24, 5, 32));
      expect(a.actualTime!.isUtc, isFalse);
      expect(a.scheduledDateTime, DateTime(2026, 9, 24, 5, 32));
      // Completed when the run ended: start + ActualTime.
      expect(
        a.completedAt,
        DateTime(2026, 9, 24, 5, 32).add(const Duration(seconds: 2021)),
      );
    });

    test('planned fields keep the plan: 8 mi, no ActualTime as duration', () {
      expect(a.distanceMiles, 8.0);
      // FS-2.3: distance/pace present and no PlannedTime -> NULL duration.
      expect(a.durationMinutes, isNull);
      // Pace from the description range, not from the actuals.
      expect(a.paceMinMinutesPerMile, closeTo(8.75, 0.001));
    });
  });

  group('completed payload "Run" (no plan at all, ran 3.9 mi)', () {
    late Activity a;

    setUp(() => a = transformer.transform(fsCompletedRun, userId)!.activity);

    test('is stored as completed with the measured values', () {
      expect(a.status, ActivityStatus.completed);
      expect(a.completionType, Activity.providerCompletionType);
      expect(a.actualDurationMinutes, 36);
      expect(a.actualDistanceMiles, closeTo(3.864, 0.001));
      expect(a.actualTime, DateTime(2026, 9, 24, 7, 28));
    });

    test('actuals never fill the planned fields', () {
      expect(a.distanceMiles, isNot(closeTo(3.864, 0.01)));
      expect(a.durationMinutes, isNot(36));
      // No plan: the same sport defaults as any empty FS plan.
      expect(a.distanceMiles, FinalSurgeDefaults.runningDistanceMiles);
      expect(a.durationMinutes, FinalSurgeDefaults.runningDurationMinutes);
    });
  });

  test('the plan-only payload stays planned with no actuals', () {
    final result = transformer.transform(fsEasyWithoutCompletion(), userId)!;
    final a = result.activity;
    expect(result.providerReportsCompletion, isFalse);
    expect(a.status, ActivityStatus.planned);
    expect(a.completionType, isNull);
    expect(a.completedAt, isNull);
    expect(a.actualTime, isNull);
    expect(a.actualDistanceMiles, isNull);
    expect(a.actualDurationMinutes, isNull);
    expect(a.distanceMiles, 8.0);
    expect(a.scheduledDateTime, DateTime(2026, 9, 24, 5, 32));
  });
}
