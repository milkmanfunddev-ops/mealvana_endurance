import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/application/default_formula_selector.dart';
import 'package:mealvana_endurance/features/onboarding/application/onboarding_formula_pin_service.dart';

// Mirrors the server-side default-formula.test.ts contract for the client
// selector used to seed onboarding pins (plan Phase 1 #3).

DefaultFormulaCandidate _c({
  required String id,
  int templateNumber = 1,
  List<String> activityTypes = const ['running', 'cycling'],
  List<String> allergens = const [],
  List<String> excludedDiets = const [],
  int selectionPriority = 0,
  bool isActive = true,
  bool universal = false,
}) {
  return DefaultFormulaCandidate(
    id: id,
    templateNumber: templateNumber,
    activityTypes: activityTypes,
    allergens: allergens,
    excludedDiets: excludedDiets,
    selectionPriority: selectionPriority,
    isActive: isActive,
    emptyActivityIsUniversal: universal,
  );
}

void main() {
  group('DefaultFormulaSelector.pickBest', () {
    test('returns null for empty candidates', () {
      expect(
        DefaultFormulaSelector.pickBest([], activityType: 'running'),
        isNull,
      );
    });

    test('picks the highest selection_priority', () {
      final result = DefaultFormulaSelector.pickBest(
        [
          _c(id: 'low', templateNumber: 1, selectionPriority: 2),
          _c(id: 'high', templateNumber: 2, selectionPriority: 9),
          _c(id: 'mid', templateNumber: 3, selectionPriority: 5),
        ],
        activityType: 'running',
      );
      expect(result, 'high');
    });

    test('ties on priority broken by lower template_number', () {
      final result = DefaultFormulaSelector.pickBest(
        [
          _c(id: 'a', templateNumber: 8, selectionPriority: 7),
          _c(id: 'b', templateNumber: 2, selectionPriority: 7),
        ],
        activityType: 'running',
      );
      expect(result, 'b');
    });

    test('filters by activity (case-insensitive)', () {
      final result = DefaultFormulaSelector.pickBest(
        [
          _c(id: 'swim', activityTypes: ['swimming'], selectionPriority: 9),
          _c(id: 'run', activityTypes: ['Running'], selectionPriority: 1),
        ],
        activityType: 'running',
      );
      expect(result, 'run');
    });

    test('excludes templates matching the user diet', () {
      final result = DefaultFormulaSelector.pickBest(
        [
          _c(id: 'meaty', excludedDiets: ['vegan'], selectionPriority: 9),
          _c(id: 'plant', selectionPriority: 1),
        ],
        activityType: 'running',
        diet: 'vegan',
      );
      expect(result, 'plant');
    });

    test('excludes templates whose allergens overlap the user allergies', () {
      final result = DefaultFormulaSelector.pickBest(
        [
          _c(id: 'nutty', allergens: ['Peanut'], selectionPriority: 9),
          _c(id: 'safe', selectionPriority: 1),
        ],
        activityType: 'running',
        allergies: ['peanut'],
      );
      expect(result, 'safe');
    });

    test('returns null when every candidate is filtered out', () {
      final result = DefaultFormulaSelector.pickBest(
        [_c(id: 'nutty', allergens: ['peanut'])],
        activityType: 'running',
        allergies: ['peanut'],
      );
      expect(result, isNull);
    });

    test('skips inactive templates', () {
      final result = DefaultFormulaSelector.pickBest(
        [
          _c(id: 'off', selectionPriority: 9, isActive: false),
          _c(id: 'on', selectionPriority: 1),
        ],
        activityType: 'running',
      );
      expect(result, 'on');
    });

    test('post universal (empty activity_types) matches any activity', () {
      final result = DefaultFormulaSelector.pickBest(
        [_c(id: 'univ', activityTypes: const [], universal: true)],
        activityType: 'swimming',
      );
      expect(result, 'univ');
    });

    test('during (non-universal) empty activity_types matches nothing', () {
      final result = DefaultFormulaSelector.pickBest(
        [_c(id: 'none', activityTypes: const [], universal: false)],
        activityType: 'running',
      );
      expect(result, isNull);
    });
  });

  group('OnboardingFormulaPinService.primarySport', () {
    test('prefers running when present', () {
      expect(
        OnboardingFormulaPinService.primarySport(
            {'swimming', 'running', 'cycling'}),
        'running',
      );
    });

    test('falls back through priority order', () {
      expect(
        OnboardingFormulaPinService.primarySport({'swimming'}),
        'swimming',
      );
    });

    test('defaults to running for an empty set', () {
      expect(
        OnboardingFormulaPinService.primarySport(<String>{}),
        'running',
      );
    });
  });
}
