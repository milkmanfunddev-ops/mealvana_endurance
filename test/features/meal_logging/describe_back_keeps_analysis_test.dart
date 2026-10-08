// Ticket 45 (testing-wave develop-2026-10, Finding 31-004): Back from Review &
// Log keeps the analysis, and seeing it again is free.
//
// Log a Meal → Describe used to pop itself and push Review in its place, so
// Back from Review landed on the Timeline: the text and the paid result were
// gone and a second Analyze charged again. The analysis now lives in
// [DescribeAnalysisController], scoped to Log a Meal, and Review is pushed on
// top of it.
//
// Seam (docs/test/README.md §Seam tests): the real controller and the real
// [MealAiService] over a mocktail SupabaseClient whose
// `functions.invoke('describe-meal', …)` answers the 200 body the function
// sent in run 31 (the analysis spread plus `_usage`). The widget half drives
// the real Log a Meal and Review & Log screens and the real MealLogController
// on an in-memory Drift; only the meal row's wire is recorded.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/presentation/widgets/token_pill.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_ai_service.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/describe_analysis_controller.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/log_meal_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/meal_review_screen.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/test_content.dart';
import '../../helpers/widget_test_harness.dart';

const _user = '607f9dd5-6fa7-48ee-a628-720d4a0506a1';
const _logDate = '2026-10-08';
const _text =
    'two scrambled eggs, a slice of whole wheat toast with butter, a banana';

/// describe-meal's 200 body in run 31 (`runs/31/notes.md`, 13-review-top):
/// the analysis spread, plus `_usage`.
Map<String, dynamic> _run31Describe200() => {
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
    {
      'name': 'Whole wheat toast with butter',
      'portion': '1 slice whole wheat bread + 1 tsp butter',
      'calories': 117,
      'carb_g': 12.8,
      'protein_g': 3.4,
      'fat_g': 5.6,
      'sodium_mg': 146,
    },
    {
      'name': 'Banana',
      'portion': '1 medium banana (~118g)',
      'calories': 105,
      'carb_g': 27,
      'protein_g': 1.3,
      'fat_g': 0.3,
      'sodium_mg': 1,
    },
  ],
  'totals': {
    'calories': 404,
    'carb_g': 41,
    'protein_g': 17.3,
    'fat_g': 19.7,
    'sodium_mg': 336,
  },
  'notes':
      'Confidence is medium as no specific brands or weights were given. '
      'Butter assumed to be approximately 1 teaspoon (~5g). Eggs assumed '
      'large and scrambled in a small amount of butter or cooking spray, '
      'which is included in the fat and calorie estimate.',
  '_usage': {
    'input_tokens': 812,
    'output_tokens': 233,
    'model': 'anthropic/claude-sonnet-4.6',
    'cost_usd': 0.005931,
  },
};

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

class _MockAuthUser extends Mock implements User {}

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

/// A signed-in client whose `describe-meal` answers run 31's 200 body.
({SupabaseClient client, FunctionsClient functions}) _client() {
  final functions = _MockFunctionsClient();
  when(
    () => functions.invoke('describe-meal', body: any(named: 'body')),
  ).thenAnswer(
    (_) async => FunctionResponse(data: _run31Describe200(), status: 200),
  );
  final authUser = _MockAuthUser();
  when(() => authUser.id).thenReturn(_user);
  final goTrue = fakeGoTrueClient();
  when(() => goTrue.currentUser).thenReturn(authUser);
  final client = fakeSupabaseClient(auth: goTrue) as MockSupabaseClient;
  when(() => client.functions).thenReturn(functions);
  return (client: client, functions: functions);
}

void _verifyCalls(FunctionsClient functions, int n) => verify(
  () => functions.invoke('describe-meal', body: any(named: 'body')),
).called(n);

void main() {
  final content = loadDefaultContent();

  group('DescribeAnalysisController (real notifier)', () {
    late FunctionsClient functions;
    late ProviderContainer container;

    setUp(() {
      final c = _client();
      functions = c.functions;
      container = ProviderContainer(
        overrides: [
          mealAiServiceProvider.overrideWithValue(
            MealAiService(supabase: c.client, report: const NoopReport()),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Log a Meal watches it; the listener stands in for the screen.
      container.listen(describeAnalysisControllerProvider, (_, _) {});
    });

    test('the same text twice is one call and the same result', () async {
      final notifier = container.read(
        describeAnalysisControllerProvider.notifier,
      );

      final first = await notifier.analyze(text: _text);
      final second = await notifier.analyze(text: '  $_text ');

      expect(first.value!.result.items, hasLength(3));
      expect(identical(first.value, second.value), isTrue);
      expect(
        container.read(describeAnalysisControllerProvider).value!.inputText,
        _text,
      );
      _verifyCalls(functions, 1);
    });

    test('changed text is a second call', () async {
      final notifier = container.read(
        describeAnalysisControllerProvider.notifier,
      );

      await notifier.analyze(text: _text);
      await notifier.analyze(text: '$_text and a coffee');

      _verifyCalls(functions, 2);
    });

    test('two taps at once with the same text share one call', () async {
      final notifier = container.read(
        describeAnalysisControllerProvider.notifier,
      );

      final results = await Future.wait([
        notifier.analyze(text: _text),
        notifier.analyze(text: _text),
      ]);

      expect(identical(results[0].value, results[1].value), isTrue);
      _verifyCalls(functions, 1);
    });

    test('clear() forgets it: the next Analyze is a new call', () async {
      final notifier = container.read(
        describeAnalysisControllerProvider.notifier,
      );

      await notifier.analyze(text: _text);
      notifier.clear();
      expect(notifier.storedFor(text: _text), isNull);
      await notifier.analyze(text: _text);

      _verifyCalls(functions, 2);
    });
  });

  testWidgets('Analyze → Review → Back keeps the text; Review again is free; '
      'Log this meal closes Log a Meal', (tester) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = _client();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = _RecordingRepository(database: db);
    final profile = _MockUser();
    when(() => profile.id).thenReturn(_user);
    final users = _MockUserRepo();
    when(() => users.getCurrentUser()).thenAnswer((_) async => profile);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          contentServiceProvider.overrideWith(testContentService),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          mockSharedPreferences(),
          appDatabaseProvider.overrideWithValue(db),
          mealAiServiceProvider.overrideWithValue(
            MealAiService(supabase: c.client, report: const NoopReport()),
          ),
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
        child: wrapForTest(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openLogMealScreen(
                  context,
                  logDate: _logDate,
                  source: 'test',
                ),
                child: const Text('open log a meal'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open log a meal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Describe'));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField), _text);
    await tester.pump();
    expect(find.byType(TokenCostChip), findsOneWidget);
    await tester.tap(find.text('Analyze'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MealReviewScreen), findsOneWidget);
    expect(find.text('Banana'), findsOneWidget);
    _verifyCalls(c.functions, 1);

    // Back lands on Describe, not the Timeline, with the text kept.
    await tester.pageBack();
    // The page transition runs a little over 400 ms.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.byType(MealReviewScreen), findsNothing);
    expect(find.byType(LogMealScreen), findsOneWidget);
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller!.text, _text);
    final reviewAgain = content['meal_log.describe.review_again']!;
    expect(find.text(reviewAgain), findsOneWidget);
    expect(find.text('Analyze'), findsNothing);
    expect(find.byType(TokenCostChip), findsNothing, reason: 'no price');

    // Review again opens the same items without a call.
    await tester.tap(find.text(reviewAgain));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MealReviewScreen), findsOneWidget);
    expect(find.text('Scrambled eggs (x2)'), findsOneWidget);
    expect(find.text('Banana'), findsOneWidget);
    verifyNever(
      () => c.functions.invoke('describe-meal', body: any(named: 'body')),
    );

    // Log this meal from there closes Review and Log a Meal.
    await tester.ensureVisible(find.text('Log this meal'));
    await tester.tap(find.text('Log this meal'));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MealReviewScreen), findsNothing);
    expect(find.byType(LogMealScreen), findsNothing);
    expect(find.text('open log a meal'), findsOneWidget);
    final rows = await tester.runAsync(() => repo.getRecentLogs(_user));
    expect(
      rows!.single.name,
      'Scrambled eggs, whole wheat toast with butter, and banana',
    );
  });
}
