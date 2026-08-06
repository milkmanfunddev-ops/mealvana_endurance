import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/carbs_per_hour_summary.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/fuel_log_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/carbs_per_hour_providers.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/fuel_log/carbs_per_hour_card.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

/// Regression cover for Bug Reports 3b4e3fdb… — the CARBS/HR card announced
/// "Your carb trend is ready." while still rendering the baseline progress
/// dots, because the service gated the trend on *prior* efforts only while the
/// card counts the current session. The two must never disagree: the "ready"
/// copy and the "Building baseline" progress row can never co-render.
final _activity = Activity(
  id: 'a1',
  userId: 'u1',
  activityType: ActivityType.running,
  title: 'Long Run',
  scheduledDateTime: DateTime(2026, 8, 3, 7),
  durationMinutes: 120,
  createdAt: DateTime(2026, 8, 2),
  updatedAt: DateTime(2026, 8, 3),
);

final _fuelLog = FuelLogData(
  items: [
    FuelLogItem(
      foodId: 'gel',
      sectionId: 'during_run',
      plannedQuantity: 1,
      actualQuantity: 1,
      name: 'Gel',
      nutritionalInfo: NutritionalInfo(carbs: 100),
    ),
  ],
);

Widget _card(CarbsPerHourBaseline baseline) {
  return ProviderScope(
    overrides: [
      carbsPerHourBaselineProvider.overrideWith((ref, arg) async => baseline),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CarbsPerHourCard(activity: _activity, fuelLog: _fuelLog),
        ),
      ),
    ),
  );
}

/// Pump the card, ignoring RenderFlex overflow. The card's fixed-width readout
/// overflows under the test font's metrics, which is unrelated to the copy this
/// test asserts on.
Future<void> _pumpCard(WidgetTester tester, CarbsPerHourBaseline baseline) async {
  bool isOverflow(String s) =>
      s.contains('overflowed') || s.contains('infinite size');

  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!isOverflow(details.exceptionAsString())) previousOnError?.call(details);
  };
  try {
    await tester.pumpWidget(_card(baseline));
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = previousOnError;
  }

  for (
    dynamic e = tester.takeException();
    e != null;
    e = tester.takeException()
  ) {
    if (!isOverflow(e.toString())) fail('Unexpected error: $e');
  }
}

void main() {
  testWidgets(
    'at 3 priors the card renders the trend, never "ready" copy beside the dots',
    (tester) async {
      await _pumpCard(
        tester,
        const CarbsPerHourBaseline(history: [50, 55, 60], count: 3),
      );

      expect(find.text('Your carb trend is ready.'), findsNothing);
      expect(find.text('Building baseline'), findsNothing);
      expect(find.text('In Baseline'), findsOneWidget);
    },
  );

  testWidgets('below the boundary the card shows progress without the payoff', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      const CarbsPerHourBaseline(history: [50, 55], count: 2),
    );

    expect(find.text('Building baseline'), findsOneWidget);
    expect(find.text('Your carb trend is ready.'), findsNothing);
    expect(find.text('3 / 4 Runs'), findsOneWidget);
  });
}
