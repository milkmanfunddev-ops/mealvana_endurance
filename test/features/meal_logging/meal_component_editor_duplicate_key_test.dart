// Sentry MEALVANA-ENDURANCE-DEV-9Y / DEV-9Z (ticket 24a): "Duplicate keys
// found. Column(...) has multiple children with key [MealComponent#3c207]".
// Build-a-meal seeds its draft by copying a logged meal's components; picking
// the same meal twice put the same MealComponent instances in the list twice,
// and the editor keyed each row with ObjectKey(component).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/widgets/meal_component_editor.dart';

void main() {
  Widget harness(
    List<MealComponent> components, {
    ValueChanged<List<MealComponent>>? onChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MealComponentEditor(
            initialComponents: components,
            onComponentsChanged: onChanged ?? (_) {},
          ),
        ),
      ),
    );
  }

  // One instance, listed twice: what two copies of the same logged meal's
  // components look like in the build-a-meal draft.
  final apple = MealComponent.fromJson(const {
    'name': 'Apple',
    'portion': '1 medium',
    'calories': 95,
  });
  final peanutButter = MealComponent.fromJson(const {
    'name': 'Peanut butter',
    'portion': '2 tbsp',
    'calories': 190,
  });

  testWidgets('the same component instance twice builds without a key clash', (
    tester,
  ) async {
    await tester.pumpWidget(harness([apple, peanutButter, apple]));

    expect(tester.takeException(), isNull);
    expect(find.text('Apple'), findsNWidgets(2));
  });

  testWidgets('removing one copy leaves the other row in place', (
    tester,
  ) async {
    List<MealComponent>? latest;
    await tester.pumpWidget(
      harness([apple, apple], onChanged: (items) => latest = items),
    );

    await tester.drag(find.text('Apple').last, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(latest, hasLength(1));
    expect(find.text('Apple'), findsOneWidget);
  });
}
