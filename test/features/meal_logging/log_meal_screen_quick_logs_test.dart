/// Ticket 58 (testing-wave; Findings 26-002, 26-003): Log a Meal's quick logs
/// keep what they came from.
///
/// Through the real Log a Meal screen and the real [MealLogController]; only
/// the meal-logging service (the write), the Recent stream and the user
/// lookup are faked.
/// - Recent → tap → Log it re-logs the tapped log itself, not a synthetic
///   one-line "1 serving" copy saved as `saved`.
/// - Common → a quick-add tile → Log it saves under the tile's name
///   ("Oatmeal + raisins"), not one built from its items ("Rolled oats and
///   Raisins"), so Recent's name de-duplication sees the same meal next time.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_logging_service.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/quick_assembly.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/saved_meal.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/log_meal_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/widget_test_harness.dart';

const _logDate = '2026-09-25';

class _MockService extends Mock implements MealLoggingService {}

class _MockUserRepo extends Mock implements UserRepository {}

class _MockUser extends Mock implements UserProfile {}

class _FakeMealLog extends Fake implements MealLog {}

final _recentLog = MealLog(
  id: '9162543b-6a51-4c1e-8f0e-2f4f3a2b9d11',
  userId: 'user-1',
  logDate: '2026-09-23',
  name: 'Rice cake and Almond butter',
  source: MealLogSource.manual,
  components: const [
    MealComponent(
      name: 'Rice cake',
      portion: '2 cakes',
      calories: 70,
      carbG: 15,
      proteinG: 1.4,
      fatG: 0.6,
    ),
    MealComponent(
      name: 'Almond butter',
      portion: '1 tbsp',
      calories: 98,
      carbG: 3,
      proteinG: 3.4,
      fatG: 9,
    ),
  ],
  calories: 168,
  carbsG: 18,
  proteinG: 4.8,
  fatG: 9.6,
  createdAt: DateTime.utc(2026, 9, 23, 15),
  updatedAt: DateTime.utc(2026, 9, 23, 15),
);

void main() {
  late _MockService service;
  late _MockUserRepo userRepo;

  setUpAll(() {
    registerFallbackValue(MealLogSource.manual);
    registerFallbackValue(_recentLog);
  });

  setUp(() {
    service = _MockService();
    when(
      () => service.logFromComponents(
        userId: any(named: 'userId'),
        name: any(named: 'name'),
        slot: any(named: 'slot'),
        logDate: any(named: 'logDate'),
        source: any(named: 'source'),
        components: any(named: 'components'),
        photoPath: any(named: 'photoPath'),
        notes: any(named: 'notes'),
        eatenAt: any(named: 'eatenAt'),
      ),
    ).thenAnswer((_) async => _FakeMealLog());
    when(
      () => service.relogMeal(
        original: any(named: 'original'),
        userId: any(named: 'userId'),
        slot: any(named: 'slot'),
        logDate: any(named: 'logDate'),
        eatenAt: any(named: 'eatenAt'),
        servings: any(named: 'servings'),
      ),
    ).thenAnswer((_) async => _FakeMealLog());
    final user = _MockUser();
    when(() => user.id).thenReturn('user-1');
    userRepo = _MockUserRepo();
    when(() => userRepo.getCurrentUser()).thenAnswer((_) async => user);
  });

  Future<void> openLogAMeal(WidgetTester tester) async {
    await smokeScreen(
      tester,
      const LogMealScreen(logDate: _logDate, source: 'test'),
      settle: false,
      overrides: [
        mealLoggingServiceProvider.overrideWithValue(service),
        userRepositoryProvider.overrideWith((ref) async => userRepo),
        recentMealsProvider.overrideWith((ref) => Stream.value([_recentLog])),
        savedMealsProvider.overrideWith(
          (ref) => Stream.value(const <SavedMeal>[]),
        ),
      ],
    );
    addTearDown(tester.view.reset);
    await tester.pump(const Duration(milliseconds: 100));
  }

  // The screen never settles (search debounce, spinners), so pump frames.
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> logIt(WidgetTester tester) async {
    await frames(tester);
    await tester.tap(find.text('Log it'));
    await frames(tester);
  }

  testWidgets('Recent → tap → Log it re-logs the tapped meal itself', (
    tester,
  ) async {
    await openLogAMeal(tester);
    await tester.tap(find.text('Recent'));
    await frames(tester);

    await tester.tap(find.text('Rice cake and Almond butter'));
    await logIt(tester);

    final original =
        verify(
              () => service.relogMeal(
                original: captureAny(named: 'original'),
                userId: 'user-1',
                slot: any(named: 'slot'),
                logDate: _logDate,
                eatenAt: any(named: 'eatenAt'),
                servings: 1,
              ),
            ).captured.single
            as MealLog;
    expect(original.id, _recentLog.id);
    verifyNever(
      () => service.logFromComponents(
        userId: any(named: 'userId'),
        name: any(named: 'name'),
        slot: any(named: 'slot'),
        logDate: any(named: 'logDate'),
        source: any(named: 'source'),
        components: any(named: 'components'),
        photoPath: any(named: 'photoPath'),
        notes: any(named: 'notes'),
        eatenAt: any(named: 'eatenAt'),
      ),
    );
  });

  testWidgets('Common → "Oatmeal + raisins" → Log it saves under the tile '
      'name with the tile items', (tester) async {
    final tile = kQuickAssemblies.firstWhere(
      (a) => a.name == 'Oatmeal + raisins',
    );
    await openLogAMeal(tester);
    await tester.tap(find.text('Common'));
    await frames(tester);

    await tester.scrollUntilVisible(
      find.text('Oatmeal + raisins'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Oatmeal + raisins'));
    await logIt(tester);

    final captured = verify(
      () => service.logFromComponents(
        userId: 'user-1',
        name: captureAny(named: 'name'),
        slot: any(named: 'slot'),
        logDate: _logDate,
        source: any(named: 'source'),
        components: captureAny(named: 'components'),
        photoPath: any(named: 'photoPath'),
        notes: any(named: 'notes'),
        eatenAt: any(named: 'eatenAt'),
      ),
    ).captured;
    expect(captured[0], 'Oatmeal + raisins');
    expect(
      (captured[1] as List<MealComponent>).map((c) => c.toJson()),
      tile.components.map((c) => c.toJson()),
    );
  });
}
