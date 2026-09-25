/// Testing-wave 18-005: a ticked Add on a Browse card had no accessibility
/// element, so VoiceOver could not tell which meals were already added.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_add_button.dart';

void main() {
  const key = ValueKey('add');

  Future<void> pump(WidgetTester tester, {required bool added}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MealAddButton(
                key: key,
                added: added,
                tooltip: added ? 'Added' : 'Add to plan',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

  testWidgets('an unticked Add is a button named by its tooltip', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, added: false);

    expect(
      tester.getSemantics(find.byKey(key)),
      isSemantics(label: 'Add to plan', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('a ticked Add is still a button, labelled as added', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, added: true);

    expect(
      tester.getSemantics(find.byKey(key)),
      isSemantics(label: 'Added', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('a ticked Add with no handler is still an element', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: MealAddButton(key: key, added: true, tooltip: 'Added'),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byKey(key)),
      isSemantics(label: 'Added', isButton: true),
    );
    handle.dispose();
  });
}
