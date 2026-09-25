// G25 (qa ea7fe30, Xuan's live bug #4 — the composition ruling's one-tap ⊕):
// tapping a Recommended row must log, not open search. At tap the curated
// row RESOLVES to its real food in the local `foods` mirror (real macros,
// zero invented numbers) and commits slot-tagged through the ordinary
// meal-log path; every carb surface ripples in the same frame (G24). The
// search handoff survives ONLY for a row that resolves to nothing, and the
// seam enumerates every such row as a data finding.
//
// Two reds:
//  * L2 `recommended-plus-one-tap-logs` — tap ⊕ → slot-tagged log with the
//    RESOLVED food's real macros + slot header/receipt ripple, one frame,
//    no navigation;
//  * seam `curated-rows-resolve` — all 27 producer-shaped curated rows run
//    against the producer-shaped foods mirror; the resolved and unresolved
//    sets are PINNED and the unresolved list is printed for the curation
//    record.
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/carb_loading/application/carb_slot_recommendations.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_food_repository.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/meal_type.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/screens/carb_slot_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/log_meal_screen.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fixtures/g25_catalog_fixtures.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

const userId = 'user-g25';

// The mutable log store the fake controller writes and the overridden
// mealLogsForDate provider watches — one write, one re-emit, real
// carbDashboardForDate recompute (the ripple under test is the real one).
final _logStore = StateProvider<List<MealLog>>((_) => const []);
final _loggedCalls = <({String name, MealSlot? slot, List<MealComponent> components, String? logMethod})>[];

class _FakeMealLogController extends MealLogController {
  @override
  Future<void> build() async {}

  @override
  Future<void> logFromComponents({
    required String name,
    MealSlot? slot,
    required String logDate,
    required MealLogSource source,
    required List<MealComponent> components,
    String? photoPath,
    String? notes,
    DateTime? eatenAt,
    String? logMethod,
  }) async {
    _loggedCalls.add((
      name: name,
      slot: slot,
      components: components,
      logMethod: logMethod,
    ));
    double sum(double? Function(MealComponent) f) =>
        components.fold(0.0, (a, c) => a + (f(c) ?? 0));
    final log = MealLog(
      id: 'log-${_loggedCalls.length}',
      userId: userId,
      logDate: logDate,
      name: name,
      source: source,
      components: components,
      slot: slot,
      carbsG: sum((c) => c.carbG),
      proteinG: sum((c) => c.proteinG),
      fatG: sum((c) => c.fatG),
      calories: components.fold<int>(0, (a, c) => a + (c.calories ?? 0)),
      eatenAt: eatenAt ?? DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    ref.read(_logStore.notifier).state = [
      ...ref.read(_logStore),
      log,
    ];
  }
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  late AppDatabase db;

  setUp(() {
    _loggedCalls.clear();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
  });

  Future<void> seedFoodsMirror() async {
    for (final f in foodRowFixtures) {
      await db.into(db.foodsTable).insert(
            FoodsTableCompanion.insert(
              id: f.id,
              name: Value(f.name),
              displayName: Value(f.displayName),
              servingSize: Value(f.servingSize),
              caloriesPerServing: Value(f.calories),
              carbsPerServing: Value(f.carbs),
              proteinPerServing: Value(f.protein),
              fatPerServing: Value(f.fat),
            ),
          );
    }
  }

  test(
      'seam curated-rows-resolve: every curated row resolves or is an '
      'ENUMERATED data finding — sets pinned', () async {
    await seedFoodsMirror();

    final resolved = <String>[];
    final unresolved = <String>[];
    for (final row in curatedRowFixtures) {
      final query = row.displayName.contains('(')
          ? row.displayName
                .substring(0, row.displayName.indexOf('('))
                .trim()
          : row.displayName;
      final resolution = await resolveCarbRecommendation(db, query);
      (resolution == null ? unresolved : resolved).add(row.name);
      if (resolution != null) {
        expect(resolution.component.carbG, isNotNull,
            reason: '${row.name}: a resolution carries real macros');
        expect(resolution.title, isNotEmpty);
      }
    }

    // The curation record — qa carries this list as data work, so it is
    // ALWAYS printed, green or red.
    // ignore: avoid_print
    print('G25 curated-rows-resolve — unresolved (${unresolved.length}/'
        '${curatedRowFixtures.length}): $unresolved');

    expect(curatedRowFixtures, hasLength(27),
        reason: 'the full seeded curation, producer-shaped');
    // Pinned sets: curation data work flips entries here DELIBERATELY.
    expect(resolved, [
      'apple',
      'bagel',
      'banana',
      'berries',
      'dates',
      'fig_bar',
      'oats',
      'orange_juice',
      'pretzels',
      'sports_drink',
      'toast',
      'waffle',
    ]);
    expect(unresolved, [
      'baked_potato',
      'beet_juice',
      'beets',
      'cereal',
      'energy_gel',
      'graham_crackers',
      'pancake',
      'pasta_marinara',
      'pizza',
      'rice',
      'rice_pudding',
      'saltines',
      'sandwich',
      'smoothie',
      'sweet_potato',
    ]);
  });

  testWidgets(
      'L2 recommended-plus-one-tap-logs: tap ⊕ → slot-tagged real-macro log '
      '+ slot surfaces ripple, one frame, no navigation', (tester) async {
    await seedFoodsMirror();
    // The curated Toast row, suitable for breakfast (producer shape).
    await db.into(db.carbLoadingFoodsTable).insert(
          CarbLoadingFoodsTableCompanion.insert(
            id: 'cf-toast',
            name: 'toast',
            displayName: 'Toast (1 slice)',
            carbsPerServing: 25,
            mealTypes: const Value('{breakfast}'),
          ),
        );
    // A live plan so today IS a loading day and the Breakfast card exists.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await db.into(db.carbLoadingPlansTable).insert(
          CarbLoadingPlansTableCompanion.insert(
            id: const Value('plan-g25'),
            userId: userId,
            totalDays: 1,
            startDate: today,
            endDate: today,
            dailyCarbTargetGrams: 544,
            generatedAt: DateTime(2026, 9, 20),
          ),
        );
    await db.into(db.carbLoadingDaysTable).insert(
          CarbLoadingDaysTableCompanion.insert(
            id: const Value('day-g25'),
            carbLoadingPlanId: 'plan-g25',
            planDate: today,
            dayNumber: 1,
            carbTargetGrams: 544,
          ),
        );

    final logger = MockAppLogger();
    when(() => logger.debug(any(),
        context: any(named: 'context'),
        data: any(named: 'data'))).thenReturn(null);
    when(() => logger.warning(any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'))).thenReturn(null);
    when(() => logger.error(any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'))).thenReturn(null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          userIdProvider.overrideWith((ref) async => userId),
          carbLoadingFoodRepositoryProvider.overrideWithValue(
            CarbLoadingFoodRepository(
              database: db,
              supabase: MockSupabaseClient(),
              logger: logger,
            ),
          ),
          carbLoadingRepositoryProvider.overrideWithValue(
            CarbLoadingRepository(
              supabase: MockSupabaseClient(),
              database: db,
              logger: logger,
              sentry: MockSentryReporter(),
            ),
          ),
          mealLogControllerProvider.overrideWith(_FakeMealLogController.new),
          mealLogsForDateProvider.overrideWith((ref, date) async* {
            yield ref
                .watch(_logStore)
                .where((l) => l.logDate == date)
                .toList();
          }),
        ],
        child: MaterialApp(
          home: CarbSlotScreen(
            slot: MealType.breakfast,
            dateStr: _ymd(today),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Before: the rec row renders, nothing logged.
    expect(find.byKey(const ValueKey('carb_slot.rec_cf-toast')),
        findsOneWidget);
    expect(find.text('Nothing logged in this slot yet.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('carb_slot.rec_cf-toast')));
    await tester.pumpAndSettle();

    // One-tap logged with the RESOLVED food's REAL macros (foods mirror:
    // Toast — 17 g carbs, 90 kcal — NOT the curated row's 25 g estimate).
    expect(_loggedCalls, hasLength(1));
    final call = _loggedCalls.single;
    expect(call.name, 'Toast');
    expect(call.slot, MealSlot.breakfast);
    expect(call.logMethod, 'carb_slot_recommendation');
    expect(call.components.single.carbG, 17.0,
        reason: 'the resolved food\'s stored macros, nothing invented');
    expect(call.components.single.calories, 90);

    // The slot surfaces rippled in the same settled frame: the Logged
    // section now carries the committed row (real provider recompute).
    expect(find.text('Nothing logged in this slot yet.'), findsNothing);
    expect(find.text('Toast'), findsWidgets);

    // Zero navigation: the search surface never opened.
    expect(find.byType(LogMealScreen), findsNothing);
  });
}
