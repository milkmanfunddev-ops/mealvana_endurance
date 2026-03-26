import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/carb_adjustment_level.dart';

void main() {
  test('ratingValue maps both directions for all levels', () {
    for (final level in CarbAdjustmentLevel.values) {
      final mapped = CarbAdjustmentLevel.fromRatingValue(level.ratingValue);
      expect(mapped, level);
    }

    expect(CarbAdjustmentLevel.fromRatingValue(null), isNull);
    expect(CarbAdjustmentLevel.fromRatingValue(0), isNull);
    expect(CarbAdjustmentLevel.fromRatingValue(6), isNull);
  });
}
