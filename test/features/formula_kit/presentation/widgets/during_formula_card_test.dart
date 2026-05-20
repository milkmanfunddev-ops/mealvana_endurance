import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_view.dart';
import 'package:mealvana_endurance/features/formula_kit/presentation/widgets/during_formula_card.dart';

DuringFormulaView _fixture({
  int templateNumber = 7,
  String formula = 'Gel + Water',
  List<String> components = const ['Gel', 'Water'],
  List<String> activities = const ['cycling'],
  List<String> durations = const ['90-150 min'],
}) {
  return DuringFormulaView(
    id: 'fixture',
    templateNumber: templateNumber,
    name: 'Test',
    formula: formula,
    foodForm: 'liquid',
    activityTypes: activities,
    durationBrackets: durations,
    gutTrainingLevels: const ['moderate'],
    componentFoodNames: components,
    allergens: const [],
    excludedDiets: const [],
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('DuringFormulaCard', () {
    testWidgets('does not render a FORMULA #<n> eyebrow', (tester) async {
      // Eyebrow was removed per design — During cards lead with the formula
      // string, not a "FORMULA #N" label.
      await tester.pumpWidget(_wrap(
        DuringFormulaCard(formula: _fixture(templateNumber: 12), onTap: () {}),
      ));
      expect(find.textContaining('FORMULA #'), findsNothing);
    });

    testWidgets('renders the formula string', (tester) async {
      await tester.pumpWidget(_wrap(
        DuringFormulaCard(
          formula: _fixture(formula: 'Sports drink + chews'),
          onTap: () {},
        ),
      ));
      expect(find.text('Sports drink + chews'), findsOneWidget);
    });

    testWidgets('does not render the raw componentFoodNames subtitle',
        (tester) async {
      // The snake_case component-names row was removed — it duplicated and
      // uglified the human-readable `formula` title above it.
      await tester.pumpWidget(_wrap(
        DuringFormulaCard(
          formula: _fixture(
            formula: 'High-carb endurance mix',
            components: const ['maltodextrin', 'fructose', 'sodium_citrate'],
          ),
          onTap: () {},
        ),
      ));
      expect(find.textContaining('maltodextrin'), findsNothing);
      expect(find.textContaining('sodium_citrate'), findsNothing);
    });

    testWidgets('humanizes triathlon activity codes', (tester) async {
      await tester.pumpWidget(_wrap(
        DuringFormulaCard(
          formula: _fixture(activities: const [
            'triathlon_bike',
            'triathlon_run',
            'triathlon_transition',
          ]),
          onTap: () {},
        ),
      ));
      expect(find.text('Tri — Bike'), findsOneWidget);
      expect(find.text('Tri — Run'), findsOneWidget);
      expect(find.text('Tri — Transition'), findsOneWidget);
    });

    testWidgets('capitalizes non-triathlon activities', (tester) async {
      await tester.pumpWidget(_wrap(
        DuringFormulaCard(
          formula: _fixture(activities: const ['running', 'cycling']),
          onTap: () {},
        ),
      ));
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Cycling'), findsOneWidget);
    });

    testWidgets('renders each duration bracket as a tag', (tester) async {
      await tester.pumpWidget(_wrap(
        DuringFormulaCard(
          formula: _fixture(durations: const ['< 90 min', '> 240 min']),
          onTap: () {},
        ),
      ));
      expect(find.text('< 90 min'), findsOneWidget);
      expect(find.text('> 240 min'), findsOneWidget);
    });

    testWidgets('invokes onTap when card is tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        DuringFormulaCard(formula: _fixture(), onTap: () => taps++),
      ));
      await tester.tap(find.byType(DuringFormulaCard));
      await tester.pump();
      expect(taps, 1);
    });
  });
}
