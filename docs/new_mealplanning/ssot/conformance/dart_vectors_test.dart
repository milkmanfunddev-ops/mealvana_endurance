// Meal-planning SSOT conformance — DART arm (the Flutter twin in lib/features/meal_planning/).
//
// Lives in docs/new_mealplanning/ssot/conformance/; copied into <app>/test/ by run_dart.sh and run with
//   flutter test test/_ssot_mealplanning_tmp_test.dart --dart-define=SSOT_VECTORS=<abs path to ssot/vectors>
//
// Arms: plan-coverage (PlanCoverageService.compute — the denominator stands in for the scope: 7 ⇔ 'dinners', else 14) ·
// cooking-timers (CookingStepTimers.findDurations / clock) · meal-icon (MealIconClassifier.classify / resolve).
// Never edit a vector to make a test pass — red means raise.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/cooking_step_timers.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_icon_classifier.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_coverage.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_meal.dart';

const String kRoot = String.fromEnvironment('SSOT_VECTORS');

Map<String, dynamic> load(String rel) =>
    jsonDecode(File('$kRoot/$rel').readAsStringSync()) as Map<String, dynamic>;
String label(Map<String, dynamic> v) => '${v['id']} [${v['status']}]';

PlanMeal planMeal(Map<String, dynamic> m, int i) => PlanMeal(
  id: 'm$i',
  planId: 'p',
  source: MealSource.library,
  libraryMealId: 'L-$i',
  name: 'meal $i',
  mealType: MealType.requireWire(m['mealType'] as String),
  servings: m['servings'] as int,
  servingsLeft: m['servings'] as int,
  kcal: (m['kcal'] as num?)?.toInt(),
  carbsG: (m['carbsG'] as num?)?.toDouble(),
  proteinG: (m['proteinG'] as num?)?.toDouble(),
  position: i,
);

void main() {
  if (kRoot.isEmpty) fail('SSOT_VECTORS must be passed with --dart-define');

  group('ssot vectors: plan-coverage', () {
    final f = load('planning/plan-coverage.json');
    for (final raw in f['vectors'] as List) {
      final v = raw as Map<String, dynamic>;
      test(label(v), () {
        final inputs = v['inputs'] as Map<String, dynamic>;
        final meals = (inputs['meals'] as List).indexed.map((e) => planMeal(e.$2 as Map<String, dynamic>, e.$1)).toList();
        final slots = inputs['scope'] == 'dinners' ? PlanCoverageService.dinnerOnlySlots : PlanCoverageService.lunchDinnerSlots;
        final c = PlanCoverageService.compute(meals, lunchDinnerSlots: slots);
        expect(c.toJson(), equals(v['expected']));
      });
    }
  });

  group('ssot vectors: cooking-timers', () {
    final f = load('planning/cooking-timers.json');
    for (final raw in f['vectors'] as List) {
      final v = raw as Map<String, dynamic>;
      test(label(v), () {
        if (v['fn'] == 'findDurations') {
          final got = CookingStepTimers.findDurations(v['inputs'] as String)
              .map((d) => {'label': d.label, 'seconds': d.seconds, 'index': d.index})
              .toList();
          expect(got, equals(v['expected']));
        } else if (v['fn'] == 'clock') {
          expect(CookingStepTimers.clock(v['inputs'] as int), equals(v['expected']));
        } else {
          fail('unknown fn ${v['fn']}');
        }
      });
    }
  });

  group('ssot vectors: meal-icon', () {
    final f = load('planning/meal-icon.json');
    for (final raw in f['vectors'] as List) {
      final v = raw as Map<String, dynamic>;
      test(label(v), () {
        final i = v['inputs'] as Map<String, dynamic>;
        final icon = i.containsKey('stored')
            ? MealIconClassifier.resolve(i['stored'] as String?, name: i['name'] as String, ingredients: i['ingredients'] as String?, pattern: i['pattern'] as String?)
            : MealIconClassifier.classify(name: i['name'] as String, ingredients: i['ingredients'] as String?, pattern: i['pattern'] as String?);
        expect(icon.wire, equals(v['expected']));
      });
    }
  });
}
