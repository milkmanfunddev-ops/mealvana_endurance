import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/widgets/meal_component_editor.dart';

/// Regression coverage for Bug 38ee3fdb — "Cannot edit quantity of a logged
/// food". The food row in MealComponentEditor had no onTap, so only the tiny
/// trailing edit icon opened the edit dialog and the row felt un-editable.
void main() {
  Widget harness(List<MealComponent> components) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MealComponentEditor(
            initialComponents: components,
            onComponentsChanged: (_) {},
          ),
        ),
      ),
    );
  }

  const components = [
    MealComponent(name: 'Blueberries', portion: '1 cup', calories: 85),
    MealComponent(name: 'Eggs', portion: '2 eggs', calories: 140),
  ];

  testWidgets('tapping the food row body opens the edit dialog', (
    tester,
  ) async {
    await tester.pumpWidget(harness(components));

    // Tap the row body via its title text, not the trailing edit icon.
    await tester.tap(find.text('Blueberries'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Item'), findsOneWidget);
    // The tapped component's values prefill the dialog.
    expect(find.widgetWithText(TextField, '1 cup'), findsOneWidget);
  });

  testWidgets('the trailing edit icon still opens the dialog', (tester) async {
    await tester.pumpWidget(harness(components));

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Edit Item'), findsOneWidget);
  });
}
