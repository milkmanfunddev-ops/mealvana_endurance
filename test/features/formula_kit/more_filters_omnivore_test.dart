// Ticket 138 (Finding 116-013): Omnivore excludes nothing, so it is never a
// "Hide formulas with" chip. A real diet still is.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/application/formula_library_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_filter_state.dart';
import 'package:mealvana_endurance/features/formula_kit/presentation/widgets/more_filters_sheet.dart';
import 'package:mealvana_endurance/features/onboarding/domain/dietary_preference.dart';

import '../../helpers/widget_test_harness.dart';

class _Seeded extends FormulaLibraryController {
  _Seeded(this.diet);
  final DietaryPreference diet;

  @override
  FutureOr<FormulaLibraryState> build() => FormulaLibraryState(
    filter: const FormulaFilterState(),
    beforeFormulas: const [],
    duringFormulas: const [],
    afterFormulas: const [],
    userDiets: [diet],
    userAllergies: const [],
  );
}

void main() {
  Future<void> pump(WidgetTester tester, DietaryPreference diet) => smokeScreen(
    tester,
    const Scaffold(body: MoreFiltersSheet()),
    overrides: [
      formulaLibraryControllerProvider.overrideWith(() => _Seeded(diet)),
    ],
  );

  testWidgets('an omnivore sees no diet chip under Hide formulas with',
      (tester) async {
    await pump(tester, DietaryPreference.omnivore);

    expect(
      find.byKey(const ValueKey('formula_kit.more_filters.diet.omnivore')),
      findsNothing,
    );
    expect(find.text(DietaryPreference.omnivore.displayName), findsNothing);
    // The allergen chips are still there.
    expect(
      find.byKey(const ValueKey('formula_kit.more_filters.allergy.peanuts')),
      findsOneWidget,
    );
  });

  testWidgets('a vegetarian still sees their diet chip', (tester) async {
    await pump(tester, DietaryPreference.vegetarian);

    expect(
      find.byKey(const ValueKey('formula_kit.more_filters.diet.vegetarian')),
      findsOneWidget,
    );
  });
}
