import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/fuel_log_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/fuel_log/fuel_log_section_widget.dart';

// Regression test for Bug 3a3e3fdb-754c-8101-adb0-d2471b0d4bb5:
// "Fuel logging: 'Food added' confirmation shows but the food is not added"
//
// Read-path half of the bug: FuelLogSectionWidget grouped items strictly by
// sub-phase when subPhaseGroups was provided, so any FuelLogItem with a
// null/unmatched subPhaseType (i.e. foods added via the section-level ADD
// FOOD button) was silently dropped from the render. The fix adds a trailing
// "Added" bucket for those items.

FuelLogItem _item({
  required String foodId,
  required String name,
  String? subPhaseType,
  bool isAdded = false,
  double planned = 1,
  double actual = 1,
}) {
  return FuelLogItem(
    foodId: foodId,
    sectionId: 'before_run',
    subPhaseType: subPhaseType,
    plannedQuantity: planned,
    actualQuantity: actual,
    name: name,
    isAdded: isAdded,
  );
}

Widget _harness({
  required List<FuelLogItem> items,
  required Map<String, List<FuelLogItem>> subPhaseGroups,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FuelLogSectionWidget(
            sectionId: 'before_run',
            title: 'Before Run',
            items: items,
            sectionColor: Colors.orange,
            subPhaseGroups: subPhaseGroups,
            onIncrement: (_, __) {},
            onDecrement: (_, __) {},
            onAddFood: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Bug 3a3e3fdb — FuelLogSectionWidget with sub-phase groups', () {
    testWidgets(
      'renders an item with null subPhaseType in a trailing Added bucket '
      'instead of dropping it',
      (tester) async {
        final mealItem = _item(
          foodId: 'oatmeal-1',
          name: 'Oatmeal',
          subPhaseType: 'meal',
        );
        // A food added via the section-level ADD FOOD flow has no sub-phase.
        final addedItem = _item(
          foodId: 'waffle-1',
          name: 'Honey Waffle',
          isAdded: true,
          planned: 0,
        );

        await tester.pumpWidget(
          _harness(
            items: [mealItem, addedItem],
            subPhaseGroups: {
              'meal': [mealItem],
            },
          ),
        );

        // Grouped item renders exactly once.
        expect(find.text('Oatmeal'), findsOneWidget);

        // THE regression: pre-fix the added item was never rendered because
        // the grouped render only iterated subPhaseGroups.
        expect(find.text('Honey Waffle'), findsOneWidget);

        // The bucket header is present. (The row itself also carries an
        // 'Added' status label, hence findsWidgets rather than one.)
        expect(find.text('Added'), findsWidgets);
      },
    );

    testWidgets(
      'renders an item whose subPhaseType matches no rendered group',
      (tester) async {
        final mealItem = _item(
          foodId: 'oatmeal-1',
          name: 'Oatmeal',
          subPhaseType: 'meal',
        );
        final orphanItem = _item(
          foodId: 'gel-1',
          name: 'Orphan Gel',
          subPhaseType: 'legacy_phase',
        );

        await tester.pumpWidget(
          _harness(
            items: [mealItem, orphanItem],
            subPhaseGroups: {
              'meal': [mealItem],
            },
          ),
        );

        expect(find.text('Orphan Gel'), findsOneWidget);
      },
    );

    testWidgets(
      'shows no Added bucket header when every item belongs to a group',
      (tester) async {
        final mealItem = _item(
          foodId: 'oatmeal-1',
          name: 'Oatmeal',
          subPhaseType: 'meal',
        );
        final snackItem = _item(
          foodId: 'banana-1',
          name: 'Banana',
          subPhaseType: 'snack',
        );

        await tester.pumpWidget(
          _harness(
            items: [mealItem, snackItem],
            subPhaseGroups: {
              'meal': [mealItem],
              'snack': [snackItem],
            },
          ),
        );

        expect(find.text('Oatmeal'), findsOneWidget);
        expect(find.text('Banana'), findsOneWidget);
        expect(find.text('Added'), findsNothing);
      },
    );
  });
}
