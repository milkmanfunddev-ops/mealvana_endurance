import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/features/formula_kit/application/formula_pin_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/before_sub_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_view.dart';
import 'package:mealvana_endurance/features/formula_kit/presentation/widgets/before_formula_card.dart';
import 'package:mealvana_endurance/features/formula_kit/presentation/widgets/pin_toggle.dart';

BeforeFormulaView _fixture({
  String id = 'fixture',
  String name = 'Oatmeal & Banana',
  String templateType = 'food',
  List<String> components = const [
    '1 cup Oats',
    '1 Banana',
    '1 tbsp Honey',
  ],
  double carbs = 62,
  double protein = 9,
  double fat = 3,
  double sodium = 180,
  String timing = '1.5-3 hours',
  BeforeSubPhase? subPhase = BeforeSubPhase.meal,
}) {
  return BeforeFormulaView(
    id: id,
    name: name,
    subPhase: subPhase,
    digestionSpeed: 'medium',
    templateType: templateType,
    componentDisplayStrings: components,
    allergens: const [],
    excludedDiets: const [],
    totalCarbsG: carbs,
    totalProteinG: protein,
    totalFatG: fat,
    totalSodiumMg: sodium,
    totalFluidMl: 250,
    totalCalories: 320,
    timingWindow: timing,
  );
}

/// Stub controller returns an empty pin set so card widgets render the
/// "unpinned" affordance without touching repositories / Drift.
class _StubPinController extends FormulaPinController {
  _StubPinController({Set<String> pinned = const <String>{}})
      : _pinned = pinned;

  final Set<String> _pinned;

  @override
  FutureOr<FormulaPinState> build() async {
    return FormulaPinState(pinnedTemplateIds: _pinned);
  }
}

/// `find.byIcon` requires `IconData`, but FontAwesome glyphs are typed as
/// `FaIconData`. Match by the glyph's codepoint, which is preserved across
/// the IconData / FaIconData boundary.
Finder _thumbtackFinder() {
  return find.byWidgetPredicate(
    (w) => w is FaIcon &&
        w.icon?.codePoint == FontAwesomeIcons.thumbtack.codePoint,
  );
}

Widget _wrap(
  Widget child, {
  Set<String> pinned = const <String>{},
}) {
  return ProviderScope(
    overrides: [
      formulaPinControllerProvider.overrideWith(
        () => _StubPinController(pinned: pinned),
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('BeforeFormulaCard', () {
    testWidgets('renders formula name', (tester) async {
      await tester.pumpWidget(_wrap(
        BeforeFormulaCard(formula: _fixture(), onTap: () {}),
      ));
      expect(find.text('Oatmeal & Banana'), findsOneWidget);
    });

    testWidgets('renders components joined by " + "', (tester) async {
      await tester.pumpWidget(_wrap(
        BeforeFormulaCard(formula: _fixture(), onTap: () {}),
      ));
      expect(
        find.text('1 cup Oats + 1 Banana + 1 tbsp Honey'),
        findsOneWidget,
      );
    });

    testWidgets('renders rounded macro pills (carbs, protein, fat, sodium)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        BeforeFormulaCard(formula: _fixture(), onTap: () {}),
      ));
      expect(find.text('62g C'), findsOneWidget);
      expect(find.text('9g P'), findsOneWidget);
      expect(find.text('3g F'), findsOneWidget);
      expect(find.text('180mg Na'), findsOneWidget);
    });

    testWidgets('renders timing window pill', (tester) async {
      await tester.pumpWidget(_wrap(
        BeforeFormulaCard(formula: _fixture(timing: '30-90 min'), onTap: () {}),
      ));
      expect(find.text('30-90 min'), findsOneWidget);
    });

    testWidgets('omits component row when components list is empty',
        (tester) async {
      await tester.pumpWidget(_wrap(
        BeforeFormulaCard(
          formula: _fixture(components: const []),
          onTap: () {},
        ),
      ));
      // Macro pills still render; component join string must not appear.
      expect(find.textContaining(' + '), findsNothing);
    });

    testWidgets('rounds half-values rather than truncating', (tester) async {
      await tester.pumpWidget(_wrap(
        BeforeFormulaCard(
          formula: _fixture(carbs: 62.6, protein: 8.4, sodium: 179.5),
          onTap: () {},
        ),
      ));
      expect(find.text('63g C'), findsOneWidget);
      expect(find.text('8g P'), findsOneWidget);
      // 179.5 rounds to 180 (banker's rounding in Dart rounds .5 away from zero).
      expect(find.text('180mg Na'), findsOneWidget);
    });

    testWidgets('invokes onTap when card is tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        BeforeFormulaCard(formula: _fixture(), onTap: () => taps++),
      ));
      await tester.tap(find.byType(BeforeFormulaCard));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('shows pin affordance for food templates', (tester) async {
      await tester.pumpWidget(_wrap(
        BeforeFormulaCard(
          formula: _fixture(templateType: 'food'),
          onTap: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(PinToggleBefore), findsOneWidget);
      expect(_thumbtackFinder(), findsOneWidget);
    });

    testWidgets('hides pin affordance for drink templates', (tester) async {
      await tester.pumpWidget(_wrap(
        BeforeFormulaCard(
          formula: _fixture(templateType: 'drink'),
          onTap: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(_thumbtackFinder(), findsNothing);
    });

    testWidgets('hides pin affordance for electrolyte templates',
        (tester) async {
      await tester.pumpWidget(_wrap(
        BeforeFormulaCard(
          formula: _fixture(templateType: 'electrolyte'),
          onTap: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(_thumbtackFinder(), findsNothing);
    });
  });
}
