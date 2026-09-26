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
///
/// Ticket 135 (Findings 112-006, 112-012, 112-013, 112-025):
/// - A Recent row logged at 2 servings previews and re-logs its per-serving
///   base, and its sheet starts on the source log's slot.
/// - A double tap on Log it writes one row and opens no second sheet.
/// - Combo and single-ingredient logs from Common track `method: common`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_logging_service.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/quick_assembly.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/saved_meal.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/log_meal_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:mealvana_endurance/features/subscription/application/pro_gate.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/widget_test_harness.dart';

const _logDate = '2026-09-25';

class _MockService extends Mock implements MealLoggingService {}

class _MockUserRepo extends Mock implements UserRepository {}

class _MockUser extends Mock implements UserProfile {}

class _FakeMealLog extends Fake implements MealLog {}

class _MockPrefs extends Mock implements SharedPreferences {}

/// The same meal re-logged at 2 servings (row 5543d340's shape): items and
/// totals doubled, `servings` 2, tagged dinner.
final _twoServingLog = _recentLog.copyWith(
  id: '5543d340-0000-4000-8000-000000000002',
  slot: MealSlot.dinner,
  servings: 2,
  components: const [
    MealComponent(
      name: 'Rice cake',
      portion: '4 cakes',
      calories: 140,
      carbG: 30,
      proteinG: 2.8,
      fatG: 1.2,
    ),
    MealComponent(
      name: 'Almond butter',
      portion: '2 tbsp',
      calories: 196,
      carbG: 6,
      proteinG: 6.8,
      fatG: 18,
    ),
  ],
  calories: 336,
  carbsG: 36,
  proteinG: 9.6,
  fatG: 19.2,
);

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
  late RecordingAnalyticsTracker analytics;

  setUpAll(() {
    registerFallbackValue(MealLogSource.manual);
    registerFallbackValue(_recentLog);
  });

  setUp(() {
    analytics = RecordingAnalyticsTracker();
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
        servings: any(named: 'servings'),
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

  Future<void> openLogAMeal(
    WidgetTester tester, {
    List<MealLog> recent = const [],
  }) async {
    await smokeScreen(
      tester,
      const LogMealScreen(logDate: _logDate, source: 'test'),
      settle: false,
      // The harness's app deps are replaced by a recording analytics sink
      // (112-025), so its other defaults are passed here by hand.
      withAppDeps: false,
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        mockSharedPreferences(),
        writeAccessProvider.overrideWithValue(const AsyncData(true)),
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: analytics,
            supabaseClient: fakeSupabaseClient(),
            sentry: const NoopSentryReporter(),
            logger: const NoopAppLogger(),
            sharedPreferences: _MockPrefs(),
          ),
        ),
        mealLoggingServiceProvider.overrideWithValue(service),
        userRepositoryProvider.overrideWith((ref) async => userRepo),
        recentMealsProvider.overrideWith(
          (ref) => Stream.value(recent.isEmpty ? [_recentLog] : recent),
        ),
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
        servings: any(named: 'servings'),
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
        servings: any(named: 'servings'),
      ),
    ).captured;
    expect(captured[0], 'Oatmeal + raisins');
    expect(
      (captured[1] as List<MealComponent>).map((c) => c.toJson()),
      tile.components.map((c) => c.toJson()),
    );
  });

  MealLog capturedRelogOriginal() =>
      verify(
            () => service.relogMeal(
              original: captureAny(named: 'original'),
              userId: any(named: 'userId'),
              slot: any(named: 'slot'),
              logDate: any(named: 'logDate'),
              eatenAt: any(named: 'eatenAt'),
              servings: any(named: 'servings'),
            ),
          ).captured.single
          as MealLog;

  List<dynamic> capturedComponentLogs() => verify(
    () => service.logFromComponents(
      userId: any(named: 'userId'),
      name: captureAny(named: 'name'),
      slot: any(named: 'slot'),
      logDate: any(named: 'logDate'),
      source: any(named: 'source'),
      components: captureAny(named: 'components'),
      photoPath: any(named: 'photoPath'),
      notes: any(named: 'notes'),
      eatenAt: any(named: 'eatenAt'),
      servings: captureAny(named: 'servings'),
    ),
  ).captured;

  group('112-012 / 112-013: a Recent row logged at 2 servings', () {
    testWidgets('previews and re-logs the per-serving base', (tester) async {
      await openLogAMeal(tester, recent: [_twoServingLog]);
      await tester.tap(find.text('Recent'));
      await frames(tester);

      expect(
        find.textContaining('336 kcal'),
        findsNothing,
        reason: 'the Recent row shows the base, not the doubled row',
      );
      expect(find.textContaining('168 kcal'), findsOneWidget);

      await tester.tap(find.text('Rice cake and Almond butter'));
      await frames(tester);
      // The sheet's preview at 1 serving is the original amount.
      expect(find.textContaining('168 kcal'), findsWidgets);

      await logIt(tester);

      final original = capturedRelogOriginal();
      expect(original.servings, 1);
      expect(original.calories, 168);
      expect(original.components.map((c) => c.portion), ['2 cakes', '1 tbsp']);
    });

    testWidgets('the sheet starts on the source log\'s slot', (tester) async {
      await openLogAMeal(tester, recent: [_twoServingLog]);
      await tester.tap(find.text('Recent'));
      await frames(tester);

      await tester.tap(find.text('Rice cake and Almond butter'));
      await frames(tester);

      final dinner = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('slot_chip.dinner')),
      );
      expect(dinner.selected, isTrue);
      final anyTime = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('slot_chip.any_time')),
      );
      expect(anyTime.selected, isFalse);

      await logIt(tester);
      verify(
        () => service.relogMeal(
          original: any(named: 'original'),
          userId: any(named: 'userId'),
          slot: MealSlot.dinner,
          logDate: any(named: 'logDate'),
          eatenAt: any(named: 'eatenAt'),
          servings: any(named: 'servings'),
        ),
      ).called(1);
    });
  });

  group('112-006: a double tap on Log it', () {
    testWidgets('logs once and opens nothing under the closing sheet', (
      tester,
    ) async {
      await openLogAMeal(tester);
      await tester.tap(find.text('Common'));
      await frames(tester);

      await tester.tap(find.text('Banana + peanut butter'));
      await frames(tester);
      final logIt = find.text('Log it');
      final where = tester.getCenter(logIt);

      await tester.tap(logIt);
      // One frame later the sheet is still closing; the second tap lands.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tapAt(where);
      await frames(tester);

      final captured = capturedComponentLogs();
      expect(captured[0], 'Banana + peanut butter');
      expect(find.text('Log it'), findsNothing, reason: 'no second sheet');
      expect(find.byType(BottomSheet), findsNothing);
    });
  });

  group('112-025: Common logs are tracked as common', () {
    Map<String, dynamic> mealLogged() =>
        analytics.findEvents('meal_logged').single.properties!;

    testWidgets('a quick-add combo', (tester) async {
      await openLogAMeal(tester);
      await tester.tap(find.text('Common'));
      await frames(tester);

      await tester.tap(find.text('Banana + peanut butter'));
      await logIt(tester);

      expect(mealLogged()['method'], 'common');
      expect(mealLogged()['source'], 'manual');
      expect(capturedComponentLogs()[2], 1, reason: 'a combo has no stepper');
    });

    testWidgets('a single ingredient at 1.5 servings keeps its unit and '
        'records the count', (tester) async {
      await openLogAMeal(tester);
      await tester.tap(find.text('Common'));
      await frames(tester);

      await tester.scrollUntilVisible(
        find.text('Egg'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Egg'));
      await frames(tester);
      await tester.tap(find.byIcon(Icons.add_circle_outline).last);
      await logIt(tester);

      expect(mealLogged()['method'], 'common');
      final captured = capturedComponentLogs();
      expect(captured[0], 'Egg');
      final egg = (captured[1] as List<MealComponent>).single;
      expect(egg.portion, '1.5 large');
      expect(egg.calories, 108);
      expect(egg.carbG, 0.6);
      expect(captured[2], 1.5);
    });
  });
}
