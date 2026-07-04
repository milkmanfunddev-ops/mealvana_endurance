// Unit tests for the meal-name auto-derivation helper used by
// DraftMealController (build-a-meal auto-naming, 2026-07 two-surface split)
// and by LogMealScreen's quick-log flows (a single quick-logged food's name
// is just deriveMealName applied to its one-item component list).

import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/meal_logging/domain/meal_auto_name.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';

MealComponent _component(String name) =>
    MealComponent(name: name, portion: '1 serving');

void main() {
  group('deriveMealName', () {
    test('empty list returns empty string', () {
      expect(deriveMealName(const []), '');
    });

    test('1 component returns the item name', () {
      expect(deriveMealName([_component('Banana')]), 'Banana');
    });

    test('2 components joins with "and"', () {
      expect(
        deriveMealName([_component('Banana'), _component('Peanut butter')]),
        'Banana and Peanut butter',
      );
    });

    test('3 components joins with comma + "and"', () {
      expect(
        deriveMealName([
          _component('Oatmeal'),
          _component('Banana'),
          _component('Honey'),
        ]),
        'Oatmeal, Banana and Honey',
      );
    });

    test('4+ components shows first two plus a remainder count', () {
      expect(
        deriveMealName([
          _component('Oatmeal'),
          _component('Banana'),
          _component('Honey'),
          _component('Milk'),
        ]),
        'Oatmeal, Banana +2',
      );

      expect(
        deriveMealName([
          _component('A'),
          _component('B'),
          _component('C'),
          _component('D'),
          _component('E'),
        ]),
        'A, B +3',
      );
    });
  });
}
