import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_mapper.dart';

/// D-021 (carb-loading@v1, qa 38ecb35): a server row missing its split fields
/// must hydrate at FRACTION scale — consumers compute
/// `carbTargetGrams * percent` (carb_loading_day_detail_page.dart), so a
/// legacy 16.67 default turns a 544 g day into a 9,068 g breakfast.
void main() {
  Map<String, dynamic> dayJsonWithoutSplits() => {
    'id': 'day-1',
    'carb_loading_plan_id': 'plan-1',
    'plan_date': '2026-09-25',
    'day_number': 1,
    'carb_target_grams': 544,
  };

  test('missing_split_fields_hydrate_as_fractions', () {
    final companion = CarbLoadingMapper.mapDayJsonToCompanion(
      dayJsonWithoutSplits(),
    );

    // The ruled six-slot split (spec/fueling/carb-loading.md, RATIFIED v1).
    expect(companion.breakfastPercent.value, 0.25);
    expect(companion.morningSnackPercent.value, 0.10);
    expect(companion.lunchPercent.value, 0.25);
    expect(companion.afternoonSnackPercent.value, 0.15);
    expect(companion.dinnerPercent.value, 0.20);
    expect(companion.eveningSnackPercent.value, 0.05);

    final sum =
        companion.breakfastPercent.value +
        companion.morningSnackPercent.value +
        companion.lunchPercent.value +
        companion.afternoonSnackPercent.value +
        companion.dinnerPercent.value +
        companion.eveningSnackPercent.value;
    expect(sum, closeTo(1.0, 1e-9));
  });

  test('present split fields pass through untouched', () {
    final json = dayJsonWithoutSplits()
      ..addAll({
        'breakfast_percent': 0.30,
        'morning_snack_percent': 0.05,
        'lunch_percent': 0.25,
        'afternoon_snack_percent': 0.15,
        'dinner_percent': 0.20,
        'evening_snack_percent': 0.05,
      });

    final companion = CarbLoadingMapper.mapDayJsonToCompanion(json);

    expect(companion.breakfastPercent.value, 0.30);
    expect(companion.morningSnackPercent.value, 0.05);
  });
}
