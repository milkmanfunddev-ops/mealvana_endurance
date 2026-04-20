import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_target_overrides.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  group('NutritionTargetOverrides.toBrickEdgeFunctionPayload', () {
    test('includes sport-specific keys and legacy global keys', () {
      const overrides = NutritionTargetOverrides(
        pre: PreActivityOverrides(carbsG: 50),
        during: DuringActivityOverrides(carbRateGPerH: 75),
        duringRun: DuringActivityOverrides(carbRateGPerH: 30),
        duringCycling: DuringActivityOverrides(carbRateGPerH: 120),
        duringSwimming: DuringActivityOverrides(carbRateGPerH: 45),
        post: PostActivityOverrides(carbsG: 80),
      );

      final payload = overrides.toBrickEdgeFunctionPayload(
        sports: const {ActivityType.running, ActivityType.cycling},
      );

      expect(payload['pre_carbs_g'], 50);
      expect(payload['post_carbs_g'], 80);

      // For brick legacy/global key, bike takes precedence in getDuring(brick).
      expect(payload['during_carb_rate_g_per_h'], 120);

      expect(payload['running_carb_rate_g_per_h'], 30);
      expect(payload['cycling_carb_rate_g_per_h'], 120);
      expect(payload.containsKey('swimming_carb_rate_g_per_h'), isFalse);
    });
  });
}
