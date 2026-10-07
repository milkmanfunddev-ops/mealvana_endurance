// Ticket 41 (testing-wave; Findings 25-001, 26-004): unknown numbers stay
// unknown in meal logs.
//
// - 25-001: the Manual tab accepted "250.5" kcal (decimal keyboard and filter)
//   but parsed it with `int.tryParse`, so the row saved `calories: null` and
//   the timeline read 0 kcal. The Build a Meal manual form parsed the same way.
// - 26-004: a quick add whose items carry no sodium saved `sodium_mg 0.0`,
//   because the item totals counted a missing value as 0 (`null ≠ 0`).
//
// Each write path runs through the real [MealLogController] and the real
// [MealLoggingService]; only the repository (the process boundary) is faked,
// and it captures the row that would be written.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_logging_service.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/draft_meal_controller.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/widgets/manual_component_form.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/widgets/manual_log_form.dart';

import '../../helpers/widget_test_harness.dart';

const _logDate = '2026-09-24';

/// Captures every row the service would write. Everything else is unused.
class _CapturingMealLogRepository implements MealLogRepository {
  final List<MealLog> inserted = [];

  @override
  Future<MealLog> insertLog(MealLog log) async {
    inserted.add(log);
    return log;
  }

  @override
  Future<List<MealLog>> insertLogs(List<MealLog> logs) async {
    inserted.addAll(logs);
    return logs;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedSavedMealsRepository implements SavedMealsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockUserProfile extends Mock implements UserProfile {}

List<Override> _overrides(_CapturingMealLogRepository repo) {
  final user = _MockUserProfile();
  when(() => user.id).thenReturn('user-1');
  final userRepo = _MockUserRepository();
  when(() => userRepo.getCurrentUser()).thenAnswer((_) async => user);
  return [
    mockAppExternalDeps(),
    userRepositoryProvider.overrideWith((_) async => userRepo),
    mealLoggingServiceProvider.overrideWithValue(
      MealLoggingService(
        mealLogRepository: repo,
        savedMealsRepository: _UnusedSavedMealsRepository(),
      ),
    ),
  ];
}

void main() {
  group(
    'parseCaloriesInput (the fields accept decimals, so must the parser)',
    () {
      test('rounds a decimal to the whole-number calories column', () {
        expect(parseCaloriesInput('250.5'), 251);
        expect(parseCaloriesInput('250.4'), 250);
        expect(parseCaloriesInput('250'), 250);
        expect(parseCaloriesInput('.5'), 1);
      });

      test('an empty or partial entry is unknown, never 0', () {
        expect(parseCaloriesInput(''), isNull);
        expect(parseCaloriesInput('.'), isNull);
        expect(parseCaloriesInput('  '), isNull);
      });
    },
  );

  group('MealTotals.ofComponents (null ≠ 0)', () {
    test('a field no item carries stays null', () {
      final totals = MealTotals.ofComponents(const [
        MealComponent(name: 'Oats', portion: '1 cup', calories: 150, carbG: 27),
        MealComponent(
          name: 'Raisins',
          portion: '1 box',
          calories: 130,
          carbG: 34,
        ),
      ]);
      expect(totals.calories, 280);
      expect(totals.carbsG, 61);
      expect(totals.proteinG, isNull);
      expect(totals.fatG, isNull);
      expect(totals.sodiumMg, isNull);
    });

    test('known values are summed when only some items carry one', () {
      final totals = MealTotals.ofComponents(const [
        MealComponent(name: 'Soup', portion: '1 bowl', sodiumMg: 450),
        MealComponent(name: 'Bread', portion: '1 slice'),
      ]);
      expect(totals.sodiumMg, 450);
    });

    test('a stated zero is kept as zero', () {
      final totals = MealTotals.ofComponents(const [
        MealComponent(name: 'Water', portion: '1 cup', sodiumMg: 0),
      ]);
      expect(totals.sodiumMg, 0);
    });

    test('no items at all is unknown', () {
      final totals = MealTotals.ofComponents(const []);
      expect(totals.calories, isNull);
      expect(totals.sodiumMg, isNull);
    });
  });

  group('writes through the real notifier', () {
    test(
      'a quick add of two items with no sodium saves sodium_mg null',
      () async {
        final repo = _CapturingMealLogRepository();
        final container = ProviderContainer(overrides: _overrides(repo));
        addTearDown(container.dispose);
        final sub = container.listen(mealLogControllerProvider, (_, _) {});
        addTearDown(sub.close);

        // Producer-shaped: the Common "Oatmeal + raisins" assembly items carry
        // no sodium_mg key at all (MealComponent.fromJson of the stored items).
        final components = [
          MealComponent.fromJson(const {
            'name': 'Oatmeal',
            'portion': '1 cup',
            'calories': 150,
            'carb_g': 27,
            'protein_g': 5,
            'fat_g': 3,
          }),
          MealComponent.fromJson(const {
            'name': 'Raisins',
            'portion': '1 small box',
            'calories': 130,
            'carb_g': 34,
            'protein_g': 1,
            'fat_g': 0,
          }),
        ];

        await container
            .read(mealLogControllerProvider.notifier)
            .logFromComponents(
              name: 'Oatmeal + raisins',
              logDate: _logDate,
              source: MealLogSource.manual,
              components: components,
            );

        expect(container.read(mealLogControllerProvider), isA<AsyncData>());
        expect(repo.inserted, hasLength(1));
        final row = repo.inserted.single;
        expect(row.sodiumMg, isNull);
        expect(row.calories, 280);
        expect(row.fatG, 3);
        expect(row.toSupabaseJson().containsKey('sodium_mg'), isFalse);
        for (final item in row.components) {
          expect(item.toJson().containsKey('sodium_mg'), isFalse);
        }
      },
    );

    testWidgets('Manual tab: 250.5 kcal saves as 251 (integer column)', (
      tester,
    ) async {
      final repo = _CapturingMealLogRepository();
      var logged = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(repo),
          child: wrapForTest(
            Scaffold(
              body: ManualLogForm(
                logDate: _logDate,
                onLogged: () => logged++,
                onLogError: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('manual_log.name_field')),
        'W14-25 Decimal kcal',
      );
      await tester.enterText(
        find.byKey(const ValueKey('manual_log.calories_field')),
        '250.5',
      );
      await tester.enterText(
        find.byKey(const ValueKey('manual_log.carbs_field')),
        '30.2',
      );
      await tester.enterText(
        find.byKey(const ValueKey('manual_log.protein_field')),
        '12.25',
      );
      await tester.enterText(
        find.byKey(const ValueKey('manual_log.fat_field')),
        '8.4',
      );
      final save = find.byKey(const ValueKey('manual_log.save_button'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(logged, 1);
      final row = repo.inserted.single;
      expect(row.calories, 251);
      expect(row.carbsG, 30.2);
      expect(row.proteinG, 12.25);
      expect(row.fatG, 8.4);
      expect(row.sodiumMg, isNull);
    });

    testWidgets('Build a Meal manual form: 250.5 kcal adds 251 and saves 251', (
      tester,
    ) async {
      final repo = _CapturingMealLogRepository();
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(repo),
          child: wrapForTest(
            Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  widgetRef = ref;
                  // Keep the auto-dispose draft alive like BuildMealScreen.
                  ref.watch(draftMealControllerProvider(_logDate));
                  return const ManualComponentForm(logDate: _logDate);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Homemade chili');
      await tester.enterText(fields.at(2), '250.5'); // Calories (kcal)
      await tester.enterText(fields.at(3), '30.2'); // Carbs
      final add = find.text('Add to meal');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pump();

      final draft = widgetRef.read(draftMealControllerProvider(_logDate));
      expect(draft.components.single.calories, 251);
      expect(draft.components.single.sodiumMg, isNull);

      final ok = await widgetRef
          .read(draftMealControllerProvider(_logDate).notifier)
          .save();
      await tester.pump();

      expect(ok, isTrue);
      final row = repo.inserted.single;
      expect(row.calories, 251);
      expect(row.carbsG, 30.2);
      expect(row.sodiumMg, isNull);
      expect(row.proteinG, isNull);
    });
  });
}
