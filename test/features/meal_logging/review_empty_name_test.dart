// Ticket 45 (testing-wave develop-2026-10, Finding 31-002): an empty meal name
// says why it will not log.
//
// Review & Log returned early on an empty name with no feedback while Log
// this meal stayed enabled. Now the button is disabled and the name field
// shows `meal_log.review.name_required` from content.
//
// On the `ai_note_survives_the_save_test.dart` harness: the analysis is the
// JSON `describe-meal` answers, parsed by the real
// [MealAnalysisResult.fromJson]; the real Review & Log screen, the real
// [MealLogController] and the real [MealLogRepository] on an in-memory Drift.
// Only the wire ([MealLogRepository.sendUpsert]) is recorded.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_analysis_result.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/meal_review_screen.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/test_content.dart';
import '../../helpers/widget_test_harness.dart';

const _user = '607f9dd5-6fa7-48ee-a628-720d4a0506a1';
const _logDate = '2026-10-08';

/// The `describe-meal` answer from run 31 (`MealAnalysisSchema`).
Map<String, dynamic> _describeMealAnswer() => {
  'name': 'Scrambled eggs, whole wheat toast with butter, and banana',
  'suggested_slot': 'breakfast',
  'confidence': 'medium',
  'items': [
    {
      'name': 'Scrambled eggs (x2)',
      'portion': '2 large eggs, scrambled',
      'calories': 182,
      'carb_g': 1.2,
      'protein_g': 12.6,
      'fat_g': 13.8,
      'sodium_mg': 189,
    },
  ],
  'totals': {
    'calories': 182,
    'carb_g': 1.2,
    'protein_g': 12.6,
    'fat_g': 13.8,
    'sodium_mg': 189,
  },
  '_usage': {'input_tokens': 900, 'output_tokens': 200, 'model': 'sonnet'},
};

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockUserRepo extends Mock implements UserRepository {}

class _MockUser extends Mock implements UserProfile {}

/// The real repository; the wire records what it would send.
class _RecordingRepository extends MealLogRepository {
  _RecordingRepository({required super.database})
    : super(supabase: _MockSupabaseClient(), report: const NoopReport());

  final sent = <List<Map<String, dynamic>>>[];

  @override
  Future<void> sendUpsert(
    List<Map<String, dynamic>> rows, {
    bool ignoreDuplicates = false,
  }) async {
    sent.add(rows);
  }
}

void main() {
  late AppDatabase db;
  late _RecordingRepository repo;

  final content = loadDefaultContent();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = _RecordingRepository(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('an emptied name disables Log this meal, says why, and writes '
      'no row', (tester) async {
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
          contentServiceProvider.overrideWith(testContentService),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          mealLogRepositoryProvider.overrideWithValue(repo),
          savedMealsRepositoryProvider.overrideWithValue(
            SavedMealsRepository(
              supabase: _MockSupabaseClient(),
              database: db,
              report: const NoopReport(),
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

    final required = content['meal_log.review.name_required']!;
    expect(required, 'Give this meal a name to log it.');
    final nameField = find.widgetWithText(TextFormField, 'Meal name');
    expect(find.text(required), findsNothing, reason: 'not before an edit');
    KylePrimaryButton button() => tester.widget<KylePrimaryButton>(
      find.widgetWithText(KylePrimaryButton, 'Log this meal'),
    );
    expect(button().onPressed, isNotNull);

    await tester.enterText(nameField, '   ');
    await tester.pump();

    expect(find.text(required), findsOneWidget);
    expect(button().onPressed, isNull);

    await tester.ensureVisible(find.text('Log this meal'));
    await tester.tap(find.text('Log this meal'), warnIfMissed: false);
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(MealReviewScreen), findsOneWidget);
    final rows = await tester.runAsync(() => repo.getRecentLogs(_user));
    expect(rows, isEmpty, reason: 'no meal_logs row is written');
    expect(repo.sent, isEmpty);

    // A name brings the button back and the line goes.
    await tester.enterText(nameField, 'Eggs');
    await tester.pump();
    expect(find.text(required), findsNothing);
    expect(button().onPressed, isNotNull);
  });
}
