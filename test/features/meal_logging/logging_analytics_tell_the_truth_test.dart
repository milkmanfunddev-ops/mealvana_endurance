// Ticket 50 (testing-wave; Findings 24-002, 27-003): logging analytics tell
// the truth.
//
// - `diary_closed` reported `items_logged: 0` after a photo or describe log
//   (Log a Meal closed as Review & Log opened, before the save) and after
//   manual logs (the Manual tab's success path never counted).
// - Removing a meal from the timeline tracked no `meal_log_deleted`: the
//   row's menu is the controller's only listener, it closes as the row
//   leaves the list, and `deleteLog` bailed on `!ref.mounted` before the
//   track call.
//
// Seam tests (docs/test/README.md): each write path runs through the real
// [MealLogController] with a listener-less `read(...notifier)`, the call
// shape the screens use, into a recording analytics sink. Only the
// repositories and the user lookup are faked; each fake yields the event
// loop, as the real Drift/Supabase round trip does.

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/meal_logging/application/diary_session.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_logging_service.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../../helpers/fakes/recording_analytics_tracker.dart';

const _user = '607f9dd5-6fa7-48ee-a628-720d4a0506a1';
const _logDate = '2026-09-24';

class _MockUserRepo extends Mock implements UserRepository {}

class _MockMealLogRepo extends Mock implements MealLogRepository {}

class _MockService extends Mock implements MealLoggingService {}

class _MockPrefs extends Mock implements SharedPreferences {}

class _MockUser extends Mock implements UserProfile {}

class _FakeMealLog extends Fake implements MealLog {}

Future<void> _yield() => Future<void>.delayed(Duration.zero);

void main() {
  late RecordingAnalyticsTracker analytics;
  late _MockMealLogRepo repo;
  late _MockService service;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(MealLogSource.manual);
  });

  setUp(() {
    analytics = RecordingAnalyticsTracker();
    repo = _MockMealLogRepo();
    service = _MockService();

    final user = _MockUser();
    when(() => user.id).thenReturn(_user);
    final userRepo = _MockUserRepo();
    when(() => userRepo.getCurrentUser()).thenAnswer((_) async {
      await _yield();
      return user;
    });

    when(
      () => repo.softDeleteLog(
        id: any(named: 'id'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) => _yield());
    when(
      () => repo.restoreLog(
        id: any(named: 'id'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) => _yield());
    when(
      () => service.logManualMeal(
        userId: any(named: 'userId'),
        name: any(named: 'name'),
        slot: any(named: 'slot'),
        logDate: any(named: 'logDate'),
        calories: any(named: 'calories'),
        carbsG: any(named: 'carbsG'),
        proteinG: any(named: 'proteinG'),
        fatG: any(named: 'fatG'),
        sodiumMg: any(named: 'sodiumMg'),
        notes: any(named: 'notes'),
        eatenAt: any(named: 'eatenAt'),
      ),
    ).thenAnswer((_) async {
      await _yield();
      return _FakeMealLog();
    });
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
    ).thenAnswer((_) async {
      await _yield();
      return _FakeMealLog();
    });

    container = ProviderContainer(
      overrides: [
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: analytics,
            supabaseClient: fakeSupabaseClient(),
            sentry: const NoopSentryReporter(),
            logger: const NoopAppLogger(),
            sharedPreferences: _MockPrefs(),
          ),
        ),
        userRepositoryProvider.overrideWith((ref) async => userRepo),
        mealLogRepositoryProvider.overrideWithValue(repo),
        mealLoggingServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
  });

  MealLogController controller() =>
      container.read(mealLogControllerProvider.notifier);

  DiarySession diary() => container.read(diarySessionProvider);

  Map<String, dynamic>? only(String event) {
    final found = analytics.findEvents(event);
    expect(found, hasLength(1), reason: '$event fired ${found.length} times');
    return found.single.properties;
  }

  group('meal_log_deleted (27-003)', () {
    test('Remove on a timeline row tracks the log id', () async {
      await controller().deleteLog('7c20d895');

      expect(only('meal_log_deleted'), {'log_id': '7c20d895'});
    });

    test('Undo tracks meal_log_restored the same way', () async {
      await controller().restoreLog('7c20d895');

      expect(only('meal_log_restored'), {'log_id': '7c20d895'});
    });
  });

  group('diary_closed items_logged (24-002, 27-003)', () {
    test('two manual logs, then Back: items_logged 2', () async {
      diary().open(logDate: _logDate);

      for (final name in ['Oats', 'Banana']) {
        await controller().logManualMeal(name: name, logDate: _logDate);
      }
      diary().closeDiary();

      expect(analytics.findEvents('meal_logged'), hasLength(2));
      expect(only('diary_closed'), {
        'duration_sec': isA<int>(),
        'items_logged': 2,
        'log_date': _logDate,
      });
    });

    test('a photo analyzed then logged on Review & Log: diary_closed fires '
        'after the save with items_logged 1', () async {
      diary().open(logDate: _logDate);

      // Describe/photo hands the diary to Review & Log, then Log a Meal
      // closes under it.
      diary().handOff();
      diary().closeDiary();
      expect(analytics.hasEvent('diary_closed'), isFalse);

      await controller().logFromComponents(
        name: 'Chicken bowl',
        logDate: _logDate,
        source: MealLogSource.photo,
        components: const [
          MealComponent(name: 'Chicken', portion: '1 bowl', calories: 300),
        ],
      );
      // Review & Log closes (context.go('/main') after the save).
      diary().closeHandOff();

      expect(
        analytics.events.map((e) => e.name),
        containsAllInOrder(['meal_logged', 'diary_closed']),
      );
      expect(only('diary_closed'), {
        'duration_sec': isA<int>(),
        'items_logged': 1,
        'log_date': _logDate,
      });
    });

    test('Review & Log backed out of without a save: items_logged 0', () {
      diary().open(logDate: _logDate);
      diary().handOff();
      diary().closeDiary();
      diary().closeHandOff();

      expect(only('diary_closed')?['items_logged'], 0);
    });

    test('a failed log does not count', () async {
      when(
        () => service.logManualMeal(
          userId: any(named: 'userId'),
          name: any(named: 'name'),
          slot: any(named: 'slot'),
          logDate: any(named: 'logDate'),
          calories: any(named: 'calories'),
          carbsG: any(named: 'carbsG'),
          proteinG: any(named: 'proteinG'),
          fatG: any(named: 'fatG'),
          sodiumMg: any(named: 'sodiumMg'),
          notes: any(named: 'notes'),
          eatenAt: any(named: 'eatenAt'),
        ),
      ).thenThrow(StateError('write failed'));
      diary().open(logDate: _logDate);

      await controller().logManualMeal(name: 'Oats', logDate: _logDate);
      diary().closeDiary();

      expect(only('diary_closed')?['items_logged'], 0);
    });

    test('Review & Log reached outside a diary tracks nothing', () {
      diary().closeHandOff();
      diary().closeDiary();

      expect(analytics.hasEvent('diary_closed'), isFalse);
    });
  });
}
