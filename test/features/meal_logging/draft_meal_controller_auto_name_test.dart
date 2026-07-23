// Unit tests for DraftMealController's auto-naming behavior — the name
// should track the component list via deriveMealName until the user
// manually edits it (nameManuallySet), mirroring the activity-title
// auto-name pattern. Only exercises the pure state-transition methods
// (add/remove/setName) — `.save()` requires DB/auth wiring and is covered
// elsewhere (meal_logging_business_logic_test.dart exercises the underlying
// MealLoggingService/repository layer it delegates to).

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/draft_meal_controller.dart';

const _logDate = '2026-07-04';

MealComponent _c(String name) =>
    MealComponent(name: name, portion: '1 serving');

void main() {
  group('DraftMealController auto-naming', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('starts empty with no name', () {
      final state = container.read(draftMealControllerProvider(_logDate));
      expect(state.isEmpty, isTrue);
      expect(state.name, isNull);
      expect(state.nameManuallySet, isFalse);
    });

    test('1 component auto-names to the item name', () {
      final notifier = container.read(
        draftMealControllerProvider(_logDate).notifier,
      );
      notifier.addComponent(_c('Banana'));

      final state = container.read(draftMealControllerProvider(_logDate));
      expect(state.name, 'Banana');
      expect(state.nameManuallySet, isFalse);
    });

    test('adding a second component recomputes the auto-name', () {
      final notifier = container.read(
        draftMealControllerProvider(_logDate).notifier,
      );
      notifier.addComponent(_c('Banana'));
      notifier.addComponent(_c('Peanut butter'));

      final state = container.read(draftMealControllerProvider(_logDate));
      expect(state.name, 'Banana and Peanut butter');
    });

    test('setName marks the name manually set and stops auto-recompute', () {
      final notifier = container.read(
        draftMealControllerProvider(_logDate).notifier,
      );
      notifier.addComponent(_c('Banana'));
      notifier.setName('My custom meal');

      var state = container.read(draftMealControllerProvider(_logDate));
      expect(state.name, 'My custom meal');
      expect(state.nameManuallySet, isTrue);

      // Adding another component must NOT overwrite the manual name.
      notifier.addComponent(_c('Peanut butter'));
      state = container.read(draftMealControllerProvider(_logDate));
      expect(state.name, 'My custom meal');
      expect(state.nameManuallySet, isTrue);
    });

    test('clearing the name field reverts to auto-naming', () {
      final notifier = container.read(
        draftMealControllerProvider(_logDate).notifier,
      );
      notifier.addComponent(_c('Banana'));
      notifier.addComponent(_c('Peanut butter'));
      notifier.setName('My custom meal');
      notifier.setName(''); // user clears the field

      final state = container.read(draftMealControllerProvider(_logDate));
      expect(state.nameManuallySet, isFalse);
      expect(state.name, 'Banana and Peanut butter');
    });

    test('removeComponentAt recomputes the auto-name', () {
      final notifier = container.read(
        draftMealControllerProvider(_logDate).notifier,
      );
      notifier.addComponent(_c('Banana'));
      notifier.addComponent(_c('Peanut butter'));
      notifier.removeComponentAt(1);

      final state = container.read(draftMealControllerProvider(_logDate));
      expect(state.name, 'Banana');
    });

    test('clear() resets components, name, and nameManuallySet', () {
      final notifier = container.read(
        draftMealControllerProvider(_logDate).notifier,
      );
      notifier.addComponent(_c('Banana'));
      notifier.setName('My custom meal');
      notifier.clear();

      final state = container.read(draftMealControllerProvider(_logDate));
      expect(state.isEmpty, isTrue);
      expect(state.name, isNull);
      expect(state.nameManuallySet, isFalse);
    });
  });

  group('DraftMealController eatenAt seeding', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('build() seeds eatenAt on the logDate day, not today', () {
      // Regression (bug 3a3e3fdb): eatenAt used to be DateTime.now(), so a
      // meal built for a past day carried today's date and sank to the
      // bottom of that day's fuel timeline.
      final state = container.read(draftMealControllerProvider(_logDate));

      expect(state.eatenAt.year, 2026);
      expect(state.eatenAt.month, 7);
      expect(state.eatenAt.day, 4);
    });

    test('clear() re-seeds eatenAt on the logDate day, not today', () {
      final notifier = container.read(
        draftMealControllerProvider(_logDate).notifier,
      );
      notifier.addComponent(_c('Banana'));
      notifier.clear();

      final state = container.read(draftMealControllerProvider(_logDate));

      expect(state.eatenAt.year, 2026);
      expect(state.eatenAt.month, 7);
      expect(state.eatenAt.day, 4);
    });

    test('a malformed logDate does not throw out of build()', () {
      expect(
        () => container.read(draftMealControllerProvider('garbage')),
        returnsNormally,
      );
    });
  });
}
