// Ticket 83 (testing-wave; Finding 23-002): the AI's note survives the save.
//
// Review & Log showed the note the analysis wrote ("Butter estimated at
// 1 tsp. ...") and dropped it at "Log this meal": `meal_logs.notes` stayed
// null and Edit Meal never showed it.
//
// Seam test (docs/test/README.md): the analysis is the JSON the
// `describe-meal` function answers (schema.ts `MealAnalysisSchema`) parsed by
// the real [MealAnalysisResult.fromJson]; the save goes through the real
// Review & Log screen, the real [MealLogController] and
// [MealLoggingService], and the real [MealLogRepository] on an in-memory
// Drift. Only the wire ([MealLogRepository.sendUpsert]) is recorded instead
// of sent, and the user lookup is faked.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_analysis_result.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/edit_meal_log_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/meal_review_screen.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/widget_test_harness.dart';

const _user = '607f9dd5-6fa7-48ee-a628-720d4a0506a1';
const _logDate = '2026-09-24';
const _note =
    'Standard breakfast-style lunch. Butter estimated at 1 tsp. Eggs cooked '
    'with a small amount of butter or oil included in calorie count.';

/// The `describe-meal` answer behind 23-002 (`MealAnalysisSchema`).
Map<String, dynamic> _describeMealAnswer() => {
  'name': 'Eggs on toast',
  'suggested_slot': 'lunch',
  'confidence': 'medium',
  'items': [
    {
      'name': 'Scrambled eggs',
      'portion': '2 large',
      'calories': 180,
      'carb_g': 1,
      'protein_g': 12,
      'fat_g': 14,
      'sodium_mg': 190,
    },
    {
      'name': 'Buttered toast',
      'portion': '1 slice',
      'calories': 110,
      'carb_g': 14,
      'protein_g': 3,
      'fat_g': 5,
      'sodium_mg': 150,
    },
  ],
  'totals': {
    'calories': 290,
    'carb_g': 15,
    'protein_g': 15,
    'fat_g': 19,
    'sodium_mg': 340,
  },
  'notes': _note,
  '_usage': {'input_tokens': 900, 'output_tokens': 200, 'model': 'haiku'},
};

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockUserRepo extends Mock implements UserRepository {}

class _MockUser extends Mock implements UserProfile {}

class _Upsert {
  _Upsert(this.rows, {required this.ignoreDuplicates});
  final List<Map<String, dynamic>> rows;
  final bool ignoreDuplicates;
}

/// The real repository; the wire records what it would send.
class _RecordingRepository extends MealLogRepository {
  _RecordingRepository({required super.database})
    : super(
        supabase: _MockSupabaseClient(),
        logger: const NoopAppLogger(),
        sentry: const NoopSentryReporter(),
      );

  final sent = <_Upsert>[];

  @override
  Future<void> sendUpsert(
    List<Map<String, dynamic>> rows, {
    bool ignoreDuplicates = false,
  }) async {
    sent.add(_Upsert(rows, ignoreDuplicates: ignoreDuplicates));
  }
}

void main() {
  late AppDatabase db;
  late _RecordingRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = _RecordingRepository(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpReview(WidgetTester tester) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final user = _MockUser();
    when(() => user.id).thenReturn(_user);
    final users = _MockUserRepo();
    when(() => users.getCurrentUser()).thenAnswer((_) async => user);

    final result = MealAnalysisResult.fromJson(_describeMealAnswer());
    final router = GoRouter(
      initialLocation: '/main',
      routes: [
        GoRoute(
          path: '/main',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push(
                '/meal-log/review',
                extra: {
                  'result': result,
                  'source': 'describe',
                  'logDate': _logDate,
                  'photoPath': null,
                },
              ),
              child: const Text('open review'),
            ),
          ),
        ),
        GoRoute(
          path: '/meal-log/review',
          builder: (_, _) => const MealReviewScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          mealLogRepositoryProvider.overrideWithValue(repo),
          // Not on this path; the service is built with it.
          savedMealsRepositoryProvider.overrideWithValue(
            SavedMealsRepository(
              supabase: _MockSupabaseClient(),
              database: db,
              logger: const NoopAppLogger(),
              sentry: const NoopSentryReporter(),
            ),
          ),
          userRepositoryProvider.overrideWith((ref) async => users),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open review'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(_note), findsOneWidget, reason: 'Review & Log shows it');
  }

  Future<void> logThisMeal(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Log this meal'));
    await tester.tap(find.text('Log this meal'));
    // Drift answers on real time; the fake clock alone never lets it.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(MealReviewScreen), findsNothing);
  }

  testWidgets('Log this meal keeps the AI note on the local row and in the '
      'upload', (tester) async {
    await pumpReview(tester);
    await logThisMeal(tester);

    final local = await tester.runAsync(() => repo.getRecentLogs(_user));
    expect(local!.single.name, 'Eggs on toast');
    expect(local.single.notes, _note);

    final uploaded = repo.sent.expand((u) => u.rows).toList();
    expect(uploaded, isNotEmpty, reason: 'the immediate upload ran');
    for (final row in uploaded) {
      expect(row['notes'], _note);
    }
  });

  testWidgets('a retried upload sends the note on both the insert and the '
      'update', (tester) async {
    await pumpReview(tester);
    await logThisMeal(tester);

    await tester.runAsync(() async {
      // The immediate upload was only recorded, never acknowledged, as when
      // the phone was offline.
      await db.customStatement('UPDATE meal_logs SET needs_upload = 1');
      repo.sent.clear();
      final result = await repo.uploadDirtyRecords(_user);
      expect(result.success, isTrue);
    });

    final insert = repo.sent.where((u) => u.ignoreDuplicates);
    final update = repo.sent.where((u) => !u.ignoreDuplicates);
    expect(insert.expand((u) => u.rows).single['notes'], _note);
    expect(update.expand((u) => u.rows).single['notes'], _note);
  });

  testWidgets('Edit Meal shows the note of a meal logged with items', (
    tester,
  ) async {
    await pumpReview(tester);
    await logThisMeal(tester);
    final logged = (await tester.runAsync(
      () => repo.getRecentLogs(_user),
    ))!.single;
    expect(logged.components, hasLength(2));

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/edit', extra: {'log': logged}),
              child: const Text('open edit'),
            ),
          ),
        ),
        GoRoute(path: '/edit', builder: (_, _) => const EditMealLogScreen()),
      ],
    );
    addTearDown(router.dispose);
    // Unmount the Review & Log app before Edit Meal gets its own.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Edit Meal'), findsOneWidget);

    final notesField = find.widgetWithText(TextFormField, 'Notes (optional)');
    expect(notesField, findsOneWidget, reason: 'open without a tap');
    expect(tester.widget<TextFormField>(notesField).controller!.text, _note);
  });
}
