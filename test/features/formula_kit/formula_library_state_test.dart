import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/application/formula_library_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/before_sub_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/during_filter_options.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_filter_state.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_view.dart';
import 'package:mealvana_endurance/features/onboarding/domain/allergy.dart';
import 'package:mealvana_endurance/features/onboarding/domain/dietary_preference.dart';

BeforeFormulaView _before({
  required String id,
  BeforeSubPhase? subPhase,
  String digestionSpeed = 'medium',
  List<String> allergens = const [],
  List<String> excludedDiets = const [],
}) {
  return BeforeFormulaView(
    id: id,
    name: 'Test $id',
    subPhase: subPhase,
    digestionSpeed: digestionSpeed,
    componentDisplayNames: const ['Oats'],
    allergens: allergens,
    excludedDiets: excludedDiets,
    totalCarbsG: 40,
    totalProteinG: 8,
    totalFatG: 4,
    totalSodiumMg: 200,
    totalFluidMl: 250,
    totalCalories: 240,
    timingWindow: '1-2 hours',
  );
}

DuringFormulaView _during({
  required String id,
  int templateNumber = 1,
  List<String> activityTypes = const ['running'],
  List<String> durationBrackets = const ['< 90 min'],
  List<String> gutTrainingLevels = const ['low'],
  List<String> allergens = const [],
  List<String> excludedDiets = const [],
}) {
  return DuringFormulaView(
    id: id,
    templateNumber: templateNumber,
    name: 'Test $id',
    formula: 'Gel + Water',
    foodForm: 'liquid',
    activityTypes: activityTypes,
    durationBrackets: durationBrackets,
    gutTrainingLevels: gutTrainingLevels,
    componentFoodNames: const ['Gel'],
    allergens: allergens,
    excludedDiets: excludedDiets,
  );
}

void main() {
  group('FormulaLibraryState — Before filtering', () {
    test('returns all formulas when no filters applied', () {
      final state = FormulaLibraryState(
        filter: const FormulaFilterState(),
        beforeFormulas: [
          _before(id: 'a'),
          _before(id: 'b'),
        ],
        duringFormulas: const [],
        userDiets: const [],
        userAllergies: const [],
      );
      expect(state.filteredBeforeFormulas, hasLength(2));
    });

    test('filters by beforeSubPhase', () {
      final state = FormulaLibraryState(
        filter: const FormulaFilterState(beforeSubPhase: BeforeSubPhase.snack),
        beforeFormulas: [
          _before(id: 'meal', subPhase: BeforeSubPhase.meal),
          _before(id: 'snack', subPhase: BeforeSubPhase.snack),
          _before(id: 'topup', subPhase: BeforeSubPhase.topUp),
        ],
        duringFormulas: const [],
        userDiets: const [],
        userAllergies: const [],
      );
      expect(state.filteredBeforeFormulas.map((f) => f.id), ['snack']);
    });

    test('filters by digestion speed', () {
      final state = FormulaLibraryState(
        filter: const FormulaFilterState(
          beforeDigestionSpeed: FormulaDigestionSpeed.fast,
        ),
        beforeFormulas: [
          _before(id: 'fast', digestionSpeed: 'fast'),
          _before(id: 'slow', digestionSpeed: 'slow'),
        ],
        duringFormulas: const [],
        userDiets: const [],
        userAllergies: const [],
      );
      expect(state.filteredBeforeFormulas.map((f) => f.id), ['fast']);
    });

    test('excludes formulas whose excluded_diets intersects user diet', () {
      final state = FormulaLibraryState(
        filter: const FormulaFilterState(),
        beforeFormulas: [
          _before(id: 'ok'),
          _before(
            id: 'not-vegan',
            excludedDiets: [DietaryPreference.vegan.dbValue],
          ),
        ],
        duringFormulas: const [],
        userDiets: const [DietaryPreference.vegan],
        userAllergies: const [],
      );
      expect(state.filteredBeforeFormulas.map((f) => f.id), ['ok']);
    });

    test('excludes formulas whose allergens intersect user allergies', () {
      final state = FormulaLibraryState(
        filter: const FormulaFilterState(),
        beforeFormulas: [
          _before(id: 'ok'),
          _before(
            id: 'has-nuts',
            allergens: [Allergy.peanuts.dbValue],
          ),
        ],
        duringFormulas: const [],
        userDiets: const [],
        userAllergies: const [Allergy.peanuts],
      );
      expect(state.filteredBeforeFormulas.map((f) => f.id), ['ok']);
    });

    test('allergen matching is case-insensitive (seed has "Dairy", user has "dairy")',
        () {
      // Regression: live pre_workout_templates rows store capitalized values
      // like "Dairy"/"Gluten" while user-side `Allergy.dairy.dbValue` returns
      // lowercase "dairy". Without case-insensitive comparison the filter
      // would leak e.g. "Bagel + Cream Cheese" past a dairy-allergic user.
      final state = FormulaLibraryState(
        filter: const FormulaFilterState(),
        beforeFormulas: [
          _before(id: 'ok'),
          _before(id: 'has-dairy', allergens: const ['Dairy', 'Gluten']),
        ],
        duringFormulas: const [],
        userDiets: const [],
        userAllergies: const [Allergy.dairy],
      );
      expect(state.filteredBeforeFormulas.map((f) => f.id), ['ok']);
    });

    test('excluded-diet matching is case-insensitive', () {
      final state = FormulaLibraryState(
        filter: const FormulaFilterState(),
        beforeFormulas: [
          _before(id: 'ok'),
          _before(id: 'not-vegan', excludedDiets: const ['Vegan']),
        ],
        duringFormulas: const [],
        userDiets: const [DietaryPreference.vegan],
        userAllergies: const [],
      );
      expect(state.filteredBeforeFormulas.map((f) => f.id), ['ok']);
    });

    test('ignoreDietaryProfile bypasses both diet and allergen checks', () {
      final state = FormulaLibraryState(
        filter: const FormulaFilterState(ignoreDietaryProfile: true),
        beforeFormulas: [
          _before(
            id: 'not-vegan',
            excludedDiets: [DietaryPreference.vegan.dbValue],
          ),
          _before(
            id: 'has-nuts',
            allergens: [Allergy.peanuts.dbValue],
          ),
        ],
        duringFormulas: const [],
        userDiets: const [DietaryPreference.vegan],
        userAllergies: const [Allergy.peanuts],
      );
      expect(state.filteredBeforeFormulas, hasLength(2));
    });
  });

  group('FormulaLibraryState — During filtering', () {
    test('filters by activity', () {
      final state = FormulaLibraryState(
        filter: const FormulaFilterState(
          phase: FormulaPhase.during,
          duringActivity: DuringActivity.cycling,
        ),
        beforeFormulas: const [],
        duringFormulas: [
          _during(id: 'run', activityTypes: const ['running']),
          _during(id: 'bike', activityTypes: const ['cycling']),
          _during(
            id: 'multi',
            activityTypes: const ['running', 'cycling'],
          ),
        ],
        userDiets: const [],
        userAllergies: const [],
      );
      expect(
        state.filteredDuringFormulas.map((f) => f.id),
        containsAll(['bike', 'multi']),
      );
      expect(state.filteredDuringFormulas, hasLength(2));
    });

    test('filters by duration bracket', () {
      final state = FormulaLibraryState(
        filter: const FormulaFilterState(
          phase: FormulaPhase.during,
          duringDuration: DuringDuration.over240,
        ),
        beforeFormulas: const [],
        duringFormulas: [
          _during(id: 'short', durationBrackets: const ['< 90 min']),
          _during(id: 'long', durationBrackets: const ['> 240 min']),
        ],
        userDiets: const [],
        userAllergies: const [],
      );
      expect(state.filteredDuringFormulas.map((f) => f.id), ['long']);
    });

    test('filters by gut training level', () {
      final state = FormulaLibraryState(
        filter: const FormulaFilterState(
          phase: FormulaPhase.during,
          duringGutLevel: DuringGutLevel.high,
        ),
        beforeFormulas: const [],
        duringFormulas: [
          _during(id: 'low', gutTrainingLevels: const ['low']),
          _during(id: 'high', gutTrainingLevels: const ['high']),
        ],
        userDiets: const [],
        userAllergies: const [],
      );
      expect(state.filteredDuringFormulas.map((f) => f.id), ['high']);
    });

    test('combines multiple During filters with AND semantics', () {
      final state = FormulaLibraryState(
        filter: const FormulaFilterState(
          phase: FormulaPhase.during,
          duringActivity: DuringActivity.cycling,
          duringDuration: DuringDuration.over240,
        ),
        beforeFormulas: const [],
        duringFormulas: [
          _during(
            id: 'bike-short',
            activityTypes: const ['cycling'],
            durationBrackets: const ['< 90 min'],
          ),
          _during(
            id: 'bike-long',
            activityTypes: const ['cycling'],
            durationBrackets: const ['> 240 min'],
          ),
          _during(
            id: 'run-long',
            activityTypes: const ['running'],
            durationBrackets: const ['> 240 min'],
          ),
        ],
        userDiets: const [],
        userAllergies: const [],
      );
      expect(state.filteredDuringFormulas.map((f) => f.id), ['bike-long']);
    });
  });
}
