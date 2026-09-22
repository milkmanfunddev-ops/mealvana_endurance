/// A lapsed account cannot log or edit meals (mp-457 §4, mp-491, ticket 12).
///
/// Through the real MealLogController and DraftMealController: each write
/// path asks the write guard first; refused, it opens the paywall once and
/// never constructs the logging service or a repository, so nothing is
/// written or queued. The draft save is refused before it delegates, so the
/// draft survives for the account to come back to.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_logging_service.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/saved_meal.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/draft_meal_controller.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';

import '../../helpers/write_access.dart';

class _FakeSavedMeal extends Fake implements SavedMeal {}

class _FakeRecipeParams extends Fake implements RecipeLogParams {}

class _FakeMealLog extends Fake implements MealLog {}

class _FakeComponent extends Fake implements MealComponent {}

class _SeededLog extends MealLogController {
  @override
  FutureOr<void> build() {}
}

class _SeededDraft extends DraftMealController {
  @override
  DraftMealState build(String logDate) => DraftMealState(
    components: [_FakeComponent()],
    eatenAt: DateTime(2026, 9, 22, 8),
    name: 'Porridge',
  );
}

void main() {
  late PaywallOpens opens;
  late ProviderContainer container;
  const logDate = '2026-09-22';

  setUp(() {
    opens = PaywallOpens();
    container = ProviderContainer(
      overrides: [
        writesRefused(),
        opens.override,
        mealLoggingServiceProvider.overrideWith(
          untouched('mealLoggingService'),
        ),
        mealLogRepositoryProvider.overrideWith(untouched('mealLogRepository')),
        savedMealsRepositoryProvider.overrideWith(
          untouched('savedMealsRepository'),
        ),
        userRepositoryProvider.overrideWith(untouched('userRepository')),
        mealLogControllerProvider.overrideWith(_SeededLog.new),
        draftMealControllerProvider.overrideWith(_SeededDraft.new),
      ],
    );
    addTearDown(container.dispose);
  });

  group('MealLogController, lapsed', () {
    MealLogController ctrl() =>
        container.read(mealLogControllerProvider.notifier);
    final paths = <String, Future<Object?> Function()>{
      'logManualMeal': () =>
          ctrl().logManualMeal(name: 'Porridge', logDate: logDate),
      'logSavedMeal': () =>
          ctrl().logSavedMeal(savedMeal: _FakeSavedMeal(), logDate: logDate),
      'logSavedMeals': () => ctrl().logSavedMeals(
        savedMeals: [_FakeSavedMeal()],
        logDate: logDate,
      ),
      'logRecipe': () =>
          ctrl().logRecipe(params: _FakeRecipeParams(), logDate: logDate),
      'logFromComponents': () => ctrl().logFromComponents(
        name: 'Porridge',
        logDate: logDate,
        source: MealLogSource.manual,
        components: [_FakeComponent()],
      ),
      'updateLog': () => ctrl().updateLog(_FakeMealLog()),
      'restoreLog': () => ctrl().restoreLog('l1'),
      'deleteLog': () => ctrl().deleteLog('l1'),
      'saveLogAsFavorite': () => ctrl().saveLogAsFavorite(_FakeMealLog()),
      'deleteSavedMeal': () => ctrl().deleteSavedMeal('m1'),
    };
    for (final entry in paths.entries) {
      test('${entry.key} opens the paywall and writes nothing', () async {
        await expectWriteRefused(opens, entry.value);
        expect(container.read(mealLogControllerProvider).hasError, isFalse);
      });
    }
  });

  test('DraftMealController.save, lapsed: refused, the draft kept', () async {
    final provider = draftMealControllerProvider(logDate);
    final saved = await container.read(provider.notifier).save();
    expect(saved, isFalse);
    expect(opens.count, 1);
    expect(container.read(provider).components, hasLength(1));
  });
}
