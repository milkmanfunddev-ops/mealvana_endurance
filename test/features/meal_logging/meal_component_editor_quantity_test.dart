/// Edit Item keeps the quantity apart from the portion base (testing-wave
/// develop-2026-10, Finding 02-005). Before the fix, Quantity 2 was folded
/// into the portion text ("2 medium banana (~118g)") and the item reopened at
/// Quantity 1 over doubled numbers, so setting 1 changed nothing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/widgets/meal_component_editor.dart';

void main() {
  // Run 02's Review & Log items (row 40600e48…): eggs plus the banana.
  const eggs = MealComponent(
    name: 'Scrambled eggs (2 large eggs)',
    portion: '2 large eggs, scrambled',
    calories: 182,
    carbG: 1.6,
    proteinG: 12.6,
    fatG: 13.8,
    sodiumMg: 190,
  );
  const banana = MealComponent(
    name: 'Banana',
    portion: '1 medium banana (~118g)',
    calories: 105,
    carbG: 27.0,
    proteinG: 1.3,
    fatG: 0.3,
    sodiumMg: 1,
  );

  late List<MealComponent> latest;

  Widget harness() {
    latest = const [eggs, banana];
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MealComponentEditor(
            initialComponents: const [eggs, banana],
            onComponentsChanged: (c) => latest = c,
          ),
        ),
      ),
    );
  }

  Finder field(String label) => find.widgetWithText(TextField, label);
  String valueOf(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!.text;

  Future<void> openBanana(WidgetTester tester) async {
    await tester.tap(find.text('Banana'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Item'), findsOneWidget);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  bool rowReads(String start) => find
      .byWidgetPredicate(
        (w) => w is Text && (w.data?.startsWith(start) ?? false),
      )
      .evaluate()
      .isNotEmpty;

  testWidgets('Quantity 2 round-trips over the original portion base', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    expect(find.textContaining('287 kcal'), findsOneWidget);

    await openBanana(tester);
    expect(valueOf(tester, 'Quantity'), '1');
    await tester.enterText(field('Quantity'), '2');
    await tester.pump();
    await save(tester);

    expect(rowReads('2 × 1 medium banana (~118g)  ·  210 kcal'), isTrue);
    expect(latest.last.quantity, 2.0);
    expect(latest.last.portion, '1 medium banana (~118g)');
    expect(latest.last.calories, 210);
    expect(find.textContaining('392 kcal'), findsOneWidget);

    // Reopen: Quantity 2 over the AI's portion, the fields show what was eaten.
    await openBanana(tester);
    expect(valueOf(tester, 'Quantity'), '2');
    expect(valueOf(tester, 'Portion'), '1 medium banana (~118g)');
    expect(valueOf(tester, 'Calories'), '210');
    expect(valueOf(tester, 'Carbs (g)'), '54.0');
    expect(valueOf(tester, 'Protein (g)'), '2.6');
    expect(valueOf(tester, 'Fat (g)'), '0.6');

    // Setting 1 puts it back.
    await tester.enterText(field('Quantity'), '1');
    await tester.pump();
    expect(valueOf(tester, 'Calories'), '105');
    await save(tester);

    expect(rowReads('1 medium banana (~118g)  ·  105 kcal'), isTrue);
    expect(find.textContaining('× 1 medium banana'), findsNothing);
    expect(latest.last.quantity, 1.0);
    expect(latest.last.toJson().containsKey('quantity'), isFalse);
    expect(find.textContaining('287 kcal'), findsOneWidget);
  });

  testWidgets('a manual Portion edit at Quantity 1 is saved verbatim', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await openBanana(tester);

    await tester.enterText(field('Portion'), '1 large banana (~136g)');
    await tester.pump();
    await save(tester);

    expect(latest.last.portion, '1 large banana (~136g)');
    expect(latest.last.quantity, 1.0);
    expect(rowReads('1 large banana (~136g)  ·  105 kcal'), isTrue);
  });
}
