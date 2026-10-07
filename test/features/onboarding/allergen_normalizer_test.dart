// Ticket 138 (Finding 116-001): the catalog says "Peanut" and the app says
// `peanuts`; the exact lower-case compares in the formula filter and the pin
// conflict label never matched. One normaliser now serves both.
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/application/formula_library_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_filter_state.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_view.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/selection_precedence.dart';
import 'package:mealvana_endurance/features/onboarding/domain/allergen_normalizer.dart';
import 'package:mealvana_endurance/features/onboarding/domain/allergy.dart';

BeforeFormulaView _formula(String id, List<String> allergens) =>
    BeforeFormulaView(
      id: id,
      name: id,
      subPhase: null,
      digestionSpeed: 'moderate',
      templateType: 'food',
      componentDisplayStrings: const ['1 thing'],
      allergens: allergens,
      excludedDiets: const [],
      totalCarbsG: 30,
      totalProteinG: 5,
      totalFatG: 2,
      totalSodiumMg: 100,
      totalFluidMl: 0,
      totalCalories: 160,
      timingWindow: '1-2 hours',
    );

void main() {
  group('normalizeAllergen', () {
    test('folds the catalog forms onto Allergy.dbValue', () {
      expect(normalizeAllergen('Peanut'), Allergy.peanuts.dbValue);
      expect(normalizeAllergen('Peanuts'), Allergy.peanuts.dbValue);
      expect(normalizeAllergen('Tree nut'), Allergy.treeNuts.dbValue);
      expect(normalizeAllergen('Tree Nuts'), Allergy.treeNuts.dbValue);
      expect(normalizeAllergen('Egg'), Allergy.eggs.dbValue);
      expect(normalizeAllergen('Milk'), Allergy.dairy.dbValue);
      expect(normalizeAllergen('Sesame seeds'), Allergy.sesame.dbValue);
    });

    test('every Allergy.dbValue is its own canonical form', () {
      for (final a in Allergy.values) {
        expect(normalizeAllergen(a.dbValue), a.dbValue);
        expect(normalizeAllergen(a.displayName), a.dbValue);
      }
    });

    test('an unknown allergen stays comparable with its own spellings', () {
      expect(normalizeAllergen('Mustard'), normalizeAllergen('mustard'));
      expect(normalizeAllergen('Lupins'), normalizeAllergen('Lupin'));
      expect(normalizeAllergen('Fish'), isNot(normalizeAllergen('Shellfish')));
    });
  });

  group('formula library filter', () {
    FormulaLibraryState state(Set<Allergy> hide) => FormulaLibraryState(
      filter: FormulaFilterState(activeAllergyFilters: hide),
      beforeFormulas: [
        _formula('pb', ['Peanut']),
        _formula('nutty', ['Tree nut']),
        _formula('plain', []),
      ],
      duringFormulas: const [],
      afterFormulas: const [],
      userDiets: const [],
      userAllergies: const [],
    );

    test('hiding peanuts hides the "Peanut" formula', () {
      final shown = state({Allergy.peanuts}).filteredBeforeFormulas;
      expect(shown.map((f) => f.id), ['nutty', 'plain']);
    });

    test('hiding tree nuts hides the "Tree nut" formula', () {
      final shown = state({Allergy.treeNuts}).filteredBeforeFormulas;
      expect(shown.map((f) => f.id), ['pb', 'plain']);
    });

    test('nothing hidden shows all', () {
      expect(state({}).filteredBeforeFormulas, hasLength(3));
    });
  });

  group('pinConflictLabelRequired', () {
    test('a pinned "Peanut" template conflicts with a peanuts allergy', () {
      expect(pinConflictLabelRequired(['Peanut'], ['peanuts']), isTrue);
      expect(pinConflictLabelRequired(['Tree nut'], ['tree_nuts']), isTrue);
    });

    test('no conflict without a shared allergen', () {
      expect(pinConflictLabelRequired(['Dairy'], ['peanuts']), isFalse);
      expect(pinConflictLabelRequired([], ['peanuts']), isFalse);
    });
  });
}
