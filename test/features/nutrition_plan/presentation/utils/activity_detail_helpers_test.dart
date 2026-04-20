import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/utils/activity_detail_helpers.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

Activity _activity({
  required ActivityType type,
  int? durationMinutes,
  int? actualDurationMinutes,
}) {
  return Activity(
    id: 'a1',
    userId: 'u1',
    activityType: type,
    title: 'Session',
    scheduledDateTime: DateTime(2026, 3, 20, 7),
    durationMinutes: durationMinutes,
    actualDurationMinutes: actualDurationMinutes,
    createdAt: DateTime(2026, 3, 19),
    updatedAt: DateTime(2026, 3, 20),
  );
}

NutritionPlan _planWithDuringCarbs(double carbsTarget) {
  return NutritionPlan(
    id: 'p1',
    name: 'Plan',
    sections: [
      PlanSection(
        id: 'during_run',
        title: 'During Run',
        foodItems: const [],
        carbsTarget: carbsTarget,
      ),
    ],
  );
}

void main() {
  group('ActivityDetailHelpers.computeDuringCarbRateGPerH', () {
    test('returns carb rate for eligible workout', () {
      final rate = ActivityDetailHelpers.computeDuringCarbRateGPerH(
        activity: _activity(type: ActivityType.running, durationMinutes: 120),
        nutritionPlan: _planWithDuringCarbs(100),
      );

      expect(rate, closeTo(50.0, 0.001));
    });

    test('uses actual duration when available', () {
      final rate = ActivityDetailHelpers.computeDuringCarbRateGPerH(
        activity: _activity(
          type: ActivityType.running,
          durationMinutes: 120,
          actualDurationMinutes: 100,
        ),
        nutritionPlan: _planWithDuringCarbs(100),
      );

      expect(rate, closeTo(60.0, 0.001));
    });

    test('returns null for short workouts and swimming', () {
      final shortRate = ActivityDetailHelpers.computeDuringCarbRateGPerH(
        activity: _activity(type: ActivityType.running, durationMinutes: 80),
        nutritionPlan: _planWithDuringCarbs(100),
      );
      final swimRate = ActivityDetailHelpers.computeDuringCarbRateGPerH(
        activity: _activity(type: ActivityType.swimming, durationMinutes: 120),
        nutritionPlan: _planWithDuringCarbs(100),
      );

      expect(shortRate, isNull);
      expect(swimRate, isNull);
    });
  });
}
