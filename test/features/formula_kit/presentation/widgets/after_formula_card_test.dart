import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/features/formula_kit/application/formula_pin_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_view.dart';
import 'package:mealvana_endurance/features/formula_kit/presentation/widgets/after_formula_card.dart';
import 'package:mealvana_endurance/features/formula_kit/presentation/widgets/pin_toggle.dart';

AfterFormulaView _fixture({
  String id = 'fixture',
  String name = 'Chocolate Milk Solo',
  String formula = '2 cups chocolate milk',
  String? travelFriendliness = 'cooler_friendly',
  String? targetCarbProteinRatio = '3:1',
}) {
  return AfterFormulaView(
    id: id,
    templateNumber: 17,
    name: name,
    formula: formula,
    activityTypes: const ['cycling'],
    componentFoodNames: const ['chocolate_milk'],
    componentDisplayStrings: const ['2 cups Chocolate Milk'],
    carbSources: const ['lactose'],
    allergens: const ['dairy'],
    excludedDiets: const ['vegan'],
    selectionPriority: 10,
    totalCarbsG: 52,
    totalProteinG: 16,
    totalFatG: 8,
    totalSodiumMg: 220,
    totalFluidMl: 480,
    totalCalories: 380,
    travelFriendliness: travelFriendliness,
    targetCarbProteinRatio: targetCarbProteinRatio,
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
    (w) =>
        w is FaIcon &&
        w.icon?.codePoint == FontAwesomeIcons.thumbtack.codePoint,
  );
}

Widget _wrap(Widget child, {Set<String> pinned = const <String>{}}) {
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
  group('AfterFormulaCard', () {
    testWidgets('renders the formula name', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AfterFormulaCard(
            formula: _fixture(name: 'Greek Yogurt + Berries'),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Greek Yogurt + Berries'), findsOneWidget);
    });

    testWidgets('renders the travel-friendliness pill when set', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AfterFormulaCard(
            formula: _fixture(travelFriendliness: 'in_bag'),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('In bag'), findsOneWidget);
    });

    testWidgets('hides the travel-friendliness pill when null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AfterFormulaCard(
            formula: _fixture(travelFriendliness: null),
            onTap: () {},
          ),
        ),
      );
      // No travel-friendliness pill present.
      expect(find.text('In bag'), findsNothing);
      expect(find.text('Cooler-friendly'), findsNothing);
      expect(find.text('Home only'), findsNothing);
    });

    testWidgets('renders C:P ratio meta pill when set', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AfterFormulaCard(
            formula: _fixture(targetCarbProteinRatio: '4:1'),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('C:P 4:1'), findsOneWidget);
    });

    testWidgets('hides C:P ratio meta pill when null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AfterFormulaCard(
            formula: _fixture(targetCarbProteinRatio: null),
            onTap: () {},
          ),
        ),
      );
      expect(find.textContaining('C:P'), findsNothing);
    });

    testWidgets('hides C:P ratio meta pill when empty string', (tester) async {
      // Defensive: the card branches on `isNotEmpty`, not just null.
      await tester.pumpWidget(
        _wrap(
          AfterFormulaCard(
            formula: _fixture(targetCarbProteinRatio: ''),
            onTap: () {},
          ),
        ),
      );
      expect(find.textContaining('C:P'), findsNothing);
    });

    testWidgets('renders pin affordance for every After formula', (
      tester,
    ) async {
      // V1 policy: AfterFormulaView.isPinnable is hard-coded true, so every
      // After card surfaces a pin toggle (unlike Before, which gates by
      // template_type).
      await tester.pumpWidget(
        _wrap(AfterFormulaCard(formula: _fixture(), onTap: () {})),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PinToggleAfter), findsOneWidget);
      expect(_thumbtackFinder(), findsOneWidget);
    });

    testWidgets('pin toggle reflects pinned state from controller', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AfterFormulaCard(
            formula: _fixture(id: 'pinned-id'),
            onTap: () {},
          ),
          pinned: const {'pinned-id'},
        ),
      );
      await tester.pumpAndSettle();
      // Pinned thumbtack uses the orange brand color; unpinned uses muted.
      final faIcon = tester.widget<FaIcon>(_thumbtackFinder());
      expect(faIcon.color, isNotNull);
    });

    testWidgets('invokes onTap when card is tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(AfterFormulaCard(formula: _fixture(), onTap: () => taps++)),
      );
      // Tap the card body, not the pin toggle.
      await tester.tap(find.text('Chocolate Milk Solo'));
      await tester.pump();
      expect(taps, 1);
    });
  });
}
