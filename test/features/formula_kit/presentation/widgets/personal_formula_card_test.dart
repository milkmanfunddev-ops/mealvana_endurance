import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/application/formula_pin_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/personal_formula.dart';
import 'package:mealvana_endurance/features/formula_kit/presentation/widgets/personal_formula_card.dart';

PersonalFormula _fixture({
  FormulaPhase phase = FormulaPhase.during,
  String? subPhase,
  List<String>? durations,
  String? travelFriendliness,
}) {
  return PersonalFormula(
    id: 'fixture',
    userId: 'user',
    name: '(Gel + Water) + Sports Drink',
    provenance: FormulaProvenance.forkedFormula,
    phase: phase,
    subPhase: subPhase,
    durations: durations,
    travelFriendliness: travelFriendliness,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );
}

/// Stub controller returns an empty pin set so the card renders the
/// "unpinned" affordance without touching repositories / Drift.
class _StubPinController extends FormulaPinController {
  @override
  FutureOr<FormulaPinState> build() async {
    return const FormulaPinState(pinnedTemplateIds: <String>{});
  }
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      formulaPinControllerProvider.overrideWith(() => _StubPinController()),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets(
    'during formula with multiple duration brackets renders one pill per '
    'bracket, not one merged pill',
    (tester) async {
      final formula = _fixture(
        durations: const ['90-150 min', '150-240 min', '> 240 min'],
      );
      await tester.pumpWidget(
        _wrap(PersonalFormulaCard(formula: formula, onTap: () {})),
      );
      await tester.pump();

      expect(find.text('90–150 min'), findsOneWidget);
      expect(find.text('150–240 min'), findsOneWidget);
      expect(find.text('> 240 min'), findsOneWidget);
      // The old bug joined the brackets into a single pill.
      expect(find.textContaining(' · '), findsNothing);
    },
  );

  testWidgets('during formula with a single duration shows one header pill', (
    tester,
  ) async {
    final formula = _fixture(durations: const ['90-150 min']);
    await tester.pumpWidget(
      _wrap(PersonalFormulaCard(formula: formula, onTap: () {})),
    );
    await tester.pump();

    expect(find.text('90–150 min'), findsOneWidget);
  });

  testWidgets('before formula shows its timing window badge', (tester) async {
    final formula = _fixture(phase: FormulaPhase.before, subPhase: 'snack');
    await tester.pumpWidget(
      _wrap(PersonalFormulaCard(formula: formula, onTap: () {})),
    );
    await tester.pump();

    expect(find.text('30-90 min'), findsOneWidget);
  });

  testWidgets('no scope set renders no scope pill', (tester) async {
    final formula = _fixture(durations: null);
    await tester.pumpWidget(
      _wrap(PersonalFormulaCard(formula: formula, onTap: () {})),
    );
    await tester.pump();

    expect(find.textContaining('min'), findsNothing);
  });
}
