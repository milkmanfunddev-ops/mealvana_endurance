// Behavior test for the quantity→nutrient scaling on the image-recognition
// Edit panel (Feature Request 390e3fdb, amended by bug 39fe3fdb). Editing the
// Quantity field on an item's Edit dialog must scale every macro
// proportionally while the Portion label stays at the unit portion — the
// quantity is communicated by the Quantity field, not by rewriting the
// portion text. On save, the quantity IS folded into the persisted portion
// (the portion string is the only place quantity is stored), so saved items
// carry the eaten amount exactly as before.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/meal_logging/domain/meal_analysis_result.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/widgets/meal_component_editor.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/widgets/meal_items_editor.dart';

Finder _fieldByLabel(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );

String _controllerText(WidgetTester tester, String label) =>
    (tester.widget(_fieldByLabel(label)) as TextField).controller!.text;

void main() {
  testWidgets('editing quantity scales macros but not the Portion label', (
    tester,
  ) async {
    List<MealAnalysisItem>? reported;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MealItemsEditor(
              initialItems: const [
                MealAnalysisItem(
                  name: 'Rice',
                  portion: '1 cup',
                  calories: 200,
                  carbG: 45,
                  proteinG: 4,
                  fatG: 1,
                  sodiumMg: 10,
                ),
              ],
              onItemsChanged: (items) => reported = items,
            ),
          ),
        ),
      ),
    );

    // Open the per-item Edit dialog.
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    expect(_controllerText(tester, 'Quantity'), '1');
    expect(_controllerText(tester, 'Portion'), '1 cup');

    // Double the quantity → every macro doubles, but the Portion label keeps
    // showing the unit portion (bug 39fe3fdb).
    await tester.enterText(_fieldByLabel('Quantity'), '2');
    await tester.pump();

    expect(_controllerText(tester, 'Calories'), '400');
    expect(_controllerText(tester, 'Carbs (g)'), '90.0');
    expect(_controllerText(tester, 'Protein (g)'), '8.0');
    expect(_controllerText(tester, 'Fat (g)'), '2.0');
    expect(_controllerText(tester, 'Sodium (mg)'), '20');
    expect(_controllerText(tester, 'Portion'), '1 cup');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(reported, isNotNull);
    final item = reported!.single;
    expect(item.calories, 400);
    expect(item.carbG, 90);
    expect(item.proteinG, 8);
    expect(item.fatG, 2);
    expect(item.sodiumMg, 20);
    // The persisted portion carries the eaten amount — unchanged behavior.
    expect(item.portion, '2 cup');
  });

  testWidgets('quantity back to baseline restores macros, Portion untouched', (
    tester,
  ) async {
    List<MealAnalysisItem>? reported;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MealItemsEditor(
              initialItems: const [
                MealAnalysisItem(
                  name: 'Rice',
                  portion: '1 cup',
                  calories: 200,
                  carbG: 45,
                  proteinG: 4,
                  fatG: 1,
                  sodiumMg: 10,
                ),
              ],
              onItemsChanged: (items) => reported = items,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(_fieldByLabel('Quantity'), '2');
    await tester.pump();
    await tester.enterText(_fieldByLabel('Quantity'), '1');
    await tester.pump();

    expect(_controllerText(tester, 'Calories'), '200');
    expect(_controllerText(tester, 'Carbs (g)'), '45.0');
    expect(_controllerText(tester, 'Portion'), '1 cup');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(reported!.single.portion, '1 cup');
    expect(reported!.single.calories, 200);
  });

  testWidgets('manual Portion edit with Quantity untouched saves verbatim', (
    tester,
  ) async {
    List<MealAnalysisItem>? reported;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MealItemsEditor(
              initialItems: const [
                MealAnalysisItem(
                  name: 'Rice',
                  portion: '1 cup',
                  calories: 200,
                  carbG: 45,
                  proteinG: 4,
                  fatG: 1,
                  sodiumMg: 10,
                ),
              ],
              onItemsChanged: (items) => reported = items,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(_fieldByLabel('Portion'), '1 big cup');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Quantity untouched → no fold; the manual edit is saved verbatim.
    expect(reported!.single.portion, '1 big cup');
    expect(reported!.single.calories, 200);
  });

  testWidgets('fractional quantity scales down from the recognized portion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MealItemsEditor(
              initialItems: const [
                MealAnalysisItem(
                  name: 'Bagel',
                  portion: '2 bagels',
                  calories: 400,
                  carbG: 80,
                  proteinG: 16,
                  fatG: 4,
                  sodiumMg: 600,
                ),
              ],
              onItemsChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    // Recognized as 2 bagels; the user actually ate 1.
    expect(_controllerText(tester, 'Quantity'), '2');
    await tester.enterText(_fieldByLabel('Quantity'), '1');
    await tester.pump();

    expect(_controllerText(tester, 'Calories'), '200');
    expect(_controllerText(tester, 'Carbs (g)'), '40.0');
    // Portion label keeps the recognized portion; Quantity says what was eaten.
    expect(_controllerText(tester, 'Portion'), '2 bagels');
  });

  testWidgets('portion with no leading number still scales macros', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MealItemsEditor(
              initialItems: const [
                MealAnalysisItem(
                  name: 'Trail mix',
                  portion: 'a handful',
                  calories: 150,
                  carbG: 15,
                  proteinG: 5,
                  fatG: 9,
                  sodiumMg: 50,
                ),
              ],
              onItemsChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    // Defaults to a 1.0 baseline when the portion has no number.
    expect(_controllerText(tester, 'Quantity'), '1');
    await tester.enterText(_fieldByLabel('Quantity'), '3');
    await tester.pump();

    expect(_controllerText(tester, 'Calories'), '450');
    expect(_controllerText(tester, 'Carbs (g)'), '45.0');
    // No leading number to rewrite → portion text is left untouched.
    expect(_controllerText(tester, 'Portion'), 'a handful');
  });

  testWidgets('component editor scales known macros and leaves nulls blank', (
    tester,
  ) async {
    MealComponent? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MealComponentEditor(
              initialComponents: const [
                // Protein is unknown (null) — must stay blank after scaling.
                MealComponent(
                  name: 'Oatmeal',
                  portion: '1 cup',
                  calories: 150,
                  carbG: 27,
                  proteinG: null,
                  fatG: 3,
                  sodiumMg: 0,
                ),
              ],
              onComponentsChanged: (c) => saved = c.single,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Edit item'));
    await tester.pumpAndSettle();

    await tester.enterText(_fieldByLabel('Quantity'), '2');
    await tester.pump();

    expect(_controllerText(tester, 'Calories'), '300');
    expect(_controllerText(tester, 'Carbs (g)'), '54.0');
    expect(_controllerText(tester, 'Protein (g)'), ''); // stays blank
    expect(_controllerText(tester, 'Portion'), '1 cup');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.calories, 300);
    expect(saved!.carbG, 54);
    expect(saved!.proteinG, isNull);
    expect(saved!.portion, '2 cup');
  });
}
